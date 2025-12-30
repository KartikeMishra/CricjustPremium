// lib/service/role_players_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class RolePlayersService {
  // ---------- helpers ----------
  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse((v ?? '').toString()) ?? 0;
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse((v ?? '').toString()) ?? 0.0;
  }

  static String _toStr(dynamic v) => (v ?? '').toString();

  static int _pickId(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      if (m.containsKey(k)) {
        final id = _toInt(m[k]);
        if (id > 0) return id;
      }
    }
    return 0;
  }

  /// Some endpoints return:
  ///   {status:1, data:[...]}
  /// Others may return:
  ///   {status:1, data:{bowlers:[...]}}  OR  {status:1, data:{ ...single item... }}
  /// This extracts the *first* list it can find, or wraps a single map as a list.
  static List<Map<String, dynamic>> _extractMapList(dynamic data) {
    // Case 1: already a List
    if (data is List) {
      return data
          .whereType<Map>()
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    // Case 2: Map that contains a list somewhere
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      // Common keys to try first
      for (final key in const ['bowlers', 'batters', 'players', 'list', 'data']) {
        final v = map[key];
        if (v is List) {
          return v
              .whereType<Map>()
              .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }
      // Fallback: pick the first value that is a List
      for (final v in map.values) {
        if (v is List) {
          return v
              .whereType<Map>()
              .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }
      // Fallback: if the map looks like a single item, wrap it
      if (map.isNotEmpty) return [map];
    }

    return const [];
  }

  /// Parses overs/balls flexibly:
  /// - if "balls" provided, use (overs, balls)
  /// - else if overs like "3.4", treat as 3 overs, 4 balls
  /// - else if overs int/double, balls 0
  static ({int overs, int balls}) _parseOversBalls(dynamic oversField, dynamic ballsField) {
    int overs = 0, balls = 0;

    if (ballsField != null) {
      overs = _toInt(oversField);
      balls = _toInt(ballsField).clamp(0, 5);
      return (overs: overs, balls: balls);
    }

    final s = _toStr(oversField);
    if (s.contains('.')) {
      final parts = s.split('.');
      overs = _toInt(parts[0]);
      balls = _toInt(parts.length > 1 ? parts[1] : 0).clamp(0, 5);
      return (overs: overs, balls: balls);
    }

    overs = _toInt(oversField);
    balls = 0;
    return (overs: overs, balls: balls);
  }

  // ---------- public API ----------
  /// GET /get-batters-by-team?match_id=..&team_id=..
  static Future<List<Map<String, dynamic>>> fetchBattersByTeam({
    required int matchId,
    required int teamId,
  }) async {
    try {
      final uri = Uri.parse(
        'https://cricjust.in/wp-json/custom-api-for-cricket/get-batters-by-team'
            '?match_id=$matchId&team_id=$teamId',
      );

      final res = await http.get(uri);
      if (res.statusCode != 200) return [];

      final body = json.decode(res.body);
      if (body is! Map || body['status'] != 1) return [];

      // Robustly handle: data:[...], or data:{batters:[...]}, or data:{...single item...}
      final list = _extractMapList(body['data']);

      return list.map<Map<String, dynamic>>((m) {
        // Accept multiple possible id keys
        final id = _pickId(m, ['user_id', 'batter_id', 'batsman_id', 'player_id', 'id']);
        final name = _toStr(m['name'] ?? m['display_name'] ?? m['user_login'] ?? 'Unknown');

        // Stats (tolerant parsing)
        final r     = _toInt(m['r']);
        final b     = _toInt(m['b']);
        final fours = _toInt(m['4s']);
        final sixes = _toInt(m['6s']);
        final sr    = _toDouble(m['sr']);
        final order = _toInt(m['order']);
        final outBy = _toStr(m['out_by']);

        // Mark OUT if API says is_out=1 OR out_by text present (and not "0")
        final isOut = _toInt(m['is_out']) == 1 || (outBy.isNotEmpty && outBy != '0');

        return {
          'id'    : id,
          'name'  : name,
          'is_out': isOut ? 1 : 0,
          'stats' : {
            'r': r,
            'b': b,
            '4s': fours,
            '6s': sixes,
            'sr': sr,
            'order': order,
            'out_by': outBy,
          },
        };
      }).where((e) => (e['id'] as int) > 0).toList();
    } catch (_) {
      return [];
    }
  }


  /// GET /get-bowlers-by-team?match_id=..&team_id=..
  static Future<List<Map<String, dynamic>>> fetchBowlersByTeam({
    required int matchId,
    required int teamId,
  }) async {
    try {
      final uri = Uri.parse(
        'https://cricjust.in/wp-json/custom-api-for-cricket/get-bowlers-by-team'
            '?match_id=$matchId&team_id=$teamId',
      );

      final res = await http.get(uri);
      if (res.statusCode != 200) return [];

      final body = json.decode(res.body);
      if (body is! Map || body['status'] != 1) return [];

      final list = _extractMapList(body['data']);
      return list.map<Map<String, dynamic>>((m) {
        final id = _pickId(m, ['bowler_id', 'player_id', 'id']);
        final name = _toStr(m['name'] ?? m['display_name'] ?? m['user_login'] ?? 'Unknown');

        final parsed = _parseOversBalls(m['overs'], m['balls']);
        final maid   = _toInt(m['maiden']);
        final runs   = _toInt(m['runs']);
        final wkts   = _toInt(m['wickets']);
        final econ   = _toDouble(m['economy']);

        return {
          'id': id,
          'name': name,
          'stats': {
            'overs': parsed.overs,
            'balls': parsed.balls,
            'maiden': maid,
            'runs': runs,
            'wickets': wkts,
            'economy': econ,
          }
        };
      }).where((e) => (e['id'] as int) > 0).toList();
    } catch (_) {
      return [];
    }
  }
}
