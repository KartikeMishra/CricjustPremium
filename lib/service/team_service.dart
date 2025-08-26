// lib/service/team_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/team_model.dart';
import '../utils/net.dart'; // <-- use the hardened GET helper

class TeamService {
  static const String _base =
      'https://cricjust.in/wp-json/custom-api-for-cricket';

  /// Fetch list of teams with pagination and search
  static Future<List<TeamModel>> fetchTeams({
    required String apiToken,
    int limit = 20,
    int skip = 0,
    String search = '',
    int? tournamentId,
  }) async {
    final uri = Uri.parse(
      '$_base/get-teams'
          '?api_logged_in_token=$apiToken'
          '&limit=$limit'
          '&skip=$skip'
          '&search=${Uri.encodeQueryComponent(search)}'
          '${tournamentId != null ? '&tournament_id=$tournamentId' : ''}',
    );

    try {
      final response = await Net.get(uri, timeout: const Duration(seconds: 20), maxRetries: 2);
      if (response.statusCode != 200) return [];
      final body = json.decode(response.body);
      if (body['status'] != 1) return [];
      final List data = body['data'] ?? [];
      return data.map((j) => TeamModel.fromJson(j)).toList();
    } catch (_) {
      // network flake -> just return empty instead of throwing
      return [];
    }
  }

  /// Fetch a single team’s details by ID using the single-team endpoint
  static Future<TeamModel?> fetchTeamDetail({
    required int teamId,
    required String apiToken,
  }) async {
    final uri = Uri.parse(
      '$_base/get-single-team?api_logged_in_token=$apiToken&team_id=$teamId',
    );
    try {
      final response = await Net.get(uri, timeout: const Duration(seconds: 20), maxRetries: 2);
      if (response.statusCode != 200) return null;

      final body = json.decode(response.body);
      if (body['status'] != 1) return null;

      final List data = body['data'] as List<dynamic>;
      if (data.isEmpty) return null;

      return TeamModel.fromJson(data.first as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Delete a team by ID
  static Future<void> deleteTeam(int teamId, String apiToken) async {
    final uri = Uri.parse(
      '$_base/delete-team?api_logged_in_token=$apiToken&team_id=$teamId',
    );
    final response = await Net.get(uri, timeout: const Duration(seconds: 20), maxRetries: 2);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete team');
    }
    final body = json.decode(response.body);
    if (body['status'] != 1) {
      throw Exception('Delete failed: ${body['message']}');
    }
  }

  /// Update team details including player list (and optional logo)
  static Future<bool> updateTeam({
    required int teamId,
    required String apiToken,
    required String name,
    required String description,
    required String origin,
    required List<int> playerIds,
    String? logoUrl,
  }) async {
    final uri = Uri.parse(
      '$_base/update-team?api_logged_in_token=$apiToken&team_id=$teamId',
    );

    final Map<String, String> body = {
      'team_name': name,
      'team_description': description,
      'team_origin': origin,
    };

    if (logoUrl != null && logoUrl.isNotEmpty) {
      body['team_logo'] = logoUrl;
    }

    for (int i = 0; i < playerIds.length; i++) {
      body['team_players[$i]'] = playerIds[i].toString();
    }

    try {
      final response = await http
          .post(
        uri,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'CricjustApp/1.0 (Flutter; Android)',
          'Connection': 'close',
        },
        body: body,
      )
          .timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) return false;
      final jsonResponse = json.decode(response.body);
      return jsonResponse['status'] == 1;
    } catch (_) {
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
      final response = await http
          .post(
        uri,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'CricjustApp/1.0 (Flutter; Android)',
          'Connection': 'close',
        },
        body: body,
      )
          .timeout(const Duration(seconds: 25));
      final jsonResponse = json.decode(response.body);
      return jsonResponse['status'] == 1;
    } catch (e) {
      // Keep your log if you want:
      // print('🚨 Error in addTeam: $e');
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
      '$_base/get-players?api_logged_in_token=$apiToken'
          '&limit=$limit&skip=$skip&search=${Uri.encodeQueryComponent(query)}',
    );

    try {
      final response = await Net.get(uri, timeout: const Duration(seconds: 20), maxRetries: 2);
      if (response.statusCode != 200) return [];
      final jsonBody = json.decode(response.body);
      return List<Map<String, dynamic>>.from(jsonBody['data'] ?? []);
    } catch (_) {
      return [];
    }
  }

  /// Fetch umpires (safe: returns [] on any network/server hiccup)
  static Future<List<Map<String, dynamic>>> fetchUmpires({
    required String apiToken,
    int limit = 20,
    int skip = 0,
  }) async {
    final uri = Uri.parse(
      '$_base/get-players?api_logged_in_token=$apiToken'
          '&limit=$limit&skip=$skip&tournament_id=0&team_id=0&type=umpire',
    );

    try {
      final res = await Net.get(uri, timeout: const Duration(seconds: 20), maxRetries: 2);
      if (res.statusCode != 200) return [];
      final map = json.decode(res.body) as Map<String, dynamic>;
      if ((map['status'] as int? ?? 0) != 1) return [];
      final list = (map['data'] as List?) ?? const [];
      // Normalize to {id, display_name}
      return list.map<Map<String, dynamic>>((e) {
        final m = e as Map<String, dynamic>;
        return {
          'id': (m['ID'] ?? m['id'] ?? '').toString(),
          'display_name': (m['display_name'] ?? m['name'] ?? 'Unknown').toString(),
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
