// lib/service/match_commentary_service.dart
import 'dart:io';
import 'dart:async'; // for TimeoutException
import 'package:http/http.dart' as http;

import '../model/match_commentary_model.dart';

class CommentaryService {
  static const String _endpoint =
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-commentry';

  // Small safety so requests don't hang forever
  static const Duration _timeout = Duration(seconds: 12);

  /// Preferred: returns a CommPage with flattened events + itemsCount.
  static Future<CommPage> fetchPage({
    required int matchId,
    required int teamId,
    int limit = 10, // match backend
    int skip = 0,
  }) async {
    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'match_id': '$matchId',
      'team_id': '$teamId',
      'limit': '$limit',
      'skip': '$skip',
    });

    try {
      final resp = await http
          .get(
        uri,
        headers: {
          HttpHeaders.acceptHeader: 'application/json',
          // Helps avoid stale caches on some WP setups (optional)
          HttpHeaders.cacheControlHeader: 'no-cache',
        },
      )
          .timeout(_timeout);

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final page = parseCommPageFromRaw(resp.body);
        // Debug (optional):
        // print('[Commentary] GET $uri -> items=${page.itemsCount}, events=${page.events.length}');
        return page;
      } else {
        throw HttpException(
          'Failed to load commentary (${resp.statusCode})',
          uri: uri,
        );
      }
    } on TimeoutException {
      throw HttpException('Commentary request timed out', uri: uri);
    } on SocketException catch (e) {
      throw HttpException('Network error: ${e.message}', uri: uri);
    }
  }

  /// Back-compat helper: returns only events for one page.
  static Future<List<CommEvent>> fetch({
    required int matchId,
    required int teamId,
    int limit = 10,
    int skip = 0,
  }) async {
    final page = await fetchPage(
      matchId: matchId,
      teamId: teamId,
      limit: limit,
      skip: skip,
    );
    return page.events;
  }
}
