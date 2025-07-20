// lib/service/match_service.dart

import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_helper.dart';
import '../model/match_model.dart';

class MatchService {
  static const String _baseUrl =
      'https://cricjust.in/wp-json/custom-api-for-cricket';

  static Future<List<MatchModel>> fetchMatches({
    required String type,
    int limit = 10,
    int skip = 0,
  }) async {
    final url = Uri.parse(
      '$_baseUrl/get-matches?type=$type&limit=$limit&skip=$skip',
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['status'] == 1) {
        final data = List<Map<String, dynamic>>.from(body['data']);
        return data.map((json) => MatchModel.fromJson(json)).toList();
      } else {
        throw Exception(body['message'] ?? 'Failed to load matches');
      }
    } else {
      throw Exception('Failed to load $type matches');
    }
  }

  static Future<MatchModel> fetchMatchById(int matchId) async {
    final url = Uri.parse('$_baseUrl/get-match-detail?match_id=$matchId');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['status'] == 1 && body['data'] != null) {
        return MatchModel.fromJson(body['data']);
      } else {
        throw Exception(body['message'] ?? 'Match not found');
      }
    } else {
      throw Exception('Failed to load match detail');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchUserMatches({
    required BuildContext context,
    int limit = 50,
    int skip = 0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final apiToken = prefs.getString('api_logged_in_token');
    if (apiToken == null) throw Exception('Missing API token');

    final url = Uri.parse(
      '$_baseUrl/get-cricket-matches?api_logged_in_token=$apiToken&limit=$limit&skip=$skip',
    );

    final response = await ApiHelper.safeRequest(
      context: context,
      requestFn: () => http.get(url),
    );

    if (response == null) return [];

    final body = jsonDecode(response.body);

    if (response.statusCode == 200 &&
        body['status'] == 1 &&
        body['data'] != null) {
      return List<Map<String, dynamic>>.from(body['data']);
    } else {
      throw Exception(body['message'] ?? 'No match data available');
    }
  }


  static Future<bool> deleteMatch(int matchId) async {
    final prefs = await SharedPreferences.getInstance();
    final apiToken = prefs.getString('api_logged_in_token');
    if (apiToken == null) throw Exception('Missing API token');

    final url = Uri.parse(
      '$_baseUrl/delete-cricket-match?api_logged_in_token=$apiToken&match_id=$matchId',
    );

    final response = await http.get(url);
    final body = jsonDecode(response.body);

    if (body['message']?.toString().toLowerCase().contains('token') ?? false) {
      await prefs.clear();
      throw Exception('Session expired. Please login again.');
    }

    if (response.statusCode == 200 && body['status'] == 1) {
      return true;
    } else {
      throw Exception(body['message'] ?? 'Failed to delete match');
    }
  }

  /// ✅ Admin-only: Fetch all matches (same as user for now)
  static Future<List<Map<String, dynamic>>> fetchAllMatchesForAdmin({
    int limit = 100,
    int skip = 0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final apiToken = prefs.getString('api_logged_in_token');
    if (apiToken == null) throw Exception('Missing API token');

    final url = Uri.parse(
      '$_baseUrl/get-cricket-matches?api_logged_in_token=$apiToken&limit=$limit&skip=$skip',
    );

    final response = await http.get(url);
    final body = jsonDecode(response.body);

    if (body['message']?.toString().toLowerCase().contains('token') ?? false) {
      await prefs.clear();
      throw Exception('Session expired. Please login again.');
    }

    if (response.statusCode == 200 &&
        body['status'] == 1 &&
        body['data'] != null) {
      return List<Map<String, dynamic>>.from(body['data']);
    } else {
      throw Exception(body['message'] ?? 'Failed to fetch matches');
    }
  }

  static Future<Map<String, dynamic>?> fetchCurrentScore(int matchId) async {
    final url = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-current-match-score?match_id=$matchId',
    );

    try {
      final res = await http.get(url);
      if (res.statusCode != 200) return null;

      final body = json.decode(res.body) as Map<String, dynamic>;
      if (body['status'] == 1 && body['current_score'] != null) {
        return body;
      }
      return null;
    } catch (e) {
      print('❌ fetchCurrentScore error: $e');
      return null;
    }
  }
}
