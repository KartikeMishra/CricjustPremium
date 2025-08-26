import 'dart:convert';
import 'package:http/http.dart' as http;

import '../model/youtube_video_model.dart';

class YoutubeVideoService {
  static const String _base = 'https://cricjust.in/wp-json/custom-api-for-cricket';

  /// Fetch list of YouTube videos.
  /// - [limit]: page size
  /// - [skip]: offset for pagination (0, limit, 2*limit, ...)
  static Future<List<YoutubeVideo>> fetch({
    int limit = 10,
    int skip = 0,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final uri = Uri.parse('$_base/get-youtube-video/').replace(
      queryParameters: {
        'limit': '$limit',
        'skip': '$skip',
      },
    );

    final res = await http.get(uri).timeout(timeout);

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.reasonPhrase}');
    }

    Map<String, dynamic> map;
    try {
      map = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Invalid JSON response');
    }

    final status = map['status'];
    if (!(status == 1 || status == '1')) {
      // Some APIs also return 'message'
      final msg = map['message']?.toString();
      throw Exception(msg ?? 'Request failed');
    }

    final data = map['data'];
    return YoutubeVideo.listFromJson(data);
  }
}
