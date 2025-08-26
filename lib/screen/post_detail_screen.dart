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
    final text =
        '${post.title}\n\nBy ${post.author} on ${post.date}\n\nRead more: https://cricjust.in/post?id=${widget.postId}';
    Share.share(text, subject: post.title);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
      isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.grey[100],

      // glossy app bar
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: isDark
              ? const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius:
            BorderRadius.vertical(bottom: Radius.circular(20)),
          )
              : const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius:
            BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: const Text(
              'Post Detail',
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
                builder: (context, snap) {
                  final post = snap.data;
                  if (post == null) return const SizedBox.shrink();
                  return IconButton(
                    icon: const Icon(Icons.share, color: Colors.white),
                    onPressed: () => _sharePost(post),
                  );
                },
              ),
            ],
          ),
        ),
      ),

      body: FutureBuilder<PostDetailModel?>(
        future: _postFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final post = snap.data;
          if (post == null) {
            return const Center(child: Text('No post found.'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // title
                Text(
                  post.title,
                  style: AppTextStyles.sectionTitle.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 8),
                // meta
                Text(
                  '${post.date} · By ${post.author}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 16),

                // hero image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(
                      imageUrl: post.image,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: Colors.grey[300],
                        child:
                        const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.broken_image, size: 50),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // categories
                if (post.categories.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    children: post.categories
                        .map(
                          (c) => Chip(
                        label: Text(c),
                        backgroundColor:
                        isDark ? Colors.grey[800] : Colors.blue[50],
                      ),
                    )
                        .toList(),
                  ),

                const SizedBox(height: 16),

                // content
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.5)
                            : Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Html(
                    // NOTE: do not mark as `const`
                    data: post.description,
                    style: {
                      'body': Style(
                        fontSize: FontSize(16),
                        lineHeight: LineHeight(1.5),
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      'p': Style(margin: Margins.only(bottom: 12)),
                      'h1': Style(
                          fontSize: FontSize(22),
                          fontWeight: FontWeight.w800),
                      'h2': Style(
                          fontSize: FontSize(20),
                          fontWeight: FontWeight.w800),
                      'h3': Style(
                          fontSize: FontSize(18),
                          fontWeight: FontWeight.w700),
                      'a': Style(
                        color: isDark
                            ? Colors.lightBlue.shade300
                            : AppColors.primary,
                        textDecoration: TextDecoration.underline,
                      ),
                      'img': Style(margin: Margins.symmetric(vertical: 8)),
                      'ul':
                      Style(margin: Margins.only(left: 16, bottom: 12)),
                      'ol':
                      Style(margin: Margins.only(left: 16, bottom: 12)),
                    },
                    // Must be synchronous & have 4 params to match type
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
