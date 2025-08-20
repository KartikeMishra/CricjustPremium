import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../service/page_content_service.dart';
import '../theme/color.dart';

class PolicyViewSheet extends StatelessWidget {
  final int pageId;
  final String fallbackTitle; // e.g. 'Privacy Policy'
  const PolicyViewSheet({super.key, required this.pageId, required this.fallbackTitle});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF121212) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: dark
                    ? null
                    : const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF42A5F5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                color: dark ? const Color(0xFF1E1E1E) : null,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fallbackTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 56), // balance close button
                ],
              ),
            ),
            // Body
            Expanded(
              child: FutureBuilder<Map<String, String>>(
                future: PageContentService.fetchPage(pageId: pageId),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError || !snap.hasData) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Failed to load content.\n${snap.error ?? ''}',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: dark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    );
                  }
                  final title = snap.data!['title']!.trim().isEmpty
                      ? fallbackTitle
                      : snap.data!['title']!;
                  final html = snap.data!['content'] ?? '';
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: dark ? Colors.white : Colors.black)),
                      const SizedBox(height: 12),
                      Html(data: html), // renders headings, paragraphs, links
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
