import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/toss_update_model.dart';

class TossService {
  /// Submits the toss decision.
  /// Returns a map containing:
  /// - `success`: bool
  /// - `message`: String (from API or fallback)
  static Future<Map<String, dynamic>> updateToss({
    required TossUpdateRequest request,
    required String token,
    required int matchId,
  }) async {
    final url =
        'https://cricjust.in/wp-json/custom-api-for-cricket/update-cricket-toss?api_logged_in_token=$token&match_id=$matchId';

    try {
      final response = await http.post(Uri.parse(url), body: request.toJson());

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        bool isSuccess = json['status'] == 1;
        String message =
            json['message'] ??
            (json['error'] is Map && json['error'].values.isNotEmpty
                ? json['error'].values.first
                : 'Unknown error');

        return {'success': isSuccess, 'message': message};
      } else {
        return {
          'success': false,
          'message': 'Network error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Something went wrong: $e'};
    }
  }

  /// Fetches existing toss info for a match
  static Future<Map<String, dynamic>> fetchTossData(int matchId) async {
    final url =
        'https://cricjust.in/wp-json/custom-api-for-cricket/get-match?match_id=$matchId&type=toss';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['status'] == 1 &&
          json['data'] is List &&
          json['data'].isNotEmpty) {
        return json['data'][0];
      } else {
        throw Exception('No toss data found');
      }
    } else {
      throw Exception('Failed to fetch toss data');
    }
  }
}
