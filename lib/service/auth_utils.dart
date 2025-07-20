import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../screen/login_screen.dart';

Future<void> handleInvalidToken(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  if (context.mounted) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}
