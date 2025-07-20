import 'dart:convert';
import 'dart:ui';
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../screen/login_screen.dart';
import '../screen/match_screen.dart';
import '../screen/tournament_screen.dart';
import '../screen/all_posts_screen.dart';
import '../screen/profile_screen.dart';
import '../theme/color.dart';
import '../theme/theme_provider.dart';
import 'add_match_screen.dart';
import 'get_matches.dart';
import 'get_team_screen.dart';
import 'get_tournament.dart';
import 'get_venue_screen.dart';
import 'home_page_content.dart';
import '../screen/global_stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _userName = '';
  String _userEmail = '';
  String? _profilePicUrl;
  String? _apiToken;

  final List<Widget> _pages = [];

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

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_logged_in_token') ?? '';
    setState(() => _apiToken = token);

    if (token.isNotEmpty) {
      try {
        final resp = await http.get(
          Uri.parse(
            'https://cricjust.in/wp-json/custom-api-for-cricket/user-info?api_logged_in_token=$token',
          ),
        );
        if (resp.statusCode == 200) {
          final jsonData = json.decode(resp.body);
          if (jsonData['status'] == 1) {
            final data = jsonData['data'];
            final extra = jsonData['extra_data'];
            setState(() {
              _userName = (extra['first_name']?.isNotEmpty ?? false)
                  ? extra['first_name']
                  : data['display_name'] ?? _userName;
              _userEmail = data['user_email'] ?? _userEmail;
              _profilePicUrl = extra['user_profile_image'];
            });
          }
        }
      } catch (_) {}
    }

    _userName = prefs.getString('userName') ?? _userName;
    _userEmail = prefs.getString('userEmail') ?? _userEmail;
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

  Widget _buildDrawerItem(IconData icon, String label, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: () {
        Navigator.pop(context);
        if (onTap != null) onTap();
      },
    );
  }

  Widget _buildDrawerNavItem(IconData icon, String label, Widget screen) {
    return _buildDrawerItem(
      icon,
      label,
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
      },
    );
  }

  Widget _buildNavIcon(int index, IconData icon, String label) {
    final bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: SizedBox(
        width: 64,
        height: 58,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? Colors.white : Colors.white70,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: Theme.of(context).brightness == Brightness.dark
              ? const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                )
              : const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, Color(0xFF42A5F5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            iconTheme: const IconThemeData(
              color: Colors.white,
            ), // ✅ MOVE THIS HERE**
            title: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                [
                  'Home',
                  'Matches',
                  'Tournaments',
                  'News',
                  'Booking',
                ][_selectedIndex],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.white),
                onPressed: () {},
              ),
              GestureDetector(
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final token = prefs.getString('api_logged_in_token') ?? '';
                  if (token.isEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(apiToken: token),
                      ),
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Hero(
                    tag: 'profile-$_userEmail',
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white,
                      backgroundImage: (_profilePicUrl?.isNotEmpty ?? false)
                          ? NetworkImage(_profilePicUrl!)
                          : null,
                      child: (_profilePicUrl == null || _profilePicUrl!.isEmpty)
                          ? const Icon(Icons.person, color: AppColors.primary)
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      drawer: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        child: Drawer(
          elevation: 10,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: Theme.of(context).brightness == Brightness.dark
                  ? const BoxDecoration(color: Color(0xFF1E1E1E))
                  : BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.85),
                          const Color(0xFF42A5F5).withOpacity(0.85),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),

              child: Column(
                children: [
                  const SizedBox(height: 48),
                  Hero(
                    tag: 'profile',
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      backgroundImage: (_profilePicUrl?.isNotEmpty ?? false)
                          ? NetworkImage(_profilePicUrl!)
                          : null,
                      child: (_profilePicUrl == null || _profilePicUrl!.isEmpty)
                          ? const Icon(
                              Icons.person,
                              color: AppColors.primary,
                              size: 40,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _userEmail,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const Divider(color: Colors.white38, height: 30),

                  /// Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Text(
                              "My Actions",
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _buildDrawerNavItem(
                            Icons.play_circle_fill,
                            'Start Match',
                            const MatchUIScreen(),
                          ),
                          _buildDrawerItem(Icons.school, 'App Tutorial'),
                          _buildDrawerItem(Icons.help_outline, 'Solve'),
                          _buildDrawerItem(Icons.sports_cricket, 'My Matches'),
                          _buildDrawerItem(Icons.person, 'My Profile'),

                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 12,
                            ),
                            child: Text(
                              "General",
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _buildDrawerItem(Icons.emoji_events, 'My Tournament'),
                          _buildDrawerItem(
                            Icons.share,
                            'Share App',
                            onTap: () {
                              Share.share(
                                '📲 Check out Cricjust – the ultimate cricket scoring and streaming app!\n\nDownload now:\nAndroid: https://play.google.com/store/apps/details?id=com.cricjust.app',
                                subject: 'Cricjust App',
                              );
                            },
                          ),
                          _buildDrawerItem(Icons.group, 'My Teams'),
                          _buildDrawerItem(Icons.people, 'Find People'),
                          _buildDrawerItem(Icons.bar_chart, 'My Stats'),
                          const Divider(color: Colors.white24, height: 24),
                          _buildDrawerNavItem(
                            Icons.location_on,
                            'Venue',
                            const GetVenueScreen(),
                          ),
                          _buildDrawerNavItem(
                            Icons.emoji_events_outlined,
                            'Tournament',
                            const TournamentListScreen(),
                          ),
                          _buildDrawerNavItem(
                            Icons.groups,
                            'Teams',
                            const GetTeamScreen(),
                          ),
                          _buildDrawerNavItem(
                            Icons.event_note,
                            'Matches',
                            const GetMatchScreen(),
                          ),
                          _buildDrawerNavItem(
                            Icons.bar_chart_outlined,
                            'Global Stats',
                            const GlobalStatsScreen(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  /// Settings & Logout section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Consumer<ThemeProvider>(
                      builder: (context, themeProvider, _) {
                        return SwitchListTile(
                          title: const Text(
                            'Dark Mode',
                            style: TextStyle(color: Colors.white),
                          ),
                          secondary: const Icon(
                            Icons.dark_mode,
                            color: Colors.white,
                          ),
                          value: themeProvider.themeMode == ThemeMode.dark,
                          onChanged: (val) => themeProvider.toggleTheme(val),
                        );
                      },
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 10,
                    ),
                    child: GestureDetector(
                      onTapDown: (_) => setState(() {}),
                      onTapUp: (_) async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.clear();
                        if (context.mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                            (route) => false,
                          );
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.3),
                              blurRadius: 12,
                              spreadRadius: 0.5,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.logout, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              "Logout",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),

      floatingActionButton: _selectedIndex == 0
          ? GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MatchUIScreen()),
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  // Blue when in light mode; translucent white when in dark mode
                  color: Theme.of(context).brightness == Brightness.light
                      ? AppColors.primary
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                  boxShadow: [
                    BoxShadow(
                      // subtle shadow using the same base color
                      color:
                          (Theme.of(context).brightness == Brightness.light
                                  ? AppColors.primary
                                  : Colors.white)
                              .withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 0.5,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sports_cricket,
                      color: Colors.white,
                    ), // white icon on blue or white-on-dark
                    const SizedBox(width: 8),
                    const Text(
                      "Start Match",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _pages[_selectedIndex],
      ),
      bottomNavigationBar: Container(
        decoration: Theme.of(context).brightness == Brightness.dark
            ? const BoxDecoration(
                color: Color(0xFF1E1E1E),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              )
            : const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, Color(0xFF42A5F5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent,
                    blurRadius: 20,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
        child: BottomAppBar(
          color: Colors.transparent,
          elevation: 0,
          child: SizedBox(
            height: 70,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavIcon(0, Icons.home, 'Home'),
                _buildNavIcon(1, Icons.sports_cricket, 'Matches'),
                _buildNavIcon(2, Icons.emoji_events, 'Tournaments'),
                _buildNavIcon(3, Icons.article, 'News'),
                _buildNavIcon(4, Icons.article, 'Booking'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
