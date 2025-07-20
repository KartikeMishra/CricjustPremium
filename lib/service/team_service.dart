// lib/service/team_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/team_model.dart';

class TeamService {
  static const String _base =
      'https://cricjust.in/wp-json/custom-api-for-cricket';

  /// Fetch list of teams with pagination and search
  static Future<List<TeamModel>> fetchTeams({
    required String apiToken,
    int limit = 20,
    int skip = 0,
    String search = '',
    int? tournamentId, // ✅ Add this
  }) async {
    final uri = Uri.parse(
      '$_base/get-teams?api_logged_in_token=$apiToken'
      '&limit=$limit&skip=$skip'
      '&search=$search'
      '${tournamentId != null ? '&tournament_id=$tournamentId' : ''}', // ✅ Append if present
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch teams');
    }
    final body = json.decode(response.body);
    if (body['status'] != 1) {
      throw Exception('API error: ${body['message']}');
    }

    final List data = body['data'] ?? [];
    return data.map((json) => TeamModel.fromJson(json)).toList();
  }

  /// Fetch a single team’s details by ID using the single-team endpoint
  static Future<TeamModel?> fetchTeamDetail({
    required int teamId,
    required String apiToken,
  }) async {
    final uri = Uri.parse(
      '$_base/get-single-team?api_logged_in_token=$apiToken&team_id=$teamId',
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch team detail');
    }

    final body = json.decode(response.body);
    if (body['status'] != 1) {
      return null;
    }

    final List data = body['data'] as List<dynamic>;
    if (data.isEmpty) return null;

    return TeamModel.fromJson(data.first as Map<String, dynamic>);
  }

  /// Delete a team by ID
  static Future<void> deleteTeam(int teamId, String apiToken) async {
    final uri = Uri.parse(
      '$_base/delete-team?api_logged_in_token=$apiToken&team_id=$teamId',
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete team');
    }
    final body = json.decode(response.body);
    if (body['status'] != 1) {
      throw Exception('Delete failed: ${body['message']}');
    }
  }

  /// Update team details (name, description, origin)
  /// Update team details including player list
  static Future<bool> updateTeam({
    required int teamId,
    required String apiToken,
    required String name,
    required String description,
    required String origin,
    required List<int> playerIds,
  }) async {
    final uri = Uri.parse(
      '$_base/update-team?api_logged_in_token=$apiToken&team_id=$teamId',
    );

    final Map<String, String> body = {
      'team_name': name,
      'team_description': description,
      'team_origin': origin,
    };

    for (int i = 0; i < playerIds.length; i++) {
      body['team_players[$i]'] = playerIds[i].toString();
    }

    try {
      final response = await http.post(uri, body: body);
      print('📡 [UPDATE TEAM] Status: ${response.statusCode}');
      print('📥 [UPDATE TEAM] Response Body: ${response.body}');

      if (response.statusCode != 200) return false;

      final jsonResponse = json.decode(response.body);
      return jsonResponse['status'] == 1;
    } catch (e) {
      print('🚨 Error in updateTeam: $e');
      return false;
    }
  }

  /// Add a new team with players (supports optional tournament_id)
  static Future<bool> addTeam({
    required String apiToken,
    required String name,
    required String description,
    required String logo,
    List<int> playerIds = const [],
    int? tournamentId,
  }) async {
    final uri = Uri.parse('$_base/add-team?api_logged_in_token=$apiToken');

    final Map<String, String> body = {
      'team_name': name,
      'team_description': description,
      'team_logo': logo,
    };

    if (tournamentId != null) {
      body['tournament_id'] = tournamentId.toString();
    }

    for (int i = 0; i < playerIds.length; i++) {
      body['team_players[$i]'] = playerIds[i].toString();
    }

    try {
      final response = await http.post(uri, body: body);
      final jsonResponse = json.decode(response.body);
      return jsonResponse['status'] == 1;
    } catch (e) {
      print('🚨 Error in addTeam: $e');
      return false;
    }
  }

  /// Search players with pagination and query
  static Future<List<Map<String, dynamic>>> searchPlayers({
    required String apiToken,
    required String query,
    int limit = 20,
    int skip = 0,
  }) async {
    final uri = Uri.parse(
      '$_base/get-players?api_logged_in_token=$apiToken&limit=$limit&skip=$skip&search=$query',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) return [];

    final jsonBody = json.decode(response.body);
    return List<Map<String, dynamic>>.from(jsonBody['data'] ?? []);
  }

  static Future<List<Map<String, dynamic>>> fetchUmpires({
    required String apiToken,
    int limit = 20,
    int skip = 0,
  }) async {
    final uri = Uri.parse(
      '$_base/get-players?api_logged_in_token=$apiToken&limit=$limit&skip=$skip&tournament_id=0&team_id=0&type=umpire',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) return [];

    final jsonBody = json.decode(response.body);
    return List<Map<String, dynamic>>.from(jsonBody['data'] ?? []);
  }
}
