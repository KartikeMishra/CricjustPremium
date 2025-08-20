// lib/utils/youtube_utils.dart
class YoutubeUtils {
  /// Returns the 11-char YouTube video ID, or null if not found.
  static String? extractVideoId(String? url) {
    if (url == null || url.isEmpty) return null;

    Uri? u;
    try {
      u = Uri.parse(url);
    } catch (_) {
      return null;
    }

    final host = u.host.toLowerCase();

    // youtu.be/<id>
    if (host.contains('youtu.be')) {
      final seg = u.pathSegments.isNotEmpty ? u.pathSegments.first : null;
      if (_isValidId(seg)) return seg;
    }

    // youtube.com/watch?v=<id>
    if (host.contains('youtube.com') && (u.path == '/watch' || u.path == '/watch/')) {
      final v = u.queryParameters['v'];
      if (_isValidId(v)) return v;
    }

    // youtube.com/embed/<id>
    final embedIdx = u.pathSegments.indexOf('embed');
    if (embedIdx != -1 && embedIdx + 1 < u.pathSegments.length) {
      final id = u.pathSegments[embedIdx + 1];
      if (_isValidId(id)) return id;
    }

    // youtube.com/shorts/<id>
    final shortsIdx = u.pathSegments.indexOf('shorts');
    if (shortsIdx != -1 && shortsIdx + 1 < u.pathSegments.length) {
      final id = u.pathSegments[shortsIdx + 1];
      if (_isValidId(id)) return id;
    }

    // youtube.com/live/<id>
    final liveIdx = u.pathSegments.indexOf('live');
    if (liveIdx != -1 && liveIdx + 1 < u.pathSegments.length) {
      final id = u.pathSegments[liveIdx + 1];
      if (_isValidId(id)) return id;
    }

    return null;
  }

  static bool _isValidId(String? id) {
    if (id == null) return false;
    // Strip any trailing params just in case
    final clean = id.split('?').first.split('&').first;
    final reg = RegExp(r'^[a-zA-Z0-9_-]{11}$');
    return reg.hasMatch(clean);
  }
}