//
// Full service with: end match (returns Super Over id), submit score, undo,
// end innings, squads, last six balls (with fallback), bowler overs, current score.
//

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

import '../model/match_score_model.dart';
import '../api/api_helper.dart';
import '../utils/score_log.dart';


void _logEndMatch(String where, {
  required Uri uri,
  required Map<String, String> body,
  int? httpStatus,
  String? respBody,
}) {
  debugPrint('• [END-MATCH][$where]');
  debugPrint('  URL => $uri');
  debugPrint('  BODY => $body');
  if (httpStatus != null) debugPrint('  HTTP => $httpStatus');
  if (respBody != null) debugPrint('  RESP => $respBody');
}
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

    // 2) Direct id keys (plus nested data variant)
    soId ??= _toInt(j['super_over_match_id']) ??
        _toInt(j['new_match_id']) ??
        _toInt(j['child_match_id']) ??
        _toInt((j['data'] as Map?)?['super_over_match_id']);

    final ok = (j['status'] == 1 || j['status'] == '1'); // tolerate string "1"
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
  static Future<EndMatchResult> endMatchWithResult({
    required BuildContext context,
    required String token,
    required int matchId,
    required String resultType,   // 'Win' | 'Draw' | 'WinBToss' | 'Tie'
    int? winningTeam,
    int? runsOrWicket,
    String? winByType,            // 'Runs' | 'Wickets'
    String? drawComment,
    String? superOvers,           // 'Yes' when Tie + Super Over
  }) async {
    // Normalize display choice
    String? normWinBy(String? v) {
      if (v == null) return null;
      final s = v.trim().toLowerCase();
      if (s == 'run' || s == 'runs') return 'Runs';
      if (s == 'wicket' || s == 'wickets') return 'Wickets';
      return null;
    }
    final winBy = normWinBy(winByType);

    // Client guards
    if (resultType == 'Win') {
      if (winningTeam == null || runsOrWicket == null || runsOrWicket <= 0 || winBy == null) {
        return const EndMatchResult(ok: false, message: 'Winning team, margin and win_by_type are required for Win');
      }
    }
    if (resultType == 'Draw' && (drawComment == null || drawComment.trim().isEmpty)) {
      return const EndMatchResult(ok: false, message: 'draw_match_comment is required for Draw');
    }

    final baseUri = Uri.parse('$_baseUrl/end-match').replace(queryParameters: {
      'api_logged_in_token': token,
      'match_id': '$matchId',
    });

    // Common fields always sent in BODY too
    final common = <String, String>{
      'api_logged_in_token': token,
      'match_id': '$matchId',
      'result_type': resultType,
    };

    // Build candidate payloads (most likely first)
    List<Map<String, String>> candidates() {
      if (resultType == 'Win') {
        final lower = winBy!.toLowerCase();              // runs | wickets
        final singular = (winBy == 'Wickets') ? 'Wicket' : winBy; // Wicket | Runs

        // A) Official docs keys (+ widely-seen aliases)
        final a = {
          ...common,
          'winning_team': '$winningTeam',
          'winning_team_id': '$winningTeam',            // alias
          'runs_or_wicket': '$runsOrWicket',
          'runs_or_wickets': '$runsOrWicket',           // alias
          'win_by_type': winBy,                          // TitleCase
          'win_by': lower,                               // alias lower
        };

        // B) Some backends want singular 'Wicket' in type
        final b = {
          ...a,
          'win_by_type': singular,                       // 'Wicket' or 'Runs'
        };

        // C) Some expect separate keys instead of a combined one
        final c = {
          ...common,
          'winning_team': '$winningTeam',
          'winning_team_id': '$winningTeam',
          if (winBy == 'Runs') ...{
            'win_by_type': 'Runs',
            'win_by_runs': '$runsOrWicket',
          } else ...{
            'win_by_type': singular,                     // 'Wicket'
            'win_by_wickets': '$runsOrWicket',
          },
          'win_by': lower,
        };

        return [a, b, c];
      }

      if (resultType == 'WinBToss') {
        return [
          {...common, if (winningTeam != null) 'winning_team': '$winningTeam'},
        ];
      }

      if (resultType == 'Draw') {
        return [
          {...common, 'draw_match_comment': drawComment!.trim()},
        ];
      }

      // Tie
      return [
        {...common, if (superOvers == 'Yes') 'super_overs': 'Yes'},
      ];
    }

    Future<(int code, Map<String, dynamic>? json, String raw)> _postOnce(
        Map<String, String> body,
        ) async {
      // Put all fields in the query string as well as in POST body
      final reqUri = baseUri.replace(
        queryParameters: {...baseUri.queryParameters, ...body},
      );

      _logEndMatch('REQ-POST', uri: reqUri, body: body);

      http.Response? res;
      try {
        res = await ApiHelper.safeRequest(
          context: context,
          requestFn: () => http.post(
            reqUri,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: body,
          ),
        );
      } catch (e) {
        _logEndMatch('ERR', uri: reqUri, body: body, respBody: 'exception: $e');
        return (0, null, 'exception: $e');
      }
      if (res == null) return (0, null, 'no response');

      _logEndMatch('RES-POST',
          uri: reqUri, body: body, httpStatus: res.statusCode, respBody: res.body);

      Map<String, dynamic>? j;
      try { j = jsonDecode(res.body) as Map<String, dynamic>; } catch (_) {}
      return (res.statusCode, j, res.body);
    }


    // Try candidates until one succeeds
    String? lastMsg;
    for (final payload in candidates()) {
      final (code, j, raw) = await _postOnce(payload);
      final ok = code == 200 && (j?['status'] == 1 || j?['status'] == '1');
      if (ok) return EndMatchResult.fromJson(j!);

      final msg = j?['message']?.toString();
      lastMsg = (msg != null && msg.isNotEmpty) ? msg : 'HTTP $code';
      // If we hit the “required” message, keep trying the next variant
      if (lastMsg!.toLowerCase().contains('required')) continue;
      // For any other error, stop early
      break;
    }

    return EndMatchResult(ok: false, message: lastMsg ?? 'End match failed');
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

  static Future<bool> submitScore(
      MatchScoreRequest req,
      String token,
      BuildContext context,
      ) async {
    final uri = Uri.parse(
      '$_baseUrl/save-cricket-match-score?api_logged_in_token=$token',
    );

    // ✅ build the full, correct payload from the model
    final body = req.toFormFields();

    // ✅ compact, ball-wise log only (no noisy GET logs)
    ScoreLog.ball(
      'SUBMIT o${body['over_number']}.b${body['ball_number']} | '
          'bat:${body['batting_team_id']} '
          'str:${body['on_strike_player_id']} '
          'non:${body['non_strike_player_id']} '
          'bowl:${body['bowler']} '
          'runs:${body['runs']} '
          'extra:${body['extra_run_type']}${body['extra_run'] != null ? '(${body['extra_run']})' : ''} '
          'wicket:${body['is_wicket'] ?? '0'} '
          'type:${body['wicket_type'] ?? '-'} '
          'out:${body['out_player'] ?? '-'} '
          'ro_by:${body['run_out_by'] ?? '-'} '
          'catch:${body['catch_by'] ?? '-'}',
    );

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
    ScoreLog.net('GET $sixUri → ${sixRes.statusCode}');

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
        ScoreLog.net('last-six-balls empty → fallback');
      }
    } else {
      ScoreLog.net('HTTP ${sixRes.statusCode} on last-six-balls → fallback');
    }

    // Fallback: current-match-score → current_inning.last_ball_data
    ScoreLog.net('Fallback to current-score');
    final curUri = Uri.parse(
      '$_baseUrl/get-current-match-score'
          '?api_logged_in_token=$token'
          '&match_id=$matchId',
    );

    final curRes = await http.get(curUri);
    ScoreLog.net('GET $curUri → ${curRes.statusCode}');
    if (curRes.statusCode != 200) return [];

    final curBody = json.decode(curRes.body) as Map<String, dynamic>;
    if (curBody['status'] != 1) return [];

    final inning = (curBody['current_score'] as Map<String, dynamic>)['current_inning']
    as Map<String, dynamic>?;
    final lastList = inning?['last_ball_data'] as List<dynamic>?;

    if (lastList == null || lastList.isEmpty) {
      ScoreLog.net('fallback last_ball_data empty');
      return [];
    }

    ScoreLog.net('parsing fallback last_ball_data');
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

  static Future<Map<String, dynamic>?> fetchLastBall({
    required int matchId,
    required int teamId,
    required String token,
  }) async {
    final uri = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-last-ball-for-internal-use'
          '?api_logged_in_token=$token&match_id=$matchId&team_id=$teamId',
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) return null;

    final body = json.decode(res.body) as Map<String, dynamic>;
    if (body['status'] != 1) return null;

    final data = body['data'];
    if (data is List && data.isNotEmpty && data.first is Map) {
      return Map<String, dynamic>.from(data.first as Map);
    }
    return null;
  }

  /// Save Player of the Match (API prefers GET with query params)
  static Future<bool> savePlayerOfTheMatch({
    required BuildContext context,
    required String token,
    required int matchId,
    required int playerId,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final base = '$_baseUrl/save-player-of-the-match';
    final postUri = Uri.parse(base);
    final postBody = {
      'api_logged_in_token': token,
      'match_id': '$matchId',
      'player_id': '$playerId',
    };

    Future<(int status, Map<String, dynamic>? json)> tryPost() async {
      final r = await http
          .post(postUri, headers: {'Accept': 'application/json'}, body: postBody)
          .timeout(timeout);
      Map<String, dynamic>? m;
      try { m = jsonDecode(r.body) as Map<String, dynamic>; } catch (_) {}
      return (r.statusCode, m);
    }

    Future<(int status, Map<String, dynamic>? json)> tryGet() async {
      final getUri = postUri.replace(queryParameters: postBody);
      final r = await http.get(getUri).timeout(timeout);
      Map<String, dynamic>? m;
      try { m = jsonDecode(r.body) as Map<String, dynamic>; } catch (_) {}
      return (r.statusCode, m);
    }

    // 1) Prefer POST
    var (status, body) = await tryPost();

    // 405/404 or explicit WP message → fallback to GET
    final noRoute = body?['message']?.toString().toLowerCase().contains('no route was found') == true;
    if (status == 405 || status == 404 || noRoute) {
      (status, body) = await tryGet();
    }

    final ok = (body?['status'] == 1 || body?['status'] == '1');
    if (!ok) {
      final msg = body?['message']?.toString() ?? 'HTTP $status';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PoTM save failed: $msg')),
      );
    }
    return ok;
  }

}
