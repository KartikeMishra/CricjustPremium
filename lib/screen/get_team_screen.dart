// lib/screen/get_team_screen.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/team_model.dart';
import '../service/team_service.dart';
import '../theme/color.dart';
import 'add_team_screen.dart';
import 'login_screen.dart';
import 'update_team.dart';

class GetTeamScreen extends StatefulWidget {
  const GetTeamScreen({super.key});

  @override
  _GetTeamScreenState createState() => _GetTeamScreenState();
}

class _GetTeamScreenState extends State<GetTeamScreen> {
  final List<TeamModel> _teams = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  String _search = '';
  String? _apiToken;
  int? _currentUserId;
  int _skip = 0;
  final int _limit = 20;
  bool _loading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _init();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearch);
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _apiToken = prefs.getString('api_logged_in_token');
    _currentUserId = prefs.getInt('user_id');
    if (_apiToken == null || _apiToken!.isEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    await _fetchTeams();
    setState(() => _loading = false);
  }

  void _onSearch() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() {
        _search = _searchController.text.trim();
        _skip = 0;
      });
      _fetchTeams(refresh: true);
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        !_loading) {
      _fetchTeams();
    }
  }

  Future<void> _fetchTeams({bool refresh = false}) async {
    if (_loadingMore || _apiToken == null) return;
    setState(() => _loadingMore = true);
    try {
      final newTeams = await TeamService.fetchTeams(
        apiToken: _apiToken!,
        limit: _limit,
        skip: _skip,
        search: _search,
      );
      if (refresh) _teams.clear();
      if (newTeams.isNotEmpty) {
        _teams.addAll(newTeams);
        _skip += _limit;
      }
    } catch (e) {
      if (e.toString().contains('Session expired')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }
    } finally {
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _deleteTeam(int teamId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Team'),
        content: const Text('Are you sure you want to delete this team?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await TeamService.deleteTeam(teamId, _apiToken!);
    setState(() => _teams.removeWhere((t) => t.teamId == teamId));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Team deleted successfully')));
  }

  Future<void> _navigateToAdd() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddTeamScreen()),
    );
    if (created == true) {
      _teams.clear();
      _skip = 0;
      await _fetchTeams(refresh: true);
    }
  }

  Future<void> _navigateToUpdate(TeamModel team) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => UpdateTeamScreen(teamId: team.teamId)),
    );
    if (updated == true) {
      _teams.clear();
      _skip = 0;
      await _fetchTeams(refresh: true);
    }
  }

  Widget _buildTeamCard(TeamModel team) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const adminUserIds = [12];
    final canEdit =
        _currentUserId != null &&
        (team.userId == _currentUserId ||
            adminUserIds.contains(_currentUserId));

    final cardColor = isDark ? Colors.grey[850] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.white70 : Colors.black87;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.primary.withOpacity(0.1),
          backgroundImage: team.teamLogo.isNotEmpty
              ? NetworkImage(team.teamLogo)
              : null,
          child: team.teamLogo.isEmpty
              ? const Icon(Icons.group, size: 26, color: AppColors.primary)
              : null,
        ),
        title: Text(
          team.teamName,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            team.teamDescription.isNotEmpty
                ? team.teamDescription
                : 'No description',
            style: TextStyle(fontSize: 13, color: subTextColor),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: canEdit
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: AppColors.primary),
                    onPressed: () => _navigateToUpdate(team),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () => _deleteTeam(team.teamId),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[100]!,

      // ───── AppBar ─────
      // replace your existing `appBar: PreferredSize(...)` with:
      appBar: PreferredSize(
        // total height = toolbar (56) + search bar (60)
        preferredSize: const Size.fromHeight(56 + 60),
        child: Container(
          decoration: isDark
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
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // ─── toolbar row ───
                SizedBox(
                  height: kToolbarHeight,
                  child: Row(
                    children: [
                      BackButton(
                        color: Colors.white, // arrow always white
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Manage Teams',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                      // placeholder to balance the back button
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                // ─── search field ───
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.white10 : Colors.black12,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search teams…',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white54 : Colors.grey,
                        ),
                        border: InputBorder.none,
                        prefixIcon: Icon(
                          Icons.search,
                          color: isDark ? Colors.white : AppColors.primary,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // ───── Body ─────
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _fetchTeams(refresh: true),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 100),
                itemCount: _teams.length + (_loadingMore ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i >= _teams.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return _buildTeamCard(_teams[i]);
                },
              ),
            ),

      // ───── FAB ─────
      floatingActionButton: isDark
          // glassy pill in dark
          ? GestureDetector(
              onTap: _navigateToAdd,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.add, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          "Add Team",
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
            )
          // solid blue FAB in light
          : FloatingActionButton.extended(
              onPressed: _navigateToAdd,
              icon: const Icon(Icons.add),
              label: const Text(
                "Add Team",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
    );
  }
}
