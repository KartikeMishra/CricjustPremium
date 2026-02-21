class YoutubeId {
  static String? tryParse(String input) {
    final url = input.trim();
    if (url.isEmpty) return null;

    // youtu.be/<id>
    final m1 = RegExp(r'youtu\.be\/([A-Za-z0-9_-]{6,})').firstMatch(url);
    if (m1 != null) return m1.group(1);

    // youtube.com/watch?v=<id>
    final m2 = RegExp(r'v=([A-Za-z0-9_-]{6,})').firstMatch(url);
    if (m2 != null) return m2.group(1);

    // youtube.com/embed/<id>
    final m3 = RegExp(r'embed\/([A-Za-z0-9_-]{6,})').firstMatch(url);
    if (m3 != null) return m3.group(1);

    // shorts/<id>
    final m4 = RegExp(r'shorts\/([A-Za-z0-9_-]{6,})').firstMatch(url);
    if (m4 != null) return m4.group(1);

    return null;
  }
}
