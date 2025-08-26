// lib/screen/my_stats_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ⬅️ to read player_id after login

import '../model/player_public_info_model.dart' as model;
import '../service/player_public_info_service.dart' as svc;
import 'login_screen.dart'; // ⬅️ for the login prompt navigation

class MyStatsPage extends StatefulWidget {
  final int playerId;
  const MyStatsPage({super.key, required this.playerId});

  @override
  State<MyStatsPage> createState() => _MyStatsPageState();
}

class _MyStatsPageState extends State<MyStatsPage> {
  late Future<model.PlayerPersonalInfo> _future;
  late int _activePlayerId;

  @override
  void initState() {
    super.initState();
    _activePlayerId = widget.playerId;
    _future = _buildFuture();
  }

  Future<model.PlayerPersonalInfo> _buildFuture() {
    // If no player yet, surface a clear "missing player_id" error for the UI to catch
    if (_activePlayerId <= 0) {
      return Future.error('missing player_id');
    }
    return svc.PlayerPersonalInfoService.fetch(_activePlayerId);
  }

  Future<void> _refresh() async {
    // If we didn't have a player id before, try to pull it from SharedPreferences after login
    if (_activePlayerId <= 0) {
      final prefs = await SharedPreferences.getInstance();
      final newId = prefs.getInt('player_id') ?? 0;
      if (newId > 0) {
        _activePlayerId = newId;
      }
    }
    setState(() {
      _future = _buildFuture();
    });
    await _future;
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
              'My Stats',
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
            final err = snap.error.toString().toLowerCase();
            final needLogin = err.contains('missing player_id') ||
                err.contains('not logged in') ||
                err.contains('unauthorized') ||
                err.contains('token');
            if (needLogin) {
              return _LoginPrompt(onLoggedIn: _refresh);
            }
            return _ErrorBox(
              message: 'Could not load stats.',
              details: snap.error.toString(),
              onRetry: _refresh,
            );
          }

          final p = snap.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _HeaderCard(p: p),
                const SizedBox(height: 16),

                if (p.batting != null || p.bowling != null) _HighlightsRow(p: p),
                if (p.batting != null || p.bowling != null) const SizedBox(height: 16),

                if (p.batting != null)
                  _StatsCard(
                    title: 'Batting Career',
                    icon: Icons.sports_cricket,
                    colorHint: Colors.orange,
                    rows: [
                      _StatRow(label: 'Matches', value: p.batting!.totalMatch, icon: Icons.event_available),
                      _StatRow(label: 'Innings', value: p.batting!.totalInnings, icon: Icons.list_alt),
                      _StatRow(label: 'Runs', value: p.batting!.totalRuns, icon: Icons.trending_up, highlight: true),
                      _StatRow(label: 'Average', value: p.batting!.average, icon: Icons.functions),
                      _StatRow(label: 'Strike Rate', value: p.batting!.strikeRate, icon: Icons.speed),
                      _StatRow(label: '4s', value: p.batting!.totalFours, icon: Icons.blur_linear),
                      _StatRow(label: '6s', value: p.batting!.totalSixes, icon: Icons.bolt),
                      _StatRow(label: '50s', value: p.batting!.total50, icon: Icons.star_half),
                      _StatRow(label: '100s', value: p.batting!.total100, icon: Icons.stars),
                      _StatRow(label: 'Best Score', value: p.batting!.bestScore, icon: Icons.emoji_events),
                    ],
                  ),

                if (p.batting != null && p.bowling != null) const SizedBox(height: 16),

                if (p.bowling != null)
                  _StatsCard(
                    title: 'Bowling Career',
                    icon: Icons.sports_baseball,
                    colorHint: Colors.teal,
                    rows: [
                      _StatRow(label: 'Matches', value: p.bowling!.totalMatch, icon: Icons.event_available),
                      _StatRow(label: 'Innings', value: p.bowling!.totalInnings, icon: Icons.list_alt),
                      _StatRow(label: 'Wickets', value: p.bowling!.totalWickets, icon: Icons.clean_hands, highlight: true),
                      _StatRow(label: 'Average', value: p.bowling!.average, icon: Icons.functions),
                      _StatRow(label: 'Economy', value: p.bowling!.economy, icon: Icons.speed),
                      _StatRow(label: 'Best', value: p.bowling!.best, icon: Icons.emoji_events),
                    ],
                  ),

                if (p.batting == null && p.bowling == null) ...[
                  const SizedBox(height: 24),
                  const _EmptyCard(text: 'No career stats yet. Play matches to build your record!'),
                ]
              ],
            ),
          );
        },
      ),
    );
  }
}

/* ============================== WIDGETS ============================== */

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
          Text('Loading stats...'),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final model.PlayerPersonalInfo p;
  const _HeaderCard({required this.p});

  @override
  Widget build(BuildContext context) {
    final roleLine = [
      if (p.playerType?.isNotEmpty ?? false) p.playerType!,
      if (p.batterType?.isNotEmpty ?? false) p.batterType!,
      if (p.bowlerType?.isNotEmpty ?? false) p.bowlerType!,
    ].join(' • ');

    return Container(
      decoration: _glassBoxDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 36,
              backgroundImage: p.imageUrl != null ? NetworkImage(p.imageUrl!) : null,
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              child: p.imageUrl == null
                  ? Text(
                (p.firstName.isNotEmpty ? p.firstName[0] : '?').toUpperCase(),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              )
                  : null,
            ),
            const SizedBox(width: 14),

            // Name + roles
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.firstName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  if (roleLine.isNotEmpty)
                    Text(
                      roleLine,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
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
}

class _HighlightsRow extends StatelessWidget {
  final model.PlayerPersonalInfo p;
  const _HighlightsRow({required this.p});

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[];

    if (p.batting != null) {
      tiles.add(_HighlightPill(title: 'Runs', value: p.batting!.totalRuns.toString(), icon: Icons.trending_up));
      tiles.add(_HighlightPill(title: 'Strike Rate', value: p.batting!.strikeRate.toString(), icon: Icons.speed));
    }
    if (p.bowling != null) {
      tiles.add(_HighlightPill(title: 'Wickets', value: p.bowling!.totalWickets.toString(), icon: Icons.clean_hands));
      tiles.add(_HighlightPill(title: 'Economy', value: p.bowling!.economy.toString(), icon: Icons.speed));
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.4,
      children: tiles,
    );
  }
}

class _HighlightPill extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const _HighlightPill({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ============================== STATS ============================== */

class _StatRow {
  final String label;
  final dynamic value;
  final IconData? icon;
  final bool highlight;
  const _StatRow({
    required this.label,
    required this.value,
    this.icon,
    this.highlight = false,
  });
}

class _StatsCard extends StatelessWidget {
  final String title;
  final List<_StatRow> rows;
  final IconData icon;
  final Color colorHint;
  const _StatsCard({
    required this.title,
    required this.rows,
    required this.icon,
    required this.colorHint,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tiles = List<Widget>.generate(rows.length, (i) {
      final r = rows[i];
      return Column(
        children: [
          _StatRowTile(row: r),
          if (i != rows.length - 1)
            Divider(
              height: 10,
              thickness: 0.6,
              color: isDark ? Colors.white12 : Colors.black12,
            ),
        ],
      );
    });

    return Container(
      decoration: _glassBoxDecoration(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      colorHint.withValues(alpha: 0.85),
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
                    ],
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            const SizedBox(height: 12),
            ...tiles,
          ],
        ),
      ),
    );
  }
}

class _StatRowTile extends StatelessWidget {
  final _StatRow row;
  const _StatRowTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final isHighlight = row.highlight;
    final valueStr = row.value.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (row.icon != null) ...[
            Icon(row.icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
          ],
          Expanded(child: Text(row.label)),
          if (isHighlight)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                valueStr,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            )
          else
            Text(valueStr, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/* ============================== MISC ============================== */

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
        color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.06),
        blurRadius: 16,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

/* ============================== LOGIN PROMPT ============================== */

class _LoginPrompt extends StatelessWidget {
  final Future<void> Function() onLoggedIn;
  const _LoginPrompt({required this.onLoggedIn});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 56, color: Colors.orange),
            const SizedBox(height: 10),
            const Text(
              'Please log in to view your stts',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('Login'),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
                await onLoggedIn(); // will pick up player_id and refresh
              },
            ),
          ],
        ),
      ),
    );
  }
}
