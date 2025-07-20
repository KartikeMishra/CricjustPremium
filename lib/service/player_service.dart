// lib/service/player_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class PlayerService {
  static const String _base =
      'https://cricjust.in/wp-json/custom-api-for-cricket';

  /// Fetch all players for a given team via the dedicated endpoint
  static Future<List<Map<String, dynamic>>> fetchTeamPlayers({
    required int teamId,
    required String apiToken,
    int limit = 100,
    int skip = 0,
    String search = '',
  }) async {
    final uri = Uri.parse(
      '$_base/get-players'
      '?api_logged_in_token=$apiToken'
      '&limit=$limit'
      '&skip=$skip'
      '&tournament_id=0'
      '&search=$search'
      '&team_id=$teamId',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) return [];

    final body = json.decode(response.body);
    if (body['status'] != 1 || body['data'] == null) return [];

    return List<Map<String, dynamic>>.from(body['data']);
  }
}
