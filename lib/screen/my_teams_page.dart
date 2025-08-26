// lib/screen/my_teams_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../model/player_public_info_model.dart' as model;
import '../service/player_public_info_service.dart' as svc;
import '../service/session_manager.dart';
import 'team_detail_screen.dart';

class MyTeamsPage extends StatefulWidget {
  final int playerId;
  const MyTeamsPage({super.key, required this.playerId});

  @override
  State<MyTeamsPage> createState() => _MyTeamsPageState();
}

class _MyTeamsPageState extends State<MyTeamsPage> {
  late Future<model.PlayerPersonalInfo> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = svc.PlayerPersonalInfoService.fetch(widget.playerId);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = svc.PlayerPersonalInfoService.fetch(widget.playerId);
    });
    await _future;
  }

  Future<void> _openTeamByName(String name) async {
    final token = await SessionManager.getToken();
    if (token == null || token.isEmpty) {
      _showSnack('You are not logged in.');
      return;
    }

    _showLoading();
    try {
      final uri = Uri.parse(
        'https://cricjust.in/wp-json/custom-api-for-cricket/get-teams'
            '?api_logged_in_token=$token'
            '&limit=10&skip=0&tournament_id=0&search=${Uri.encodeQueryComponent(name)}',
      );
      final res = await http.get(uri);
      Navigator.of(context, rootNavigator: true).pop(); // close loading

      if (res.statusCode != 200) {
        _showSnack('Failed to search teams (${res.statusCode}).');
        return;
      }
      final json = jsonDecode(res.body);
      final List data = (json['data'] as List?) ?? [];

      if (data.isEmpty) {
        _showSnack('No team found for “$name”.');
        return;
      }

      if (data.length == 1) {
        final m = data.first as Map<String, dynamic>;
        final int teamId = _toInt(m['team_id']);
        _goToTeam(teamId);
        return;
      }

      final picked = await showModalBottomSheet<_TeamMini>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).cardColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (ctx) {
          final items = data.map((e) {
            final m = e as Map<String, dynamic>;
            return _TeamMini(
              id: _toInt(m['team_id']),
              name: (m['team_name'] ?? '').toString(),
              logo: (m['team_logo'] ?? '').toString(),
            );
          }).toList();
          return _PickTeamSheet(candidates: items, keyword: name);
        },
      );

      if (picked != null) _goToTeam(picked.id);
    } catch (e) {
      Navigator.of(context, rootNavigator: true).maybePop();
      _showSnack('Error: ${e.toString()}');
    }
  }

  void _goToTeam(int teamId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TeamDetailScreen(teamId: teamId)),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
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
              colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          child: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text(
              'Manage Teams',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
      ),
      body: FutureBuilder<model.PlayerPersonalInfo>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const _LoadingView();
          }
          if (snap.hasError) {
            return _ErrorBox(
              message: 'Could not load teams.',
              details: snap.error.toString(),
              onRetry: _refresh,
            );
          }

          final p = snap.data!;
          final teamNames = (p.teams)
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toSet()
              .toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

          final filter = _query.trim().toLowerCase();
          final filtered = filter.isEmpty
              ? teamNames
              : teamNames.where((t) => t.toLowerCase().contains(filter)).toList();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
              children: [
                // Search bar (pill)
                _SearchField(
                  hint: 'Search teams...',
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 16),

                if (teamNames.isEmpty)
                  const _EmptyCard(text: 'No teams found for this player.')
                else if (filtered.isEmpty)
                  _EmptySearch(query: _query)
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final name = filtered[i];
                      return _TeamListCard(
                        name: name,
                        subtitle: _subtitleFromName(name),
                        onTap: () => _openTeamByName(name),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/* ------------------------------ WIDGETS ------------------------------ */

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('Loading teams...'),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const _SearchField({required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _TeamListCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final VoidCallback onTap;
  const _TeamListCard({
    required this.name,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final initials = _initialsFromName(name);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.28)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: primary.withValues(alpha: 0.12),
              child: Text(
                initials,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: primary,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      letterSpacing: 0.6,
                      fontSize: 12,
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initialsFromName(String s) {
    final parts =
    s.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _EmptyCard extends StatelessWidget {
  final String text;
  const _EmptyCard({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _glassBoxDecoration(context),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  final String query;
  const _EmptySearch({required this.query});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _glassBoxDecoration(context),
      padding: const EdgeInsets.all(20),
      child: const Row(
        children: [
          Icon(Icons.search_off, color: Colors.orange),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'No results found. Try a different name.',
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------------ PICKER SHEET ------------------------------ */

class _TeamMini {
  final int id;
  final String name;
  final String logo;
  _TeamMini({required this.id, required this.name, required this.logo});
}

class _PickTeamSheet extends StatelessWidget {
  final List<_TeamMini> candidates;
  final String keyword;
  const _PickTeamSheet({required this.candidates, required this.keyword});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.groups_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Select “$keyword”',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: candidates.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final t = candidates[i];
                  return ListTile(
                    onTap: () => Navigator.pop(context, t),
                    leading: CircleAvatar(
                      backgroundColor:
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      backgroundImage:
                      (t.logo.isNotEmpty) ? NetworkImage(t.logo) : null,
                      child: t.logo.isEmpty
                          ? Text(
                        _initialsFromName(t.name),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                          : null,
                    ),
                    title:
                    Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.chevron_right),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initialsFromName(String s) {
    final parts =
    s.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

/* ------------------------------ HELPERS ------------------------------ */

class _ErrorBox extends StatelessWidget {
  final String message;
  final String details;
  final Future<void> Function() onRetry;
  const _ErrorBox({
    required this.message,
    required this.details,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black12,
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 10),
            Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(details,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ]),
        ),
      ),
    );
  }
}

BoxDecoration _glassBoxDecoration(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: isDark ? const Color(0xFF1E1E1E) : Colors.white.withValues(alpha: 0.96),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
    boxShadow: [
      BoxShadow(
        color:
        isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.06),
        blurRadius: 16,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

int _toInt(dynamic v) {
  if (v is int) return v;
  return int.tryParse(v?.toString() ?? '0') ?? 0;
}

/// Make a neat small uppercase subtitle like in your screenshot.
/// Removes common suffix words (cricket/club/team/cc), then uppercases.
/// Make a neat small uppercase subtitle like in your screenshot.
/// Removes common suffix words (cricket/club/team/cc), then uppercases.
String _subtitleFromName(String name) {
  // handle CC / C.C / c.c as well
  final pattern = RegExp(r'\b(cricket|club|team|c\.?c\.?)\b', caseSensitive: false);
  final cleaned = name
      .replaceAll(pattern, '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return (cleaned.isEmpty ? name : cleaned).toUpperCase();
}

