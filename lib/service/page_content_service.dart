import 'dart:convert';
import 'package:http/http.dart' as http;

class PageContentService {
  static const String _base = 'https://cricjust.in/wp-json/custom-api-for-cricket';

  /// Returns {"title": "...", "content": "<p>...</p>"} or throws.
  static Future<Map<String, String>> fetchPage({required int pageId}) async {
    final uri = Uri.parse('$_base/get-page-content?page_id=$pageId');
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (json['status'] != 1 || json['data'] == null) {
      throw Exception(json['message']?.toString() ?? 'Failed to load page');
    }
    final data = json['data'] as Map<String, dynamic>;
    return {
      'title': (data['post_title'] ?? '').toString(),
      'content': (data['post_content'] ?? '').toString(),
    };
  }
}
