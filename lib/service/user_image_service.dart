// lib/service/user_image_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // compute()
import 'package:http/http.dart' as http;
import '../model/user_image.dart';

class UserImageService {
  static const String _base = 'https://cricjust.in/wp-json/custom-api-for-cricket';
  static const String _endpoint = 'upload-cricket-user-images';

  // Toggle verbose logs for troubleshooting
  static const bool kDebugUpload = true;
  static void _log(String msg) {
    if (kDebugUpload) debugPrint('🧪 [Upload] $msg');
  }

  /// GET images (paginated)
  static Future<List<UserImage>> fetchImages({
    required String token,
    int limit = 20,
    int skip = 0,
  }) async {
    final uri = Uri.parse(
      '$_base/get-cricket-user-images?api_logged_in_token=$token&limit=$limit&skip=$skip',
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch images (${res.statusCode})');
    }
    final body = jsonDecode(res.body);
    if (body is! Map || body['status'] != 1) {
      throw Exception('API error: ${body is Map ? (body['message'] ?? 'unknown') : 'unknown'}');
    }
    final List data = (body['data'] ?? []) as List;
    return data.map((e) => UserImage.fromMap((e as Map).cast<String, dynamic>())).toList();
  }

  /// DELETE image
  static Future<bool> deleteImage({
    required String token,
    required int imageId,
  }) async {
    final uri = Uri.parse(
      '$_base/delete-user-sponsor?api_logged_in_token=$token&image_id=$imageId',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) return false;
    final body = jsonDecode(res.body);
    return body is Map && body['status'] == 1;
  }

  /// Upload image as Base64 -> `image_data`.
  ///
  /// Two attempts:
  ///  - Attempt #1: raw base64 (fail fast; default 8s)
  ///  - Attempt #2: data:URI prefix (longer; default 15s)
  ///
  /// You can override timeouts via [postTimeout] (applies to BOTH attempts).
// REPLACE your current uploadAndGetUrl with this version (adds Attempt #3 JSON)
  // ADD this helper near _postForm:
  static Future<http.Response> _postJson(Uri uri, Map<String, dynamic> jsonBody) {
    final headers = {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json, text/plain, */*',
      'Connection': 'close', // mitigate some WAF/keep-alive stalls
      'User-Agent': 'CricjustPremium/1.0 (Flutter http)',
    };
    return http.post(uri, headers: headers, body: jsonEncode(jsonBody));
  }

  static Future<String> uploadAndGetUrl({
    required String token,
    required File file,
    Duration postTimeout = const Duration(seconds: 30),
  }) async {
    // Split provided timeout roughly across attempts
    final post1Timeout = Duration(seconds: (postTimeout.inSeconds * 0.27).clamp(5, 15).toInt());
    final post2Timeout = Duration(seconds: (postTimeout.inSeconds * 0.45).clamp(8, 25).toInt());
    final post3Timeout = Duration(seconds: (postTimeout.inSeconds * 0.65).clamp(10, 30).toInt());

    final overall = Stopwatch()..start();

    if (!await file.exists()) throw Exception('File not found: ${file.path}');

    final bytes = await file.readAsBytes();
    final String base64Raw = await compute<List<int>, String>(base64Encode, bytes);

    final uri = Uri.parse('$_base/$_endpoint?api_logged_in_token=$token');
    http.Response res;

    // ATTEMPT #1: form-URL-encoded, raw base64
    try {
      _log('POST #1 raw (x-www-form-urlencoded, ${post1Timeout.inSeconds}s)');
      res = await _postForm(uri, {'image_data': base64Raw})
          .timeout(post1Timeout);
      _log('POST #1 status: ${res.statusCode}');
      if (_isGood(res)) {
        final url = _extractUrl(res.body);
        if (url != null) {
          _log('SUCCESS #1 in ${overall.elapsedMilliseconds} ms → $url');
          return url;
        }
      }
    } on TimeoutException {
      _log('POST #1 timeout at ${post1Timeout.inSeconds}s');
    } catch (e) {
      _log('POST #1 error: $e');
    }

    // ATTEMPT #2: form-URL-encoded, data:URI
    final mime = _mimeForPath(file.path);
    final withPrefix = 'data:$mime;base64,$base64Raw';
    try {
      _log('POST #2 data:URI (x-www-form-urlencoded, ${post2Timeout.inSeconds}s)');
      res = await _postForm(uri, {'image_data': withPrefix})
          .timeout(post2Timeout);
      _log('POST #2 status: ${res.statusCode}');
      if (_isGood(res)) {
        final url = _extractUrl(res.body);
        if (url != null) {
          _log('SUCCESS #2 in ${overall.elapsedMilliseconds} ms → $url');
          return url;
        }
      }
    } on TimeoutException {
      _log('POST #2 timeout at ${post2Timeout.inSeconds}s');
    } catch (e) {
      _log('POST #2 error: $e');
    }

    // ATTEMPT #3: JSON body (many WP handlers accept this even if not documented)
    try {
      _log('POST #3 JSON (application/json, ${post3Timeout.inSeconds}s)');
      res = await _postJson(uri, {'image_data': base64Raw})
          .timeout(post3Timeout);
      _log('POST #3 status: ${res.statusCode}');
      if (_isGood(res)) {
        final url = _extractUrl(res.body);
        if (url != null) {
          _log('SUCCESS #3 in ${overall.elapsedMilliseconds} ms → $url');
          return url;
        }
      }
      throw Exception('Upload failed: ${res.statusCode} ${_trim(res.body)}');
    } on TimeoutException {
      throw Exception('Upload timed out (all attempts) after ${overall.elapsedMilliseconds} ms');
    } catch (e) {
      rethrow;
    } finally {
      overall.stop();
    }
  }


  /// Explicit urlencoded form POST. Sets content-type and encodes body deterministically.
  static Future<http.Response> _postForm(Uri uri, Map<String, String> fields) async {
    final headers = {
      'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
      'Accept': 'application/json, text/plain, */*',
      'User-Agent': 'CricjustPremium/1.0 (Flutter http)',
    };
    final body = fields.entries
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return http.post(uri, headers: headers, body: body);
  }

  static bool _isGood(http.Response res) {
    if (res.statusCode != 200) return false;
    try {
      final j = jsonDecode(res.body);
      return j is Map && (j['status'] == 1 || j['status'] == true);
    } catch (_) {
      return res.body.startsWith('http'); // fallback: raw URL response
    }
  }

  static String? _extractUrl(String body) {
    try {
      final j = jsonDecode(body);
      if (j is Map) {
        final url = (j['image_url'] ?? j['url'] ?? j['data']?['url'])?.toString();
        if (url != null && url.isNotEmpty) return url;
      }
    } catch (_) {
      if (body.startsWith('http')) return body.trim();
    }
    return null;
  }

  static String _mimeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'application/octet-stream';
  }

  static String _trim(String s, [int max = 400]) {
    if (s.length <= max) return s;
    return '${s.substring(0, max)} …(${s.length} chars)';
  }
}
