// lib/service/match_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_helper.dart';
import '../model/match_model.dart';

class MatchService {
  static const String _baseUrl =
      'https://cricjust.in/wp-json/custom-api-for-cricket';

  // ---------------------------------------------------------------------------
  // Robust GET (fixes: "Connection closed before full header was received")
  // ---------------------------------------------------------------------------
  static const Map<String, String> _defaultHeaders = {
    'Accept': 'application/json',
    // Avoid reusing flaky keep-alive sockets that sometimes break on this API
    'Connection': 'close',
  };

  /// A tiny resilient GET wrapper that:
  /// - sets `Connection: close` to avoid buggy keep-alive reuse
  /// - applies a timeout
  /// - retries on transient network exceptions
  /// - preserves ApiHelper.safeRequest behavior when `context` is provided
  static Future<http.Response> _robustGet(
      Uri uri, {
        BuildContext? context,
        int retries = 3,
        Duration timeout = const Duration(seconds: 20),
      }) async {
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        if (context != null) {
          final res = await ApiHelper.safeRequest(
            context: context,
            requestFn: () => http.get(uri, headers: _defaultHeaders),
          ).timeout(timeout);
          if (res == null) throw Exception('Request cancelled or failed');
          return res;
        } else {
          return await http.get(uri, headers: _defaultHeaders).timeout(timeout);
        }
      } on http.ClientException catch (_) {
        if (attempt >= retries) rethrow;
      } on SocketException catch (_) {
        if (attempt >= retries) rethrow;
      } on TimeoutException catch (_) {
        if (attempt >= retries) rethrow;
      }
      // brief linear backoff
      await Future.delayed(Duration(milliseconds: 200 * attempt));
    }
  }

  // -------------------------
  // Helpers
  // -------------------------
  static Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('api_logged_in_token') ?? '';
  }

  static Future<int?> _playerId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('player_id');
    return (id != null && id > 0) ? id : null;
  }

  static bool _looksLikeSessionExpired(String? message) {
    final m = (message ?? '').toLowerCase();
    return m.contains('token') ||
        m.contains('session') ||
        m.contains('unauthorized') ||
        m.contains('invalid api logged in token');
  }

  /// GET + JSON decode with optional ApiHelper.safeRequest (when context given)
  static Future<Map<String, dynamic>> _getJson({
    required Uri uri,
    BuildContext? context,
  }) async {
    final res = await _robustGet(uri, context: context);

    Map<String, dynamic>? body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>?;
    } catch (_) {
      body = null;
    }

    if (res.statusCode != 200 || body == null) {
      throw Exception('HTTP ${res.statusCode}');
    }

    if (body['status'] != 1) {
      final msg = (body['message'] ?? 'Failed').toString();
      if (_looksLikeSessionExpired(msg)) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        throw Exception('Session expired. Please login again.');
      }
      throw Exception(msg);
    }
    return body;
  }

  // -------------------------
  // New: PLAYER-SCOPED matches (no token, uses player_id)
  // -------------------------

  /// Raw fetch of a player's matches using the new endpoint:
  /// /get-player-public-info?player_id=..&type=match
  static Future<List<Map<String, dynamic>>> fetchMatchesByPlayerId({
    required int playerId,
  }) async {
    if (playerId <= 0) {
      throw Exception('Invalid player_id');
    }

    final uri = Uri.parse(
      '$_baseUrl/get-player-public-info?player_id=$playerId&type=match',
    );

    final res = await _robustGet(uri);
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }

    final decoded = json.decode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Bad response');
    }

    final status = decoded['status'];
    final ok = (status == 1 || status == '1' || status == true);
    if (!ok) {
      throw Exception(decoded['message']?.toString() ?? 'API error');
    }

    // Try to find the list of matches defensively
    final data = decoded['data'];
    List<dynamic> list = const [];

    if (data is List) {
      list = data;
    } else if (data is Map<String, dynamic>) {
      list = (data['matches'] as List?) ??
          (data['my_matches'] as List?) ??
          (data['data'] as List?) ??
          (data['list'] as List?) ??
          const [];
      if (list.isEmpty) {
        // fallback: first List inside map
        for (final v in data.values) {
          if (v is List) {
            list = v;
            break;
          }
        }
      }
    }

    return list.cast<Map<String, dynamic>>();
  }

  /// Convenience: read player_id from storage and fetch matches.
  static Future<List<Map<String, dynamic>>> fetchMyMatchesViaPlayer() async {
    final pid = await _playerId();
    if (pid == null) {
      throw Exception('Not logged in (missing player_id)');
    }
    return fetchMatchesByPlayerId(playerId: pid);
  }

  // -------------------------
  // Unified listing (token-based, admin/user scope decided by backend)
  // -------------------------

  /// Core listing: server scopes by token (user/admin).
  static Future<List<Map<String, dynamic>>> getCricketMatches({
    BuildContext? context,
    int limit = 20,
    int skip = 0,
    String search = '',
    int? tournamentId,
    int? status, // optional filter if backend supports
  }) async {
    final token = await _token();
    if (token.isEmpty) throw Exception('Missing API token');

    final qp = <String, String>{
      'api_logged_in_token': token,
      'limit': '$limit',
      'skip': '$skip',
    };
    if (search.isNotEmpty) qp['search'] = search;
    if (tournamentId != null) qp['tournament_id'] = '$tournamentId';
    if (status != null) qp['status'] = '$status';

    final uri = Uri.parse('$_baseUrl/get-cricket-matches')
        .replace(queryParameters: qp);

    final body = await _getJson(uri: uri, context: context);
    final data = body['data'];
    return (data is List)
        ? data.cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[];
  }

  /// Your existing entry points preserved, now using the unified getter.
  static Future<List<Map<String, dynamic>>> fetchUserMatches({
    required BuildContext context,
    int limit = 20,
    int skip = 0,
    String search = '',
    int? tournamentId,
    int? status,
  }) {
    return getCricketMatches(
      context: context,
      limit: limit,
      skip: skip,
      search: search,
      tournamentId: tournamentId,
      status: status,
    );
  }

  static Future<List<Map<String, dynamic>>> fetchAllMatchesForAdmin({
    int limit = 20,
    int skip = 0,
    String search = '',
    int? tournamentId,
    int? status,
  }) {
    // Admin/list is decided by backend via token; keeping a separate method for clarity
    return getCricketMatches(
      limit: limit,
      skip: skip,
      search: search,
      tournamentId: tournamentId,
      status: status,
    );
  }

  // -------------------------
  // Legacy endpoints (kept)
  // -------------------------

  /// Legacy feed by type (home sections). Increase `limit` where you call it.
  static Future<List<MatchModel>> fetchMatches({
    required String type,
    int limit = 10,
    int skip = 0,
  }) async {
    final url = Uri.parse(
      '$_baseUrl/get-matches?type=$type&limit=$limit&skip=$skip',
    );

    final res = await _robustGet(url);
    if (res.statusCode != 200) {
      throw Exception('Failed to load $type matches');
    }
    final body = jsonDecode(res.body);
    if (body['status'] == 1) {
      final data = List<Map<String, dynamic>>.from(body['data']);
      return data.map((json) => MatchModel.fromJson(json)).toList();
    } else {
      final msg = (body['message'] ?? 'Failed to load matches').toString();
      if (_looksLikeSessionExpired(msg)) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        throw Exception('Session expired. Please login again.');
      }
      throw Exception(msg);
    }
  }

  /// If your Update screen expects single-match details, prefer the newer
  /// single-match endpoint below. This is kept for backward-compatibility.
  static Future<MatchModel> fetchMatchById(int matchId) async {
    final url = Uri.parse('$_baseUrl/get-match-detail?match_id=$matchId');
    final res = await _robustGet(url);

    if (res.statusCode != 200) {
      throw Exception('Failed to load match detail');
    }
    final body = jsonDecode(res.body);
    if (body['status'] == 1 && body['data'] != null) {
      return MatchModel.fromJson(body['data']);
    } else {
      final msg = (body['message'] ?? 'Match not found').toString();
      if (_looksLikeSessionExpired(msg)) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        throw Exception('Session expired. Please login again.');
      }
      throw Exception(msg);
    }
  }

  // -------------------------
  // Single match (newer detail)
  // -------------------------

  static Future<Map<String, dynamic>?> getSingleCricketMatch(int matchId) async {
    final token = await _token();
    if (token.isEmpty) throw Exception('Missing API token');

    final uri = Uri.parse(
      '$_baseUrl/get-single-cricket-match'
          '?api_logged_in_token=$token&match_id=$matchId',
    );

    final body = await _getJson(uri: uri);
    final data = body['data'];
    if (data is List && data.isNotEmpty) {
      return data.first as Map<String, dynamic>;
    }
    return null;
  }

  // -------------------------
  // Current score (resilient)
  // -------------------------

  static Future<Map<String, dynamic>?> fetchCurrentScore(int matchId) async {
    // Try the lightweight current-score first
    final currentUri = Uri.parse(
      '$_baseUrl/get-current-match-score?match_id=$matchId',
    );
    try {
      final res = await _robustGet(
        currentUri,
        timeout: const Duration(seconds: 12),
      );
      if (res.statusCode == 200) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        if (body['status'] == 1 && body['current_score'] != null) {
          return body;
        }
      }
    } catch (_) {
      // fall through to summary
    }

    // Fallback to summary (richer, but heavier)
    try {
      final token = await _token();
      final summaryUri = Uri.parse(
        '$_baseUrl/get-match?match_id=$matchId&type=summary&api_logged_in_token=$token',
      );
      final body = await _getJson(uri: summaryUri);
      return body;
    } catch (e) {
      debugPrint('❌ fetchCurrentScore fallback error: $e');
      return null;
    }
  }

  // -------------------------
  // Delete
  // -------------------------

  static Future<bool> deleteMatch(int matchId) async {
    final token = await _token();
    if (token.isEmpty) throw Exception('Missing API token');

    final uri = Uri.parse(
      '$_baseUrl/delete-cricket-match'
          '?api_logged_in_token=$token&match_id=$matchId',
    );

    final body = await _getJson(uri: uri);
    return body['status'] == 1;
  }


  // -------------------------
// Update Match
// -------------------------

  static Future<Map<String, dynamic>> updateMatch({
    required String apiToken,
    required int matchId,
    required Map<String, String> formData,
  }) async {
    final uri = Uri.parse('$_baseUrl/update-cricket-match').replace(
      queryParameters: {
        'api_logged_in_token': apiToken,
        'match_id': matchId.toString(),
      },
    );

    try {
      final res = await http.post(uri, body: formData).timeout(const Duration(seconds: 25));

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.reasonPhrase}');
      }

      final body = json.decode(res.body);
      if (body is! Map<String, dynamic>) {
        throw Exception('Invalid response format');
      }

      if (body['status'] != 1) {
        final msg = (body['message'] ??
            (body['error']?.toString() ?? 'Failed to update match'))
            .toString();
        if (_looksLikeSessionExpired(msg)) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
          throw Exception('Session expired. Please login again.');
        }
        throw Exception(msg);
      }

      return body;
    } on TimeoutException {
      throw Exception('Server timeout, please try again.');
    } on SocketException {
      throw Exception('Network error. Please check your connection.');
    } catch (e) {
      throw Exception('Failed to update match: $e');
    }
  }
// -------------------------
// Update Group
// -------------------------
  static Future<Map<String, dynamic>> updateGroup({
    required String token,
    required int tournamentId,
    required int groupId,
    required String groupName,
  }) async {
    final uri = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/update-group'
          '?api_logged_in_token=$token',
    );

    final body = {
      'tournament_id': tournamentId.toString(),
      'group_id': groupId.toString(),
      'group_name': groupName,
    };

    try {
      final response = await http
          .post(uri, body: body)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final jsonBody = json.decode(response.body);
      if (jsonBody['status'] == 1) {
        return {
          'success': true,
          'message': jsonBody['message'] ?? 'Group updated successfully',
          'data': jsonBody['data'] ?? [],
        };
      } else {
        return {
          'success': false,
          'message': jsonBody['message'] ??
              (jsonBody['error']?.toString() ?? 'Failed to update group'),
        };
      }
    } on TimeoutException {
      return {'success': false, 'message': 'Server timeout. Please try again.'};
    } on SocketException {
      return {'success': false, 'message': 'Network error. Please check your connection.'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to update group: $e'};
    }
  }


}
