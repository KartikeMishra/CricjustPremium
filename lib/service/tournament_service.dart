import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/tournament_model.dart';
import '../model/tournament_overview_model.dart';
import '../model/fair_play_model.dart';
import '../model/tournament_match_detail_model.dart';
import '../model/tournament_stats_model.dart';

class TournamentService {
  static const String _base = 'https://cricjust.in/wp-json/custom-api-for-cricket';

  static Future<Map<String, dynamic>> fetchTournamentOverview(int id) async {
    final uri = Uri.parse('$_base/get-single-tournament-overview?tournament_id=$id&type=overview');
    final resp = await http.get(uri);

    if (resp.statusCode != 200) {
      throw Exception('Failed to load overview (HTTP ${resp.statusCode})');
    }

    final body = json.decode(resp.body) as Map<String, dynamic>;
    if (body['status'] != 1) {
      throw Exception('API returned status ${body['status']}');
    }

    final dataMap = body['data'] as Map<String, dynamic>;
    final tournament = TournamentOverview.fromJson(dataMap);

    final teamsJson = (body['teams'] as List<dynamic>?) ?? [];
    final pointsTeams = teamsJson.map((e) => TeamStanding.fromJson(e)).toList();

    final hasGroups = (dataMap['is_group'] as int? ?? 0) == 1;
    final groups = hasGroups
        ? (body['groups'] as List<dynamic>?)?.map((g) => GroupModel.fromJson(g)).toList() ?? []
        : [GroupModel(groupId: '0', groupName: 'All Teams')];

    return {
      'tournament': tournament,
      'pointsTeams': pointsTeams,
      'groups': groups,
    };
  }

  static Future<List<FairPlayStanding>> fetchFairPlay(int id) async {
    final uri = Uri.parse('$_base/get-single-tournament-overview?tournament_id=$id&type=fairplay');
    final resp = await http.get(uri);

    if (resp.statusCode != 200) {
      throw Exception('Failed to load fair-play (HTTP ${resp.statusCode})');
    }

    final body = json.decode(resp.body) as Map<String, dynamic>;
    if (body['status'] != 1) {
      throw Exception('API returned status ${body['status']}');
    }

    final listJson = (body['data'] as List<dynamic>?) ?? [];
    return listJson.map((e) => FairPlayStanding.fromJson(e)).toList();
  }

  static Future<Map<String, dynamic>> fetchTournamentOverviewWithFairPlay(int id) async {
    final overview = await fetchTournamentOverview(id);
    final fairPlay = await fetchFairPlay(id);
    overview['fairPlayTeams'] = fairPlay;
    return overview;
  }

  static Future<Map<String, dynamic>> fetchTournamentStats(int tournamentId) async {
    final url = Uri.parse('$_base/get-single-tournament-overview?tournament_id=$tournamentId&type=stats');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final jsonBody = jsonDecode(response.body);
      if (jsonBody['status'] == 1) {
        return {
          'mostRuns': (jsonBody['get_most_runs_api'] as List?)?.map((e) => RunStats.fromJson(e)).toList() ?? [],
          'mostWickets': (jsonBody['get_most_wickets_api'] as List?)?.map((e) => WicketStats.fromJson(e)).toList() ?? [],
          'mostSixes': (jsonBody['get_most_sixes_api'] as List?)?.map((e) => SixStats.fromJson(e)).toList() ?? [],
          'mostFours': (jsonBody['get_most_fours_api'] as List?)?.map((e) => FourStats.fromJson(e)).toList() ?? [],
          'highestScores': (jsonBody['get_highest_score_api'] as List?)?.map((e) => HighestScore.fromJson(e)).toList() ?? [],
          'mvp': (jsonBody['mvp'] as List?)?.map((e) => MVP.fromJson(e)).toList() ?? [],
          'summary': jsonBody['get_all'] != null ? SummaryStats.fromJson(jsonBody['get_all']) : SummaryStats(
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

  static Future<List<TournamentModel>> fetchTournaments({String? type, int? limit, int? skip}) async {
    final params = <String, String>{};
    if (type != null) params['type'] = type;
    if (limit != null) params['limit'] = limit.toString();
    if (skip != null) params['skip'] = skip.toString();

    final uri = Uri.parse('$_base/get-tournaments').replace(queryParameters: params);
    final resp = await http.get(uri);

    if (resp.statusCode != 200) {
      throw Exception('Failed to load tournaments (HTTP ${resp.statusCode})');
    }

    final body = json.decode(resp.body) as Map<String, dynamic>;
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

    if (resp.statusCode != 200) {
      throw Exception('Failed to load tournament matches (HTTP ${resp.statusCode})');
    }

    final body = json.decode(resp.body) as Map<String, dynamic>;
    if (body['status'] != 1 || body['data'] == null || body['data'] is! List) {
      return [];
    }

    final matchesJson = body['data'] as List<dynamic>;
    return matchesJson.map((e) => TournamentMatchDetail.fromJson(e)).toList();
  }
}