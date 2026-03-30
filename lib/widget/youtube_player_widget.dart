import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:flutter/material.dart';

class MatchVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const MatchVideoPlayer({super.key, required this.videoUrl});

  @override
  State<MatchVideoPlayer> createState() => _MatchVideoPlayerState();
}

class _MatchVideoPlayerState extends State<MatchVideoPlayer> {
  late YoutubePlayerController _controller;

  @override
  @override
  void initState() {
    super.initState();

    final videoId = YoutubePlayer.convertUrlToId(widget.videoUrl) ?? ''; // ✅

    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
      ),
      builder: (context, player) {
        return Column(
          children: [
            player,
          ],
        );
      },
    );
  }
}