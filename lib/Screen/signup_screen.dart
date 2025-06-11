// Updated Flutter SignupScreen with dynamic player-type logic and numeric-only phone input

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/color.dart';
import '../theme/text_styles.dart';
import 'home_screen.dart';
import 'package:flutter/services.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();

  String? _gender, _userType, _playerType, _batterType, _bowlerType;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  void _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      _dobCtrl.text = DateFormat('yyyy-MM-dd').format(date);
    }
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse('https://cricjust.in/wp-json/custom-api-for-cricket/register');
      final request = http.MultipartRequest('POST', uri);

      request.fields['first_name'] = _nameCtrl.text.trim();
      request.fields['user_email'] = _emailCtrl.text.trim();
      request.fields['user_phone'] = _phoneCtrl.text.trim();
      request.fields['user_password'] = _passwordCtrl.text;
      request.fields['user_dob'] = _dobCtrl.text;
      request.fields['user_gender'] = _gender ?? '';
      request.fields['user_type'] = _userType ?? '';

      if (_userType == 'cricket_player') {
        request.fields['player_type'] = _playerType ?? '';
        if (_playerType == 'batter' || _playerType == 'all_rounder') {
          request.fields['batter_type'] = _batterType?.toLowerCase() ?? '';
        }
        if (_playerType == 'bowler' || _playerType == 'all_rounder') {
          request.fields['bowler_type'] = _bowlerType?.toLowerCase() ?? '';
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
          await prefs.setString('profilePic', data['extra_data']['user_profile_image']);
        }

        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else {
        setState(() => _errorMessage = data['message'] ?? 'Signup failed');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Could not signup. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.grey[100],
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up'), backgroundColor: AppColors.primary),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(children: [
            Image.asset('lib/asset/images/cricjust_logo.png', height: 80),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: _decoration('Full Name'),
              validator: (v) => v!.trim().isEmpty ? 'Enter name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              decoration: _decoration('Email'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v == null || !RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w]{2,4}").hasMatch(v)
                  ? 'Enter valid email'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              decoration: _decoration('Phone Number'),
              keyboardType: TextInputType.number,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) => v == null || v.length != 10 ? 'Enter 10 digit number' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dobCtrl,
              readOnly: true,
              decoration: _decoration('Date of Birth').copyWith(
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _pickDate,
                ),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Select DOB' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: _decoration('Gender'),
              value: _gender,
              items: ['Male', 'Female'].map((g) => DropdownMenuItem(value: g.toLowerCase(), child: Text(g))).toList(),
              onChanged: (val) => setState(() => _gender = val),
              validator: (v) => v == null ? 'Select gender' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: _decoration('User Type'),
              value: _userType,
              items: [
                DropdownMenuItem(value: 'cricket_player', child: Text('Player')),
                DropdownMenuItem(value: 'cricket_umpire', child: Text('Umpire')),
                DropdownMenuItem(value: 'cricket_scorer', child: Text('Scorer')),
                DropdownMenuItem(value: 'cricket_commentator', child: Text('Commentator')),
              ],
              onChanged: (val) => setState(() {
                _userType = val;
                _playerType = _batterType = _bowlerType = null;
              }),
              validator: (v) => v == null ? 'Select user type' : null,
            ),
            if (_userType == 'cricket_player') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: _decoration('Player Type'),
                value: _playerType,
                items: [
                  'All-Rounder',
                  'Batter',
                  'Bowler',
                  'Wicket-Keeper'
                ].map((e) => DropdownMenuItem(
                  value: e.toLowerCase().replaceAll('-', '_'),
                  child: Text(e),
                )).toList(),
                onChanged: (val) => setState(() => _playerType = val),
                validator: (v) => v == null ? 'Select player type' : null,
              ),
              if (_playerType == 'batter' || _playerType == 'all_rounder')
                Column(children: [
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: _decoration('Batter Type'),
                    value: _batterType,
                    items: ['Left', 'Right']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) => setState(() => _batterType = val),
                    validator: (v) => v == null ? 'Select batter type' : null,
                  ),
                ]),
              if (_playerType == 'bowler' || _playerType == 'all_rounder')
                Column(children: [
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: _decoration('Bowler Type'),
                    value: _bowlerType,
                    items: ['Pace', 'Spin']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) => setState(() => _bowlerType = val),
                    validator: (v) => v == null ? 'Select bowler type' : null,
                  ),
                ])
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              decoration: _decoration('Password').copyWith(
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) => v == null || v.length < 6 ? 'Min 6 characters' : null,
            ),
            const SizedBox(height: 12),
            if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isLoading ? null : _signup,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Sign Up', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Already have an account? "),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text('Login',
                      style: AppTextStyles.heading.copyWith(
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                      )),
                ),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}