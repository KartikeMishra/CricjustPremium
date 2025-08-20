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

    final resp = await http.get(uri);

    if (resp.statusCode != 200) {
      // real transport/server problem – let UI show an error
      throw Exception('Failed to load stats (HTTP ${resp.statusCode})');
    }

    final dynamic raw = json.decode(resp.body);

    // If API returns a list or a map with status 0 / missing stats, treat as "no data"
    if (raw is List) return MatchStats.empty();
    if (raw is Map) {
      final status = raw['status'];
      final hasStats = (raw['stats'] != null) ||
          (raw['data'] is Map && (raw['data']['stats'] != null));
      if (status == 0 || !hasStats) return MatchStats.empty();

      // Pass whole payload; model handles different shapes/keys.
      return MatchStats.fromJson(raw); // delegates to fromAny in the model
    }

    // Unknown shape – safest fallback
    return MatchStats.empty();
  }
}

