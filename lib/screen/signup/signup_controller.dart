import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignupController {
  SignupController._();

  static Future<String> pickDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      return DateFormat('yyyy-MM-dd').format(date);
    }
    return "";
  }

  static Future<void> signup(
      {required String firstName,
      required String email,
      required String phone,
      required String password,
      required String dob,
      required String gender,
      required String userType,
      required String playerType,
      String? batterType,
      String? bowlerType,
      VoidCallback? onSuccess,
      VoidCallback? onComplete,
      Function(String)? onFailure}) async {
    try {
      final uri = Uri.parse(
        'https://cricjust.in/wp-json/custom-api-for-cricket/register',
      );
      final request = http.MultipartRequest('POST', uri);

      request.fields['first_name'] = firstName;
      request.fields['user_email'] = email;
      request.fields['user_phone'] = phone;
      request.fields['user_password'] = password;
      request.fields['user_dob'] = dob;
      request.fields['user_gender'] = gender;
      request.fields['user_type'] = userType;

      if (userType == 'cricket_player') {
        request.fields['player_type'] = playerType;
        if (playerType == 'batter' || playerType == 'all_rounder') {
          request.fields['batter_type'] = batterType?.toLowerCase() ?? '';
        }
        if (playerType == 'bowler' || playerType == 'all_rounder') {
          request.fields['bowler_type'] = bowlerType?.toLowerCase() ?? '';
        }
      }

      final response = await request.send();
      final respStr = await response.stream.bytesToString();
      final data = json.decode(respStr) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['status'] == 1) {
        final token = data['api_logged_in_token'] as String?;
        final userData = data['data'] as Map<String, dynamic>;
        final prefs = await SharedPreferences.getInstance();

        if (token != null) await prefs.setString('api_logged_in_token', token);
        await prefs.setString('userName', userData['display_name'] ?? '');
        await prefs.setString('userEmail', userData['user_email'] ?? '');

        if (data['extra_data']?['user_profile_image'] != null) {
          await prefs.setString(
            'profilePic',
            data['extra_data']['user_profile_image'],
          );
        }

        onSuccess?.call();
      } else {
        onFailure?.call(data['message'] ?? 'Signup failed');
      }
    } catch (e) {
      onFailure?.call('Could not signup. Please try again.');
    } finally {
      onComplete?.call();
    }
  }
}
