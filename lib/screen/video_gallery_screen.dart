// lib/screen/videos/video_gallery_screen.dart
import 'package:cricjust_premium/screen/youtube_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart'; // ⬅️ add
import '../../service/youtube_video_service.dart';
import '../../model/youtube_video_model.dart';
import '../../theme/color.dart';
import '../widget/video_card.dart';

class VideoGalleryScreen extends StatefulWidget {
  const VideoGalleryScreen({super.key});

  @override
  State<VideoGalleryScreen> createState() => _VideoGalleryScreenState();
}

class _VideoGalleryScreenState extends State<VideoGalleryScreen> {
  static const int _limit = 12;

  final _scroll = ScrollController();
  final List<YoutubeVideo> _items = [];
  bool _loading = false;
  bool _done = false;
  int _skip = 0;

  @override
  void initState() {
    super.initState();
    _fetch();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _fetch({bool refresh = false}) async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      if (refresh) {
        _skip = 0;
        _items.clear();
        _done = false;
      }
      final page = await YoutubeVideoService.fetch(limit: _limit, skip: _skip);
      if (page.isEmpty) {
        _done = true;
      } else {
        _items.addAll(page);
        _skip += _limit;
      }
    } catch (_) {
      // optionally show a SnackBar
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onScroll() {
    if (_done || _loading) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _fetch();
    }
  }

  Future<void> _openVideo(YoutubeVideo v) async {
    final id = (v.videoId ?? '').trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This video has no videoId')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => YoutubePlayerScreen(
          videoId: id,
          title: v.title ?? 'Video',
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? null
                : const LinearGradient(
              colors: [AppColors.primary, Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            color: isDark ? const Color(0xFF1E1E1E) : null,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
            systemOverlayStyle: SystemUiOverlayStyle.light,
            title: const Text(
              'Videos',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),

      body: RefreshIndicator(
        onRefresh: () => _fetch(refresh: true),
        child: _items.isEmpty && _loading
            ? _GridShimmer()
            : GridView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 230,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _items.length + (_loading ? 2 : 0),
          itemBuilder: (_, i) {
            if (i >= _items.length) return const _TileShimmer();

            final video = _items[i];
            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _openVideo(video),          // ⬅️ open on tap
              child: VideoCard(
                video: video,
                height: 210,
                margin: EdgeInsets.zero,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GridShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 230,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => const _TileShimmer(),
    );
  }
}

class _TileShimmer extends StatelessWidget {
  const _TileShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.white10
          : Colors.black12,
      highlightColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.white24
          : Colors.black26,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}
