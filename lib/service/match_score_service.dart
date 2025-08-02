// lib/service/match_score_service.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../model/match_score_model.dart';
import '../api/api_helper.dart';

class MatchScoreService {
  /// Submit a single ball’s score
  static Future<bool> submitScore(
      MatchScoreRequest req,
      String token,
      BuildContext context,
      ) async {
    final uri = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/save-cricket-match-score'
          '?api_logged_in_token=$token',
    );

    final body = <String, String>{
      'match_id': req.matchId.toString(),
      'batting_team_id': req.battingTeamId.toString(),
      'on_strike_player_id': req.onStrikePlayerId.toString(),
      'on_strike_player_order': req.onStrikePlayerOrder.toString(),
      'non_strike_player_id': req.nonStrikePlayerId.toString(),
      'non_strike_player_order': req.nonStrikePlayerOrder.toString(),
      'bowler': req.bowler.toString(),
      'over_number': req.overNumber.toString(),
      'ball_number': req.ballNumber.toString(),
      'runs': req.runs.toString(),
      'extra_run_type': req.extraRunType ?? '0',
      if (req.extraRun != null) 'extra_run': req.extraRun!.toString(),
      if (req.isWicket != null) 'is_wicket': req.isWicket!.toString(),
      if (req.wicketType != null) 'wicket_type': req.wicketType!,
      if (req.commentry != null) 'commentry': req.commentry!,
    };

    print('📤 [API] save-cricket-match-score payload: ${jsonEncode(body)}');

    final res = await ApiHelper.safeRequest(
      context: context,
      requestFn: () => http.post(uri, body: body),
    );
    if (res == null) return false;

    print('📥 [API] Response: ${res.statusCode} ${res.body}');
    if (res.statusCode != 200) return false;

    final decoded = json.decode(res.body) as Map<String, dynamic>;
    if (decoded['status'] != 1) {
      print('❌ [API] Error: ${decoded['message']}');
      return false;
    }
    return true;
  }

  /// Undo the last ball that was submitted
  static Future<bool> undoLastBall(
      int matchId,
      String token,
      BuildContext context,
      ) async {
    final uri = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/undo-last-ball-match'
          '?api_logged_in_token=$token'
          '&match_id=$matchId',
    );

    final res = await ApiHelper.safeRequest(
      context: context,
      requestFn: () => http.get(uri),
    );
    if (res == null || res.statusCode != 200) return false;

    final body = json.decode(res.body) as Map<String, dynamic>;
    return body['status'] == 1;
  }

  /// End the first innings of the match
  static Future<bool> endInning({
    required int matchId,
    required String token,
  }) async {
    final uri = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/end-inning'
          '?api_logged_in_token=$token'
          '&match_id=$matchId',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to end inning (HTTP ${response.statusCode})');
    }
    final body = json.decode(response.body) as Map<String, dynamic>;
    return body['status'] == 1;
  }

  /// Fetch both teams’ squads (for batting/bowling) at match start
  static Future<Map<String, List<Map<String, dynamic>>>> fetchSquads({
    required int matchId,
  }) async {
    final uri = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-match'
          '?match_id=$matchId&type=squad',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch squads (HTTP ${res.statusCode})');
    }
    final body = json.decode(res.body) as Map<String, dynamic>;
    if (body['status'] != 1) {
      throw Exception('Error fetching squads: ${body['message']}');
    }
    final data = body['data'][0] as Map<String, dynamic>;
    return {
      'team1': List<Map<String, dynamic>>.from(data['team_1'] as List),
      'team2': List<Map<String, dynamic>>.from(data['team_2'] as List),
    };
  }

  /// Fetch the current match score (to detect innings end & update UI)
  static Future<Map<String, dynamic>> fetchCurrentScore({
    required int matchId,
  }) async {
    final uri = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-current-match-score'
          '?match_id=$matchId',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch current score (HTTP ${res.statusCode})');
    }
    final body = json.decode(res.body) as Map<String, dynamic>;
    if (body['status'] != 1) {
      throw Exception('Error fetching current score: ${body['message']}');
    }
    return body['current_score'] as Map<String, dynamic>;
  }

  /// End a completed match
  static Future<bool> endMatch({
    required BuildContext context,
    required String token,
    required int matchId,
    required String resultType, // Win, Draw, Tie, WinBToss
    int? winningTeam,
    int? runsOrWicket,
    String? winByType, // Runs or Wickets
    String? drawComment,
    String? superOvers,
  }) async {
    final uri = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/end-match'
          '?api_logged_in_token=$token&match_id=$matchId',
    );

    final body = {
      'result_type': resultType,
      if (winningTeam != null) 'winning_team': winningTeam.toString(),
      if (runsOrWicket != null) 'runs_or_wicket': runsOrWicket.toString(),
      if (winByType != null) 'win_by_type': winByType,
      if (drawComment != null) 'draw_match_comment': drawComment,
      if (superOvers != null) 'super_overs': superOvers,
    };

    print('📤 End Match Payload: $body');

    final res = await ApiHelper.safeRequest(
      context: context,
      requestFn: () => http.post(uri, body: body),
    );
    if (res == null || res.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Failed to end match")),
      );
      return false;
    }

    final response = json.decode(res.body);
    if (response['status'] == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Match ended successfully")),
      );
      return true;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("❌ ${response['message'] ?? 'Match end failed'}")),
    );
    return false;
  }
  /// Fetch the last six balls for a team in a match (extras placed last)
  static Future<List<Map<String, dynamic>>> fetchLastSixBalls({
    required int matchId,
    required int teamId,
  }) async {
    final uri = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-last-six-balls'
          '?match_id=$matchId&team_id=$teamId',
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      debugPrint('❌ Failed to fetch last six balls (HTTP ${res.statusCode})');
      return [];
    }

    final body = json.decode(res.body);
    if (body['status'] != 1 || body['message'] == null) {
      debugPrint('❌ Error from API: ${body['message']}');
      return [];
    }

    final balls = List<Map<String, dynamic>>.from(body['message']);

    // Sort: legal deliveries first, extras after
    final legalBalls = balls.where((b) => b['is_extra'] == 0).toList();
    final extras = balls.where((b) => b['is_extra'] == 1).toList();
    return [...legalBalls, ...extras];
  }

  // lib/service/match_score_service.dart

  static Future<Map<String, dynamic>?> getCurrentScore(int matchId, String token) async {
    try {
      final uri = Uri.parse(
        'https://cricjust.in/wp-json/custom-api-for-cricket/get-current-match-score?match_id=$matchId&api_logged_in_token=$token',
      );

      final response = await http.get(uri);
      final json = jsonDecode(response.body);

      print('📡 Raw TV API Response: $json');

      if (json['status'] == 1 && json['current_score'] != null) {
        return json['current_score'];
      }

      return null;
    } catch (e) {
      print('❌ Error fetching current score: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchLastBalls(int matchId, int teamId) async {
    final url = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-last-six-balls?match_id=$matchId&team_id=$teamId',
    );
    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['status'] == 1 && json['message'] is List) {
          return List<Map<String, dynamic>>.from(json['message']);
        }
      }
    } catch (_) {}
    return [];
  }





}
