// lib/html_bottom_sheet.dart
// Bottom sheet that fetches and renders a remote HTML page (WordPress endpoint).
// Usage:
// HtmlBottomSheet.show(context, pageId: 3554, fallbackTitle: 'Cricjust — FAQ');

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart'; // <-- NEW

/// Minimal page model
class _PageContent {
  final String title;
  final String html;
  const _PageContent({required this.title, required this.html});
}

/// Simple memory cache (per session) to avoid re-fetching
class _PageCache {
  static final _mem = <int, _PageContent>{};
  static _PageContent? get(int id) => _mem[id];
  static void set(int id, _PageContent page) => _mem[id] = page;
}

class HtmlBottomSheet {
  /// One-liner to open the sheet anywhere
  static Future<void> show(
      BuildContext context, {
        required int pageId,
        required String fallbackTitle,
      }) async {
    final dark = Theme.of(context).brightness == Brightness.dark;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: _SheetScaffold(
          dark: dark,
          child: _HtmlPageBody(pageId: pageId, fallbackTitle: fallbackTitle),
        ),
      ),
    );
  }
}

/// Minimal chrome: rounded container + small grabber; title/actions live in body
class _SheetScaffold extends StatelessWidget {
  final Widget child;
  final bool dark;
  const _SheetScaffold({required this.child, required this.dark});

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.85;
    return Container(
      height: h,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF121212) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Grab handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: dark ? Colors.white24 : Colors.black26,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _HtmlPageBody extends StatefulWidget {
  final int pageId;
  final String fallbackTitle;
  const _HtmlPageBody({required this.pageId, required this.fallbackTitle});

  @override
  State<_HtmlPageBody> createState() => _HtmlPageBodyState();
}

class _HtmlPageBodyState extends State<_HtmlPageBody> {
  late Future<_PageContent> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchPage(widget.pageId, widget.fallbackTitle);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _fetchPage(widget.pageId, widget.fallbackTitle, bypassCache: true);
    });
    await _future;
  }

  Future<void> _sharePage(_PageContent page) async {
    // Public-facing WP link using page_id as a fallback (works even without permalinks)
    final url = 'https://cricjust.in/?page_id=${widget.pageId}';
    final title = page.title.isEmpty ? widget.fallbackTitle : page.title;
    await Share.share('$title\n\n$url', subject: title);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<_PageContent>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _LoadingState(dark: dark);
        }
        if (snap.hasError || !snap.hasData) {
          return _ErrorState(
            dark: dark,
            message:
            'Failed to load content.\n${snap.error?.toString() ?? ''}'.trim(),
            onRetry: () {
              setState(() {
                _future = _fetchPage(widget.pageId, widget.fallbackTitle, bypassCache: true);
              });
            },
          );
        }

        final page = snap.data!;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  // Title row with actions
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          page.title.isEmpty ? widget.fallbackTitle : page.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: dark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Share',
                        icon: Icon(Icons.ios_share,
                            color: dark ? Colors.white70 : Colors.black54),
                        onPressed: () => _sharePage(page), // <-- IMPLEMENTED
                      ),
                      IconButton(
                        tooltip: 'Close',
                        icon: Icon(Icons.close_rounded,
                            color: dark ? Colors.white70 : Colors.black54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Html(
                    data: _normalizeHtml(page.html),
                    onLinkTap: (url, _, __) async {
                      if (url == null) return;
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    style: {
                      'body': Style(
                        color: dark ? Colors.white70 : Colors.black87,
                        fontSize: FontSize(16),
                        lineHeight: const LineHeight(1.5),
                      ),
                      'h1': Style(fontSize: FontSize(22), fontWeight: FontWeight.w800),
                      'h2': Style(fontSize: FontSize(19), fontWeight: FontWeight.w700),
                      'h3': Style(fontSize: FontSize(17), fontWeight: FontWeight.w700),
                      'ul': Style(margin: Margins.symmetric(vertical: 8)),
                      'hr': Style(margin: Margins.symmetric(vertical: 16)),
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Fetch page content from the endpoint
Future<_PageContent> _fetchPage(
    int pageId,
    String fallbackTitle, {
      bool bypassCache = false,
    }) async {
  if (!bypassCache) {
    final cached = _PageCache.get(pageId);
    if (cached != null) return cached;
  }

  final uri = Uri.parse(
    'https://cricjust.in/wp-json/custom-api-for-cricket/get-page-content?page_id=$pageId',
  );

  final res = await http.get(uri);
  Map<String, dynamic> map;
  try {
    map = json.decode(res.body) as Map<String, dynamic>;
  } catch (_) {
    throw Exception('HTTP ${res.statusCode}');
  }

  if (res.statusCode == 200 && map['status'] == 1 && map['data'] != null) {
    final data = map['data'] as Map<String, dynamic>;
    final page = _PageContent(
      title: (data['post_title'] ?? fallbackTitle).toString(),
      html: (data['post_content'] ?? '').toString(),
    );
    _PageCache.set(pageId, page);
    return page;
  }

  throw Exception(map['message']?.toString() ?? 'Failed to load content');
}

/// Normalize incoming HTML: fix small typos and tame oversize headings
String _normalizeHtml(String html) {
  // Fix tiny typos seen in your content dump
  html = html.replaceAll('Cricjuston', 'Cricjust on');
  html = html.replaceAll('Wicket-Keeperfor', 'Wicket-Keeper for');
  html = html.replaceAll('Sync Nowwhen', 'Sync Now when');

  // If a big TL;DR span exists, reduce its impact
  html = html.replaceAll(
      RegExp(r'font-size:\s*2\.25em', caseSensitive: false), 'font-size:1.35em');

  // Optional: convert TL;DR span to a smaller heading if it matches the known pattern
  final tlDr = RegExp(
    r'<span[^>]*?>\s*TL;DR\s*(?:\([^)]+\))?\s*</span>',
    caseSensitive: false,
  );
  if (tlDr.hasMatch(html)) {
    html = html.replaceAll(tlDr, '<h3>Quick Answers</h3>');
  }

  return html;
}

/// Loading skeleton (no extra deps)
class _LoadingState extends StatelessWidget {
  final bool dark;
  const _LoadingState({required this.dark});

  @override
  Widget build(BuildContext context) {
    final base = dark ? Colors.white10 : Colors.black12;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Container(
          height: 22,
          width: 220,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(
          8,
              (i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Error UI with retry button
class _ErrorState extends StatelessWidget {
  final bool dark;
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({
    required this.dark,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 44, color: dark ? Colors.white70 : Colors.black45),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: dark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
