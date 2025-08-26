// ProfileScreen – FULL CODE (stable back handler + glossy UI + overflow-free grid)
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../model/user_profile_model.dart';
import '../screen/login_screen.dart';
import '../theme/color.dart';
import '../theme/text_styles.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String apiToken; // can be empty; we fallback to prefs
  const ProfileScreen({super.key, required this.apiToken});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  bool _isLoading = true;
  String? _error;
  String _token = '';
  bool _changed = false; // returned to previous page on pop

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final fromPrefs = prefs.getString('api_logged_in_token') ?? '';
    _token = widget.apiToken.isNotEmpty ? widget.apiToken : fromPrefs;

    if (_token.isEmpty) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    await _fetchProfile(_token);
  }

  Future<void> _fetchProfile(String token) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final url = Uri.parse(
        'https://cricjust.in/wp-json/custom-api-for-cricket/user-info?api_logged_in_token=$token',
      );
      final resp = await http.get(url);
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');

      final decoded = json.decode(resp.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Unexpected response shape');
      }

      if (decoded['status'] != 1) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
        );
        return;
      }

      final data = (decoded['data'] ?? {}) as Map<String, dynamic>;
      final extra = (decoded['extra_data'] ?? {}) as Map<String, dynamic>;

      setState(() {
        _profile = UserProfile.fromJson(data, extra);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    if (_token.isEmpty) return;
    await _fetchProfile(_token);
  }

  // ---- Back handler (safe, no recursion, works with nested navigators) ----
  Future<bool> _onBack() async {
    final root = Navigator.of(context, rootNavigator: true);
    if (root.canPop()) {
      root.pop(_changed); // return whether profile changed
      return false;       // handled
    }
    return true;          // nothing to pop → let system handle (exit/previous)
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onBack, // do NOT call maybePop here (causes recursion)
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            _profile?.displayName ?? 'My Profile',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _onBack, // use same handler
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 10),
              Text(
                'Could not load profile',
                style: AppTextStyles.heading.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center, style: AppTextStyles.caption),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_profile == null) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Reload'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: _profileCard(),
      ),
    );
  }

  // ---------- UI ----------
  Widget _profileCard() {
    final p = _profile!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tiles = <Widget>[
      _InfoTile(icon: Icons.perm_identity, label: 'User ID', value: p.id),
      _InfoTile(icon: Icons.account_circle, label: 'Username', value: p.login),
      _InfoTile(icon: Icons.face, label: 'Nickname', value: p.nickname),
      _InfoTile(icon: Icons.badge, label: 'First Name', value: p.firstName),
      _InfoTile(icon: Icons.wc, label: 'Gender', value: p.gender),
      _InfoTile(icon: Icons.cake, label: 'DOB', value: p.dob),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProfileHeader(
          name: p.displayName,
          email: p.email,
          photoUrl: p.profileImage,
          tint: AppColors.primary,
        ),
        const SizedBox(height: 18),

        // Details card (fixed-height grid to avoid overflow)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF101010) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFEAEFF5)),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Details',
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 12),
              GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: tiles.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent: 72, // enough vertical space for content
                ),
                itemBuilder: (_, i) => tiles[i],
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        // Actions
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(Icons.edit, color: AppColors.primary),
                label: Text('Edit Profile',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                onPressed: () async {
                  final updated = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => EditProfileScreen(profile: p)),
                  );
                  if (updated == true) {
                    _changed = true;
                    await _fetchProfile(_token);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text('Logout',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (_) => false,
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ===== Helpers =====

class _ProfileHeader extends StatelessWidget {
  final String name, email, photoUrl;
  final Color tint;
  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          Container(
            height: 190,
            decoration: BoxDecoration(
              gradient: isDark
                  ? const LinearGradient(
                colors: [Color(0xFF1A1A1A), Color(0xFF111111)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
                  : const LinearGradient(
                colors: [Color(0xFFE3F2FD), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: -18,
            left: -12,
            child: _bubble(86, Colors.white.withValues(alpha: 0.18)),
          ),
          Positioned(
            bottom: -22,
            right: -16,
            child: _bubble(120, Colors.white.withValues(alpha: 0.14)),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(height: 190, color: Colors.transparent),
          ),
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [tint.withValues(alpha: 0.7), tint.withValues(alpha: 0.2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 46,
                    backgroundColor: Colors.white,
                    backgroundImage:
                    photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                    child: photoUrl.isEmpty
                        ? Icon(Icons.person, size: 46, color: tint)
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Object? value;
  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = (value?.toString() ?? '-').isEmpty ? '-' : value.toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // compact
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE3EDF8)),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
            child: Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min, // avoids tall asks
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
