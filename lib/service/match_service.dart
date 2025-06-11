// lib/services/match_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/match_model.dart';

class MatchService {
  static Future<List<MatchModel>> fetchMatches({
    required String type,
    int limit = 10,
    int skip = 0,
  }) async {
    final url = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-matches?type=$type&limit=$limit&skip=$skip',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final data = List<Map<String, dynamic>>.from(body['data']);
      return data.map((json) => MatchModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load $type matches');
    }
  }

  static Future<MatchModel> fetchMatchById(int matchId) async {
    final url = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-match-detail?match_id=$matchId',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);

      if (body['status'] == 1 && body['data'] != null) {
        return MatchModel.fromJson(body['data']);
      } else {
        throw Exception('Match not found');
      }
    } else {
      throw Exception('Failed to load match detail');
    }
  }
}
