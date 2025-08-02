import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../screen/login_screen.dart'; // ✅ Make sure this path is correct

class ApiHelper {
  static Future<http.Response?> safeRequest({
    required BuildContext context,
    required Future<http.Response> Function() requestFn,
  }) async {
    try {
      final response = await requestFn();

      final bodyLower = response.body.toLowerCase();
      final isSessionExpired = bodyLower.contains("token") ||
          bodyLower.contains("session expired") ||
          bodyLower.contains("unauthorized");

      if (isSessionExpired) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        if (context.mounted) {
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Session Expired"),
              content: const Text("Your session has expired. Please log in again."),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                    );
                  },
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        }

        return null;
      }

      return response;
    } catch (e) {
      print("❌ Network/API error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Network error. Please try again.")),
        );
      }
      return null;
    }
  }
}
