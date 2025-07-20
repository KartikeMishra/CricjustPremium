import 'dart:convert';
import 'package:http/http.dart' as http;

import '../model/match_summary_model.dart';
import '../model/match_scorecard_model.dart';
import '../model/match_squad_model.dart';
import '../model/match_stats_model.dart';
import '../model/toss_update_model.dart'; // ✅ Import commentary model

class MatchService {
  static Future<MatchSummary> fetchMatchSummary(int matchId) async {
    final url = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-match?match_id=$matchId&type=summary',
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return MatchSummary.fromJson(data);
    } else {
      throw Exception('Failed to load match summary');
    }
  }

  static Future<bool> updateToss(
    TossUpdateRequest request,
    String token,
    int matchId,
  ) async {
    final url =
        'https://cricjust.in/wp-json/custom-api-for-cricket/update-cricket-toss?api_logged_in_token=$token&match_id=$matchId';

    final response = await http.post(Uri.parse(url), body: request.toJson());

    return response.statusCode == 200;
  }
}

class MatchScorecardService {
  static Future<MatchScorecardResponse> fetchScorecard(int matchId) async {
    final url = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-match?match_id=$matchId&type=scorecard',
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return MatchScorecardResponse.fromJson(data);
    } else {
      throw Exception('Failed to load scorecard');
    }
  }
}

class MatchSquadService {
  static Future<MatchSquad> fetchSquad(int matchId) async {
    final url = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-match?match_id=$matchId&type=squad',
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return MatchSquad.fromJson(data);
    } else {
      throw Exception('Failed to load match squad');
    }
  }
}

class MatchStatsService {
  static Future<MatchStats> fetchStats(int matchId) async {
    final uri = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-match'
      '?match_id=$matchId&type=stats&user_ip=123456789',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load stats (HTTP ${response.statusCode})');
    }

    final Map<String, dynamic> body = json.decode(response.body);
    if (body['status'] != 1) {
      throw Exception('API returned status=${body['status']}');
    }

    // ⚠️ Pass the full JSON—so MatchStats.fromJson can see "stats"
    return MatchStats.fromJson(body);
  }
}
