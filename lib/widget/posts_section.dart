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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with icon
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.article, color: Colors.blue, size: 18),
                    SizedBox(width: 6),
                    Text("Latest News", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
                GestureDetector(
                  onTap: widget.onLoadMore,
                  child: const Row(
                    children: [
                      Text("Load More", style: TextStyle(color: Colors.blue)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios, size: 12, color: Colors.blue),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          _isLoading
              ? Column(
            children: List.generate(3, (index) => _buildShimmerCard()),
          )
              : Column(children: _posts.map((post) => PostCard(post: post)).toList()),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildShimmerCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          height: 220,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
