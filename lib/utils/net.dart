// lib/utils/net.dart
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Hardened HTTP helper with timeouts, retries, and "Connection: close".
class Net {
  Net._();
  static final HttpClient _hc = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10)
    ..idleTimeout = const Duration(seconds: 5)
    ..maxConnectionsPerHost = 4;

  static final http.Client client = IOClient(_hc);

  static Future<http.Response> get(
      Uri uri, {
        Map<String, String>? headers,
        Duration timeout = const Duration(seconds: 15),
        int maxRetries = 2,
      }) async {
    final h = <String, String>{
      'Accept': 'application/json',
      'User-Agent': 'CricjustApp/1.0 (Flutter; Android)',
      'Connection': 'close',
      ...?headers,
    };

    int attempt = 0;
    while (true) {
      try {
        final res = await client.get(uri, headers: h).timeout(timeout);
        return res;
      } on SocketException catch (_) {
        if (attempt++ < maxRetries) {
          await Future.delayed(Duration(milliseconds: 300 * (1 << attempt)));
          continue;
        }
        rethrow;
      } on TimeoutException catch (_) {
        if (attempt++ < maxRetries) {
          await Future.delayed(Duration(milliseconds: 300 * (1 << attempt)));
          continue;
        }
        rethrow;
      } on http.ClientException catch (_) {
        if (attempt++ < maxRetries) {
          await Future.delayed(Duration(milliseconds: 300 * (1 << attempt)));
          continue;
        }
        rethrow;
      }
    }
  }
}
