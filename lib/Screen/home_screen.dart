import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../screen/add_match_screen.dart';
import '../screen/add_team_screen.dart';
import '../screen/add_tournament_screen.dart';
import '../screen/add_venue_screen.dart';
import '../screen/login_screen.dart';
import '../screen/match_screen.dart';
import '../screen/tournament_screen.dart';
import '../screen/all_posts_screen.dart';
import '../screen/profile_screen.dart';
import '../theme/color.dart';
import '../theme/theme_provider.dart';
import 'home_page_content.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

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
        final uri = Uri.parse(
          'https://cricjust.in/wp-json/custom-api-for-cricket/user-info?api_logged_in_token=$token',
        );
        final resp = await http.get(uri);
        if (resp.statusCode == 200) {
          final jsonData = json.decode(resp.body) as Map<String, dynamic>;
          if (jsonData['status'] == 1) {
            final data = jsonData['data'] as Map<String, dynamic>;
            final extra = jsonData['extra_data'] as Map<String, dynamic>;

            setState(() {
              _userName = (extra['first_name'] as String?)?.isNotEmpty == true
                  ? extra['first_name'] as String
                  : data['display_name'] as String? ?? _userName;
              _userEmail = data['user_email'] as String? ?? _userEmail;
              _profilePicUrl = extra['user_profile_image'] as String?;
            });
            return;
          }
        }
      } catch (_) {
        // ignore and fallback
      }
    }

    // fallback to local storage
    setState(() {
      _userName = prefs.getString('userName') ?? _userName;
      _userEmail = prefs.getString('userEmail') ?? _userEmail;
      _profilePicUrl = prefs.getString('profilePic');
    });
  }

  void _onItemTapped(int index) {
    if (index == 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking is not ready yet.')),
      );
      return;
    }
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 2,
        centerTitle: true,
        title: Text(
          ['Home', 'Matches', 'Tournaments', 'News', 'Booking'][_selectedIndex],
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                  MaterialPageRoute(builder: (_) => ProfileScreen(apiToken: token)),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                backgroundImage: (_profilePicUrl != null && _profilePicUrl!.isNotEmpty)
                    ? NetworkImage(_profilePicUrl!)
                    : null,
                child: (_profilePicUrl == null || _profilePicUrl!.isEmpty)
                    ? const Icon(Icons.person, color: AppColors.primary)
                    : null,
              ),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: AppColors.primary),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage: (_profilePicUrl != null && _profilePicUrl!.isNotEmpty)
                    ? NetworkImage(_profilePicUrl!)
                    : null,
                child: (_profilePicUrl == null || _profilePicUrl!.isEmpty)
                    ? const Icon(Icons.person, color: AppColors.primary, size: 40)
                    : null,
              ),
              accountName: Text(_userName, style: const TextStyle(color: Colors.white)),
              accountEmail: Text(_userEmail, style: const TextStyle(color: Colors.white70)),
            ),
            Expanded(
              child: ListView(
                children: [
                  _buildDrawerNavItem(Icons.play_circle_fill, 'Start Match', const AddMatchScreen()),
                  _buildDrawerItem(Icons.school, 'App Tutorial'),
                  _buildDrawerItem(Icons.help_outline, 'Solve'),
                  _buildDrawerItem(Icons.sports_cricket, 'My Matches'),
                  _buildDrawerItem(Icons.person, 'My Profile'),
                  _buildDrawerItem(Icons.emoji_events, 'My Tournament'),
                  _buildDrawerItem(Icons.share, 'Share App'),
                  _buildDrawerItem(Icons.group, 'My Teams'),
                  _buildDrawerItem(Icons.people, 'Find People'),
                  _buildDrawerItem(Icons.bar_chart, 'My Stats'),
                  const Divider(),
                  _buildDrawerNavItem(Icons.location_on, 'Add Venue', const AddVenueScreen()),
                  _buildDrawerNavItem(Icons.emoji_events_outlined, 'Add Tournament', const AddTournamentScreen()),
                  _buildDrawerNavItem(Icons.add_circle_outline, 'Add Teams', const AddTeamScreen()),
                  _buildDrawerNavItem(Icons.add_circle_outline, 'Add Match', const AddMatchScreen()),
                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, _) {
                      return SwitchListTile(
                        title: const Text('Dark Mode', style: TextStyle(fontSize: 16)),
                        secondary: const Icon(Icons.dark_mode, color: AppColors.primary),
                        value: themeProvider.themeMode == ThemeMode.dark,
                        onChanged: (val) {
                          themeProvider.toggleTheme(val);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () async {
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
          ],
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _pages[_selectedIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.sports_cricket), label: 'Matches'),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_events), label: 'Tournaments'),
          BottomNavigationBarItem(icon: Icon(Icons.article), label: 'News'),
          BottomNavigationBarItem(icon: Icon(Icons.location_on), label: 'Booking'),
        ],
      ),
    );
  }

  ListTile _buildDrawerNavItem(IconData icon, String label, Widget destination) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label, style: const TextStyle(fontSize: 16)),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => destination),
        );
      },
    );
  }

  Widget _buildDrawerItem(IconData icon, String label, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label, style: const TextStyle(fontSize: 16)),
      onTap: () {
        Navigator.pop(context);
        if (onTap != null) onTap();
      },
    );
  }
}