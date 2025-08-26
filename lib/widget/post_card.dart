// lib/widget/post_card.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import '../model/post_model.dart';
import '../screen/post_detail_screen.dart';

class PostCard extends StatelessWidget {
  final PostModel post;

  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostDetailScreen(postId: post.id)),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: isDark
              ? null
              : const LinearGradient(
            colors: [Color(0xFFEAF4FF), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          color: isDark ? const Color(0xFF1F1F1F) : null,
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black26 : Colors.blue.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🖼️ Image (with proper cache sizing)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final screenW = MediaQuery.of(context).size.width;
                    final dpr = MediaQuery.of(context).devicePixelRatio;
                    final logicalW = (constraints.maxWidth.isFinite
                        ? constraints.maxWidth
                        : screenW) *
                        (16 / 9); // approximate horizontal pixels shown in 16:9
                    final cacheW =
                    (logicalW * dpr).clamp(480, 2048).toInt(); // guard rails

                    return AspectRatio(
                      aspectRatio: 16 / 9,
                      child: CachedNetworkImage(
                        imageUrl: post.image,
                        width: double.infinity,
                        fit: BoxFit.cover,

                        // ✅ use memCacheWidth / maxWidthDiskCache for CachedNetworkImage
                        memCacheWidth: cacheW,
                        maxWidthDiskCache: cacheW,

                        placeholder: (context, url) => Shimmer.fromColors(
                          baseColor:
                          isDark ? Colors.grey[800]! : Colors.grey[300]!,
                          highlightColor:
                          isDark ? Colors.grey[700]! : Colors.grey[100]!,
                          child: Container(
                            color: isDark
                                ? Colors.grey[850]
                                : Colors.grey[300],
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color:
                          isDark ? Colors.grey[850] : Colors.grey[300],
                          child: const Center(
                            child: Icon(Icons.broken_image, size: 40),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // 📝 Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color:
                          isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        post.shortInfo,
                        style:
                        Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? Colors.white70
                              : Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "By ${post.author} • ${post.date}",
                        style:
                        Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isDark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if ((post.categories).isNotEmpty)
                        Wrap(
                          spacing: 6,
                          runSpacing: -8,
                          children: post.categories
                              .map(
                                (cat) => Chip(
                              label: Text(
                                cat,
                                style: const TextStyle(fontSize: 12),
                              ),
                              backgroundColor: isDark
                                  ? Colors.grey.shade800
                                  : Colors.blue.shade50,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                            ),
                          )
                              .toList(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
