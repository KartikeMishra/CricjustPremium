// lib/service/venue_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../model/venue_model.dart';

class VenueService {
  static const String _baseUrl =
      'https://cricjust.in/wp-json/custom-api-for-cricket';

  /// Fetch the list of venues

  /// ✅ Fetch venues
  static Future<List<Venue>> fetchVenues({
    required String apiToken, // ← add this
    int limit = 20,
    int skip = 0,
    String search = '',
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/get-venue'
      '?limit=$limit'
      '&skip=$skip'
      '&type=all'
      '&search=${Uri.encodeQueryComponent(search)}'
      '&api_logged_in_token=$apiToken',
    );

    final response = await http.get(uri);
    if (kDebugMode) debugPrint('📥 fetchVenues raw: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch venues (HTTP ${response.statusCode})');
    }

    final body = json.decode(response.body) as Map<String, dynamic>;

    // handle invalid‐token
    if (body['status'] == 0 &&
        body['error'] is Map &&
        (body['error'] as Map).containsKey('api_logged_in_token')) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      throw Exception('Session expired. Please login again.');
    }

    if (body['status'] != 1) {
      throw Exception('API error: ${body['message'] ?? 'Unknown error'}');
    }

    final data = body['data'] as List<dynamic>? ?? [];
    return data.map((e) => Venue.fromJson(e)).toList();
  }

  // … deleteVenue and updateVenue stay the same …

  /// Delete a venue by ID
  static Future<void> deleteVenue({
    required String apiToken,
    required int venueId,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/delete-venue'
      '?venue_id=$venueId'
      '&api_logged_in_token=$apiToken',
    );
    final response = await http.get(uri);
    if (kDebugMode) debugPrint('📤 deleteVenue raw: ${response.body}');

    final body = json.decode(response.body);
    if ((body['message']?.toString().toLowerCase().contains('token') ??
        false)) {
      throw Exception('Session expired. Please login again.');
    }
    if (body['status'] != 1) {
      throw Exception('Delete error: ${body['message'] ?? 'Unknown error'}');
    }
  }

  /// Add a new venue
  static Future<Venue> addVenue({
    required String apiToken,
    required String name,
    required String info,
    String? link,
  }) async {
    final uri = Uri.parse('$_baseUrl/add-venue');
    final body = {
      'venue_name': name,
      'venue_info': info,
      'api_logged_in_token': apiToken,
    };
    if (link != null) body['venue_link'] = link;

    final response = await http.post(uri, body: body);
    final jsonBody = json.decode(response.body);
    if (kDebugMode) debugPrint('📥 addVenue raw: $jsonBody');

    if ((jsonBody['message']?.toString().toLowerCase().contains('token') ??
        false)) {
      throw Exception('Session expired. Please login again.');
    }
    if (jsonBody['status'] != 1) {
      throw Exception('Add error: ${jsonBody['message'] ?? 'Unknown error'}');
    }

    final data = jsonBody['data'];
    if (data is List && data.isNotEmpty) {
      return Venue.fromJson(data.first);
    } else if (data is Map<String, dynamic>) {
      return Venue.fromJson(data);
    } else {
      throw Exception('Add error: Unexpected data format');
    }
  }

  /// Update an existing venue
  static Future<Venue> updateVenue({
    required String apiToken,
    required int venueId,
    required String name,
    required String info,
    String? link,
  }) async {
    final uri = Uri.parse('$_baseUrl/update-venue');
    final response = await http.post(
      uri,
      body: {
        'venue_id': venueId.toString(),
        'venue_name': name,
        'venue_info': info,
        'venue_link': link ?? '',
        'api_logged_in_token': apiToken,
      },
    );
    final body = json.decode(response.body);
    if (kDebugMode) debugPrint('📥 updateVenue raw: $body');

    if ((body['message']?.toString().toLowerCase().contains('token') ??
        false)) {
      throw Exception('Session expired. Please login again.');
    }
    if (body['status'] != 1) {
      throw Exception('Update error: ${body['message'] ?? 'Unknown error'}');
    }

    final dataList = body['data'] as List<dynamic>? ?? [];
    if (dataList.isEmpty) {
      throw Exception('Update error: No data returned');
    }
    return Venue.fromJson(dataList.first);
  }
}
