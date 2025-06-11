import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../model/user_profile.dart';
import '../screen/login_screen.dart';
import '../theme/color.dart';
import '../theme/text_styles.dart';

class ProfileScreen extends StatefulWidget {
  final String apiToken;
  const ProfileScreen({Key? key, required this.apiToken}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final url = Uri.parse(
          'https://cricjust.in/wp-json/custom-api-for-cricket/user-info'
              '?api_logged_in_token=${widget.apiToken}');
      final resp = await http.get(url);
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
      final jsonData = json.decode(resp.body) as Map<String, dynamic>;
      if (jsonData['status'] != 1) throw Exception('API status ${jsonData['status']}');

      final data  = jsonData['data'] as Map<String, dynamic>;
      final extra = jsonData['extra_data'] as Map<String, dynamic>;

      setState(() {
        _profile = UserProfile.fromJson(data, extra);
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1976D2), // AppColors.primary
              Color(0xFF42A5F5),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : (_error != null
                  ? Center(child: Text('Error: $_error'))
                  : _buildProfileView()),
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(_profile?.displayName ?? 'Profile', style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
    );
  }

  Widget _buildProfileView() {
    final p = _profile!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage:
                          p.profileImage.isNotEmpty ? NetworkImage(p.profileImage) : null,
                      child: p.profileImage.isEmpty
                          ? Icon(Icons.person, size: 50, color: AppColors.primary)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(p.displayName, style: AppTextStyles.heading.copyWith(fontSize: 24)),
                    const SizedBox(height: 4),
                    Text(p.email, style: AppTextStyles.caption.copyWith(fontSize: 15)),
                    const Divider(height: 32, thickness: 1.2),
                    _infoRow(Icons.perm_identity, 'User ID', p.id),
                    _infoRow(Icons.account_circle, 'Username', p.login),
                    _infoRow(Icons.face, 'Nickname', p.nickname),
                    _infoRow(Icons.badge, 'First Name', p.firstName),
                    _infoRow(Icons.badge_outlined, 'Last Name', p.lastName),
                    _infoRow(Icons.wc, 'Gender', p.gender),
                    _infoRow(Icons.cake, 'DOB', p.dob),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 180,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text('Logout', style: TextStyle(color: Colors.white, fontSize: 16)),
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text('$label:', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 5,
            child: Text(value, style: AppTextStyles.caption.copyWith(fontSize: 15)),
          ),
        ],
      ),
    );
  }
}
