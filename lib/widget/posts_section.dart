import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../model/post_model.dart';
import '../service/post_service.dart';
import 'post_card.dart';

class PostsSection extends StatefulWidget {
  final VoidCallback onLoadMore;

  const PostsSection({super.key, required this.onLoadMore});

  @override
  State<PostsSection> createState() => _PostsSectionState();
}

class _PostsSectionState extends State<PostsSection> {
  List<PostModel> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    try {
      final posts = await PostService.fetchPosts(limit: 3);
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading posts: $e");
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[600]! : Colors.grey[100]!;

    return Column(
      children: [
        _isLoading
            ? Column(
          children: List.generate(3, (_) => _buildShimmerCard(baseColor, highlightColor)),
        )
            : Column(
          children: _posts.map((post) => PostCard(post: post)).toList(),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: widget.onLoadMore,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text("See All News"),
        ),
      ],
    );
  }

  Widget _buildShimmerCard(Color base, Color highlight) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: Container(
          height: 220,
          width: double.infinity,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
