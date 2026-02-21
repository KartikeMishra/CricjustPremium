import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../model/post_model.dart';
import '../service/post_service.dart';
import 'post_card.dart';
import '../theme/color.dart';

class PostsSection extends StatefulWidget {
  final VoidCallback onLoadMore;
  final void Function(bool hasData)? onDataLoaded;

  const PostsSection({
    super.key,
    required this.onLoadMore,
    this.onDataLoaded,
  });

  @override
  State<PostsSection> createState() => _PostsSectionState();
}

class _PostsSectionState extends State<PostsSection>
    with AutomaticKeepAliveClientMixin {
  // ---------------- CACHE ----------------
  static List<PostModel>? _cache;
  static DateTime? _cacheTime;
  static const Duration _ttl = Duration(seconds: 30);
  // --------------------------------------

  List<PostModel> _posts = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    // ✅ Serve from cache if fresh
    if (_cache != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _ttl) {
      _posts = _cache!;
      _isLoading = false;
      widget.onDataLoaded?.call(_posts.isNotEmpty);
      if (mounted) setState(() {});
      return;
    }

    int retry = 0;

    while (retry < 3) {
      try {
        final posts = await PostService
            .fetchPosts(limit: 3)
            .timeout(const Duration(seconds: 6));

        _cache = posts;
        _cacheTime = DateTime.now();

        if (!mounted) return;
        setState(() {
          _posts = posts;
          _isLoading = false;
        });

        widget.onDataLoaded?.call(posts.isNotEmpty);
        return;
      } catch (_) {
        retry++;
        await Future.delayed(const Duration(milliseconds: 400));
      }
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    widget.onDataLoaded?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 🔑 keep-alive required

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[600]! : Colors.grey[100]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isLoading)
          Column(
            children: List.generate(
              3,
                  (_) => _buildShimmerCard(baseColor, highlightColor),
            ),
          )
        else if (_posts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No news available')),
          )
        else
          Column(
            children: _posts.map((post) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF7FAFC), Colors.white],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: PostCard(post: post),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton.icon(
            onPressed: widget.onLoadMore,
            icon: const Icon(Icons.newspaper_outlined),
            label: const Text("See All News"),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: AppColors.primary,
              padding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 3,
              shadowColor: Colors.blue.shade100,
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildShimmerCard(Color base, Color highlight) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: Container(
          height: 220,
          width: double.infinity,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}
