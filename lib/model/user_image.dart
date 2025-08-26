// lib/model/user_image.dart
class UserImage {
  final int id;
  final String url;
  final String? caption;

  UserImage({
    required this.id,
    required this.url,
    this.caption,
  });

  /// Primary factory: accepts a flat map (one image item).
  /// Handles multiple key aliases and absolutizes relative URLs.
  factory UserImage.fromMap(Map<String, dynamic> m) {
    int parseId(dynamic v) {
      if (v == null) return 0;
      return int.tryParse(v.toString()) ?? 0;
    }

    String parseUrl(Map<String, dynamic> m) {
      // Try common keys your API might return
      const keys = ['image_url', 'image', 'url', 'src'];
      for (final k in keys) {
        final v = m[k];
        if (v != null && v.toString().isNotEmpty) {
          return _absolutize(v.toString());
        }
      }
      // Sometimes the URL is nested inside "data": { url: ... }
      final data = m['data'];
      if (data is Map) {
        final nested = (data['image_url'] ?? data['url'] ?? data['src'])?.toString();
        if (nested != null && nested.isNotEmpty) {
          return _absolutize(nested);
        }
      }
      return '';
    }

    return UserImage(
      id: parseId(m['image_id'] ?? m['ID'] ?? m['id']),
      url: parseUrl(m),
      caption: (m['caption'] ?? m['title'] ?? m['description'] ?? '').toString(),
    );
  }

  /// Parses an **upload response** like:
  /// { "status":1, "message":"Image Uploaded.", "image_url":"https://..." }
  /// Returns a minimal model (id may be 0 if not provided).
  factory UserImage.fromUploadResponse(Map<String, dynamic> m) {
    final url = (m['image_url'] ?? m['url'] ?? m['data']?['url'])?.toString() ?? '';
    return UserImage(
      id: int.tryParse('${m['image_id'] ?? m['id'] ?? 0}') ?? 0,
      url: _absolutize(url),
      caption: (m['caption'] ?? m['title'] ?? '').toString(),
    );
  }

  /// Optional: serialize if you cache locally
  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'caption': caption,
  };

  static String _absolutize(String input) {
    if (input.isEmpty) return input;
    if (input.startsWith('http://') || input.startsWith('https://')) return input;
    // Handle relative paths from WP (e.g. "/wp-content/uploads/...")
    final startsWithSlash = input.startsWith('/');
    return 'https://cricjust.in${startsWithSlash ? '' : '/'}$input';
  }
}
