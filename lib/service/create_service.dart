import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../model/create_user_model.dart';

class CreateService {
  static const String _base =
      'https://cricjust.in/wp-json/custom-api-for-cricket';

  // Keep this here so the UI can read from one source.
  static const List<String> supportedUserTypes = <String>[
    'cricket_player',
    'cricket_umpire',
    'cricket_scorer',
    'cricket_commentator',
  ];

  static Future<CreateUserResponse> createUser({
    required String apiToken,
    required CreateUserRequest request,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    // client-side validation first
    final errors = request.validate();
    if (errors.isNotEmpty) {
      return CreateUserResponse(
        ok: false,
        message: errors.values.first,
        raw: {'errors': errors},
      );
    }

    final uri = Uri.parse(
        '$_base/create-user?api_logged_in_token=$apiToken');

    try {
      final res = await http
          .post(uri, body: request.toFormFields())
          .timeout(timeout);

      Map<String, dynamic> json;
      try {
        json = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        return CreateUserResponse(
          ok: false,
          message: 'HTTP ${res.statusCode}',
          raw: {'http_status': res.statusCode, 'body': res.body},
        );
      }

      final resp = CreateUserResponse.fromJson(json);
      if (!resp.ok && kDebugMode) {
        debugPrint('Create user failed: ${resp.message} -> ${resp.raw}');
      }
      return resp;
    } catch (e) {
      return CreateUserResponse(
        ok: false,
        message: 'Network error: $e',
        raw: {'exception': e.toString()},
      );
    }
  }
}
