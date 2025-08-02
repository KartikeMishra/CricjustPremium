// lib/service/player_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class PlayerService {
  static const String _base = 'https://cricjust.in/wp-json/custom-api-for-cricket';

  /// Simple in‑memory cache so we don’t hit the API again for the same player.
  static final Map<int, Map<String, dynamic>> _playerCache = {};

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

    final res = await http.get(uri);
    if (res.statusCode != 200) return [];

    final body = json.decode(res.body);
    if (body['status'] != 1 || body['data'] == null) return [];

    return List<Map<String, dynamic>>.from(body['data']);
  }

  /// Fetch a single player's public info. Uses in-memory cache.
  static Future<Map<String, dynamic>?> fetchPlayerPublicInfo(int playerId) async {
    // Return cached if we already fetched it.
    if (_playerCache.containsKey(playerId)) {
      return _playerCache[playerId];
    }

    final uri = Uri.parse('$_base/get-player-public-info?player_id=$playerId');
    try {
      final res = await http.get(uri);
      if (res.statusCode != 200) return null;

      final body = json.decode(res.body);
      if (body['status'] == 1) {
        final data = (body['message'] ?? {}) as Map<String, dynamic>;
        _playerCache[playerId] = data;
        return data;
      }
    } catch (e) {
      // swallow & return null – your UI can decide what to do
    }
    return null;
  }

  /// Preload a bunch of player profiles in one go (will fill the cache).
  static Future<void> preloadPlayerProfiles(Iterable<int> playerIds) async {
    for (final id in playerIds) {
      if (!_playerCache.containsKey(id)) {
        await fetchPlayerPublicInfo(id);
      }
    }
  }

  /// Quick helper to get a display name (cached or fetched).
  static Future<String?> getPlayerName(int playerId) async {
    final info = await fetchPlayerPublicInfo(playerId);
    // Adjust keys based on your API's actual response fields.
    return info?['display_name'] ??
        info?['name'] ??
        info?['user_login'] ??
        info?['player_name'];
  }

  /// Clear the in-memory cache (if you ever need to).
  static void clearCache() => _playerCache.clear();
}
