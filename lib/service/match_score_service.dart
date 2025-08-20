// lib/service/match_score_service.dart
//
// Full service with: end match (returns Super Over id), submit score, undo,
// end innings, squads, last six balls (with fallback), bowler overs, current score.

import 'dart:convert';
import 'package:flutter/foundation.dart'; // debugPrint
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

import '../model/match_score_model.dart';
import '../api/api_helper.dart';

class EndMatchResult {
  final bool ok;
  final int? superOverMatchId;
  final String? message;
  final Map<String, dynamic>? raw;

  const EndMatchResult({
    required this.ok,
    this.superOverMatchId,
    this.message,
    this.raw,
  });

  static int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// Parses typical response shapes:
  /// - { super_over_match_data: [{ match_id: ... }], status, message }
  /// - { super_over_match_id / new_match_id / child_match_id, status, message }
  factory EndMatchResult.fromJson(Map<String, dynamic> j) {
    int? soId;

    // 1) Array form: super_over_match_data: [ { match_id } ]
    final soData = j['super_over_match_data'];
    if (soData is List && soData.isNotEmpty) {
      final first = soData.first;
      final idStr = (first is Map && first['match_id'] != null)
          ? first['match_id'].toString()
          : null;
      soId = idStr != null ? int.tryParse(idStr) : null;
    }

    // 2) Direct id keys
    soId ??= _toInt(j['super_over_match_id']) ??
        _toInt(j['new_match_id']) ??
        _toInt(j['child_match_id']);

    final ok = j['status'] == 1;
    final msg = (j['message'] ?? '').toString();

    return EndMatchResult(ok: ok, superOverMatchId: soId, message: msg, raw: j);
  }
}

class MatchScoreService {
  static const String _baseUrl =
      'https://cricjust.in/wp-json/custom-api-for-cricket';

  // ────────────────────────────────────────────────────────────────────────────
  // END MATCH (with optional Super Over) – returns Super Over match id (if any)
  // ────────────────────────────────────────────────────────────────────────────

  /// New: end match and get structured result including Super Over match id.
  /// IMPORTANT: When Tie + Super Over selected, pass `superOvers: 'Yes'`.
  static Future<EndMatchResult> endMatchWithResult({
    required BuildContext context,
    required String token,
    required int matchId,
    required String resultType, // 'Win', 'Draw', 'Tie', 'WinBToss'
    int? winningTeam,
    int? runsOrWicket,
    String? winByType,          // 'runs' | 'wickets' (case-insensitive)
    String? drawComment,
    String? superOvers,         // 'Yes' when Tie + Super Over selected, else null
  }) async {
    // Keeping your existing endpoint form (token & matchId in query; POST body for rest)
    final uri = Uri.parse(
      '$_baseUrl/end-match?api_logged_in_token=$token&match_id=$matchId',
    );

    final payload = <String, String>{
      'result_type': resultType,
      if (winningTeam != null) 'winning_team': '$winningTeam',
      if (runsOrWicket != null) 'runs_or_wicket': '$runsOrWicket',
      if (winByType != null) 'win_by_type': winByType.toLowerCase(),
      if (drawComment != null) 'draw_match_comment': drawComment,
      if (superOvers != null) 'super_overs': superOvers, // 'Yes'
    };

    final res = await ApiHelper.safeRequest(
      context: context,
      requestFn: () => http.post(uri, body: payload),
    );

    if (res == null || res.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Failed to end match')),
      );
      return const EndMatchResult(
        ok: false,
        superOverMatchId: null,
        message: 'HTTP error',
      );
    }

    final decoded = json.decode(res.body) as Map<String, dynamic>;
    final parsed = EndMatchResult.fromJson(decoded);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          parsed.ok
              ? (parsed.message?.isNotEmpty == true
              ? parsed.message!
              : '✅ Match ended successfully')
              : '❌ ${parsed.message ?? 'Failed to end match'}',
        ),
      ),
    );

    return parsed;
  }

  /// Backward-compatible wrapper (keeps old calls compiling).
  static Future<bool> endMatch({
    required BuildContext context,
    required String token,
    required int matchId,
    required String resultType, // Win, Draw, Tie, WinBToss
    int? winningTeam,
    int? runsOrWicket,
    String? winByType,
    String? drawComment,
    String? superOvers,
  }) async {
    final r = await endMatchWithResult(
      context: context,
      token: token,
      matchId: matchId,
      resultType: resultType,
      winningTeam: winningTeam,
      runsOrWicket: runsOrWicket,
      winByType: winByType,
      drawComment: drawComment,
      superOvers: superOvers,
    );
    return r.ok;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // SUBMIT SCORE / UNDO / INNINGS / SQUADS / SNAPSHOTS / HELPERS
  // ────────────────────────────────────────────────────────────────────────────

  /// Submit a single ball’s score
  static Future<bool> submitScore(
      MatchScoreRequest req,
      String token,
      BuildContext context,
      ) async {
    final uri = Uri.parse(
      '$_baseUrl/save-cricket-match-score?api_logged_in_token=$token',
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
      if (req.commentry != null) 'commentry': req.commentry!, // API spelling
      if (req.wktkprId != null) 'wktkpr_id': req.wktkprId!.toString(),
    };

    final res = await ApiHelper.safeRequest(
      context: context,
      requestFn: () => http.post(uri, body: body),
    );

    if (res == null || res.statusCode != 200) return false;
    final decoded = json.decode(res.body) as Map<String, dynamic>;
    return decoded['status'] == 1;
  }

  /// Undo the last ball that was submitted
  static Future<bool> undoLastBall(
      int matchId,
      String token,
      BuildContext context,
      ) async {
    final uri = Uri.parse(
      '$_baseUrl/undo-last-ball-match?api_logged_in_token=$token&match_id=$matchId',
    );
    final res = await ApiHelper.safeRequest(
      context: context,
      requestFn: () => http.get(uri),
    );
    if (res == null || res.statusCode != 200) return false;
    final body = json.decode(res.body) as Map<String, dynamic>;
    return body['status'] == 1;
  }

  /// End the current innings of the match
  static Future<bool> endInning({
    required int matchId,
    required String token,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/end-inning?api_logged_in_token=$token&match_id=$matchId',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Failed to end innings (HTTP ${res.statusCode})');
    }
    final body = json.decode(res.body) as Map<String, dynamic>;
    return body['status'] == 1;
  }

  /// Fetch both teams’ squads at match start
  static Future<Map<String, List<Map<String, dynamic>>>> fetchSquads({
    required int matchId,
  }) async {
    final uri = Uri.parse('$_baseUrl/get-match?match_id=$matchId&type=squad');
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch squads (HTTP ${res.statusCode})');
    }
    final body = json.decode(res.body) as Map<String, dynamic>;
    if (body['status'] != 1) {
      throw Exception('API error: ${body['message']}');
    }
    final data = (body['data'] as List).first as Map<String, dynamic>;
    return {
      'team1': List<Map<String, dynamic>>.from(data['team_1']),
      'team2': List<Map<String, dynamic>>.from(data['team_2']),
    };
  }

  /// Fetch the last six deliveries for a match & team.
  /// 1) Tries dedicated endpoint (token from SharedPreferences)
  /// 2) Falls back to current-score’s last_ball_data
  static Future<List<Map<String, dynamic>>> fetchLastSixBalls({
    required int matchId,
    required int teamId,
  }) async {
    // Token
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_logged_in_token') ?? '';

    // Primary: get-last-six-balls
    final sixUri = Uri.parse(
      '$_baseUrl/get-last-six-balls'
          '?api_logged_in_token=$token'
          '&match_id=$matchId'
          '&team_id=$teamId',
    );
    final sixRes = await http.get(sixUri);
    debugPrint('🔍 GET $sixUri → ${sixRes.statusCode}: ${sixRes.body}');

    if (sixRes.statusCode == 200) {
      final body = json.decode(sixRes.body) as Map<String, dynamic>;
      final msg = body['message'];
      if (body['status'] == 1 && msg is List) {
        return msg.map<Map<String, dynamic>>((e) {
          return {
            'over_number': int.tryParse('${e['over_number']}') ?? 0,
            'ball_number': int.tryParse('${e['ball_number']}') ?? 0,
            'runs': int.tryParse('${e['runs']}') ?? 0,
            'is_wicket': int.tryParse('${e['is_wicket']}') ?? 0,
            'is_extra': int.tryParse('${e['is_extra']}') ?? 0,
            'extra_run_type': (e['extra_run_type'] ?? '').toString(),
            'extra_run': int.tryParse('${e['extra_run']}') ?? 0,
          };
        }).toList();
      } else {
        debugPrint('   ↳ get-last-six-balls returned no list; will fallback');
      }
    } else {
      debugPrint('❌ HTTP ${sixRes.statusCode} on get-last-six-balls, fallback');
    }

    // Fallback: current-match-score → current_inning.last_ball_data
    debugPrint('🛠️ Fallback to get-current-match-score');
    final curUri = Uri.parse(
      '$_baseUrl/get-current-match-score'
          '?api_logged_in_token=$token'
          '&match_id=$matchId',
    );
    final curRes = await http.get(curUri);
    debugPrint('🔍 GET $curUri → ${curRes.statusCode}: ${curRes.body}');
    if (curRes.statusCode != 200) return [];

    final curBody = json.decode(curRes.body) as Map<String, dynamic>;
    if (curBody['status'] != 1) return [];

    final inning = (curBody['current_score'] as Map<String, dynamic>)['current_inning']
    as Map<String, dynamic>?;
    final lastList = inning?['last_ball_data'] as List<dynamic>?;

    if (lastList == null || lastList.isEmpty) {
      debugPrint('   ↳ Fallback last_ball_data empty');
      return [];
    }

    debugPrint('   ↳ Parsing fallback last_ball_data');
    return lastList.map<Map<String, dynamic>>((e) {
      return {
        'over_number': int.tryParse('${e['over_number']}') ?? 0,
        'ball_number': int.tryParse('${e['ball_number']}') ?? 0,
        'runs': int.tryParse('${e['runs'] ?? '0'}') ?? 0,
        'is_wicket': int.tryParse('${e['is_wicket']}') ?? 0,
        'is_extra': int.tryParse('${e['is_extra']}') ?? 0,
      };
    }).toList();
  }

  /// Fetch bowler overs from the full scorecard
  static Future<Map<int, double>> fetchBowlerOversFromScorecard({
    required int matchId,
    required int fieldingTeamId,
  }) async {
    final uri = Uri.parse('$_baseUrl/get-match?match_id=$matchId&type=scorecard');
    final res = await http.get(uri);
    if (res.statusCode != 200) return {};
    final body = json.decode(res.body) as Map<String, dynamic>;
    if (body['status'] != 1 || body['scorecard'] == null) return {};

    final scorecard = body['scorecard'] as List<dynamic>;
    Map<String, dynamic>? teamData;
    for (final entry in scorecard) {
      final t1 = entry['team_1'] as Map<String, dynamic>?;
      final t2 = entry['team_2'] as Map<String, dynamic>?;
      if (t1?['team_id'] == fieldingTeamId) {
        teamData = t1;
        break;
      }
      if (t2?['team_id'] == fieldingTeamId) {
        teamData = t2;
        break;
      }
    }
    if (teamData == null) return {};

    final bowlers = teamData['scorecard']?['bowlers'] as List<dynamic>? ?? [];
    final Map<int, double> oversMap = {};
    for (final b in bowlers) {
      final id = int.tryParse(b['bowler_id'].toString()) ?? 0;
      final overs = int.tryParse(b['overs'].toString()) ?? 0;
      final balls = int.tryParse(b['balls'].toString()) ?? 0;
      if (id > 0) oversMap[id] = overs + balls / 6.0;
    }
    return oversMap;
  }

  /// Fetches the full "current_score" JSON (including last_ball_data) for a match
  static Future<Map<String, dynamic>?> getCurrentScore(
      int matchId,
      String token,
      ) async {
    final uri = Uri.parse(
      '$_baseUrl/get-current-match-score?match_id=$matchId&api_logged_in_token=$token',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) return null;
    final body = json.decode(res.body) as Map<String, dynamic>;
    if (body['status'] != 1 || body['current_score'] == null) return null;
    return body['current_score'] as Map<String, dynamic>;
  }
}
