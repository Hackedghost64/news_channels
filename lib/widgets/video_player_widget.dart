import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:video_player/video_player.dart' as vp;

import '../models/channel.dart';

class VideoPlayerWidget extends StatefulWidget {
  const VideoPlayerWidget({
    super.key,
    required this.channel,
    required this.streamUrl,
    required this.headers,
    required this.onPreviousChannel,
    required this.onNextChannel,
    required this.onShowChannelGuide,
    this.onPlaybackUnavailable,
  });

  final Channel channel;
  final String streamUrl;
  final Map<String, String> headers;
  final VoidCallback onPreviousChannel;
  final VoidCallback onNextChannel;
  final VoidCallback onShowChannelGuide;
  final ValueChanged<String>? onPlaybackUnavailable;

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  mk.Player? _mkPlayer;
  mkv.VideoController? _mkController;
  vp.VideoPlayerController? _vpController;
  Timer? _controlsTimer;

  String? _error;
  bool _isLoading = true;
  bool _showControls = true;
  bool _isPlaying = false;
  bool _isMuted = false;
  bool _hasReportedPlaybackUnavailable = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel.url != widget.channel.url ||
        oldWidget.streamUrl != widget.streamUrl ||
        oldWidget.headers.toString() != widget.headers.toString()) {
      _hasReportedPlaybackUnavailable = false;
      _initializePlayer();
    }
  }

  Future<void> _initializePlayer() async {
    if (widget.streamUrl.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Stream URL is empty.';
        _isLoading = false;
      });
      return;
    }

    _cancelControlsTimer();

    if (mounted) {
      setState(() {
        _error = null;
        _isLoading = true;
        _showControls = true;
      });
      _hasReportedPlaybackUnavailable = false;
    }

    try {
      await _disposePlayers();

      if (kIsWeb) {
        final controller = vp.VideoPlayerController.networkUrl(
          Uri.parse(widget.streamUrl),
          httpHeaders: widget.headers,
        );
        _vpController = controller;
        controller.addListener(_handleWebControllerUpdate);
        await controller.initialize();
        await controller.setLooping(true);
        await controller.play();

        if (!mounted) {
          return;
        }
        setState(() {
          _isPlaying = controller.value.isPlaying;
          _isMuted = controller.value.volume == 0;
          _isLoading = false;
        });
      } else {
        final player = mk.Player();
        _mkPlayer = player;
        _mkController = mkv.VideoController(player);

        player.stream.playing.listen((playing) {
          if (!mounted) {
            return;
          }
          setState(() {
            _isPlaying = playing;
          });
        });

        player.stream.buffering.listen((buffering) {
          if (!mounted) {
            return;
          }
          setState(() {
            _isLoading = buffering;
          });
        });

        player.stream.volume.listen((volume) {
          if (!mounted) {
            return;
          }
          setState(() {
            _isMuted = volume == 0;
          });
        });

        player.stream.error.listen((error) {
          if (!mounted) {
            return;
          }
          debugPrint('MEDIA_KIT_ERROR: $error');
          setState(() {
            _error = error.toString();
            _isLoading = false;
            _showControls = true;
          });
          _reportPlaybackUnavailableIfNeeded(_error!);
        });

        await player.open(
          mk.Media(widget.streamUrl, httpHeaders: widget.headers),
        );

        if (!mounted) {
          return;
        }
        setState(() {
          _isPlaying = true;
          _isLoading = false;
        });
      }

      _scheduleControlsHide();
    } catch (error, stackTrace) {
      debugPrint('PLAYER_INIT_ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _formatPlaybackError(error.toString());
        _isLoading = false;
        _showControls = true;
      });
      _reportPlaybackUnavailableIfNeeded(_error!);
    }
  }

  Future<void> _disposePlayers() async {
    final webController = _vpController;
    if (webController != null) {
      webController.removeListener(_handleWebControllerUpdate);
      await webController.dispose();
      _vpController = null;
    }

    await _mkPlayer?.dispose();
    _mkPlayer = null;
    _mkController = null;
  }

  void _handleWebControllerUpdate() {
    final controller = _vpController;
    if (controller == null || !mounted) {
      return;
    }

    final value = controller.value;
    setState(() {
      _isLoading = value.isBuffering;
      _isPlaying = value.isPlaying;
      _isMuted = value.volume == 0;
      if (value.hasError) {
        _error = _formatPlaybackError(
          value.errorDescription ?? 'Unknown web playback error',
        );
        _showControls = true;
        _reportPlaybackUnavailableIfNeeded(_error!);
      }
    });
  }

  void _reportPlaybackUnavailableIfNeeded(String message) {
    if (_hasReportedPlaybackUnavailable) {
      return;
    }
    _hasReportedPlaybackUnavailable = true;
    widget.onPlaybackUnavailable?.call(message);
  }

  String _formatPlaybackError(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('demuxer') && normalized.contains('parse')) {
      return 'The stream responded, but this player could not parse the HLS '
          'playlist. This source likely needs different headers or uses a '
          'playlist variant that VLC accepts more easily than the app player.';
    }
    return message;
  }

  Future<void> _togglePlayback() async {
    try {
      if (kIsWeb) {
        final controller = _vpController;
        if (controller == null) {
          return;
        }

        if (controller.value.isPlaying) {
          await controller.pause();
        } else {
          await controller.play();
        }
      } else {
        final player = _mkPlayer;
        if (player == null) {
          return;
        }

        if (_isPlaying) {
          await player.pause();
        } else {
          await player.play();
        }
      }

      _showControlsTemporarily();
    } catch (error, stackTrace) {
      debugPrint('PLAYER_TOGGLE_ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _toggleMute() async {
    try {
      if (kIsWeb) {
        final controller = _vpController;
        if (controller == null) {
          return;
        }
        await controller.setVolume(_isMuted ? 1 : 0);
      } else {
        final player = _mkPlayer;
        if (player == null) {
          return;
        }
        await player.setVolume(_isMuted ? 100 : 0);
      }

      _showControlsTemporarily();
    } catch (error, stackTrace) {
      debugPrint('PLAYER_VOLUME_ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _error = error.toString();
        });
      }
    }
  }

  void _cancelControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = null;
  }

  void _scheduleControlsHide() {
    if (_error != null || !_showControls) {
      return;
    }

    _cancelControlsTimer();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showControls = false;
      });
    });
  }

  void _showControlsTemporarily() {
    if (!mounted) {
      return;
    }

    setState(() {
      _showControls = true;
    });
    _scheduleControlsHide();
  }

  void _handleDoubleTap(TapDownDetails details, BoxConstraints constraints) {
    final midpoint = constraints.maxWidth / 2;
    if (details.localPosition.dx < midpoint) {
      widget.onPreviousChannel();
    } else {
      widget.onNextChannel();
    }
    _showControlsTemporarily();
  }

  @override
  void dispose() {
    _cancelControlsTimer();
    _disposePlayers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _showControlsTemporarily,
          onDoubleTapDown: (details) => _handleDoubleTap(details, constraints),
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity.abs() < 250) {
              return;
            }
            if (velocity < 0) {
              widget.onNextChannel();
            } else {
              widget.onPreviousChannel();
            }
            _showControlsTemporarily();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: Colors.black, child: _buildVideoSurface()),
              if (_showControls || _error != null)
                _PlayerControlsOverlay(
                  channelName: widget.channel.name,
                  isPlaying: _isPlaying,
                  isMuted: _isMuted,
                  isLoading: _isLoading,
                  error: _error,
                  onPreviousChannel: widget.onPreviousChannel,
                  onNextChannel: widget.onNextChannel,
                  onTogglePlayback: _togglePlayback,
                  onToggleMute: _toggleMute,
                  onRetry: _initializePlayer,
                  onShowChannelGuide: widget.onShowChannelGuide,
                ),
              if (_isLoading && _error == null)
                const Center(
                  child: CircularProgressIndicator(color: Colors.redAccent),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideoSurface() {
    if (kIsWeb && _vpController != null && _vpController!.value.isInitialized) {
      return Center(
        child: AspectRatio(
          aspectRatio: _vpController!.value.aspectRatio == 0
              ? 16 / 9
              : _vpController!.value.aspectRatio,
          child: vp.VideoPlayer(_vpController!),
        ),
      );
    }

    if (!kIsWeb && _mkController != null) {
      return mkv.Video(
        controller: _mkController!,
        fit: BoxFit.contain,
        fill: Colors.black,
      );
    }

    return const SizedBox.expand();
  }
}

class _PlayerControlsOverlay extends StatelessWidget {
  const _PlayerControlsOverlay({
    required this.channelName,
    required this.isPlaying,
    required this.isMuted,
    required this.isLoading,
    required this.error,
    required this.onPreviousChannel,
    required this.onNextChannel,
    required this.onTogglePlayback,
    required this.onToggleMute,
    required this.onRetry,
    required this.onShowChannelGuide,
  });

  final String channelName;
  final bool isPlaying;
  final bool isMuted;
  final bool isLoading;
  final String? error;
  final VoidCallback onPreviousChannel;
  final VoidCallback onNextChannel;
  final VoidCallback onTogglePlayback;
  final VoidCallback onToggleMute;
  final VoidCallback onRetry;
  final VoidCallback onShowChannelGuide;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.64),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.72),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Text(
                    channelName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 16),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ControlButton(
                    icon: Icons.skip_previous_rounded,
                    tooltip: 'Previous channel',
                    onPressed: onPreviousChannel,
                  ),
                  const SizedBox(width: 12),
                  _ControlButton(
                    icon: isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    tooltip: isPlaying ? 'Pause' : 'Play',
                    isPrimary: true,
                    onPressed: onTogglePlayback,
                  ),
                  const SizedBox(width: 12),
                  _ControlButton(
                    icon: Icons.skip_next_rounded,
                    tooltip: 'Next channel',
                    onPressed: onNextChannel,
                  ),
                  const SizedBox(width: 12),
                  _ControlButton(
                    icon: Icons.grid_view_rounded,
                    tooltip: 'Channel guide',
                    onPressed: onShowChannelGuide,
                  ),
                  const SizedBox(width: 12),
                  _ControlButton(
                    icon: isMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    tooltip: isMuted ? 'Unmute' : 'Mute',
                    onPressed: onToggleMute,
                  ),
                  const SizedBox(width: 12),
                  _ControlButton(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Retry stream',
                    onPressed: onRetry,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  error == null
                      ? isLoading
                            ? 'Buffering live stream...'
                            : 'Double tap or swipe to change channel'
                      : 'Retry the stream or open the guide to switch sources.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isPrimary = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isPrimary
            ? Colors.redAccent.withValues(alpha: 0.95)
            : Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: isPrimary ? 68 : 56,
            height: isPrimary ? 68 : 56,
            child: Icon(icon, color: Colors.white, size: isPrimary ? 34 : 26),
          ),
        ),
      ),
    );
  }
}
