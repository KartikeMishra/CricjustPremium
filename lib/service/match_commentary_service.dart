import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/match_commentary_model.dart';

class MatchCommentaryService {
  static Future<List<CommentaryItem>> fetchCommentary({
    required int matchId,
    required int teamId,
    int limit = 10,
    int skip = 0,
  }) async {
    final url = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-commentry?match_id=$matchId&team_id=$teamId&limit=$limit&skip=$skip',
    );

    final response = await http.get(url);
    print("🔁 Commentary API Status: ${response.statusCode}");
    print("📦 API Response: ${response.body}");

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);

      if (body['status'] == 1 && body['data'] != null && body['data'] is List) {
        return (body['data'] as List)
            .map((item) => CommentaryItem.fromJson(item))
            .toList();
      } else {
        return [];
      }
    } else {
      throw Exception('Failed to load commentary');
    }
  }
}
