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

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _play();

    _player.stream.error.listen((error) {
      setState(() {
        _error = error;
      });
    });
  }

  void _play() {
    if (widget.url.isNotEmpty) {
      _player.open(Media(widget.url));
    }
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _error = null;
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
    if (_error != null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Text(
            'call divyam the error is : [$_error]',
            style: const TextStyle(color: Colors.red, fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (widget.url.isEmpty) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text(
            'Waiting for stream link...',
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
      );
    }

    return Video(
      controller: _controller,
      fill: Colors.black,
    );
  }
}
