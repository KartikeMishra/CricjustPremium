import 'package:cricjust_premium/widget/video_card.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../service/youtube_video_service.dart';
import '../../model/youtube_video_model.dart';
import '../../theme/color.dart';
import '../screen/video_gallery_screen.dart';

class VideosHomeSection extends StatefulWidget {
  const VideosHomeSection({super.key});

  @override
  State<VideosHomeSection> createState() => _VideosHomeSectionState();
}

class _VideosHomeSectionState extends State<VideosHomeSection> {
  late Future<List<YoutubeVideo>> _future;
  final _page = PageController(viewportFraction: 0.90);
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _future = YoutubeVideoService.fetch(limit: 5, skip: 0);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.28)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.ondemand_video, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Videos',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VideoGalleryScreen()),
                  );
                },
                child: const Text('See All'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Content
          FutureBuilder<List<YoutubeVideo>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return _LoadingCarousel();
              }
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Failed to load videos',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }
              final items = snap.data ?? const <YoutubeVideo>[];
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No videos available'),
                );
              }
              return Column(
                children: [
                  SizedBox(
                    height: 210,
                    child: PageView.builder(
                      controller: _page,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemCount: items.length,
                      itemBuilder: (_, i) => VideoCard(video: items[i]),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Dots(count: items.length, index: _index),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LoadingCarousel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.white10
              : Colors.black12,
          highlightColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.white24
              : Colors.black26,
          child: Container(
            width: 300,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: 3,
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;
  const _Dots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 6,
          width: active ? 18 : 6,
          decoration: BoxDecoration(
            color: active
                ? (isDark ? Colors.white : AppColors.primary)
                : (isDark ? Colors.white24 : Colors.black12),
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }
}
