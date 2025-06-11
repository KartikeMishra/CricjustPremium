import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/post_model.dart';
import '../model/post_detail_model.dart'; // ✅ Add this import

class PostService {
  /// Fetch list of posts for the feed
  static Future<List<PostModel>> fetchPosts({int limit = 10, int skip = 0}) async {
    final url = Uri.parse('https://cricjust.in/wp-json/custom-api-for-cricket/get-news?limit=$limit&skip=$skip');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<PostModel> posts = (data['data'] as List)
          .map((postJson) => PostModel.fromJson(postJson))
          .toList();
      return posts;
    } else {
      throw Exception('Failed to load posts');
    }
  }

  /// Fetch a single post by ID for the detail screen
  static Future<PostDetailModel> fetchSinglePost(int postId) async {
    final url = Uri.parse('https://cricjust.in/wp-json/custom-api-for-cricket/get-single-news?post_id=$postId');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return PostDetailModel.fromJson(data['data'][0]); // ✅ Use correct model
    } else {
      throw Exception('Failed to load post');
    }
  }
}
