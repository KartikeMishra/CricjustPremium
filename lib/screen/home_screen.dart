// lib/screen/home_screen.dart
// HomeScreen – always smooth: no toggle, no heavy blur, static (one-time) backdrop on Home,
// and IndexedStack to keep tabs alive.

import 'dart:convert';
import 'package:another_flushbar/flushbar.dart';
import 'package:cricjust_premium/screen/permission/receiver_qr_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../screen/login_screen.dart';
import '../screen/match_screen.dart';
import '../screen/tournament_screen.dart';
import '../screen/all_posts_screen.dart';
import '../screen/profile_screen.dart';
import '../service/session_manager.dart';
import '../theme/color.dart';
import '../theme/theme_provider.dart';
import 'add_match_screen.dart';
import 'add_sponsor_screen.dart';
import 'create_user_screen.dart';
import 'get_matches.dart';
import 'get_team_screen.dart';
import 'get_tournament.dart';
import 'get_venue_screen.dart';
import 'home_page_content.dart';
import '../screen/global_stats_screen.dart';
import 'my_matches_page.dart';
import 'my_stats_page.dart';
import 'my_teams_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

/// Small screen that shows a QR linking to the Play Store
class _AppLinkQrScreen extends StatelessWidget {
  const _AppLinkQrScreen();

  static const String _url =
      'https://play.google.com/store/apps/details?id=com.cricjust.app';

  PreferredSizeWidget _buildConsistentHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: Container(
        decoration: isDark
            ? const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        )
            : const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, Color(0xFF42A5F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.maybePop(context),
            tooltip: 'Back',
          ),
          title: const Text(
            'Scan to Download',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF111111) : const Color(0xFFF5F7FA),
      appBar: _buildConsistentHeader(context),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Card(
                  elevation: isDark ? 1 : 3,
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  surfaceTintColor:
                  isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: const Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        SizedBox(height: 8),
                        _QrCard(url: _url),
                        SizedBox(height: 14),
                        _QrHelpText(),
                        SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QrHelpText extends StatelessWidget {
  const _QrHelpText();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const url =
        'https://play.google.com/store/apps/details?id=com.cricjust.app';
    return Column(
      children: [
        Text(
          'Scan this QR to open the Play Store page.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          url,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white38 : Colors.black45,
          ),
        ),
      ],
    );
  }
}

class _QrCard extends StatelessWidget {
  final String url;
  const _QrCard({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white12
              : Colors.black12,
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: _QrRender(),
      ),
    );
  }
}

class _QrRender extends StatelessWidget {
  const _QrRender();

  static const _url =
      'https://play.google.com/store/apps/details?id=com.cricjust.app';

  @override
  Widget build(BuildContext context) {
    return QrImageView(
      data: _url,
      version: QrVersions.auto,
      size: 260,
    );
  }
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _userName = '';
  String _userEmail = '';
  String? _profilePicUrl;
  String? _apiToken;
  bool _isLoggedIn = false;
  bool _isAdmin = false;

  final List<Widget> _pages = [];
  final PageStorageBucket _bucket = PageStorageBucket();

  @override
  void initState() {
    super.initState();
    _pages.addAll([
      HomePageContent(onLoadMoreTap: () => _onItemTapped(3)),
      const MatchScreen(),
      const TournamentScreen(),
      const AllPostsScreen(),
    ]);
    _loadUserInfo();
  }

  Color get _barStart => AppColors.primary;
  Color get _barEnd => const Color(0xFF42A5F5);

  bool _computeIsAdminFromPrefs(SharedPreferences prefs) {
    final rolesList = prefs.getStringList('roles') ?? const [];
    final rolesLower = rolesList.map((e) => e.toLowerCase()).toList();
    if (rolesLower.contains('administrator')) return true;

    if (rolesLower.isEmpty) {
      final csv = (prefs.getString('roles_csv') ?? '').trim();
      if (csv.isNotEmpty &&
          csv.split(',').map((e) => e.trim().toLowerCase()).contains('administrator')) {
        return true;
      }
      final legacy = (prefs.getString('role') ??
          prefs.getString('user_role') ??
          prefs.getString('userType') ??
          '')
          .toLowerCase();
      if (legacy.contains('admin')) return true;
    }

    if (prefs.getBool('is_admin') == true) return true;
    return false;
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_logged_in_token') ?? '';
    final adminFlag = _computeIsAdminFromPrefs(prefs);

    setState(() {
      _apiToken = token;
      _isLoggedIn = token.isNotEmpty;
      _isAdmin = adminFlag;
    });

    if (token.isNotEmpty) {
      try {
        final resp = await http.get(Uri.parse(
          'https://cricjust.in/wp-json/custom-api-for-cricket/user-info?api_logged_in_token=$token',
        ));
        if (resp.statusCode == 200) {
          final jsonData = json.decode(resp.body);
          if (jsonData['status'] == 1) {
            final data = jsonData['data'];
            final extra = jsonData['extra_data'];
            setState(() {
              _userName = (extra['first_name']?.toString().isNotEmpty ?? false)
                  ? extra['first_name'].toString()
                  : (data['display_name']?.toString() ?? _userName);
              _userEmail = data['user_email']?.toString() ?? _userEmail;
              _profilePicUrl = extra['user_profile_image']?.toString();
              _isLoggedIn = true;
            });
            await prefs.setString('userName', _userName);
            await prefs.setString('userEmail', _userEmail);
            if (_profilePicUrl != null) {
              await prefs.setString('profilePic', _profilePicUrl!);
            }
          } else {
            await prefs.remove('api_logged_in_token');
            await prefs.remove('userName');
            await prefs.remove('userEmail');
            await prefs.remove('profilePic');
            setState(() {
              _apiToken = null;
              _isLoggedIn = false;
              _userName = '';
              _userEmail = '';
              _profilePicUrl = null;
              _isAdmin = false;
            });
          }
        }
      } catch (_) {
        // ignore – fall back to cached values below
      }
    }

    setState(() {
      _userName = prefs.getString('userName') ?? _userName;
      _userEmail = prefs.getString('userEmail') ?? _userEmail;
      _profilePicUrl = prefs.getString('profilePic') ?? _profilePicUrl;
      _isLoggedIn = (prefs.getString('api_logged_in_token') ?? '').isNotEmpty;
      _isAdmin = _computeIsAdminFromPrefs(prefs);
    });
  }

  static const String _playLink =
      'https://play.google.com/store/apps/details?id=com.cricjust.app';
  static const String _shareText =
      '📲 Check out Cricjust – the ultimate cricket scoring and streaming app!\n\nDownload now:\nAndroid: $_playLink';

  void _showShareOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.black12, borderRadius: BorderRadius.circular(4)),
              ),
              ListTile(
                leading: const Icon(Icons.ios_share),
                title: const Text('Share app link'),
                subtitle: Text(_playLink, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () {
                  Navigator.pop(context);
                  Share.share(_shareText, subject: 'Cricjust App');
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copy link'),
                onTap: () async {
                  await Clipboard.setData(const ClipboardData(text: _playLink));
                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied to clipboard')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_2),
                title: const Text('Show QR code'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const _AppLinkQrScreen()),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _onItemTapped(int index) {
    if (index == 4) {
      Flushbar(
        title: "Coming Soon",
        message: "Booking is not ready yet.",
        duration: const Duration(seconds: 2),
        flushbarPosition: FlushbarPosition.TOP,
        backgroundColor: AppColors.primary,
        margin: const EdgeInsets.all(8),
        borderRadius: BorderRadius.circular(12),
      ).show(context);
      return;
    }
    setState(() => _selectedIndex = index);
  }

  BoxDecoration _barDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? const BoxDecoration(
      color: Color(0xFF1E1E1E),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
    )
        : BoxDecoration(
      gradient: LinearGradient(
        colors: [AppColors.primary, const Color(0xFF42A5F5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x3D2196F3),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    );
  }

  Color _glassTileColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.white.withValues(alpha: 0.12);

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    child: Text(text,
        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
  );

  Widget _buildDrawerItem(IconData icon, String label, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.pop(context);
          onTap?.call();
        },
        child: Ink(
          decoration: BoxDecoration(
            color: _glassTileColor(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: ListTile(
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
            title: Text(label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white70),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerNavItem(IconData icon, String label, Widget screen) {
    return _buildDrawerItem(
      icon,
      label,
      onTap: () {
        Navigator.of(context, rootNavigator: true)
            .push(MaterialPageRoute(builder: (_) => screen));
      },
    );
  }

  Widget _buildNavIcon(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return SizedBox(
      height: 32,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _onItemTapped(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withValues(alpha: 0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected ? Border.all(color: Colors.white.withValues(alpha: 0.20)) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 30, color: Colors.white.withValues(alpha: isSelected ? 1 : 0.6)),
                const SizedBox(width: 8),
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.0,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: Colors.white.withValues(alpha: isSelected ? 1 : 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _ensureLoggedInWithPrompt() async {
    if (_isLoggedIn) return true;
    await Navigator.of(context, rootNavigator: true)
        .push(MaterialPageRoute(builder: (_) => const LoginScreen()));
    if (!mounted) return false;
    await _loadUserInfo();
    return _isLoggedIn;
  }

  Future<int?> _ensurePlayerId() async {
    if (!await _ensureLoggedInWithPrompt()) return null;
    final pid = await SessionManager.getPlayerId();
    if (pid == null || pid <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't get your player id. Please log in again.")),
      );
      return null;
    }
    return pid;
  }

  Widget _buildAuthButton() {
    final title = _isLoggedIn ? 'Logout' : 'Login';
    final icon = _isLoggedIn ? Icons.logout : Icons.login;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          if (!mounted) return;
          if (_isLoggedIn) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.clear();
            setState(() {
              _isLoggedIn = false;
              _apiToken = null;
              _userName = '';
              _userEmail = '';
              _profilePicUrl = null;
              _isAdmin = false;
            });
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
            );
          } else {
            Navigator.of(context).pop();
            await Navigator.of(context, rootNavigator: true)
                .push(MaterialPageRoute(builder: (_) => const LoginScreen()));
            if (mounted) await _loadUserInfo();
          }
        },
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.28),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      // AppBar
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: _barDecoration(context),
          child: Stack(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                iconTheme: const IconThemeData(color: Colors.white),
                title: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: Text(
                    ['Home', 'Matches', 'Tournaments', 'News', 'Booking'][_selectedIndex],
                    key: ValueKey(_selectedIndex),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
                actions: [
                  // Profile
                  GestureDetector(
                    onTap: () async {
                      if (!_isLoggedIn) {
                        await Navigator.of(context, rootNavigator: true)
                            .push(MaterialPageRoute(builder: (_) => const LoginScreen()));
                        if (mounted) await _loadUserInfo();
                      } else {
                        final changed =
                        await Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(apiToken: _apiToken ?? ''),
                          ),
                        );
                        if (changed == true && mounted) {
                          await _loadUserInfo();
                        }
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [AppColors.primary.withValues(alpha: 0.95), _barEnd.withValues(alpha: 0.7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: const [
                            BoxShadow(color: Color(0x3D2196F3), blurRadius: 10, offset: Offset(0, 4)),
                          ],
                        ),
                        child: Hero(
                          tag: 'profile-$_userEmail',
                          child: CircleAvatar(
                            radius: 17,
                            backgroundColor: Colors.white,
                            child: ClipOval(
                              child: (_profilePicUrl != null && _profilePicUrl!.isNotEmpty)
                                  ? Image.network(
                                _profilePicUrl!,
                                width: 34, height: 34, fit: BoxFit.cover,
                                cacheWidth: 96, cacheHeight: 96,
                              )
                                  : const Icon(Icons.person, color: AppColors.primary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

      // Drawer (no BackdropFilter)
      drawer: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        child: Drawer(
          elevation: 10,
          child: Container(
            decoration: isDark
                ? const BoxDecoration(color: Color(0xFF1E1E1E))
                : BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary.withValues(alpha: 0.88), const Color(0xFF42A5F5).withValues(alpha: 0.88)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: true,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12).copyWith(
                  bottom: MediaQuery.of(context).padding.bottom + 24,
                ),
                physics: const BouncingScrollPhysics(),
                children: [
                  const SizedBox(height: 36),
                  // Header
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.primary.withValues(alpha: 0.9), const Color(0xFF42A5F5).withValues(alpha: 0.5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white,
                        child: ClipOval(
                          child: (_profilePicUrl != null && _profilePicUrl!.isNotEmpty)
                              ? Image.network(
                            _profilePicUrl!,
                            width: 80, height: 80, fit: BoxFit.cover,
                            cacheWidth: 160, cacheHeight: 160,
                          )
                              : const Icon(Icons.person, color: AppColors.primary, size: 40),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      _userName.isEmpty ? 'Guest' : _userName,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Center(
                    child: Text(
                      _userEmail.isEmpty ? 'Not logged in' : _userEmail,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                  const Divider(color: Colors.white38, height: 30),

                  // ===== My Actions =====
                  _sectionTitle("My Actions"),
                  _buildDrawerItem(
                    Icons.play_circle_fill,
                    'Start Match',
                    onTap: () async {
                      if (!await _ensureLoggedInWithPrompt()) return;
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(builder: (_) => const MatchUIScreen()),
                      );
                    },
                  ),
                  _buildDrawerItem(Icons.school, 'App Tutorial'),
                  _buildDrawerItem(Icons.help_outline, 'Solve'),
                  _buildDrawerItem(Icons.share, 'Share App', onTap: _showShareOptions),
                  _buildDrawerItem(Icons.people, 'Find People'),

                  // ===== General =====
                  _sectionTitle("General"),
                  _buildDrawerNavItem(Icons.bar_chart_outlined, 'Global Stats', const GlobalStatsScreen()),
                  _buildDrawerItem(
                    Icons.person,
                    'My Profile',
                    onTap: () async {
                      if (!await _ensureLoggedInWithPrompt()) return;
                      final changed = await Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(builder: (_) => ProfileScreen(apiToken: _apiToken ?? '')),
                      );
                      if (changed == true && mounted) await _loadUserInfo();
                    },
                  ),
                  _buildDrawerItem(
                    Icons.sports_cricket,
                    'My Matches',
                    onTap: () async {
                      if (!await _ensureLoggedInWithPrompt()) return;
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(builder: (_) => const MyMatchesPage()),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    Icons.group,
                    'My Teams',
                    onTap: () async {
                      final pid = await _ensurePlayerId();
                      if (pid == null) return;
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(builder: (_) => MyTeamsPage(playerId: pid)),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    Icons.bar_chart,
                    'My Stats',
                    onTap: () async {
                      final pid = await _ensurePlayerId();
                      if (pid == null) return;
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(builder: (_) => MyStatsPage(playerId: pid)),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    Icons.qr_code_2,
                    'My QR Code',
                    onTap: () async {
                      final phone = await SessionManager.getPhone() ?? '';
                      final name = await SessionManager.getUserName();
                      if (phone.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Add your phone in Profile first')),
                        );
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ReceiverQrScreen(phone: phone, name: name)),
                      );
                    },
                  ),
                  const Divider(color: Colors.white24, height: 24),

                  _buildDrawerItem(
                    Icons.person_add_alt_1_outlined,
                    'Add User',
                    onTap: () async {
                      if (!await _ensureLoggedInWithPrompt()) return;
                      final token = await SessionManager.getToken();
                      if (token == null || token.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please log in to continue')),
                        );
                        return;
                      }
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(builder: (_) => CreateUserScreen(apiToken: token)),
                      );
                    },
                  ),

                  if (_isAdmin)
                    _buildDrawerItem(
                      Icons.add_circle_outline,
                      'Add Sponsor',
                      onTap: () async {
                        if (!await _ensureLoggedInWithPrompt()) return;
                        if (!_isAdmin) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Only admins can access this')),
                          );
                          return;
                        }
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(builder: (_) => const AddSponsorScreen()),
                        );
                      },
                    ),

                  _buildDrawerItem(
                    Icons.location_on,
                    'Add Venue',
                    onTap: () async {
                      if (!await _ensureLoggedInWithPrompt()) return;
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(builder: (_) => const GetVenueScreen()),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    Icons.emoji_events_outlined,
                    'Add Tournament',
                    onTap: () async {
                      if (!await _ensureLoggedInWithPrompt()) return;
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(builder: (_) => const TournamentListScreen()),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    Icons.groups,
                    'Add Teams',
                    onTap: () async {
                      if (!await _ensureLoggedInWithPrompt()) return;
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(builder: (_) => const GetTeamScreen()),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    Icons.event_note,
                    'Add Matches',
                    onTap: () async {
                      if (!await _ensureLoggedInWithPrompt()) return;
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(builder: (_) => const GetMatchScreen()),
                      );
                    },
                  ),

                  const Divider(color: Colors.white24, height: 24),

                  // Login/Logout CTA
                  _buildAuthButton(),
                ],
              ),
            ),
          ),
        ),
      ),

      // Start Match FAB
      floatingActionButton: _selectedIndex == 0
          ? GestureDetector(
        onTap: () => Navigator.of(context, rootNavigator: true)
            .push(MaterialPageRoute(builder: (_) => const MatchUIScreen())),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, const Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF42A5F5).withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sports_cricket, color: Colors.white),
              SizedBox(width: 8),
              Text("Start Match",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      // Body: static backdrop only on Home + keep pages alive with IndexedStack
      body: Stack(
        children: [
          if (_selectedIndex == 0)
            const Positioned.fill(child: SubtleBackdrop()), // paint-once, zero animation
          PageStorage(
            bucket: _bucket,
            child: IndexedStack(index: _selectedIndex, children: _pages),
          ),
        ],
      ),

      // Bottom nav
      bottomNavigationBar: Container(
        decoration: isDark
            ? const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        )
            : BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, const Color(0xFF42A5F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          boxShadow: [
            BoxShadow(color: const Color(0xFF42A5F5).withValues(alpha: 0.45), blurRadius: 20, offset: Offset(0, -6)),
          ],
        ),
        child: BottomAppBar(
          color: Colors.transparent,
          elevation: 0,
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 6),
            child: SizedBox(
              height: 56,
              child: Row(children: [
                Expanded(child: Center(child: _buildNavIcon(0, Icons.home_rounded, 'Home'))),
                Expanded(child: Center(child: _buildNavIcon(1, Icons.sports_cricket_rounded, 'Matches'))),
                Expanded(child: Center(child: _buildNavIcon(2, Icons.emoji_events_rounded, 'Tournaments'))),
                Expanded(child: Center(child: _buildNavIcon(3, Icons.article_rounded, 'News'))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// ---------- Static, paint-once backdrop (extremely cheap) ----------
class SubtleBackdrop extends StatelessWidget {
  const SubtleBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      painter: _StaticBackdrop(isDark: isDark),
      size: Size.infinite,
    );
  }
}

class _StaticBackdrop extends CustomPainter {
  final bool isDark;
  _StaticBackdrop({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final bg = isDark ? const Color(0xFF0E1217) : const Color(0xFFF5F7FA);
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);

    // Soft, static blobs (no blur, no saveLayer)
    void blob(Color c, double cx, double cy, double r, double opacity) {
      final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
      final grad = RadialGradient(
        colors: [c.withOpacity(opacity), Colors.transparent],
        stops: const [0.0, 1.0],
      );
      canvas.drawRect(rect.inflate(r), Paint()..shader = grad.createShader(rect));
    }

    final primary = AppColors.primary;
    const secondary = Color(0xFF42A5F5);

    final maxDim = w > h ? w : h;
    blob(primary,   w * 0.18, h * 0.22, maxDim * 0.45, isDark ? 0.20 : 0.16);
    blob(secondary, w * 0.84, h * 0.30, maxDim * 0.42, isDark ? 0.18 : 0.14);
    blob(primary,   w * 0.52, h * 0.82, maxDim * 0.38, isDark ? 0.18 : 0.14);
  }

  @override
  bool shouldRepaint(covariant _StaticBackdrop old) => old.isDark != isDark;
}
