import 'dart:convert';
import 'package:http/http.dart' as http;

class YouTubeStreamService {
  static const String baseUrl = "https://cricjust.in/wp-json/cricjust/v1/yt";
  static const String apiKey = "pxu05VOeYDRunxJ5bjG5"; // ✅ Your x-api-key

  /// ✅ Create Stream
  Future<Map<String, dynamic>> startMatchStream({
    required int matchId,
    String privacy = "public",
    String latency = "ultraLow",
  }) async {
    final url = Uri.parse("$baseUrl/start-match");

    final response = await http.post(
      url,
      headers: {
        "x-api-key": apiKey,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: {
        "matchId": matchId.toString(),
        "privacy": privacy,
        "latency": latency,
      },
    );

    print("🌐 URL: $url");
    print("📤 Body: matchId=$matchId, privacy=$privacy, latency=$latency");
    print("📩 Response (${response.statusCode}): ${response.body}");

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data["ok"] == true) {
        return {
          "success": true,
          "broadcastId": data["broadcastId"],
          "watchUrl": data["watchUrl"],
          "rtmpsUrl": data["rtmpsUrl"],
          "title": data["title"],
        };
      } else {
        return {"success": false, "message": data["message"] ?? "Unknown error"};
      }
    }

    return {
      "success": false,
      "message": "Failed (${response.statusCode}): ${response.reasonPhrase}",
    };
  }

  /// ✅ Go Live API
  Future<Map<String, dynamic>> goLive(String broadcastId) async {
    final url = Uri.parse("$baseUrl/live-match");
    final response = await http.post(
      url,
      headers: {
        "x-api-key": apiKey,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: {"broadcastId": broadcastId},
    );
    print("📩 goLive => ${response.body}");
    final data = json.decode(response.body);
    return data["ok"] == true
        ? {"success": true}
        : {"success": false, "message": data["message"]};
  }

  /// ✅ Stop Stream API
  Future<Map<String, dynamic>> stopLive(String broadcastId) async {
    final url = Uri.parse("$baseUrl/stop-match");
    final response = await http.post(
      url,
      headers: {
        "x-api-key": apiKey,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: {"broadcastId": broadcastId},
    );
    print("📩 stopLive => ${response.body}");
    final data = json.decode(response.body);
    return data["ok"] == true
        ? {"success": true}
        : {"success": false, "message": data["message"]};
  }

  /// ✅ Get Stream Data API
  Future<Map<String, dynamic>> getStreamData(int matchId) async {
    final url = Uri.parse("$baseUrl/get-stream-data");
    final response = await http.post(
      url,
      headers: {
        "x-api-key": apiKey,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: {"matchId": matchId.toString()},
    );
    print("📩 getStreamData => ${response.body}");
    final data = json.decode(response.body);
    return data["ok"] == true
        ? {
      "success": true,
      "broadcastId": data["broadcastId"],
      "status": data["status"],
    }
        : {"success": false, "message": data["message"]};
  }
}
