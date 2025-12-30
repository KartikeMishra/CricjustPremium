import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String apiKey = "pxu05VOeYDRunxJ5bjG5";
  static const String baseUrl = "https://cricjust.in/wp-json/cricjust/v1/yt";

  static Future<void> goLive(String broadcastId) async {
    final res = await http.post(
      Uri.parse("$baseUrl/live-match"),
      headers: {
        "x-api-key": apiKey,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: {"broadcastId": broadcastId},
    );

    print("🚀 [GoLive] ${res.statusCode}: ${res.body}");
  }
}
