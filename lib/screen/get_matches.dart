// lib/screen/get_match_screen.dart

import 'dart:async';
import 'dart:ui';
import 'package:cricjust_premium/screen/permission/grant_permission_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../service/session_manager.dart';
import '../service/match_service.dart';
import '../service/youtube_stream_service.dart';
import '../theme/color.dart';
import '../widget/toss_dialog.dart';
import 'add_match_screen.dart';
import 'update_match_screen.dart';
import 'match_scoring_screen.dart';
import 'login_screen.dart';

class GetMatchScreen extends StatefulWidget {
  const GetMatchScreen({super.key});

  @override
  State<GetMatchScreen> createState() => _GetMatchScreenState();
}

class _GetMatchScreenState extends State<GetMatchScreen> {
  // data
  final _matches = <Map<String, dynamic>>[];

  // session
  int? _currentPlayerId; // from SessionManager
  String? _token;
  bool _isAdmin = false;

  // loading / paging
  bool _loading = true;
  bool _loadingPage = false;
  bool _hasMore = true;
  bool _isNavigatingToScoreScreen = false;

  // source marker (if true, API already scoped to token user)
  bool _usingUserMatches = false;

  final _scroll = ScrollController();
  final int _limit = 20;
  int _skip = 0;

  // ---------- helpers ----------
  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString());
  }

  int? _resolveOwnerId(Map<String, dynamic> m) {
    const keys = [
      'player_id',
      'owner_player_id',
      'created_player_id',
      'match_player_id',
      'user_id',
      'created_by',
      'owner_id',
      'author_id',
      'post_author',
      'added_by',
      'match_user_id',
      'match_created_by',
      'createdby',
      'uid',
    ];
    for (final k in keys) {
      final id = _asInt(m[k]);
      if (id != null && id > 0) return id;
    }
    for (final k in ['player', 'user', 'author', 'owner']) {
      final v = m[k];
      if (v is Map) {
        final nid = _asInt(v['id']);
        if (nid != null && nid > 0) return nid;
      }
    }
    return null;
  }

  // ---------- lifecycle ----------
  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200 &&
        !_loadingPage &&
        _hasMore) {
      _fetchPage();
    }
  }

  // ---------- init / session ----------
  Future<void> _init() async {
    await migrateRoleKeys();

    _token = await SessionManager.getToken();
    _currentPlayerId = await SessionManager.getPlayerId();

    if (_token == null || _token!.isEmpty) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    _isAdmin = await resolveIsAdminSafe();

    await _loadMatches();
  }

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

  // ---------- data ----------
  Future<void> _loadMatches() async {
    setState(() {
      _loading = true;
      _matches.clear();
      _skip = 0;
      _hasMore = true;
    });
    await _fetchPage();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchPage() async {
    if (_loadingPage || !_hasMore) return;
    setState(() => _loadingPage = true);

    try {
      List<Map<String, dynamic>> page;
      if (_isAdmin) {
        page = await MatchService.fetchAllMatchesForAdmin(
          limit: _limit,
          skip: _skip,
        );
        _usingUserMatches = false; // browsing all matches
      } else {
        page = await MatchService.fetchUserMatches(
          context: context,
          limit: _limit,
          skip: _skip,
        );
        _usingUserMatches = true; // API already scoped to token user
      }

      if (!mounted) return;
      setState(() {
        _matches.addAll(page);
        _skip += page.length; // advance by actual count
        _hasMore = page.length == _limit;
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
      if (mounted) setState(() => _loadingPage = false);
    }
  }

  Future<void> _deleteMatch(int matchId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Match'),
        content: const Text('Are you sure you want to delete this match?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
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
      await MatchService.deleteMatch(matchId);
      if (!mounted) return;
      setState(() =>
          _matches.removeWhere((m) => _asInt(m['match_id']) == matchId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Match deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  // ---------- CONSISTENT HEADER ----------
  PreferredSizeWidget _buildConsistentHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.canPop(context);
    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: Container(
        decoration: isDark
            ? const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius:
          BorderRadius.vertical(bottom: Radius.circular(20)),
        )
            : const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, Color(0xFF42A5F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius:
          BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: canPop
              ? IconButton(
            icon:
            const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.maybePop(context),
            tooltip: 'Back',
          )
              : null,
          title: const Text(
            'Manage Matches',
            style:
            TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  // ---------- UI bits (visual only) ----------
  Widget _actionIcon({
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.10),
              border: Border.all(color: color.withValues(alpha: 0.20)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }

  Color _chipBg(Color c) => c.withValues(alpha: 0.12);
  Color _chipBorder(Color c) => c.withValues(alpha: 0.30);

  Widget _miniChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _chipBg(color),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _chipBorder(color)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12.5)),
        ],
      ),
    );
  }

  Widget _statusChips(Map<String, dynamic> m) {
    final tossDone = m['toss_win'] != null && m['toss_win_chooses'] != null;
    final venue = (m['match_venue'] ?? '').toString();
    final date = (m['match_date'] ?? '').toString();
    final time = (m['match_time'] ?? '').toString();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (venue.isNotEmpty)
          _miniChip(icon: Icons.place, label: 'Venue', color: Colors.indigo),
        if (date.isNotEmpty)
          _miniChip(icon: Icons.calendar_today, label: date, color: Colors.teal),
        if (time.isNotEmpty)
          _miniChip(icon: Icons.schedule, label: time, color: Colors.deepPurple),
        _miniChip(
          icon: tossDone ? Icons.verified : Icons.sports,
          label: tossDone ? 'Toss decided' : 'Toss pending',
          color: tossDone ? Colors.green : Colors.orange,
        ),
      ],
    );
  }

  Widget _buildCard(Map<String, dynamic> match) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final matchId = _asInt(match['match_id']);
    final teamAId = _asInt(match['team_one']);
    final teamBId = _asInt(match['team_two']);

    final ownerId = _resolveOwnerId(match);
    final isOwner =
        _currentPlayerId != null && ownerId != null && _currentPlayerId == ownerId;

    // capabilities (visual show/hide only; logic unchanged)
    bool canEdit, canDelete, canScore;
    if (_usingUserMatches) {
      canEdit = true;
      canDelete = true;
      canScore = true;
    } else {
      canEdit = _isAdmin || isOwner;
      canDelete = _isAdmin || isOwner;
      canScore = _isAdmin || isOwner;
    }

    if (kDebugMode) {
      debugPrint(
          '[GetMatchScreen] ownerId=$ownerId currentPlayerId=$_currentPlayerId '
              'isAdmin=$_isAdmin usingUserMatches=$_usingUserMatches matchId=$matchId '
              '=> canEdit=$canEdit canDelete=$canDelete canScore=$canScore');
    }

    final title = (match['match_name'] ?? 'Match').toString();
    final teamA = (match['team_one_name'] ?? 'Team A').toString();
    final teamB = (match['team_two_name'] ?? 'Team B').toString();

    String initials(String s) {
      final parts = s.trim().split(RegExp(r'\s+'));
      if (parts.isEmpty) return '?';
      if (parts.length == 1) {
        return parts.first.characters.first.toUpperCase();
      }
      return (parts.first.characters.first + parts.last.characters.first)
          .toUpperCase();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: isDark ? 1 : 4,
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        surfaceTintColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        shadowColor: isDark ? Colors.black : Colors.black12,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border(
              left: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.85),
                width: 4,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '#${matchId ?? '-'}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white70 : AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Teams row
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor:
                      (isDark ? Colors.white12 : Colors.blue.shade50),
                      child: Text(
                        initials(teamA),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.blue.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        teamA,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'vs',
                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        teamB,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    CircleAvatar(
                      radius: 18,
                      backgroundColor:
                      (isDark ? Colors.white12 : Colors.orange.shade50),
                      child: Text(
                        initials(teamB),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Status chips
                _statusChips(match),

                const SizedBox(height: 12),

                // Actions
                Row(
                  children: [
                    if (canEdit)
                      _actionIcon(
                        icon: Icons.edit,
                        color: AppColors.primary,
                        tooltip: 'Edit',
                        onTap: matchId == null
                            ? null
                            : () => Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                UpdateMatchScreen(matchId: matchId),
                          ),
                        ).then((updated) {
                          if (updated == true) _loadMatches();
                        }),
                      ),
                    if (canDelete)
                      _actionIcon(
                        icon: Icons.delete,
                        color: Colors.red,
                        tooltip: 'Delete',
                        onTap: matchId == null ? null : () => _deleteMatch(matchId),
                      ),
                    if (canScore)
                      _actionIcon(
                        icon: Icons.sports_cricket,
                        color: Colors.green,
                        tooltip: 'Scoring',
                        onTap: () async {
                          if (matchId != null && teamAId != null && teamBId != null) {
                            final tossWinner = match['toss_win'];
                            final tossDecision = match['toss_win_chooses'];

                            if (tossWinner != null && tossDecision != null) {
                              if (_isNavigatingToScoreScreen) return;
                              setState(() => _isNavigatingToScoreScreen = true);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AddScoreScreen(matchId: matchId, token: _token!),
                                ),
                              ).then((_) {
                                if (mounted) {
                                  setState(() => _isNavigatingToScoreScreen = false);
                                }
                              });
                            } else {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (_) => TossDialog(
                                  matchId: matchId,
                                  teamAId: teamAId,
                                  teamBId: teamBId,
                                  token: _token!,
                                  teamAName: teamA,
                                  teamBName: teamB,
                                ),
                              );
                              if (ok == true) {
                                await _loadMatches();
                                final refreshed = _matches.firstWhere(
                                      (m) => _asInt(m['match_id']) == matchId,
                                  orElse: () => match,
                                );
                                if (refreshed['toss_win'] != null &&
                                    refreshed['toss_win_chooses'] != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AddScoreScreen(
                                          matchId: matchId, token: _token!),
                                    ),
                                  );
                                }
                              }
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Missing team data for scoring screen.'),
                              ),
                            );
                          }
                        },
                      ),
                    if (canEdit || canScore)
                      _actionIcon(
                        icon: Icons.qr_code_2,
                        color: Colors.blueGrey,
                        tooltip: 'Grant Access',
                        onTap: matchId == null
                            ? null
                            : () async {
                          final token = _token;
                          if (token == null || token.isEmpty) {
                            if (!mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LoginScreen()),
                            );
                            return;
                          }

                          final granted = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GrantPermissionScreen(
                                apiToken: token,
                                initialType: 'matches',
                                initialTypeId: matchId,
                                initialTitle: title,
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


                 /*   _actionIcon(
                      icon: Icons.live_tv_rounded,
                      color: Colors.redAccent,
                      tooltip: 'YouTube Live Stream',
                      onTap: matchId == null
                          ? null
                          : () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => YouTubeStreamScreen(matchId: matchId),
                          ),
                        );
                      },
                    ),

                  */


                    const Spacer(),
                    Icon(Icons.chevron_right,
                        color: isDark ? Colors.white54 : Colors.black38),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- empty state ----------
  Widget _emptyState(bool isDark) {
    return ListView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.28),
        Icon(Icons.sports_cricket,
            size: 64, color: isDark ? Colors.white24 : Colors.black26),
        const SizedBox(height: 12),
        Text(
          'No matches yet',
          textAlign: TextAlign.center,
          style:
          TextStyle(fontSize: 16, color: isDark ? Colors.white70 : Colors.black54),
        ),
        const SizedBox(height: 6),
        Text(
          'Tap “Add Match” to create one.',
          textAlign: TextAlign.center,
          style: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
        ),
      ],
    );
  }

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF111111) : const Color(0xFFF5F7FA),
      appBar: _buildConsistentHeader(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadMatches,
        child: _matches.isEmpty
            ? _emptyState(isDark)
            : ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: _matches.length + 1,
          itemBuilder: (context, i) {
            if (i == _matches.length) {
              if (!_hasMore) {
                return const SizedBox(height: 72);
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: _loadingPage
                      ? const CircularProgressIndicator()
                      : const SizedBox.shrink(),
                ),
              );
            }
            return _buildCard(_matches[i]);
          },
        ),
      ),
      floatingActionButton: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: FloatingActionButton.extended(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 4,
            icon: const Icon(Icons.add),
            label: const Text('Add Match',
                style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () async {
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const MatchUIScreen()),
              ) ??
                  false;

              if (created) {
                await _loadMatches();
                if (!mounted) return;
                _scroll.animateTo(
                  0,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Fixture saved!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }
}