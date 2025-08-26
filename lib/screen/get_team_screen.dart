// lib/screen/get_team_screen.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// NEW: for granting via QR
import 'package:cricjust_premium/screen/permission/grant_permission_screen.dart';

import '../model/team_model.dart';
import '../service/session_manager.dart';
import '../service/team_service.dart';
import '../theme/color.dart';
import 'add_team_screen.dart';
import 'login_screen.dart';
import 'update_team.dart';

class GetTeamScreen extends StatefulWidget {
  const GetTeamScreen({super.key});

  @override
  State<GetTeamScreen> createState() => _GetTeamScreenState();
}

class _GetTeamScreenState extends State<GetTeamScreen> {
  // data
  final List<TeamModel> _teams = [];

  // controllers
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  // session / paging / state
  String _search = '';
  String? _apiToken;
  int? _currentPlayerId; // like GetMatchScreen
  int _skip = 0;
  final int _limit = 20;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _isAdmin = false;

  // NEW: mark when the list is already scoped to token user (full control)
  bool _usingUserTeams = true; // default true because fetchTeams() uses token

  // ---------- helpers ----------
  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString());
  }

  /// Try to find who owns/created the team.
  int? _teamOwnerId(TeamModel t) {
    try {
      final id = t.userId; // common name in many APIs
      if (id > 0) return id;
    } catch (_) {}
    try {
      final m = t.toJson();
      const keys = [
        'user_id',
        'player_id',
        'owner_player_id',
        'created_player_id',
        'created_by',
        'author_id',
        'added_by',
      ];
      for (final k in keys) {
        final v = _asInt(m[k]);
        if (v != null && v > 0) return v;
      }
    } catch (_) {}
    return null;
  }

  String _initialsFrom(String s) {
    final parts = s.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  Widget _networkAvatar({
    required BuildContext context,
    required String? url,
    required String fallbackText, // team initials or name initial
    double size = 56,
  }) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final target = (size * dpr).round();

    if (url == null || url.isEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: AppColors.primary.withValues(alpha: 0.10),
        child: Text(
          fallbackText,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.primary,
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.primary.withValues(alpha: 0.10),
      child: ClipOval(
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: target, // downscale in cache for reliability/perf
          loadingBuilder: (ctx, child, progress) {
            if (progress == null) return child;
            return Center(
              child: SizedBox(
                width: size * 0.45,
                height: size * 0.45,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
          errorBuilder: (ctx, err, stack) {
            return Container(
              alignment: Alignment.center,
              color: Colors.transparent,
              child: Text(
                fallbackText,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.primary,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------- lifecycle ----------
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearch);
    _init();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _searchController.removeListener(_onSearch);
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ---------- init / session ----------
  Future<void> _init() async {
    setState(() => _loading = true);

    await migrateRoleKeys(); // no-op if already clean
    _apiToken = await SessionManager.getToken();
    _currentPlayerId = await SessionManager.getPlayerId();

    if (_apiToken == null || _apiToken!.isEmpty) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    _isAdmin = await resolveIsAdminSafe();

    // If later you add an admin-wide endpoint, flip this to false there.
    _usingUserTeams = true;

    // reset paging
    _skip = 0;
    _hasMore = true;

    await _fetchTeams(refresh: true);

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<bool> _ensureSession() async {
    _apiToken = await SessionManager.getToken();
    _currentPlayerId = await SessionManager.getPlayerId();

    if (_apiToken == null || _apiToken!.isEmpty) {
      if (!mounted) return false;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return false;
    }
    _isAdmin = await resolveIsAdminSafe();
    return true;
  }

  // ---------- admin + prefs helpers ----------
  Future<bool> resolveIsAdminSafe() async {
    final prefs = await SharedPreferences.getInstance();

    final anyRoles = prefs.get('roles');
    if (anyRoles is List) {
      final roles = anyRoles.map((e) => e.toString().toLowerCase()).toList();
      if (roles.contains('administrator') || roles.contains('admin')) return true;
    } else if (anyRoles is String) {
      final s = anyRoles.toLowerCase();
      if (s.contains('administrator') || s.contains('admin')) return true;
    }

    final rolesCsv = prefs.get('roles_csv');
    if (rolesCsv != null && rolesCsv.toString().toLowerCase().contains('admin')) {
      return true;
    }

    for (final k in ['role', 'user_role', 'userType', 'user_type']) {
      final v = prefs.get(k);
      if (v != null && v.toString().toLowerCase().contains('admin')) return true;
    }

    final rawIsAdmin = prefs.get('is_admin');
    if (rawIsAdmin is bool) return rawIsAdmin;
    if (rawIsAdmin is int) return rawIsAdmin == 1;
    if (rawIsAdmin != null) {
      final s = rawIsAdmin.toString().trim().toLowerCase();
      if (['1', 'true', 'yes', 'admin', 'administrator'].contains(s)) return true;
    }
    return false;
  }

  Future<void> migrateRoleKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final r = prefs.get('roles');
    if (r is String) {
      final parts =
      r.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      await prefs.setStringList('roles', parts);
    }
    final rc = prefs.get('roles_csv');
    if (rc != null && rc is! String) {
      await prefs.remove('roles_csv');
    }
  }

  // ---------- UI events ----------
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
        !_loading &&
        _hasMore) {
      _fetchTeams();
    }
  }

  // ---------- data ----------
  Future<void> _fetchTeams({bool refresh = false}) async {
    if (_loadingMore) return;
    if (!await _ensureSession()) return;

    if (refresh) {
      _skip = 0;
      _hasMore = true;
      _teams.clear();
    }
    if (!_hasMore) return;

    setState(() => _loadingMore = true);
    try {
      final newTeams = await TeamService.fetchTeams(
        apiToken: _apiToken!, // safe now
        limit: _limit,
        skip: _skip,
        search: _search,
      );

      // This endpoint is scoped to token user => full control
      _usingUserTeams = true;

      setState(() {
        _teams.addAll(newTeams);
        _skip += newTeams.length; // advance by what we actually got
        _hasMore = newTeams.length == _limit; // stop when fewer than limit
      });
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('session expired') || msg.contains('unauthorized')) {
        await SessionManager.clear();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _hardRefresh() async {
    if (!await _ensureSession()) return;
    setState(() {
      _skip = 0;
      _teams.clear();
      _loading = true;
    });
    await _fetchTeams(refresh: true);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _deleteTeam(int teamId) async {
    if (!await _ensureSession()) return;

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

    try {
      await TeamService.deleteTeam(teamId, _apiToken!);
      setState(() => _teams.removeWhere((t) => t.teamId == teamId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Team deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
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

  // ---------- card ----------
  Widget _buildTeamCard(TeamModel team) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final ownerId = _teamOwnerId(team);
    final isOwner =
        _currentPlayerId != null && ownerId != null && _currentPlayerId == ownerId;

    // CAPABILITIES:
    // If list is already user-scoped, token user can manage all → full control.
    // Else (future: admin/all list), allow only for admin or owner.
    final bool canEdit   = _usingUserTeams ? true : (_isAdmin || isOwner);
    final bool canDelete = _usingUserTeams ? true : (_isAdmin || isOwner);
    final bool canGrant  = canEdit; // grant only when you can act on the team

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
        leading: _networkAvatar(
          context: context,
          url: team.teamLogo,
          fallbackText: _initialsFrom(team.teamName),
          size: 56,
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
        trailing: (canEdit || canDelete || canGrant)
            ? Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canEdit)
              IconButton(
                icon: const Icon(Icons.edit, color: AppColors.primary),
                tooltip: 'Edit',
                onPressed: () => _navigateToUpdate(team),
              ),
            if (canDelete)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                tooltip: 'Delete',
                onPressed: () => _deleteTeam(team.teamId),
              ),
            if (canGrant)
              IconButton(
                icon: const Icon(Icons.qr_code_2, color: Colors.blueGrey),
                tooltip: 'Grant Access',
                onPressed: () async {
                  final token = _apiToken;
                  if (token == null || token.isEmpty) {
                    if (!mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                    return;
                  }
                  final granted = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GrantPermissionScreen(
                        apiToken: token,
                        initialType: 'teams',             // pin to teams
                        initialTypeId: team.teamId,       // pass selected team id
                        initialTitle: team.teamName,      // optional: header
                      ),
                    ),
                  );
                  if (granted == true && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Access granted')),
                    );
                  }
                },
              ),
          ],
        )
            : null,
      ),
    );
  }

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[100]!,

      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56 + 60), // toolbar + search
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
                SizedBox(
                  height: kToolbarHeight,
                  child: Row(
                    children: const [
                      BackButton(color: Colors.white),
                      Expanded(
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
                      SizedBox(width: 48), // balance BackButton
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _hardRefresh,
        child: _teams.isEmpty
            ? ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [SizedBox(height: 240)],
        )
            : ListView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
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

      floatingActionButton: isDark
          ? GestureDetector(
        onTap: _navigateToAdd,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.add, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Add Team',
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
          : FloatingActionButton.extended(
        onPressed: _navigateToAdd,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Team',
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
