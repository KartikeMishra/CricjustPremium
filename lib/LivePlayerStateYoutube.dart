import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class TestLivePlayer extends StatefulWidget {
  final String youtubeUrl;

  const TestLivePlayer({
    super.key,
    required this.youtubeUrl,
  });

  @override
  State<TestLivePlayer> createState() => _TestLivePlayerState();
}

class _TestLivePlayerState extends State<TestLivePlayer> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();

    final videoId =
        YoutubePlayerController.convertUrlToId(widget.youtubeUrl) ??
            _extractVideoId(widget.youtubeUrl);

    _controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        strictRelatedVideos: true,
        playsInline: true,

        /// ⭐ LIVE ERROR 152 FIX
        origin: "https://www.youtube.com",
      ),
    );

    _controller.cueVideoById(videoId: videoId);
  }

  String _extractVideoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;

    final v = uri.queryParameters['v'];
    if (v != null && v.isNotEmpty) return v;

    if (uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }
    return url;
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: YoutubePlayer(controller: _controller),
    );
  }
}
