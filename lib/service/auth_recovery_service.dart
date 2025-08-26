// lib/service/auth_recovery_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthRecoveryService {
  static const String _base = 'https://cricjust.in/wp-json/custom-api-for-cricket';

  static Future<_ApiResp> _post(
      String path,
      Map<String, String> body, {
        Duration timeout = const Duration(seconds: 20),
      }) async {
    final uri = Uri.parse('$_base/$path');
    try {
      final res = await http.post(uri, body: body).timeout(timeout);

      // Try to parse JSON even for non-200 responses so we can extract error messages
      Map<String, dynamic> map;
      try {
        map = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        // Not JSON → fall back to HTTP status text
        final msg = 'HTTP ${res.statusCode}';
        return _ApiResp(false, msg);
      }

      final bool status =
      (map['status'] == 1 || map['status'] == '1' || map['success'] == true);

      // Prefer 'message'; otherwise flatten 'error' / 'errors'
      String? msg = _asString(map['message']);
      if (msg == null || msg.trim().isEmpty) {
        msg = _flattenErrors(map['error']) ??
            _flattenErrors(map['errors']) ??
            (status ? 'OK' : 'Failed');
      }

      return _ApiResp(status, msg, data: map);
    } catch (e) {
      return _ApiResp(false, e.toString());
    }
  }

  /// Step 1: Send OTP to email
  static Future<_ApiResp> sendOtp({required String email}) {
    return _post('forgot-pass-send-otp', {'email': email});
  }

  /// Step 2: Verify OTP
  static Future<_ApiResp> verifyOtp({
    required String email,
    required String otp,
  }) {
    return _post('forgot-pass-verify-otp', {'email': email, 'otp': otp});
  }

  /// Step 3: Set new password
  /// Step 3: Set new password
  static Future<_ApiResp> setNewPassword({
    required String email,
    required String otp,
    required String newPassword,
    required String confirmPassword, // ⬅️ add this
  }) {
    return _post('forgot-pass-set-new-pass', {
      'email': email,
      'otp': otp,
      'new_password': newPassword,
      're_type_new_password': confirmPassword, // ⬅️ required by your API
    });
  }


  // ---------- helpers ----------
  static String? _asString(dynamic v) {
    if (v == null) return null;
    return v is String ? v : v.toString();
  }

  /// Flattens string/list/map error payloads into a single readable string.
  /// Examples:
  ///   {"email": "Email not found"}           -> "Email not found"
  ///   {"email": ["Err1","Err2"]}             -> "Err1\nErr2"
  ///   ["Err1","Err2"]                        -> "Err1\nErr2"
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
}

class _ApiResp {
  final bool ok;
  final String message;
  final Map<String, dynamic>? data;
  _ApiResp(this.ok, this.message, {this.data});
}
