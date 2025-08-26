import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../service/session_manager.dart'; // ⬅️ ADDED (Option A)
import '../screen/home_screen.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
  }

  Future<void> _loadRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPhone = prefs.getString('remembered_phone');
    final remember = prefs.getBool('remember_me') ?? false;

    if (remember) {
      _phoneCtrl.text = savedPhone ?? '';
      // Do NOT prefill password anymore
      setState(() => _rememberMe = true);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final phone = _phoneCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final uri = Uri.parse('https://cricjust.in/wp-json/custom-api-for-cricket/login');

    try {
      // Do NOT set a custom content-type; WordPress expects form-encoded body.
      final resp = await http.post(uri, body: {
        'phone_number': phone,
        'password': password,
      });

      assert(() {
        // ignore: avoid_print
        print('LOGIN ${resp.statusCode}: ${resp.body}');
        return true;
      }());

      if (resp.statusCode != 200) {
        _showError('Server error: ${resp.statusCode}');
        return;
      }

      final Map<String, dynamic> jsonData = json.decode(resp.body);
      final status = jsonData['status'];
      final ok = (status == 1 || status == '1');
      if (!ok) {
        _showError(jsonData['message']?.toString() ?? 'Login failed');
        return;
      }

      final token = (jsonData['api_logged_in_token'] ?? '').toString();
      final data = (jsonData['data'] ?? {}) as Map<String, dynamic>;

      final id = int.tryParse('${data['ID'] ?? ''}') ?? 0;
      final displayName = (data['display_name'] ?? '').toString();
      final email = (data['user_email'] ?? '').toString();
      final userLogin = (data['user_login'] ?? '').toString(); // phone as per your API

      // ---- NEW: extract roles and compute is_admin ----
      List<String> roles = [];
      final rolesDyn = data['roles'];
      if (rolesDyn is List) {
        roles = rolesDyn.map((e) => e.toString()).toList();
      } else if (rolesDyn is String) {
        // CSV/string fallback just in case
        roles = rolesDyn
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      final rolesLower = roles.map((r) => r.toLowerCase()).toList();
      final isAdmin = rolesLower.contains('administrator') || rolesLower.any((r) => r.contains('admin'));

      // ===== Option A: write canonical session keys via SessionManager (for QR) =====
      await SessionManager.saveSession(
        apiToken: token,
        playerId: id,
        phone: userLogin,        // stored under 'phone' (normalized) for Receiver QR
        displayName: displayName, // stored under 'display_name'
      );
      // ============================================================================

      final prefs = await SharedPreferences.getInstance();

      // Core session values (keep existing keys to avoid disturbing other logic)
      if (token.isNotEmpty) await prefs.setString('api_logged_in_token', token);
      await prefs.setInt('player_id', id); // used across app as current user/player id
      await prefs.setString('userName', displayName);
      await prefs.setString('userEmail', email);
      await prefs.setString('phoneNumber', userLogin);

      // Store roles in multiple forms so different screens can read them
      await prefs.setStringList('roles', roles);
      await prefs.setString('roles_csv', roles.join(',')); // fallback
      await prefs.setBool('is_admin', isAdmin);
      if (roles.isNotEmpty) {
        // legacy keys some screens still inspect
        await prefs.setString('role', roles.first);
        await prefs.setString('user_role', roles.first);
        await prefs.setString('userType', roles.first);
      }

      // Remember Me (phone only)
      if (_rememberMe) {
        await prefs.setString('remembered_phone', phone);
        await prefs.remove('remembered_password'); // ensure old value is cleared
        await prefs.setBool('remember_me', true);
      } else {
        await prefs.remove('remembered_phone');
        await prefs.remove('remembered_password');
        await prefs.setBool('remember_me', false);
      }

      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      assert(() {
        // ignore: avoid_print
        print('LOGIN ERROR: $e');
        return true;
      }());
      _showError('Login failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
      prefixIcon: Icon(icon, color: isDark ? Colors.white70 : Colors.black54),
      suffixIcon: hint == "Password"
          ? IconButton(
        icon: Icon(
          _obscurePassword ? Icons.visibility_off : Icons.visibility,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
      )
          : null,
      filled: true,
      fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black45 : Colors.black12,
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        Theme.of(context).brightness == Brightness.dark
                            ? 'lib/asset/images/Theme1.png'
                            : 'lib/asset/images/cricjust_logo.png',
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Welcome',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('Login to continue', style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 24),

                      // Phone Number
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: _buildInputDecoration("Phone Number", Icons.phone),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Enter phone number';
                          if (!RegExp(r'^\d{10,15}$').hasMatch(val.trim())) return 'Invalid number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePassword,
                        decoration: _buildInputDecoration("Password", Icons.lock),
                        validator: (val) => val == null || val.isEmpty ? 'Enter password' : null,
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (val) => setState(() => _rememberMe = val ?? false),
                            activeColor: Theme.of(context).primaryColor,
                          ),
                          Text("Remember Me", style: Theme.of(context).textTheme.bodyMedium),

                          const Spacer(),

                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                              );
                            },
                            child: const Text('Forgot Password?'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _isLoading ? null : _login,
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                              : const Text('Login', style: TextStyle(color: Colors.white, fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen()));
                        },
                        child: Text.rich(
                          TextSpan(
                            text: "Don't have an account? ",
                            children: [
                              TextSpan(
                                text: 'Register',
                                style: TextStyle(
                                  decoration: TextDecoration.underline,
                                  color: isDark ? Colors.lightBlueAccent : Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
