// lib/service/global_search_service.dart
// ONE SERVICE FILE: calls WP JSON once per type

import 'dart:io';
import 'package:http/http.dart' as http;

import '../model/search_result_model.dart';

class GlobalSearchService {
  static const String _endpoint =
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-search-by-type';

  static Future<String> _getRaw(SearchType type, String query) async {
    final q = query.trim();
    if (q.isEmpty) return '{"status":1,"data":[]}';

    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'search_type': searchTypeParam(type),
      'search_words': q,
    });

    final resp = await http.get(uri, headers: {
      HttpHeaders.acceptHeader: 'application/json',
    });

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw HttpException('Search failed (${resp.statusCode})');
    }

    return resp.body;
  }

  static Future<List<PlayerResult>> players(String query) async {
    final body = await _getRaw(SearchType.player, query);
    return SearchResponseParser.parsePlayers(body);
  }

  static Future<List<MatchResult>> matches(String query) async {
    final body = await _getRaw(SearchType.match, query);
    return SearchResponseParser.parseMatches(body);
  }

  static Future<List<TournamentResult>> tournaments(String query) async {
    final body = await _getRaw(SearchType.tournament, query);
    return SearchResponseParser.parseTournaments(body);
  }
}
