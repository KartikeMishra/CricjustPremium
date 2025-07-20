// lib/service/match_score_service.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../model/match_score_model.dart';
import '../api/api_helper.dart'; // ✅ Add this import

class MatchScoreService {
  static Future<bool> submitScore(
      MatchScoreRequest req,
      String token,
      BuildContext context, // ✅ Add context
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

    print('📤 [API] save-cricket-match-score payload:');
    print(jsonEncode(body));

    // ✅ Centralized safe request (with session check)
    final res = await ApiHelper.safeRequest(
      context: context,
      requestFn: () => http.post(uri, body: body),
    );

    if (res == null) return false; // ⛔ Session expired or network issue

    print('📥 [API] raw response body: ${res.body}');

    if (res.statusCode != 200) {
      print('❌ [API] HTTP status ${res.statusCode}');
      return false;
    }

    Map<String, dynamic> decoded;
    try {
      decoded = json.decode(res.body) as Map<String, dynamic>;
    } catch (e, st) {
      print('🔥 [API] JSON parse error in submitScore: $e');
      print(st);
      return false;
    }

    if (decoded['status'] != 1) {
      print('❌ [API] error message: ${decoded['message']}');
      return false;
    }

    return true;
  }

  /// ⚡️ NEW: undo the last ball
  static Future<bool> undoLastBall(
      int matchId,
      String token,
      BuildContext context, // ✅ Add context here too
      ) async {
    final uri = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/undo-last-ball-match'
          '?api_logged_in_token=$token&match_id=$matchId',
    );

    final res = await ApiHelper.safeRequest(
      context: context,
      requestFn: () => http.get(uri),
    );

    if (res == null || res.statusCode != 200) return false;

    final body = json.decode(res.body) as Map<String, dynamic>;
    return body['status'] == 1;
  }
}
