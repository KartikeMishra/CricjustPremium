import 'dart:convert';
import 'package:http/http.dart' as http;

import '../model/match_summary_model.dart';
import '../model/match_scorecard_model.dart';
import '../model/match_squad_model.dart';
import '../model/match_stats_model.dart';
import '../model/match_commentary_model.dart'; // ✅ Import commentary model

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
    final url = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-match?match_id=$matchId&type=stats',
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return MatchStats.fromJson(data);
    } else {
      throw Exception('Failed to load match stats');
    }
  }
}