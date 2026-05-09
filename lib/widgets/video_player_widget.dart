import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
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
      if (mounted) {
        setState(() {
          _buffering = buffering;
        });
      }
    });

    _player.stream.completed.listen((completed) {
      if (completed && mounted) {
        _play(); 
      }
    });
    
    _player.stream.playing.listen((playing) {
      debugPrint('MEDIA_KIT_PLAYING_STATE: $playing');
    });
  }

  void _play() {
    final url = widget.channel.streamUrl;
    if (url.isNotEmpty) {
      debugPrint('MEDIA_KIT_PLAYING: $url');
      setState(() {
        _error = null;
        _buffering = true;
      });
      _player.open(Media(url)).catchError((e) {
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
    if (oldWidget.channel.url != widget.channel.url) {
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
          if (widget.channel.url.isNotEmpty && _error == null)
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

          if (widget.channel.url.isEmpty)
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
