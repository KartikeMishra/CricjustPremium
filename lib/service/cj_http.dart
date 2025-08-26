// lib/service/cj_http.dart
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class CJHttp {
  static http.Client? _client;

  static http.Client _newClient() {
    final io = HttpClient()
      ..idleTimeout = const Duration(seconds: 5)
      ..connectionTimeout = const Duration(seconds: 15)
      ..autoUncompress = true
      ..userAgent = 'Cricjust/1.0 (Flutter)';
    return IOClient(io);
  }

  static http.Client get client => _client ??= _newClient();

  static Future<http.Response> getWithRetry(
      Uri uri, {
        Map<String, String>? headers,
        int retries = 3,
        Duration timeout = const Duration(seconds: 20),
        bool cacheBust = true,
      }) async {
    Uri u = uri;
    if (cacheBust) {
      final qp = Map<String, String>.from(u.queryParameters)
        ..['ts'] = DateTime.now().millisecondsSinceEpoch.toString();
      u = u.replace(queryParameters: qp);
    }

    int attempt = 0;
    while (true) {
      attempt++;
      try {
        final resp = await client
            .get(
          u,
          headers: {
            'Accept': 'application/json',
            'Connection': 'close', // <-- avoid buggy keep-alive reuse
            ...?headers,
          },
        )
            .timeout(timeout);
        return resp;
      } on http.ClientException catch (_) {
        if (attempt >= retries) rethrow;
      } on SocketException catch (_) {
        if (attempt >= retries) rethrow;
      } on TimeoutException catch (_) {
        if (attempt >= retries) rethrow;
      }
      // brief backoff, then recreate client to drop any bad sockets
      await Future.delayed(Duration(milliseconds: 250 * attempt));
      _client?.close();
      _client = null;
    }
  }
}
