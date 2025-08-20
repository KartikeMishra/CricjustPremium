// lib/service/match_youtube_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class MatchYoutubeService {
  static const String _base = 'https://cricjust.in/wp-json/custom-api-for-cricket';

  static Future<_ApiResp> updateYoutube({
    required String apiToken,
    required int matchId,
    required String youtubeUrl,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final uri = Uri.parse(
      '$_base/update-cricket-youtube-embed?api_logged_in_token=$apiToken&match_id=$matchId',
    );

    try {
      final res = await http.post(uri, body: {'youtube': youtubeUrl}).timeout(timeout);

      Map<String, dynamic> map;
      try {
        map = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        return _ApiResp(false, 'HTTP ${res.statusCode}', raw: res.body);
      }

      final ok = (map['status'] == 1 || map['status'] == '1');
      final message = (map['message']?.toString() ??
          (ok ? 'YouTube link updated' : 'Update failed'));

      return _ApiResp(ok, message, data: map);
    } catch (e) {
      return _ApiResp(false, e.toString());
    }
  }
}

/// Light response wrapper
class _ApiResp {
  final bool ok;
  final String message;
  final Map<String, dynamic>? data;
  final String? raw;
  _ApiResp(this.ok, this.message, {this.data, this.raw});
}
