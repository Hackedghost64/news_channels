import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String url;
  final String channelName;

  const VideoPlayerWidget({
    super.key,
    required this.url,
    required this.channelName,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late final Player _player;
  late final VideoController _controller;
  String? _error;
  bool _buffering = true;

  @override
  void initState() {
    super.initState();
    _player = Player(
      configuration: const PlayerConfiguration(
        muted: false,
        bufferSize: 1024 * 1024 * 10, // 10MB buffer
      ),
    );
    _controller = VideoController(_player);
    
    _setupListeners();
    _play();
  }

  void _setupListeners() {
    _player.stream.error.listen((error) {
      debugPrint('MEDIA_KIT_ERROR: $error');
      if (mounted) {
        setState(() {
          _error = error;
          _buffering = false;
        });
      }
    });

    _player.stream.buffering.listen((buffering) {
      debugPrint('MEDIA_KIT_BUFFERING: $buffering');
      if (mounted) {
        setState(() {
          _buffering = buffering;
        });
      }
    });

    _player.stream.completed.listen((completed) {
      debugPrint('MEDIA_KIT_COMPLETED: $completed');
      if (completed && mounted) {
        _play(); // Auto-restart if it ends
      }
    });
    
    _player.stream.status.listen((status) {
      debugPrint('MEDIA_KIT_STATUS: $status');
    });
  }

  void _play() {
    if (widget.url.isNotEmpty) {
      debugPrint('MEDIA_KIT_PLAYING: ${widget.url}');
      setState(() {
        _error = null;
        _buffering = true;
      });
      _player.open(Media(widget.url)).then((_) {
        debugPrint('MEDIA_KIT_OPEN_SUCCESS');
      }).catchError((e) {
        debugPrint('MEDIA_KIT_OPEN_ERROR: $e');
        if (mounted) {
          setState(() {
            _error = e.toString();
            _buffering = false;
          });
        }
      });
    }
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _play();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          if (widget.url.isNotEmpty && _error == null)
            Video(
              controller: _controller,
              fill: Colors.black,
            ),
          
          if (_buffering && _error == null)
            const Center(
              child: CircularProgressIndicator(color: Colors.red),
            ),

          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
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
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _play,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      child: const Text('Retry Stream'),
                    ),
                  ],
                ),
              ),
            ),

          if (widget.url.isEmpty)
            const Center(
              child: Text(
                'Waiting for stream link...',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
        ],
      ),
    );
  }
}
