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

/// ---------- Top-level helpers (must NOT be nested) ----------

/// Lightweight in-memory cache with TTL.
class _Cache<T> {
  final T data;
  final DateTime at;
  _Cache(this.data, this.at);

  bool isFresh(Duration ttl) => DateTime.now().difference(at) < ttl;
}

/// Top-level JSON parser so `compute` can use it.
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

  // Reuse one client and a small timeout to keep things snappy.
  static final http.Client _client = http.Client();
  static const _httpTimeout = Duration(seconds: 12);
  static const Map<String, String> _headers = {
    'accept': 'application/json',
    'accept-encoding': 'gzip',
    'connection': 'keep-alive',
  };

  /// Small GET helper: checks HTTP, parses JSON off the main thread,
  /// and handles "token" errors consistently.
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

  /// Small POST helper (same behavior as GET).
  static Future<Map<String, dynamic>> _post(
      Uri uri, {
        Map<String, String>? body,
      }) async {
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
      '$_base/get-single-tournament-overview?tournament_id=$id&type=overview',
    );

    final body = await _get(uri);
    if (body['status'] != 1) {
      throw Exception('API returned status ${body['status']}');
    }

    final dataMap = body['data'] as Map<String, dynamic>;
    final tournament = TournamentOverview.fromJson(dataMap);

    final teamsJson = (body['teams'] as List<dynamic>?) ?? [];
    final pointsTeams =
    teamsJson.map((e) => TeamStanding.fromJson(e)).toList();

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
      '$_base/get-single-tournament-overview?tournament_id=$id&type=fairplay',
    );
    final body = await _get(uri);

    if (body['status'] != 1) {
      throw Exception('API returned status ${body['status']}');
    }

    final listJson = (body['data'] as List<dynamic>?) ?? [];
    return listJson.map((e) => FairPlayStanding.fromJson(e)).toList();
  }

  static Future<Map<String, dynamic>> fetchTournamentOverviewWithFairPlay(
      int id,
      ) async {
    final overview = await fetchTournamentOverview(id);
    final fairPlay = await fetchFairPlay(id);
    overview['fairPlayTeams'] = fairPlay;
    return overview;
  }

  // ---------- Stats (with mem cache) ----------

  static const Duration _statsTtl = Duration(minutes: 5);
  static final Map<int, _Cache<Map<String, dynamic>>> _statsMem = {};

  /// Read cached tournament stats (if still fresh).
  static Map<String, dynamic>? getCachedTournamentStats(int tournamentId) {
    final c = _statsMem[tournamentId];
    if (c == null) return null;
    return c.isFresh(_statsTtl) ? c.data : null;
  }

  static Future<Map<String, dynamic>> fetchTournamentStats(
      int tournamentId, {
        bool force = false,
      }) async {
    // Fast path: return fresh cache.
    final cached = _statsMem[tournamentId];
    if (!force && cached != null && cached.isFresh(_statsTtl)) {
      return cached.data;
    }

    final uri = Uri.parse(
      '$_base/get-single-tournament-overview?tournament_id=$tournamentId&type=stats',
    );
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
      // Fail soft with an empty structure.
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

    // Store in cache.
    _statsMem[tournamentId] =
        _Cache<Map<String, dynamic>>(result, DateTime.now());
    return result;
  }

  // ---------- Lists & Matches ----------

  static Future<List<TournamentModel>> fetchTournaments({
    String? type,
    int? limit,
    int? skip,
  }) async {
    final params = <String, String>{};
    if (type != null) params['type'] = type;
    if (limit != null) params['limit'] = limit.toString();
    if (skip != null) params['skip'] = skip.toString();

    final uri = Uri.parse('$_base/get-tournaments')
        .replace(queryParameters: params);
    final body = await _get(uri);

    if (body['status'] != 1) {
      throw Exception('API returned status ${body['status']}');
    }

    final listJson = (body['data'] as List<dynamic>?) ?? [];
    return listJson.map((e) => TournamentModel.fromJson(e)).toList();
  }

  static Future<List<TournamentMatchDetail>> fetchTournamentMatches(
      int tournamentId, {
        String type = 'recent',
      }) async {
    final uri = Uri.parse(
      '$_base/get-single-tournament-overview?tournament_id=$tournamentId&type=$type',
    );
    final body = await _get(uri);

    if (body['status'] != 1 || body['data'] == null || body['data'] is! List) {
      return [];
    }

    final matchesJson = body['data'] as List<dynamic>;
    return matchesJson.map((e) => TournamentMatchDetail.fromJson(e)).toList();
  }

  static Future<List<TournamentModel>> fetchAllTournamentsRaw({
    required String apiToken,
    int limit = 20,
    int skip = 0,
  }) async {
    final uri = Uri.parse(
      '$_base/get-tournament?api_logged_in_token=$apiToken&limit=$limit&skip=$skip',
    );
    final body = await _get(uri);

    if (body['status'] == 1 && body['data'] is List) {
      final List data = body['data'];
      return data.map((e) => TournamentModel.fromJson(e)).toList();
    } else {
      // Return empty list safely instead of throwing.
      return [];
    }
  }

  // ---------- CRUD-ish endpoints ----------

  static Future<void> deleteTournament(
      int tournamentId,
      String apiToken,
      ) async {
    final uri = Uri.parse(
      '$_base/delete-tournament'
          '?api_logged_in_token=$apiToken&tournament_id=$tournamentId',
    );
    final body = await _get(uri);

    if (body['status'] != 1) {
      throw Exception('Failed to delete tournament: ${body['message']}');
    }
  }

  static Future<TournamentModel> updateTournament({
    required int tournamentId,
    required String name,
    required String desc,
    required String logo,
    String? brochure,
    required int isGroup,
    required int isOpen,
    required int isTrial,
    required String startDate,
    required String trialEndDate,
    required int maxAge,
    required int pp,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_logged_in_token') ?? '';

    final uri = Uri.parse('$_base/update-tournament');
    final body = await _post(uri, body: {
      'api_logged_in_token': token,
      'tournament_id': tournamentId.toString(),
      'tournament_name': name,
      'tournament_desc': desc,
      'tournament_logo': logo,
      'tournament_brochure': brochure ?? '',
      'is_group': isGroup.toString(),
      'is_open': isOpen.toString(),
      'is_trial': isTrial.toString(),
      'start_date': startDate,
      'trial_end_date': trialEndDate,
      'max_age': maxAge.toString(),
      'pp': pp.toString(),
    });

    if (body['status'] != 1) {
      throw Exception("Update error: ${body['message'] ?? 'Unknown error'}");
    }

    final List<dynamic> dataList = body['data'];
    if (dataList.isEmpty) {
      throw Exception("Update error: Tournament data not found");
    }

    return TournamentModel.fromJson(dataList.first);
  }

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

  static Future<List<Map<String, dynamic>>> getGroups({
    required String token,
    required int tournamentId,
  }) async {
    final uri = Uri.parse(
      '$_base/get-groups?api_logged_in_token=$token&tournament_id=$tournamentId',
    );
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

  static Future<Map<String, dynamic>> createTeamForGroup({
    required String token,
    required int tournamentId,
    required int groupId,
    required String teamName,
    required String teamLogo,
    required String playerIds, // comma-separated
  }) async {
    final uri = Uri.parse('$_base/add-team?api_logged_in_token=$token');
    final body = await _post(uri, body: {
      'team_name': teamName,
      'team_description': 'Created from group assignment',
      'team_logo': teamLogo,
      'team_players': playerIds,
      'tournament_id': tournamentId.toString(),
      'group_id': groupId.toString(),
    });
    return body;
  }

  static Future<Map<String, dynamic>> updateGroup({
    required String token,
    required int tournamentId,
    required int groupId,
    required String groupName,
  }) async {
    final uri = Uri.parse('$_base/update-group');
    final body = await _post(uri, body: {
      'api_logged_in_token': token,
      'tournament_id': tournamentId.toString(),
      'group_id': groupId.toString(),
      'group_name': groupName,
    });

    return {
      'success': body['status'] == 1,
      'message': body['message'] ?? 'Unknown',
    };
  }

  static Future<Map<String, dynamic>> deleteGroup({
    required String token,
    required int tournamentId,
    required int groupId,
  }) async {
    final uri = Uri.parse(
      '$_base/delete-group'
          '?api_logged_in_token=$token&tournament_id=$tournamentId&group_id=$groupId',
    );
    final body = await _get(uri);
    return {
      'success': body['status'] == 1,
      'message': body['message'] ?? 'Unknown',
    };
  }

  // ---------- Single Team lookup (winner name, etc.) ----------

  /// Fetch a team's name by ID using the single-team endpoint.
  /// Returns null if not found or API status != 1.
  static Future<String?> fetchTeamNameById({
    required String apiToken,
    required int teamId,
  }) async {
    final uri = Uri.parse(
      '$_base/get-single-team?api_logged_in_token=$apiToken&team_id=$teamId',
    );

    final body = await _get(uri); // uses your shared GET + token error handler

    if (body['status'] == 1 &&
        body['data'] is List &&
        (body['data'] as List).isNotEmpty) {
      final first = (body['data'] as List).first;
      final name = first['team_name']?.toString();
      if (name != null && name.trim().isNotEmpty) {
        return name.trim();
      }
    }
    return null;
  }

  /// Convenience: fetch names for multiple team IDs.
  /// Calls the single-team API per id (deduped) and returns {teamId: teamName}.
  static Future<Map<int, String>> fetchTeamNamesByIds({
    required String apiToken,
    required Iterable<int> teamIds,
  }) async {
    final out = <int, String>{};
    final ids = teamIds.where((id) => id > 0).toSet();
    for (final id in ids) {
      try {
        final name = await fetchTeamNameById(apiToken: apiToken, teamId: id);
        if (name != null) out[id] = name;
      } catch (_) {
        // ignore individual failures; continue with the rest
      }
    }
    return out;
  }


}
