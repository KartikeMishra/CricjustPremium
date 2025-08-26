// lib/screen/team_detail_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Screen/player_info.dart';
import '../theme/color.dart';                 // AppColors.primary
import '../service/session_manager.dart';     // SessionManager.getToken()

class TeamDetailScreen extends StatefulWidget {
  final int teamId;
  const TeamDetailScreen({super.key, required this.teamId});

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  bool _loading = true;
  bool _loadingPlayers = false;
  String? _error;
  _TeamDetail? _team;

  /// id -> player display name
  final Map<int, String> _playerNames = {};

  /// process-level memo (persists while app alive)
  static final Map<int, String> _nameMemo = {};
  static const _nameCacheTtl = Duration(days: 3);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await SessionManager.getToken();
      if (!mounted) return;

      if (token == null || token.isEmpty) {
        setState(() {
          _error = 'You are not logged in.';
          _loading = false;
        });
        return;
      }

      final url = Uri.parse(
        'https://cricjust.in/wp-json/custom-api-for-cricket/get-single-team'
            '?api_logged_in_token=$token&team_id=${widget.teamId}',
      );

      final res = await http.get(url).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }

      final json = jsonDecode(res.body);
      final list = (json['data'] as List?) ?? const [];
      if (json['status'] != 1 || list.isEmpty) {
        throw Exception('No team found');
      }

      final t = _TeamDetail.fromJson(list.first);

      setState(() {
        _team = t;
        _loading = false;
      });

      // Resolve player names in background (non-blocking)
      _playerNames.clear();
      Future.microtask(() => _loadPlayerNames(t.playerIds));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /* ====================== Player Name Resolution ====================== */

  Future<void> _loadPlayerNames(List<int> ids) async {
    if (!mounted || ids.isEmpty) return;

    setState(() => _loadingPlayers = true);
    try {
      // warm from cache
      await _preloadNamesFromCache(ids);
      final pendingAfterCache = ids.where((id) => !_playerNames.containsKey(id)).toList();
      if (pendingAfterCache.isEmpty) return;

      // bulk by team
      try {
        final bulkUri = Uri.parse(
          'https://cricjust.in/wp-json/custom-api-for-cricket/get-players'
              '?team_id=${_team!.teamId}&limit=200&skip=0',
        );
        final res = await http.get(bulkUri).timeout(const Duration(seconds: 12));
        if (res.statusCode == 200) {
          final j = jsonDecode(res.body);
          final List data = (j['data'] as List?) ?? const [];
          if (data.isNotEmpty) {
            final Map<int, String> newly = {};
            for (final row in data) {
              final m = (row as Map<String, dynamic>);
              final id = _toInt(m['ID'] ?? m['id'] ?? m['player_id']);
              if (id > 0 && ids.contains(id)) {
                newly[id] = _titleCase(_extractPlayerName(m, id));
              }
            }
            if (newly.isNotEmpty) {
              _playerNames.addAll(newly);
              if (mounted) setState(() {});
              await _saveNamesToCache(newly);
            }
          }
        }
      } catch (_) {}

      // fallback per id
      final unresolved = ids.where((id) => !_playerNames.containsKey(id)).toList();
      if (unresolved.isEmpty) return;

      Future<void> fetchOne(int id) async {
        if (_playerNames.containsKey(id)) return;
        try {
          final uri = Uri.parse(
            'https://cricjust.in/wp-json/custom-api-for-cricket/get-player-public-info?player_id=$id',
          );
          final r = await http.get(uri).timeout(const Duration(seconds: 8));
          if (r.statusCode == 200) {
            final j = jsonDecode(r.body);
            dynamic d = j['player_info'];
            d ??= (j['data'] is List && j['data'].isNotEmpty) ? j['data'][0] : j['data'];
            final name = _titleCase(_extractPlayerName(d, id));
            _playerNames[id] = name;
          } else {
            _playerNames[id] = 'Player $id';
          }
        } catch (_) {
          _playerNames[id] = 'Player $id';
        }
      }

      for (final chunk in _chunks(unresolved, 8)) {
        await Future.wait(chunk.map(fetchOne));
        if (mounted) setState(() {});
      }

      await _saveNamesToCache({
        for (final id in ids.where((i) => _playerNames.containsKey(i))) id: _playerNames[id]!,
      });
    } finally {
      if (mounted) setState(() => _loadingPlayers = false);
    }
  }

  Future<void> _preloadNamesFromCache(List<int> ids) async {
    final sp = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    bool any = false;

    for (final id in ids) {
      if (_playerNames.containsKey(id)) continue;

      final memo = _nameMemo[id];
      if (memo != null) {
        _playerNames[id] = memo;
        any = true;
        continue;
      }

      final name = sp.getString('player_name:$id');
      final ts = sp.getInt('player_name_ts:$id') ?? 0;
      if (name != null && (now - ts) < _nameCacheTtl.inMilliseconds) {
        _playerNames[id] = name;
        _nameMemo[id] = name;
        any = true;
      }
    }
    if (any && mounted) setState(() {});
  }

  Future<void> _saveNamesToCache(Map<int, String> newly) async {
    if (newly.isEmpty) return;
    newly.forEach((k, v) => _nameMemo[k] = v);
    final sp = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final e in newly.entries) {
      await sp.setString('player_name:${e.key}', e.value);
      await sp.setInt('player_name_ts:${e.key}', now);
    }
  }

  /* ============================ UI / Build ============================ */

  Future<void> _onRefresh() async {
    _playerNames.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: PreferredSize(
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
            title: const Text(
              'Team Details',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(message: _error!, onRetry: _load)
          : RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _HeaderCard(team: _team!),
            const SizedBox(height: 16),
            _AboutCard(team: _team!),
            const SizedBox(height: 12),
            _ChipsBlock(
              team: _team!,
              onCopyTeamId: () async {
                await Clipboard.setData(ClipboardData(text: _team!.teamId.toString()));
                if (!mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(content: Text('Team ID copied')),
                  );
              },
            ),
            const SizedBox(height: 8),
            _PlayersSection(
              ids: _team!.playerIds,
              names: _playerNames,
              loading: _loadingPlayers,
              onTapPlayer: (id) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlayerPublicInfoTab(playerId: id),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/* ============================= UI WIDGETS ============================= */
class _HeaderCard extends StatelessWidget {
  final _TeamDetail team;
  const _HeaderCard({required this.team});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final badge = w * 0.22;
    final badgeSize = badge.clamp(68.0, 96.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          Center(child: _LogoBadge(imageUrl: team.teamLogo, size: badgeSize)),
          const SizedBox(height: 16),
          Card(
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                children: [
                  Text(
                    team.teamName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 14,
                    runSpacing: 4,
                    children: [
                      _MetaItem(
                        icon: Icons.calendar_today_outlined,
                        text: DateFormat('dd MMM yyyy • hh:mm a').format(team.created),
                      ),
                      _MetaItem(
                        icon: Icons.people_outline,
                        text: '${team.playerIds.length} players',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _LogoBadge extends StatelessWidget {
  final String? imageUrl;
  final double size;
  const _LogoBadge({required this.imageUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    final ring = Theme.of(context).scaffoldBackgroundColor;

    return Card(
      elevation: 8,
      shape: const CircleBorder(),
      margin: EdgeInsets.zero,
      color: ring,
      child: Padding(
        padding: const EdgeInsets.all(4), // ring thickness
        child: CircleAvatar(
          radius: size / 2,
          backgroundColor: Colors.white,
          foregroundImage:
          (imageUrl != null && imageUrl!.isNotEmpty) ? NetworkImage(imageUrl!) : null,
          child: (imageUrl == null || imageUrl!.isEmpty)
              ? const Icon(Icons.shield_outlined, size: 36)
              : null,
        ),
      ),
    );
  }
}


class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.75);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.9)),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}

class _AboutCard extends StatelessWidget {
  final _TeamDetail team;
  const _AboutCard({required this.team});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Theme.of(context).dividerColor)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _SectionTitle(icon: Icons.info_outline, label: 'About Team'),
            const SizedBox(height: 8),
            Text(
              (team.teamDescription?.trim().isNotEmpty ?? false)
                  ? team.teamDescription!.trim()
                  : 'KNIGHT SCORCHERS',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ]),
        ),
      ),
    );
  }
}


class _ChipsBlock extends StatelessWidget {
  final _TeamDetail team;
  final VoidCallback onCopyTeamId;
  const _ChipsBlock({required this.team, required this.onCopyTeamId});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _Pill(
              onLongPress: onCopyTeamId,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.badge_outlined, size: 18),
                const SizedBox(width: 8),
                const Text('Team ID', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                Text('${team.teamId}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ),
            const SizedBox(width: 10),
            Chip(
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
              avatar: Icon(
                Icons.circle,
                size: 12,
                color: team.status == 1 ? Colors.green : Colors.redAccent,
              ),
              label: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('Status', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                Text(
                  team.status == 1 ? 'Active' : 'Inactive',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ]),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).dividerColor),
              ),
              backgroundColor: Theme.of(context).cardColor,
            ),
            // add more chips here with: const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}


// a pill without Container
class _Pill extends StatelessWidget {
  final Widget child;
  final VoidCallback? onLongPress;
  const _Pill({required this.child, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      color: Theme.of(context).cardColor,
      shape: StadiumBorder(side: BorderSide(color: Theme.of(context).dividerColor)),
      child: InkWell(
        onLongPress: onLongPress,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: child,
        ),
      ),
    );
  }
}

class _PlayersSection extends StatelessWidget {
  final List<int> ids;
  final Map<int, String> names;
  final bool loading;
  final void Function(int id) onTapPlayer;
  const _PlayersSection({required this.ids, required this.names, required this.loading, required this.onTapPlayer});

  @override
  Widget build(BuildContext context) {
    final sorted = [...ids]..sort((a, b) {
      final na = names[a], nb = names[b];
      if (na == null && nb == null) return a.compareTo(b);
      if (na == null) return 1;
      if (nb == null) return -1;
      return na.toLowerCase().compareTo(nb.toLowerCase());
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.people_outline,
            label: 'Players (${ids.length})',
            trailing: loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : null,
          ),
          const SizedBox(height: 8),
          if (ids.isEmpty)
            const Text('No players added yet.')
          else
            Wrap(
              spacing: 10, runSpacing: 10,
              children: sorted.map((id) {
                final label = names[id];
                final busy = loading && label == null;
                return InputChip(
                  onPressed: () => onTapPlayer(id),
                  avatar: const Icon(Icons.person_outline, size: 16),
                  label: busy
                      ? const _PulseDot()
                      : Text(label ?? 'Player $id', style: const TextStyle(fontWeight: FontWeight.w600)),
                  shape: StadiumBorder(side: BorderSide(color: Theme.of(context).dividerColor)),
                  backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}


class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: const SizedBox(
        width: 14,
        height: 14,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xFFB0BEC5),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  const _SectionTitle({required this.icon, required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 42),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

/* ============================== HELPERS ============================== */

String _extractPlayerName(dynamic d, int id) {
  if (d is Map<String, dynamic>) {
    final n = d['first_name'] ??
        d['display_name'] ??
        d['full_name'] ??
        d['player_name'] ??
        d['user_login'] ??
        d['name'];
    if (n != null && n.toString().trim().isNotEmpty) {
      return n.toString().trim();
    }
  }
  return 'Player $id';
}

String _titleCase(String s) {
  if (s.isEmpty) return s;
  final parts = s.toLowerCase().split(RegExp(r'\s+'));
  return parts.map((p) => p.isEmpty ? p : (p[0].toUpperCase() + p.substring(1))).join(' ');
}

int _toInt(dynamic v) => (v is int) ? v : int.tryParse(v?.toString() ?? '0') ?? 0;

Iterable<List<T>> _chunks<T>(List<T> list, int size) sync* {
  for (var i = 0; i < list.length; i += size) {
    yield list.sublist(i, min(i + size, list.length));
  }
}

/* =============================== MODEL =============================== */

class _TeamDetail {
  final int teamId;
  final int tournamentId;
  final int fairplay;
  final int groupId;
  final String teamName;
  final String? teamDescription;
  final String? teamOrigin;
  final String? teamLogo;
  final int status;
  final DateTime created;
  final int userId;
  final String playersCsv;

  _TeamDetail({
    required this.teamId,
    required this.tournamentId,
    required this.fairplay,
    required this.groupId,
    required this.teamName,
    required this.teamDescription,
    required this.teamOrigin,
    required this.teamLogo,
    required this.status,
    required this.created,
    required this.userId,
    required this.playersCsv,
  });

  factory _TeamDetail.fromJson(Map<String, dynamic> j) {
    DateTime created;
    try {
      created = DateFormat('yyyy-MM-dd HH:mm:ss').parse(j['created']);
    } catch (_) {
      created = DateTime.now();
    }

    return _TeamDetail(
      teamId: _toInt(j['team_id']),
      tournamentId: _toInt(j['tournament_id']),
      fairplay: _toInt(j['fairplay']),
      groupId: _toInt(j['group_id']),
      teamName: j['team_name'] ?? 'Team',
      teamDescription: j['team_description'],
      teamOrigin: j['team_origin']?.toString(),
      teamLogo: j['team_logo']?.toString(),
      status: _toInt(j['status']),
      created: created,
      userId: _toInt(j['user_id']),
      playersCsv: j['team_players']?.toString() ?? '',
    );
  }

  List<int> get playerIds {
    if (playersCsv.trim().isEmpty) return [];
    return playersCsv
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((e) => int.tryParse(e) ?? -1)
        .where((e) => e > 0)
        .toList();
  }
}
