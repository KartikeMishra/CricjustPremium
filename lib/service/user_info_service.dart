// lib/service/user_info_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../model/user_profile_model.dart';

class UserInfoService {
  static const String _base =
      'https://cricjust.in/wp-json/custom-api-for-cricket';

  // ---- helpers ----
  static String? _asString(dynamic v) {
    if (v == null) return null;
    return v is String ? v : v.toString();
  }

  static String? _flattenErrors(dynamic err) {
    if (err == null) return null;
    if (err is String) return err.trim().isEmpty ? null : err;
    if (err is List) {
      final parts = err.map(_asString).whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty);
      final s = parts.join('\n');
      return s.isEmpty ? null : s;
    }
    if (err is Map) {
      final parts = <String>[];
      err.forEach((_, v) {
        if (v is List) {
          parts.addAll(v.map(_asString).whereType<String>());
        } else {
          final s = _asString(v);
          if (s != null && s.trim().isNotEmpty) parts.add(s);
        }
      });
      final s = parts.map((e) => e.trim()).where((e) => e.isNotEmpty).join('\n');
      return s.isEmpty ? null : s;
    }
    final s = err.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Fetch current user's profile using their API token.
  ///
  /// Accepts either `extra` or `extra_data` from the API.
  static Future<UserProfile> getUserInfo({
    required String apiToken,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final url = Uri.parse('$_base/user-info?api_logged_in_token=$apiToken');
    final res = await http.get(url).timeout(timeout);

    Map<String, dynamic> body;
    try {
      body = json.decode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('HTTP ${res.statusCode}: ${res.reasonPhrase}');
    }

    final ok = (body['status'] == 1 || body['status'] == '1');
    if (!ok) {
      final msg = _asString(body['message']) ??
          _flattenErrors(body['error']) ??
          _flattenErrors(body['errors']) ??
          'Failed to get user info';
      throw Exception(msg);
    }

    final data  = (body['data'] ?? {}) as Map<String, dynamic>;
    final extra = (body['extra'] ?? body['extra_data'] ?? {}) as Map<String, dynamic>;
    return UserProfile.fromJson(data, extra);
  }

  /// Update user info (form-encoded).
  ///
  /// Send only fields you want to change, e.g.:
  /// {
  ///   'first_name': 'John',
  ///   'user_dob': '2000-01-01',
  ///   'user_gender': 'male',
  ///   'description': 'All-Rounder',
  ///   'user_profile_image': 'https://...png',   // ⬅️ update image
  ///   'user_type': 'cricket_umpire',            // ⬅️ update role/type
  /// }
  ///
  /// Returns a friendly map:
  /// { ok: bool, message: String, data: {...}, extra_data: {...}, raw: {...} }
  static Future<Map<String, dynamic>> updateUserInfo({
    required String apiToken,
    required Map<String, String> updatedFields,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final url = Uri.parse('$_base/update-user-info?api_logged_in_token=$apiToken');

    try {
      // No custom headers needed; WP handles form-encoded by default.
      final res = await http.post(url, body: updatedFields).timeout(timeout);

      Map<String, dynamic> map;
      try {
        map = json.decode(res.body) as Map<String, dynamic>;
      } catch (_) {
        return {
          'ok': false,
          'message': 'HTTP ${res.statusCode}',
          'raw': res.body,
        };
      }

      final ok = (map['status'] == 1 || map['status'] == '1');
      final msg = _asString(map['message']) ??
          _flattenErrors(map['error']) ??
          _flattenErrors(map['errors']) ??
          (ok ? 'Updated successfully' : 'Update failed');

      return {
        'ok': ok,
        'message': msg,
        'data': map['data'],
        'extra_data': map['extra_data'] ?? map['extra'],
        'raw': map,
      };
    } catch (e) {
      return {'ok': false, 'message': e.toString()};
    }
  }
}
