import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:video_player/video_player.dart' as vp;
import '../models/channel.dart';

class VideoPlayerWidget extends StatefulWidget {
  final Channel channel;

  const VideoPlayerWidget({
    super.key,
    required this.channel,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  // Media Kit (TV/Mobile)
  mk.Player? _mkPlayer;
  mkv.VideoController? _mkController;

  // Video Player (Web)
  vp.VideoPlayerController? _vpController;

  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    final url = widget.channel.streamUrl;
    if (url.isEmpty) return;

    setState(() {
      _error = null;
      _isLoading = true;
    });

    try {
      if (kIsWeb) {
        await _disposePlayers();
        _vpController = vp.VideoPlayerController.networkUrl(Uri.parse(url));
        await _vpController!.initialize();
        _vpController!.play();
        _vpController!.setLooping(true);
        if (mounted) setState(() => _isLoading = false);
      } else {
        await _disposePlayers();
        _mkPlayer = mk.Player();
        _mkController = mkv.VideoController(_mkPlayer!);
        
        _mkPlayer!.stream.error.listen((error) {
          debugPrint('MEDIA_KIT_ERROR: $error');
          if (mounted) setState(() => _error = error.toString());
        });

        _mkPlayer!.stream.buffering.listen((buffering) {
          if (mounted) setState(() => _isLoading = buffering);
        });

        await _mkPlayer!.open(mk.Media(url));
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('PLAYER_INIT_ERROR: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _disposePlayers() async {
    await _mkPlayer?.dispose();
    await _vpController?.dispose();
    _mkPlayer = null;
    _vpController = null;
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel.url != widget.channel.url) {
      _initializePlayer();
    }
  }

  @override
  void dispose() {
    _disposePlayers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Web Player
          if (kIsWeb && _vpController != null && _vpController!.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: _vpController!.value.aspectRatio,
                child: vp.VideoPlayer(_vpController!),
              ),
            ),

          // TV Player (Media Kit)
          if (!kIsWeb && _mkController != null)
            mkv.Video(
              controller: _mkController!,
              fill: Colors.black,
            ),

          if (_isLoading && _error == null)
            const Center(child: CircularProgressIndicator(color: Colors.red)),

          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'call divyam the error is : [$_error]',
                      style: const TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _initializePlayer,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
