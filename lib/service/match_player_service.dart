import 'dart:convert';
import 'package:http/http.dart' as http;

import '../model/match_player_model.dart';

class MatchPlayerService {
  static Future<PlayerPublicInfo> fetchPlayerInfo(int playerId) async {
    final url = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-player-public-info'
          '?player_id=$playerId',
    );
    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception('Failed to load player info');
    }
    final jsonBody = json.decode(response.body) as Map<String, dynamic>;
    if (jsonBody['status'] != 1 || jsonBody['player_info'] == null) {
      throw Exception(jsonBody['message'] ?? 'No player info available');
    }
    return PlayerPublicInfo.fromJson(jsonBody);
  }
}
