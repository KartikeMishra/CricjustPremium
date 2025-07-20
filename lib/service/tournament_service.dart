import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../model/tournament_model.dart';
import '../model/tournament_overview_model.dart';
import '../model/fair_play_model.dart';
import '../model/tournament_match_detail_model.dart';
import '../model/tournament_stats_model.dart';

class TournamentService {
  static const String _base =
      'https://cricjust.in/wp-json/custom-api-for-cricket';

  static Future<Map<String, dynamic>> fetchTournamentOverview(int id) async {
    final uri = Uri.parse(
      '$_base/get-single-tournament-overview?tournament_id=$id&type=overview',
    );
    final resp = await http.get(uri);

    final prefs = await SharedPreferences.getInstance();
    final body = json.decode(resp.body) as Map<String, dynamic>;
    if (body['message']?.toString().toLowerCase().contains('token') ?? false) {
      await prefs.clear();
      throw Exception('Session expired. Please login again.');
    }

    if (resp.statusCode != 200) {
      throw Exception('Failed to load overview (HTTP ${resp.statusCode})');
    }

    if (body['status'] != 1) {
      throw Exception('API returned status ${body['status']}');
    }

    final dataMap = body['data'] as Map<String, dynamic>;
    final tournament = TournamentOverview.fromJson(dataMap);

    final teamsJson = (body['teams'] as List<dynamic>?) ?? [];
    final pointsTeams = teamsJson.map((e) => TeamStanding.fromJson(e)).toList();

    final hasGroups = (dataMap['is_group'] as int? ?? 0) == 1;
    final groups = hasGroups
        ? (body['groups'] as List<dynamic>?)
                  ?.map((g) => GroupModel.fromJson(g))
                  .toList() ??
              []
        : [GroupModel(groupId: '0', groupName: 'All Teams')];

    return {
      'tournament': tournament,
      'pointsTeams': pointsTeams,
      'groups': groups,
    };
  }

  static Future<List<FairPlayStanding>> fetchFairPlay(int id) async {
    final uri = Uri.parse(
      '$_base/get-single-tournament-overview?tournament_id=$id&type=fairplay',
    );
    final resp = await http.get(uri);

    final prefs = await SharedPreferences.getInstance();
    final body = json.decode(resp.body) as Map<String, dynamic>;
    if (body['message']?.toString().toLowerCase().contains('token') ?? false) {
      await prefs.clear();
      throw Exception('Session expired. Please login again.');
    }

    if (resp.statusCode != 200) {
      throw Exception('Failed to load fair-play (HTTP ${resp.statusCode})');
    }

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

  static Future<Map<String, dynamic>> fetchTournamentStats(
    int tournamentId,
  ) async {
    final url = Uri.parse(
      '$_base/get-single-tournament-overview?tournament_id=$tournamentId&type=stats',
    );
    final response = await http.get(url);

    final prefs = await SharedPreferences.getInstance();
    final jsonBody = jsonDecode(response.body);
    if (jsonBody['message']?.toString().toLowerCase().contains('token') ??
        false) {
      await prefs.clear();
      throw Exception('Session expired. Please login again.');
    }

    if (response.statusCode == 200) {
      if (jsonBody['status'] == 1) {
        return {
          'mostRuns':
              (jsonBody['get_most_runs_api'] as List?)
                  ?.map((e) => RunStats.fromJson(e))
                  .toList() ??
              [],
          'mostWickets':
              (jsonBody['get_most_wickets_api'] as List?)
                  ?.map((e) => WicketStats.fromJson(e))
                  .toList() ??
              [],
          'mostSixes':
              (jsonBody['get_most_sixes_api'] as List?)
                  ?.map((e) => SixStats.fromJson(e))
                  .toList() ??
              [],
          'mostFours':
              (jsonBody['get_most_fours_api'] as List?)
                  ?.map((e) => FourStats.fromJson(e))
                  .toList() ??
              [],
          'highestScores':
              (jsonBody['get_highest_score_api'] as List?)
                  ?.map((e) => HighestScore.fromJson(e))
                  .toList() ??
              [],
          'mvp':
              (jsonBody['mvp'] as List?)
                  ?.map((e) => MVP.fromJson(e))
                  .toList() ??
              [],
          'summary': jsonBody['get_all'] != null
              ? SummaryStats.fromJson(jsonBody['get_all'])
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
        throw Exception("API returned status != 1");
      }
    } else {
      throw Exception("Failed to connect to server");
    }
  }

  static Future<List<TournamentModel>> fetchTournaments({
    String? type,
    int? limit,
    int? skip,
  }) async {
    final params = <String, String>{};
    if (type != null) params['type'] = type;
    if (limit != null) params['limit'] = limit.toString();
    if (skip != null) params['skip'] = skip.toString();

    final uri = Uri.parse(
      '$_base/get-tournaments',
    ).replace(queryParameters: params);
    final resp = await http.get(uri);

    final prefs = await SharedPreferences.getInstance();
    final body = json.decode(resp.body) as Map<String, dynamic>;
    if (body['message']?.toString().toLowerCase().contains('token') ?? false) {
      await prefs.clear();
      throw Exception('Session expired. Please login again.');
    }

    if (resp.statusCode != 200) {
      throw Exception('Failed to load tournaments (HTTP ${resp.statusCode})');
    }

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
    final resp = await http.get(uri);

    final prefs = await SharedPreferences.getInstance();
    final body = json.decode(resp.body) as Map<String, dynamic>;
    if (body['message']?.toString().toLowerCase().contains('token') ?? false) {
      await prefs.clear();
      throw Exception('Session expired. Please login again.');
    }

    if (resp.statusCode != 200) {
      throw Exception(
        'Failed to load tournament matches (HTTP ${resp.statusCode})',
      );
    }

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
    final response = await http.get(uri);
    final prefs = await SharedPreferences.getInstance();

    final jsonBody = json.decode(response.body);
    if (jsonBody['message']?.toString().toLowerCase().contains('token') ??
        false) {
      await prefs.clear();
      throw Exception('Session expired. Please login again.');
    }

    if (response.statusCode == 200) {
      if (jsonBody['status'] == 1 && jsonBody['data'] is List) {
        final List data = jsonBody['data'];
        return data.map((e) => TournamentModel.fromJson(e)).toList();
      } else {
        // Return empty list safely instead of throwing
        return [];
      }
    } else {
      throw Exception('HTTP Error: ${response.statusCode}');
    }
  }

  static Future<void> deleteTournament(
    int tournamentId,
    String apiToken,
  ) async {
    final url = Uri.parse(
      '$_base/delete-tournament?api_logged_in_token=$apiToken&tournament_id=$tournamentId',
    );
    final response = await http.get(url);
    final prefs = await SharedPreferences.getInstance();
    final jsonData = json.decode(response.body);

    if (jsonData['message']?.toString().toLowerCase().contains('token') ??
        false) {
      await prefs.clear();
      throw Exception('Session expired. Please login again.');
    }

    if (response.statusCode != 200 || jsonData['status'] != 1) {
      throw Exception('Failed to delete tournament: ${jsonData['message']}');
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
    final response = await http.post(
      uri,
      body: {
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
      },
    );

    final body = json.decode(response.body);
    if (body['message']?.toString().toLowerCase().contains('token') ?? false) {
      await prefs.clear();
      throw Exception('Session expired. Please login again.');
    }

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
    final url = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/add-group?api_logged_in_token=$token',
    );
    final response = await http.post(
      url,
      body: {'tournament_id': tournamentId.toString(), 'group_name': groupName},
    );

    final data = jsonDecode(response.body);
    return {
      'success': response.statusCode == 200 && data['status'] == 1,
      'data': data['data'],
      'message': data['message'] ?? '',
    };
  }

  static Future<List<Map<String, dynamic>>> getGroups({
    required String token,
    required int tournamentId,
  }) async {
    final url = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-groups?api_logged_in_token=$token&tournament_id=$tournamentId',
    );
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 1 && data['data'] is List) {
        return (data['data'] as List).map<Map<String, dynamic>>((e) {
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
    } else {
      throw Exception('Failed to fetch groups: ${response.body}');
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
    final url = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/add-team?api_logged_in_token=$token',
    );
    final body = {
      'team_name': teamName,
      'team_description': 'Created from group assignment',
      'team_logo': teamLogo,
      'team_players': playerIds,
      'tournament_id': tournamentId.toString(),
      'group_id': groupId.toString(),
    };
    final response = await http.post(url, body: body);
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> updateGroup({
    required String token,
    required int tournamentId,
    required int groupId,
    required String groupName,
  }) async {
    final url = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/update-group',
    );
    final response = await http.post(
      url,
      body: {
        'api_logged_in_token': token,
        'tournament_id': tournamentId.toString(),
        'group_id': groupId.toString(),
        'group_name': groupName,
      },
    );

    final data = json.decode(response.body);
    return {
      'success': response.statusCode == 200 && data['status'] == 1,
      'message': data['message'] ?? 'Unknown',
    };
  }

  static Future<Map<String, dynamic>> deleteGroup({
    required String token,
    required int tournamentId,
    required int groupId,
  }) async {
    final url = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/delete-group'
      '?api_logged_in_token=$token&tournament_id=$tournamentId&group_id=$groupId',
    );

    final response = await http.get(url);
    final data = json.decode(response.body);
    return {
      'success': response.statusCode == 200 && data['status'] == 1,
      'message': data['message'] ?? 'Unknown',
    };
  }
}
