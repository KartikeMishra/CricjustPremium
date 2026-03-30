import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class YoutubeBox extends StatefulWidget {
  final String videoId;

  const YoutubeBox({super.key, required this.videoId});

  @override
  State<YoutubeBox> createState() => _YoutubeBoxState();
}

class _YoutubeBoxState extends State<YoutubeBox> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();

    _controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
      ),
    );

    _controller.loadVideoById(videoId: widget.videoId);

    /// ✅ NEW METHOD
    Future.delayed(const Duration(milliseconds: 300), () {
      _controller.playVideo();
    });
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerScaffold(
      controller: _controller,
      builder: (context, player) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: player,
          ),
        );
      },
    );
  }
}