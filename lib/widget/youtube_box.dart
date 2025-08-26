// lib/widget/youtube_box.dart
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/youtube_utils.dart';

class YouTubeBox extends StatefulWidget {
  final String youtubeUrl; // raw URL from your API

  const YouTubeBox({super.key, required this.youtubeUrl});

  @override
  State<YouTubeBox> createState() => _YouTubeBoxState();
}

class _YouTubeBoxState extends State<YouTubeBox> {
  YoutubePlayerController? _controller;
  String? _videoId;

  @override
  void initState() {
    super.initState();
    _videoId = YoutubeUtils.extractVideoId(widget.youtubeUrl);
    if (_videoId != null) {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: _videoId!,
        autoPlay: false,
        params: const YoutubePlayerParams(
          showControls: true,
          enableCaption: true,
          playsInline: true,
          showFullscreenButton: true,
          strictRelatedVideos: true,
          // You can add: startAt, endAt, etc. if needed
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_videoId == null) {
      // Fallback: show button to open the original URL
      return _OpenExternallyCard(url: widget.youtubeUrl);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: YoutubePlayer(controller: _controller!),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => launchUrl(Uri.parse(widget.youtubeUrl), mode: LaunchMode.externalApplication),
            child: const Text('Open in YouTube'),
          ),
        ),
      ],
    );
  }
}

class _OpenExternallyCard extends StatelessWidget {
  final String url;
  const _OpenExternallyCard({required this.url});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('YouTube video', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                child: const Text('Play on YouTube'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
