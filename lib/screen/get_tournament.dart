import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/tournament_model.dart';
import '../screen/add_tournament_screen.dart';
import '../screen/login_screen.dart';
import '../screen/manage_groups_screen.dart';
import '../screen/update_tournament_screen.dart';
import '../service/tournament_service.dart';
import '../service/session_manager.dart';
import '../theme/color.dart';
import 'manage_tournament_teams_screen.dart';

class TournamentListScreen extends StatefulWidget {
  const TournamentListScreen({super.key});

  @override
  State<TournamentListScreen> createState() => _TournamentListScreenState();
}

class _TournamentListScreenState extends State<TournamentListScreen> {
  String? _apiToken;
  int? _currentPlayerId;
  bool _isAdmin = false;

  final List<TournamentModel> _tournaments = [];
  final Map<int, String> _teamNameCache = {};
  final Set<int> _pendingWinnerFetches = {};

  bool _isLoading = true;
  String _search = '';
  Timer? _debounce;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await _migrateRoleKeys();

    if (!await _ensureSession()) return;
    await _fetchTournaments();
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

    _isAdmin = await _resolveIsAdminSafe();
    return true;
  }

  Future<bool> _resolveIsAdminSafe() async {
    final prefs = await SharedPreferences.getInstance();

    final dynamic rolesAny = prefs.get('roles');
    if (rolesAny is List) {
      final roles = rolesAny.map((e) => e.toString().toLowerCase()).toList();
      if (roles.contains('administrator') || roles.contains('admin')) return true;
    } else if (rolesAny is String) {
      final csv = rolesAny.toLowerCase();
      if (csv.contains('administrator') || csv.contains('admin')) return true;
    }

    for (final key in ['role', 'user_role', 'userType', 'user_type']) {
      final v = prefs.get(key);
      if (v != null && v.toString().toLowerCase().contains('admin')) return true;
    }

    final rawIsAdmin = prefs.get('is_admin');
    if (rawIsAdmin is bool) return rawIsAdmin;
    if (rawIsAdmin is int) return rawIsAdmin == 1;
    if (rawIsAdmin != null) {
      final s = rawIsAdmin.toString().trim().toLowerCase();
      if (['1', 'true', 'yes', 'admin', 'administrator'].contains(s)) return true;
    }

    const hardcodedAdmins = <int>{12};
    if (_currentPlayerId != null && hardcodedAdmins.contains(_currentPlayerId)) {
      return true;
    }

    return false;
  }

  Future<void> _migrateRoleKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final r = prefs.get('roles');
    if (r is String) {
      final parts = r.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      await prefs.setStringList('roles', parts);
    }
  }

  // --------------------------------------------------------------------------
  // Fetch tournaments for this logged-in user
  // --------------------------------------------------------------------------
  Future<void> _fetchTournaments() async {
    if (!await _ensureSession()) return;
    setState(() => _isLoading = true);

    try {
      final data = await TournamentService.fetchUserTournaments(
        apiToken: _apiToken!,
        limit: 50,
        skip: 0,
      );

      final q = _search.toLowerCase();
      final filtered = q.isEmpty
          ? data
          : data.where((t) {
        final name = (t.tournamentName ?? '').toLowerCase();
        final desc = (t.tournamentDesc ?? '').toLowerCase();
        return name.contains(q) || desc.contains(q);
      }).toList();

      setState(() {
        _tournaments
          ..clear()
          ..addAll(filtered);
      });

      await _populateWinnerNames(filtered);
    } catch (e) {
      final lower = e.toString().toLowerCase();
      if (lower.contains('unauthorized') || lower.contains('session expired')) {
        await SessionManager.clear();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --------------------------------------------------------------------------
  // Populate winner team names
  // --------------------------------------------------------------------------
  Future<void> _populateWinnerNames(Iterable<TournamentModel> list) async {
    if (_apiToken == null || _apiToken!.isEmpty) return;

    final idsToFetch = <int>{};
    for (final t in list) {
      final wid = t.winner;
      if (wid != null && wid != 0 && !_teamNameCache.containsKey(wid)) {
        idsToFetch.add(wid);
      }
    }
    if (idsToFetch.isEmpty) return;

    await Future.wait(idsToFetch.map((id) async {
      try {
        final name = await TournamentService.fetchTeamNameById(
          apiToken: _apiToken!,
          teamId: id,
        );
        if (name != null && name.trim().isNotEmpty) {
          _teamNameCache[id] = name.trim();
        }
      } catch (_) {}
    }));

    if (mounted) setState(() {});
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _search = _searchController.text.trim());
      await _fetchTournaments();
    });
  }

  // --------------------------------------------------------------------------
  // Delete tournament
  // --------------------------------------------------------------------------
  Future<void> _confirmDelete(int tournamentId) async {
    if (!await _ensureSession()) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Tournament'),
        content: const Text('Are you sure you want to delete this tournament?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await TournamentService.deleteTournament(
        apiToken: _apiToken!, // ✅ Named parameter
        tournamentId: tournamentId, // ✅ Named parameter
      );

      if (!mounted) return;
      Navigator.pop(context);
      setState(() => _tournaments.removeWhere((t) => t.tournamentId == tournamentId));

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Deleted successfully')));
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }


  // --------------------------------------------------------------------------
  // UI builders
  // --------------------------------------------------------------------------
  Widget _buildTournamentCard(TournamentModel t, bool isDark) {
    final isCompleted = t.winner != null && t.winner != 0;

    final isCreator = _currentPlayerId != null && _currentPlayerId == t.userId;
    final canEdit = _isAdmin || (!isCompleted && isCreator);
    final canDelete = _isAdmin || (!isCompleted && isCreator);

    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey[300]! : Colors.black87;
    final cardColor = isDark ? Colors.grey[900]! : Colors.white;

    String? winnerLabel() {
      final wid = t.winner;
      if (wid == null || wid == 0) return null;
      final cached = _teamNameCache[wid];
      if (cached != null) return cached;
      if (!_pendingWinnerFetches.contains(wid)) {
        _pendingWinnerFetches.add(wid);
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            final name = await TournamentService.fetchTeamNameById(
              apiToken: _apiToken!,
              teamId: wid,
            );
            if (name != null && name.trim().isNotEmpty) {
              _teamNameCache[wid] = name.trim();
              if (mounted) setState(() {});
            }
          } finally {
            _pendingWinnerFetches.remove(wid);
          }
        });
      }
      return null;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            const BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 4),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                backgroundImage: t.tournamentLogo.isNotEmpty
                    ? NetworkImage(t.tournamentLogo)
                    : null,
                child: t.tournamentLogo.isEmpty
                    ? const Icon(Icons.emoji_events, size: 26, color: AppColors.primary)
                    : null,
              ),
              title: Text(t.tournamentName,
                  style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.tournamentDesc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: subTextColor)),
                    if (isCompleted)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: [
                            const Icon(Icons.emoji_events, size: 18, color: Colors.amber),
                            Text('Winner: ${winnerLabel() ?? '—'}',
                                style: const TextStyle(
                                    color: Colors.green, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              trailing: (canEdit || canDelete)
                  ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canEdit)
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blueAccent),
                      onPressed: () async {
                        final updated = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UpdateTournamentScreen(tournament: t),
                          ),
                        );
                        if (updated == true) _fetchTournaments();
                      },
                    ),
                  if (canDelete)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => _confirmDelete(t.tournamentId),
                    ),
                ],
              )
                  : null,
            ),
            if (!isCompleted)
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    if (t.isGroup == true)
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ManageGroupsScreen(tournamentId: t.tournamentId),
                            ),
                          );
                        },
                        icon:
                        const Icon(Icons.groups, size: 20, color: AppColors.primary),
                        label: const Text('Manage Groups',
                            style: TextStyle(color: AppColors.primary)),
                      ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ManageTournamentTeamsScreen(
                                tournamentId: t.tournamentId),
                          ),
                        );
                      },
                      icon: const Icon(Icons.groups_2,
                          size: 20, color: AppColors.primary),
                      label: const Text('Manage Teams',
                          style: TextStyle(color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Build
  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.grey[100];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Manage Tournaments',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor:
        isDark ? const Color(0xFF1E1E1E) : AppColors.primary,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchTournaments,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchTournaments,
        child: _tournaments.isEmpty
            ? ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 200),
            Center(child: Text('No tournaments found.')),
            SizedBox(height: 300),
          ],
        )
            : ListView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: _tournaments.length,
          itemBuilder: (_, i) =>
              _buildTournamentCard(_tournaments[i], isDark),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const AddTournamentScreen()),
          );
          if (created == true) _fetchTournaments();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Tournament'),
        backgroundColor: AppColors.primary,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
