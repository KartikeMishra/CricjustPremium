// lib/screen/post_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';

import '../model/post_detail_model.dart';
import '../service/post_service.dart';
import '../theme/color.dart';
import '../theme/text_styles.dart';

class PostDetailScreen extends StatefulWidget {
  final int postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late Future<PostDetailModel?> _postFuture;

  @override
  void initState() {
    super.initState();
    _postFuture = PostService.fetchSinglePost(widget.postId);
  }

  void _sharePost(PostDetailModel post) {
    final shareText =
        '${post.title}\n\nBy ${post.author} on ${post.date}\n\nRead more: https://cricjust.in/post?id=${widget.postId}';
    Share.share(shareText, subject: post.title);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? Theme.of(context).scaffoldBackgroundColor
          : Colors.grey[100],

      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: isDark
              ? const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                )
              : const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, Color(0xFF42A5F5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: const Text(
              "Post Detail",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              FutureBuilder<PostDetailModel?>(
                future: _postFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return IconButton(
                      icon: const Icon(Icons.share, color: Colors.white),
                      onPressed: () => _sharePost(snapshot.data!),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),

      body: FutureBuilder<PostDetailModel?>(
        future: _postFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('No post found.'));
          }

          final post = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title,
                  style: AppTextStyles.sectionTitle.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  "${post.date} · By ${post.author}",
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(
                      imageUrl: post.image,
                      fit: BoxFit.cover,
                      placeholder: (c, u) => Container(
                        color: Colors.grey[300],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (c, u, e) => Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.broken_image, size: 50),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: post.categories
                      .map(
                        (cat) => Chip(
                          label: Text(cat),
                          backgroundColor: isDark
                              ? Colors.grey[800]
                              : Colors.blue.shade50,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withOpacity(0.5)
                            : Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Html(data: post.description),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
