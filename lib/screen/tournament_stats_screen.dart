// lib/screen/tournament_stats_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import '../model/tournament_stats_model.dart';
import '../service/tournament_service.dart';
import '../theme/color.dart';

class TournamentStatsScreen extends StatefulWidget {
  final int tournamentId;
  const TournamentStatsScreen({super.key, required this.tournamentId});

  @override
  State<TournamentStatsScreen> createState() => _TournamentStatsScreenState();
}

class _TournamentStatsScreenState extends State<TournamentStatsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _loading = true;
  String? _error; // kept for telemetry but we won’t show a scary error screen

  SummaryStats? summary;
  List<RunStats> mostRuns = const [];
  List<WicketStats> mostWickets = const [];
  List<SixStats> mostSixes = const [];
  List<FourStats> mostFours = const [];
  List<MVP> mvps = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await TournamentService.fetchTournamentStats(widget.tournamentId);

      // Expect the service to normalize results. If it throws (e.g., API
      // gives []), we’ll fall into catch and show empty states instead.
      setState(() {
        summary      = r['summary'];
        mostRuns     = r['mostRuns'] ?? const [];
        mostWickets  = r['mostWickets'] ?? const [];
        mostSixes    = r['mostSixes'] ?? const [];
        mostFours    = r['mostFours'] ?? const [];
        mvps         = r['mvp'] ?? const [];
        _loading     = false;
      });
    } catch (e) {
      // Treat parsing/shape issues as "no data" instead of crashing the UI.
      setState(() {
        _error   = e.toString();
        summary  = null;
        mostRuns = const [];
        mostWickets = const [];
        mostSixes = const [];
        mostFours = const [];
        mvps = const [];
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ---------------- UI helpers ----------------

  Widget _shimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      itemCount: 6,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          height: 64,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _emptyState(String msg, {IconData icon = Icons.auto_graph_outlined}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: isDark ? Colors.white30 : Colors.black26),
            const SizedBox(height: 10),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 14.5,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                'Showing empty state.',
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tile(
      String? img,
      String name,
      String subtitle, {
        String? trailing,
        VoidCallback? onTap,
      }) {
    final hasImage = (img ?? '').isNotEmpty;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          radius: 24,
          backgroundImage: hasImage
              ? NetworkImage(img!)
              : const AssetImage('lib/asset/images/Random_Image.png')
          as ImageProvider,
        ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: trailing == null
            ? null
            : Text(
          trailing,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.1);
  }

  Widget _animatedSummaryCard(
      String title,
      IconData icon,
      Color color,
      String value,
      ) {
    final endVal = int.tryParse(value) ?? 0;
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: endVal),
      duration: const Duration(milliseconds: 700),
      builder: (_, val, __) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withValues(alpha: 0.14),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text(
                      '$val',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    ).animate().fadeIn(duration: 250.ms).slideY(begin: .1);
  }

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: isDark
              ? BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(12)),
          )
              : BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(12)),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'Summary'),
              Tab(text: 'Most Runs'),
              Tab(text: 'Most Wickets'),
              Tab(text: 'Most Sixes'),
              Tab(text: 'Most Fours'),
              Tab(text: 'MVPs'),
            ],
          ),
        ),

        Expanded(
          child: _loading
              ? _shimmerList()
              : TabBarView(
            controller: _tabController,
            children: [
              // 0) Summary
              RefreshIndicator(
                onRefresh: _load,
                child: summary == null
                    ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 24),
                    _emptyState('No summary available yet.'),
                  ],
                )
                    : ListView(
                  padding:
                  const EdgeInsets.symmetric(vertical: 16),
                  physics:
                  const AlwaysScrollableScrollPhysics(),
                  children: [
                    _animatedSummaryCard(
                        'Matches', Icons.sports_cricket,
                        Colors.blue, summary!.matches),
                    _animatedSummaryCard(
                        'Runs', Icons.sports_baseball,
                        Colors.green, summary!.runs),
                    _animatedSummaryCard(
                        'Wickets', Icons.sports_handball,
                        Colors.red, summary!.wickets),
                    _animatedSummaryCard(
                        'Sixes', Icons.sports_martial_arts,
                        Colors.purple, summary!.sixes),
                    _animatedSummaryCard(
                        'Fours', Icons.sports,
                        Colors.orange, summary!.fours),
                    _animatedSummaryCard(
                        'Balls', Icons.sports_soccer,
                        Colors.teal, summary!.balls),
                    _animatedSummaryCard(
                        'Extras', Icons.stars,
                        Colors.grey, summary!.extras),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Note: some data could not be loaded. Pull to refresh.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white38
                                : Colors.black38,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // 1) Most Runs
              RefreshIndicator(
                onRefresh: _load,
                child: mostRuns.isEmpty
                    ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 24),
                    _emptyState('No batting leaderboard yet.'),
                  ],
                )
                    : ListView(
                  padding:
                  const EdgeInsets.symmetric(vertical: 8),
                  physics:
                  const AlwaysScrollableScrollPhysics(),
                  children: mostRuns.map((e) {
                    return _tile(
                      e.playerImage,
                      e.displayName,
                      e.teamName,
                      trailing: '${e.runs} Runs',
                    );
                  }).toList(),
                ),
              ),

              // 2) Most Wickets
              RefreshIndicator(
                onRefresh: _load,
                child: mostWickets.isEmpty
                    ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 24),
                    _emptyState('No bowling leaderboard yet.'),
                  ],
                )
                    : ListView(
                  padding:
                  const EdgeInsets.symmetric(vertical: 8),
                  physics:
                  const AlwaysScrollableScrollPhysics(),
                  children: mostWickets.map((e) {
                    final inns = (e.innings.toString() ?? '0');
                    final avg  = (e.avg.toString() ?? '-');
                    return _tile(
                      e.playerImage,
                      e.displayName,
                      '${e.wickets} wickets • $inns inns',
                      trailing: 'Avg: $avg',
                    );
                  }).toList(),
                ),
              ),

              // 3) Most Sixes
              RefreshIndicator(
                onRefresh: _load,
                child: mostSixes.isEmpty
                    ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 24),
                    _emptyState('No sixes leaderboard yet.'),
                  ],
                )
                    : ListView(
                  padding:
                  const EdgeInsets.symmetric(vertical: 8),
                  physics:
                  const AlwaysScrollableScrollPhysics(),
                  children: mostSixes.map((e) {
                    return _tile(
                      e.playerImage,
                      e.displayName,
                      e.teamName,
                      trailing: '${e.sixes} Sixes',
                    );
                  }).toList(),
                ),
              ),

              // 4) Most Fours
              RefreshIndicator(
                onRefresh: _load,
                child: mostFours.isEmpty
                    ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 24),
                    _emptyState('No fours leaderboard yet.'),
                  ],
                )
                    : ListView(
                  padding:
                  const EdgeInsets.symmetric(vertical: 8),
                  physics:
                  const AlwaysScrollableScrollPhysics(),
                  children: mostFours.map((e) {
                    return _tile(
                      e.playerImage,
                      e.displayName,
                      e.teamName,
                      trailing: '${e.fours} Fours',
                    );
                  }).toList(),
                ),
              ),

              // 5) MVPs (count occurrences)
              RefreshIndicator(
                onRefresh: _load,
                child: mvps.isEmpty
                    ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 24),
                    _emptyState('No MVPs yet.'),
                  ],
                )
                    : Builder(builder: (_) {
                  final counts = <String, int>{};
                  final firstSeen = <String, MVP>{};
                  for (final m in mvps) {
                    counts[m.displayName] =
                        (counts[m.displayName] ?? 0) + 1;
                    firstSeen.putIfAbsent(m.displayName, () => m);
                  }
                  final sortedNames = counts.keys.toList()
                    ..sort((a, b) =>
                        counts[b]!.compareTo(counts[a]!));

                  return ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    physics:
                    const AlwaysScrollableScrollPhysics(),
                    children: sortedNames.map((name) {
                      final m = firstSeen[name]!;
                      final pts = counts[name]!;
                      return _tile(
                        m.playerImage,
                        m.displayName,
                        m.teamName,
                        trailing: '$pts',
                      );
                    }).toList(),
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
