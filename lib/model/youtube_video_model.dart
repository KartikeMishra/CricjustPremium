import 'package:intl/intl.dart';

class YoutubeVideoAuthor {
  final int id;
  final String name;

  const YoutubeVideoAuthor({
    required this.id,
    required this.name,
  });

  factory YoutubeVideoAuthor.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const YoutubeVideoAuthor(id: 0, name: 'Unknown');
    return YoutubeVideoAuthor(
      id: _asInt(json['author_id']),
      name: (json['author_name'] ?? 'Unknown').toString(),
    );
  }
}

class YoutubeVideo {
  final int id;
  final String title;

  /// Original date string from the API (e.g., "March 8, 2025")
  final String dateText;

  /// Parsed date (may be null if parsing fails)
  final DateTime? date;

  /// Raw iframe HTML from `short_info`
  final String shortInfoHtml;

  final YoutubeVideoAuthor author;

  /// Extracted src from iframe (e.g., https://www.youtube.com/embed/VIDEO_ID?...), may be null
  final String? embedUrl;

  /// Parsed video id (e.g., "QOUWaB-XyTo"), may be null
  final String? videoId;

  /// Derived helpful URLs (null-safe if videoId missing)
  String? get watchUrl => videoId == null ? null : 'https://www.youtube.com/watch?v=$videoId';
  String? get thumbnailUrl => videoId == null ? null : 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';

  const YoutubeVideo({
    required this.id,
    required this.title,
    required this.dateText,
    required this.date,
    required this.shortInfoHtml,
    required this.author,
    required this.embedUrl,
    required this.videoId,
  });

  factory YoutubeVideo.fromJson(Map<String, dynamic> json) {
    final html = (json['short_info'] ?? '').toString();
    final embed = _extractEmbedSrc(html);
    final vid = _extractVideoId(embed);

    return YoutubeVideo(
      id: _asInt(json['id']),
      title: (json['title'] ?? '').toString(),
      dateText: (json['date'] ?? '').toString(),
      date: _parseDate((json['date'] ?? '').toString()),
      shortInfoHtml: html,
      author: YoutubeVideoAuthor.fromJson(json['author'] as Map<String, dynamic>?),
      embedUrl: embed,
      videoId: vid,
    );
  }

  static List<YoutubeVideo> listFromJson(dynamic data) {
    if (data is List) {
      return data.map((e) => YoutubeVideo.fromJson(e as Map<String, dynamic>)).toList();
    }
    return const [];
  }
}

/// ---------- helpers ----------
int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is String) {
    final n = int.tryParse(v.trim());
    if (n != null) return n;
  }
  return 0;
}

DateTime? _parseDate(String s) {
  if (s.trim().isEmpty) return null;
  try {
    // API format like: "March 8, 2025"
    final f = DateFormat('MMMM d, yyyy', 'en_US');
    return f.parse(s);
  } catch (_) {
    return null;
  }
}

String? _extractEmbedSrc(String html) {
  // Look for src="...". Keep it simple & safe.
  final m = RegExp(r'src="([^"]+)"', caseSensitive: false).firstMatch(html);
  if (m == null) return null;
  final url = m.group(1)?.trim();
  if (url == null || url.isEmpty) return null;
  return url;
}

String? _extractVideoId(String? url) {
  if (url == null || url.isEmpty) return null;
  try {
    final u = Uri.parse(url);

    // Case 1: https://www.youtube.com/embed/VIDEO_ID
    final ix = u.pathSegments.indexOf('embed');
    if (ix >= 0 && ix + 1 < u.pathSegments.length) {
      final seg = u.pathSegments[ix + 1];
      if (seg.isNotEmpty) return seg;
    }

    // Case 2: https://youtu.be/VIDEO_ID
    if (u.host.contains('youtu.be') && u.pathSegments.isNotEmpty) {
      final seg = u.pathSegments.first;
      if (seg.isNotEmpty) return seg;
    }

    // Case 3: https://www.youtube.com/watch?v=VIDEO_ID
    final vParam = u.queryParameters['v'];
    if (vParam != null && vParam.isNotEmpty) return vParam;

    // Fallback: regex from /embed/ if the URI parser missed
    final m = RegExp(r'youtube\.com/embed/([^?"/]+)', caseSensitive: false).firstMatch(url);
    if (m != null) return m.group(1);
  } catch (_) {}
  return null;
}
