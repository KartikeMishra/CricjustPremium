// lib/screen/get_tournament.dart  (or tournament_list_screen.dart — keep your path)

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
  // ───────── Session / permissions ─────────
  String? _apiToken;
  int? _currentPlayerId; // use player id consistently
  bool _isAdmin = false;

  // ───────── Data ─────────
  final List<TournamentModel> _tournaments = [];

  // Cache: teamId -> teamName (for showing winner)
  final Map<int, String> _teamNameCache = {};
  final Set<int> _pendingWinnerFetches = {}; // prevent duplicate fetches

  // ───────── UI / search ─────────
  bool _isLoading = true;
  String _search = '';
  Timer? _debounce;

  // ───────── Controllers ─────────
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // ───────── Lifecycle ─────────
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
    // Optional: normalize legacy role keys so future reads are stable
    await migrateRoleKeys();

    if (!await _ensureSession()) return;
    await _fetchTournaments();
  }

  /// Ensure we have a valid token + player id; redirect to login if not.
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

  // ───────── Admin & roles (type-safe) ─────────
  Future<bool> resolveIsAdminSafe() async {
    final prefs = await SharedPreferences.getInstance();

    // roles may be List, String(csv), or something else
    final dynamic rolesAny = prefs.get('roles');
    if (rolesAny is List) {
      final roles = rolesAny.map((e) => e.toString().toLowerCase()).toList();
      if (roles.contains('administrator') || roles.contains('admin')) return true;
    } else if (rolesAny is String) {
      final csv = rolesAny.toLowerCase();
      if (csv.contains('administrator') || csv.contains('admin')) return true;
    }

    // legacy key: could be non-string (e.g., bool); never use getString
    final dynamic legacyAny = prefs.get('roles_csv');
    if (legacyAny != null && legacyAny.toString().toLowerCase().contains('admin')) {
      return true;
    }

    for (final key in ['role', 'user_role', 'userType', 'user_type']) {
      final v = prefs.get(key);
      if (v != null && v.toString().toLowerCase().contains('admin')) return true;
    }

    // Flexible is_admin (bool/int/string)
    final rawIsAdmin = prefs.get('is_admin');
    if (rawIsAdmin is bool) return rawIsAdmin;
    if (rawIsAdmin is int) return rawIsAdmin == 1;
    if (rawIsAdmin != null) {
      final s = rawIsAdmin.toString().trim().toLowerCase();
      if (['1', 'true', 'yes', 'admin', 'administrator'].contains(s)) return true;
    }

    // (Optional) hardcoded fallbacks
    const hardcodedAdmins = <int>{12};
    if (_currentPlayerId != null && hardcodedAdmins.contains(_currentPlayerId)) {
      return true;
    }

    return false;
  }

  Future<void> migrateRoleKeys() async {
    final prefs = await SharedPreferences.getInstance();

    final r = prefs.get('roles');
    if (r is String) {
      final parts = r.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      await prefs.setStringList('roles', parts);
    }

    final rc = prefs.get('roles_csv');
    if (rc != null && rc is! String) {
      // if it was saved as a bool/int/etc., remove it to avoid future type issues
      await prefs.remove('roles_csv');
    }
  }

  // ───────── Data fetch ─────────
  Future<void> _fetchTournaments() async {
    if (!await _ensureSession()) return;
    setState(() => _isLoading = true);

    try {
      // If your API supports server-side search, pass _search in the request.
      final data = await TournamentService.fetchAllTournamentsRaw(apiToken: _apiToken!);

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
      if (lower.contains('401') ||
          lower.contains('unauthorized') ||
          lower.contains('invalid api logged in token') ||
          lower.contains('session expired')) {
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
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Preload winner team names for completed tournaments.
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
      } catch (_) {
        // ignore individual failures
      }
    }));

    if (mounted) setState(() {}); // refresh visible cards
  }

  // ───────── Search ─────────
  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _search = _searchController.text.trim());
      await _fetchTournaments();
    });
  }

  // ───────── Delete ─────────
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

    // Simple blocking loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await TournamentService.deleteTournament(tournamentId, _apiToken!);
      if (!mounted) return;
      Navigator.pop(context); // close loader

      setState(() => _tournaments.removeWhere((t) => t.tournamentId == tournamentId));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Deleted successfully')));
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loader
      final lower = e.toString().toLowerCase();
      if (lower.contains('unauthorized') || lower.contains('session expired')) {
        await SessionManager.clear();
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  // ───────── UI ─────────
  Widget _buildTournamentCard(TournamentModel t, bool isDark) {
    final isCompleted = t.winner != null && t.winner != 0;

    // Permissions: admin or creator (and not completed) can edit/delete
    final isCreator = _currentPlayerId != null && _currentPlayerId == t.userId;
    final canEdit   = _isAdmin || (!isCompleted && isCreator);
    final canDelete = _isAdmin || (!isCompleted && isCreator);

    final textColor = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? Colors.grey[900]! : Colors.white;
    final subTextColor = isDark ? Colors.grey[300]! : Colors.black87;

    // Winner label (uses cache; lazy-fetch if needed)
    String? winnerLabel() {
      final wid = t.winner;
      if (wid == null || wid == 0) return null;

      final cached = _teamNameCache[wid];
      if (cached != null && cached.trim().isNotEmpty) return cached.trim();

      if (_apiToken != null &&
          _apiToken!.isNotEmpty &&
          !_pendingWinnerFetches.contains(wid)) {
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
          } catch (_) {
            // ignore
          } finally {
            _pendingWinnerFetches.remove(wid);
          }
        });
      }
      return null; // show "—" until fetched
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
              title: Text(
                t.tournamentName,
                style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.tournamentDesc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: subTextColor),
                    ),
                    if (isCompleted)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: [
                            const Icon(Icons.emoji_events, size: 18, color: Colors.amber),
                            Text(
                              'Winner: ${winnerLabel() ?? '—'}',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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

            // Ongoing tournament actions
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
                              builder: (_) => ManageGroupsScreen(tournamentId: t.tournamentId),
                            ),
                          );
                        },
                        icon: const Icon(Icons.groups, size: 20, color: AppColors.primary),
                        label: const Text('Manage Groups',
                            style: TextStyle(color: AppColors.primary)),
                      ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ManageTournamentTeamsScreen(tournamentId: t.tournamentId),
                          ),
                        );
                      },
                      icon: const Icon(Icons.groups_2, size: 20, color: AppColors.primary),
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

  // ───────── Build ─────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.grey[100];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(124),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 56,
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: isDark
                  ? null
                  : const LinearGradient(
                colors: [AppColors.primary, Color(0xFF42A5F5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              color: isDark ? const Color(0xFF1E1E1E) : null,
              borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
          ),
          title: const Text(
            'Manage Tournaments',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(68),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black26 : Colors.black12,
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  style:
                  TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Search tournaments...',
                    hintStyle: TextStyle(
                        color: isDark ? Colors.white54 : Colors.grey),
                    border: InputBorder.none,
                    prefixIcon:
                    const Icon(Icons.search, color: AppColors.primary),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchTournaments,
        child: _tournaments.isEmpty
            ? ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Center(child: Text('No tournaments found.')),
            SizedBox(height: 400),
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
