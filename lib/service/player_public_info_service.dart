// lib/service/player_personal_info_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../model/player_public_info_model.dart';

class PlayerPersonalInfoService {
  static const String _baseUrl =
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-player-public-info?player_id=';

  /// Fetch personal info for a player by their [playerId]
  static Future<PlayerPersonalInfo> fetch(int playerId) async {
    final uri = Uri.parse('$_baseUrl$playerId');

    final res = await http.get(uri).timeout(const Duration(seconds: 20));

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.reasonPhrase}');
    }

    final body = json.decode(res.body) as Map<String, dynamic>;
    final status = (body['status'] ?? 0) as int;
    if (status != 1) {
      throw Exception('API returned status != 1');
    }

    return PlayerPersonalInfo.fromJson(body);
  }
}
