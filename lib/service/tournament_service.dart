// lib/service/tournament_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart'; // for compute()
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../model/tournament_model.dart';
import '../model/tournament_overview_model.dart';
import '../model/fair_play_model.dart';
import '../model/tournament_match_detail_model.dart';
import '../model/tournament_stats_model.dart';

/// ---------- Top-level helpers ----------

class _Cache<T> {
  final T data;
  final DateTime at;
  _Cache(this.data, this.at);
  bool isFresh(Duration ttl) => DateTime.now().difference(at) < ttl;
}

Map<String, dynamic> _parseJson(String s) =>
    json.decode(s) as Map<String, dynamic>;

bool _hasTokenError(Map<String, dynamic> body) {
  final msg = body['message']?.toString().toLowerCase() ?? '';
  return msg.contains('token');
}

Future<void> _handleTokenErrorIfAny(Map<String, dynamic> body) async {
  if (_hasTokenError(body)) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    throw Exception('Session expired. Please login again.');
  }
}

/// ---------- Service ----------

class TournamentService {
  static const String _base =
      'https://cricjust.in/wp-json/custom-api-for-cricket';

  static final http.Client _client = http.Client();
  static const _httpTimeout = Duration(seconds: 12);
  static const Map<String, String> _headers = {
    'accept': 'application/json',
    'accept-encoding': 'gzip',
    'connection': 'keep-alive',
  };

  static Future<Map<String, dynamic>> _get(Uri uri) async {
    final resp =
    await _client.get(uri, headers: _headers).timeout(_httpTimeout);
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}');
    }
    final body = await compute(_parseJson, resp.body);
    await _handleTokenErrorIfAny(body);
    return body;
  }

  static Future<Map<String, dynamic>> _post(Uri uri,
      {Map<String, String>? body}) async {
    final resp = await _client
        .post(uri, headers: _headers, body: body)
        .timeout(_httpTimeout);
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}');
    }
    final parsed = await compute(_parseJson, resp.body);
    await _handleTokenErrorIfAny(parsed);
    return parsed;
  }

  // ---------- Overview ----------

  static Future<Map<String, dynamic>> fetchTournamentOverview(int id) async {
    final uri = Uri.parse(
        '$_base/get-single-tournament-overview?tournament_id=$id&type=overview');
    final body = await _get(uri);

    if (body['status'] != 1) {
      throw Exception('API returned status ${body['status']}');
    }

    final dataMap = body['data'] as Map<String, dynamic>;
    final tournament = TournamentOverview.fromJson(dataMap);

    final teamsJson = (body['teams'] as List<dynamic>?) ?? [];
    final pointsTeams = teamsJson.map((e) => TeamStanding.fromJson(e)).toList();

    final hasGroups = (dataMap['is_group'] as int? ?? 0) == 1;
    final groups = hasGroups
        ? ((body['groups'] as List<dynamic>?) ?? [])
        .map((g) => GroupModel.fromJson(g))
        .toList()
        : [GroupModel(groupId: '0', groupName: 'All Teams')];

    return {
      'tournament': tournament,
      'pointsTeams': pointsTeams,
      'groups': groups,
    };
  }

  // ---------- Fair Play ----------

  static Future<List<FairPlayStanding>> fetchFairPlay(int id) async {
    final uri = Uri.parse(
        '$_base/get-single-tournament-overview?tournament_id=$id&type=fairplay');
    final body = await _get(uri);
    if (body['status'] != 1) {
      throw Exception('API returned status ${body['status']}');
    }
    final listJson = (body['data'] as List<dynamic>?) ?? [];
    return listJson.map((e) => FairPlayStanding.fromJson(e)).toList();
  }

  static Future<Map<String, dynamic>> fetchTournamentOverviewWithFairPlay(
      int id) async {
    final overview = await fetchTournamentOverview(id);
    final fairPlay = await fetchFairPlay(id);
    overview['fairPlayTeams'] = fairPlay;
    return overview;
  }

  // ---------- Stats with cache ----------

  static const Duration _statsTtl = Duration(minutes: 5);
  static final Map<int, _Cache<Map<String, dynamic>>> _statsMem = {};

  static Map<String, dynamic>? getCachedTournamentStats(int tournamentId) {
    final c = _statsMem[tournamentId];
    if (c == null) return null;
    return c.isFresh(_statsTtl) ? c.data : null;
  }

  static Future<Map<String, dynamic>> fetchTournamentStats(
      int tournamentId,
      {bool force = false}) async {
    final cached = _statsMem[tournamentId];
    if (!force && cached != null && cached.isFresh(_statsTtl)) {
      return cached.data;
    }

    final uri = Uri.parse(
        '$_base/get-single-tournament-overview?tournament_id=$tournamentId&type=stats');
    final body = await _get(uri);

    Map<String, dynamic> result;
    if (body['status'] == 1) {
      result = {
        'mostRuns': (body['get_most_runs_api'] as List?)
            ?.map((e) => RunStats.fromJson(e))
            .toList() ??
            <RunStats>[],
        'mostWickets': (body['get_most_wickets_api'] as List?)
            ?.map((e) => WicketStats.fromJson(e))
            .toList() ??
            <WicketStats>[],
        'mostSixes': (body['get_most_sixes_api'] as List?)
            ?.map((e) => SixStats.fromJson(e))
            .toList() ??
            <SixStats>[],
        'mostFours': (body['get_most_fours_api'] as List?)
            ?.map((e) => FourStats.fromJson(e))
            .toList() ??
            <FourStats>[],
        'highestScores': (body['get_highest_score_api'] as List?)
            ?.map((e) => HighestScore.fromJson(e))
            .toList() ??
            <HighestScore>[],
        'mvp': (body['mvp'] as List?)?.map((e) => MVP.fromJson(e)).toList() ??
            <MVP>[],
        'summary': body['get_all'] != null
            ? SummaryStats.fromJson(body['get_all'])
            : SummaryStats(
          matches: '0',
          runs: '0',
          wickets: '0',
          sixes: '0',
          fours: '0',
          balls: '0',
          extras: '0',
        ),
      };
    } else {
      result = {
        'mostRuns': <RunStats>[],
        'mostWickets': <WicketStats>[],
        'mostSixes': <SixStats>[],
        'mostFours': <FourStats>[],
        'highestScores': <HighestScore>[],
        'mvp': <MVP>[],
        'summary': SummaryStats(
          matches: '0',
          runs: '0',
          wickets: '0',
          sixes: '0',
          fours: '0',
          balls: '0',
          extras: '0',
        ),
      };
    }

    _statsMem[tournamentId] =
        _Cache<Map<String, dynamic>>(result, DateTime.now());
    return result;
  }

  // ---------- Tournament Lists ----------

  static Future<List<TournamentModel>> fetchPublicTournaments({
    String type = 'recent',
    int limit = 10,
    int skip = 0,
  }) async {
    final params = {
      'type': type,
      'limit': limit.toString(),
      'skip': skip.toString(),
    };
    final uri =
    Uri.parse('$_base/get-tournaments').replace(queryParameters: params);

    final body = await _get(uri);
    if (body['status'] != 1) {
      throw Exception('API returned status ${body['status']}');
    }
    final listJson = (body['data'] as List<dynamic>?) ?? [];
    return listJson.map((e) => TournamentModel.fromJson(e)).toList();
  }

  static Future<List<TournamentModel>> fetchUserTournaments({
    required String apiToken,
    int limit = 20,
    int skip = 0,
  }) async {
    final uri = Uri.parse('$_base/get-tournament').replace(queryParameters: {
      'api_logged_in_token': apiToken,
      'limit': limit.toString(),
      'skip': skip.toString(),
    });

    final body = await _get(uri);
    if (body['status'] == 0 &&
        (body['message']?.toString().toLowerCase().contains('token') ??
            false)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      throw Exception('Session expired. Please login again.');
    }
    if (body['status'] != 1) {
      throw Exception('API returned status ${body['status']}');
    }

    final listJson = (body['data'] as List<dynamic>?) ?? [];
    return listJson.map((e) => TournamentModel.fromJson(e)).toList();
  }

  // ---------- Group Management ----------

  static Future<Map<String, dynamic>> addGroup({
    required String token,
    required int tournamentId,
    required String groupName,
  }) async {
    final uri = Uri.parse('$_base/add-group?api_logged_in_token=$token');
    final body = await _post(uri, body: {
      'tournament_id': tournamentId.toString(),
      'group_name': groupName,
    });
    return {
      'success': body['status'] == 1,
      'data': body['data'],
      'message': body['message'] ?? '',
    };
  }

  static Future<Map<String, dynamic>> updateGroup({
    required String token,
    required int tournamentId,
    required int groupId,
    required String groupName,
  }) async {
    final uri = Uri.parse('$_base/update-group?api_logged_in_token=$token');
    final body = await _post(uri, body: {
      'tournament_id': tournamentId.toString(),
      'group_id': groupId.toString(),
      'group_name': groupName,
    });
    return {
      'success': body['status'] == 1,
      'data': body['data'],
      'message': body['message'] ?? '',
    };
  }

  static Future<List<Map<String, dynamic>>> getGroups({
    required String token,
    required int tournamentId,
  }) async {
    final uri = Uri.parse(
        '$_base/get-groups?api_logged_in_token=$token&tournament_id=$tournamentId');
    final body = await _get(uri);
    if (body['status'] == 1 && body['data'] is List) {
      return (body['data'] as List).map<Map<String, dynamic>>((e) {
        return {
          'group_id': int.tryParse(e['group_id'].toString()) ?? 0,
          'group_name': e['group_name'] ?? '',
          'tournament_id':
          int.tryParse(e['tournament_id'].toString()) ?? tournamentId,
        };
      }).toList();
    } else {
      return [];
    }
  }

  static Future<Map<String, dynamic>> deleteGroup({
    required String token,
    required int tournamentId,
    required int groupId,
  }) async {
    final uri = Uri.parse(
        '$_base/delete-group?api_logged_in_token=$token&tournament_id=$tournamentId&group_id=$groupId');
    final body = await _get(uri);
    return {
      'success': body['status'] == 1,
      'message': body['message'] ?? 'Unknown',
    };
  }

  // ---------- Single Team Lookup ----------

  static Future<String?> fetchTeamNameById({
    required String apiToken,
    required int teamId,
  }) async {
    final uri = Uri.parse(
        '$_base/get-single-team?api_logged_in_token=$apiToken&team_id=$teamId');
    final body = await _get(uri);

    if (body['status'] == 1 &&
        body['data'] is List &&
        (body['data'] as List).isNotEmpty) {
      final first = (body['data'] as List).first;
      final name = first['team_name']?.toString();
      if (name != null && name.trim().isNotEmpty) return name.trim();
    }
    return null;
  }



  // ---------- Tournament Matches ----------
  static Future<List<TournamentMatchDetail>> fetchTournamentMatches(
      int tournamentId, {
        String type = 'recent',
      }) async {
    final uri = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-single-tournament-overview'
          '?tournament_id=$tournamentId&type=$type',
    );

    final body = await _get(uri);

    if (body['status'] != 1 || body['data'] == null || body['data'] is! List) {
      return [];
    }

    final matchesJson = body['data'] as List<dynamic>;
    return matchesJson.map((e) => TournamentMatchDetail.fromJson(e)).toList();
  }
// ---------- Delete Tournament ----------
  static Future<Map<String, dynamic>> deleteTournament({
    required String apiToken,
    required int tournamentId,
  }) async {
    final uri = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/delete-tournament'
          '?api_logged_in_token=$apiToken&tournament_id=$tournamentId',
    );

    final body = await _get(uri);

    if (body['status'] == 1) {
      return {
        'success': true,
        'message': body['message'] ?? 'Tournament deleted successfully',
      };
    } else {
      return {
        'success': false,
        'message': body['message'] ?? 'Failed to delete tournament',
      };
    }
  }

}
