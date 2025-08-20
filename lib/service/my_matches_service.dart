// lib/service/my_matches_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../model/my_matches_model.dart';
import '../service/session_manager.dart';

class MyMatchesService {
  static const String _base =
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-player-public-info';

  /// Fetch matches for the current (or provided) player using the new endpoint:
  /// GET /get-player-public-info?player_id=<id>&type=match
  static Future<List<MyMatch>> fetch({int? playerId}) async {
    // Resolve player id
    int? pid = playerId ?? await SessionManager.getPlayerId();
    if (pid == null || pid <= 0) {
      // Fallback to prefs if SessionManager doesn’t have it
      final prefs = await SharedPreferences.getInstance();
      pid = prefs.getInt('player_id');
    }
    if (pid == null || pid <= 0) {
      throw Exception('Not logged in (missing player_id)');
    }

    final uri = Uri.parse('$_base?player_id=$pid&type=match');
    final resp = await http.get(uri, headers: const {
      'accept': 'application/json',
      'accept-encoding': 'gzip',
      'connection': 'keep-alive',
    });

    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}');
    }

    final root = json.decode(resp.body) as Map<String, dynamic>;

    // Some responses use {status, data:[...]}, others nest lists deeper (e.g. {data: {matches: []}})
    final status = root['status'];
    if (status != 1 && status != '1') {
      // API sometimes returns message when no data
      final msg = (root['message'] ?? 'API error').toString();
      // Don’t throw hard on empty; return empty list if “no matches”
      if (msg.toLowerCase().contains('no match')) return <MyMatch>[];
      throw Exception('API error: $msg');
    }

    final data = root['data'];
    List list;

    if (data is List) {
      list = data;
    } else if (data is Map) {
      list = (data['matches'] as List?) ??
          (data['match'] as List?) ??
          (data['data'] as List?) ??
          const <dynamic>[];
    } else {
      list = const <dynamic>[];
    }

    return list
        .whereType<Map>()
        .map((e) => MyMatch.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
