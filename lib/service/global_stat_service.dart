import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/global_stat_model.dart';

class GlobalStatService {
  static const String _baseUrl =
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-globalstats';

  // 🧠 In-memory cache
  static Map<String, String>? _cachedStats;
  static DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// 🔁 Fetches overall stats with caching and parallel requests
  static Future<Map<String, String>> fetchOverallStats() async {
    if (_cachedStats != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
      return _cachedStats!;
    }

    final fields = [
      'total_extras',
      'total_balls',
      'total_runs',
      'total_wickets',
      'total_fours',
      'total_sixes',
      'total_matches',
    ];

    final responses = await Future.wait(
      fields.map((field) async {
        try {
          final uri = Uri.parse('$_baseUrl?type=$field');
          final response = await http.get(uri);

          if (response.statusCode == 200) {
            final body = json.decode(response.body);
            if (body['status'] == 1 &&
                body['data'] is List &&
                body['data'].isNotEmpty) {
              final data = body['data'][0];
              final value = data.values.firstWhere(
                (v) => v != null && v.toString().isNotEmpty,
                orElse: () => '0',
              );
              return MapEntry(field, value.toString());
            }
          }
        } catch (_) {}
        return MapEntry(field, '0');
      }),
    );

    final resultMap = Map.fromEntries(responses);
    _cachedStats = resultMap;
    _lastFetchTime = DateTime.now();
    return resultMap;
  }

  /// 🎯 Fetches global player stats list based on type
  static Future<List<GlobalStat>> fetchStats({
    String type = 'most_runs',
  }) async {
    final uri = Uri.parse('$_baseUrl?type=$type');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return GlobalStat.fromJsonList(response.body);
    } else {
      throw Exception('Failed to load $type stats');
    }
  }

  /// 🧹 Clears cache manually
  static void clearCache() {
    _cachedStats = null;
    _lastFetchTime = null;
  }

  static DateTime? get lastFetchTime => _lastFetchTime;
}
