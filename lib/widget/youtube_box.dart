import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class YouTubeBox extends StatefulWidget {
  final String youtubeUrl;

  const YouTubeBox({
    super.key,
    required this.youtubeUrl,
  });

  @override
  State<YouTubeBox> createState() => _YouTubeBoxState();
}

class _YouTubeBoxState extends State<YouTubeBox> {
  late YoutubePlayerController _controller;
  String? _videoId;

  @override
  void initState() {
    super.initState();

    /// ⭐ Convert ANY youtube format → videoId
    _videoId =
        YoutubePlayerController.convertUrlToId(widget.youtubeUrl) ??
            _extractIdFromIframe(widget.youtubeUrl) ??
            widget.youtubeUrl;

    /// ⭐ Stable controller (LIVE safe)
    _controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        strictRelatedVideos: true,
        enableJavaScript: true,
        playsInline: true,
      ),
    );

    /// ⭐ LIVE streams ke liye BEST method
    if (_videoId != null && _videoId!.isNotEmpty) {
      _controller.cueVideoById(videoId: _videoId!);
    }
  }

  /// iframe support
  String? _extractIdFromIframe(String text) {
    final reg = RegExp(r'embed\/([a-zA-Z0-9_-]+)');
    final match = reg.firstMatch(text);
    return match?.group(1);
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_videoId == null || _videoId!.isEmpty) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: YoutubePlayer(
          controller: _controller,
        ),
      ),
    );
  }
}
