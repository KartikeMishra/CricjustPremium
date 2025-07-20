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
  bool isLoading = true;
  String? error;
  SummaryStats? summary;
  List<RunStats> mostRuns = [];
  List<WicketStats> mostWickets = [];
  List<SixStats> mostSixes = [];
  List<FourStats> mostFours = [];
  List<MVP> mvps = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final r = await TournamentService.fetchTournamentStats(
        widget.tournamentId,
      );
      setState(() {
        summary = r['summary'];
        mostRuns = r['mostRuns'];
        mostWickets = r['mostWickets'];
        mostSixes = r['mostSixes'];
        mostFours = r['mostFours'];
        mvps = r['mvp'];
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _shimmer() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: 5,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildListTile(
    String? img,
    String name,
    String subtitle, [
    String? trailing,
  ]) {
    final hasImage = img?.isNotEmpty == true;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          radius: 28,
          backgroundImage: hasImage
              ? NetworkImage(img!)
              : const AssetImage('lib/asset/images/Random_Image.png')
                    as ImageProvider,
        ),
        title: Text(name),
        subtitle: Text(subtitle),
        trailing: trailing == null ? null : Text(trailing),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY();
  }

  Widget _buildAnimatedSummaryCard(
    String title,
    IconData icon,
    Color color,
    String value,
  ) {
    final count = int.tryParse(value) ?? 0;
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: count),
      duration: const Duration(milliseconds: 800),
      builder: (context, val, _) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.15),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$val',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ).animate().fadeIn(duration: 300.ms).slideY();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // flush under the outer header
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: isDark
              ? BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                )
              : BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF42A5F5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
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
          child: isLoading
              ? _shimmer()
              : error != null
              ? Center(child: Text('Error: $error'))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // 0. Summary
                    RefreshIndicator(
                      onRefresh: _loadStats,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        children: summary != null
                            ? [
                                _buildAnimatedSummaryCard(
                                  'Matches',
                                  Icons.sports_cricket,
                                  Colors.blue,
                                  summary!.matches,
                                ),
                                _buildAnimatedSummaryCard(
                                  'Runs',
                                  Icons.sports_baseball,
                                  Colors.green,
                                  summary!.runs,
                                ),
                                _buildAnimatedSummaryCard(
                                  'Wickets',
                                  Icons.sports_handball,
                                  Colors.red,
                                  summary!.wickets,
                                ),
                                _buildAnimatedSummaryCard(
                                  'Sixes',
                                  Icons.sports_martial_arts,
                                  Colors.purple,
                                  summary!.sixes,
                                ),
                                _buildAnimatedSummaryCard(
                                  'Fours',
                                  Icons.sports,
                                  Colors.orange,
                                  summary!.fours,
                                ),
                                _buildAnimatedSummaryCard(
                                  'Balls',
                                  Icons.sports_soccer,
                                  Colors.teal,
                                  summary!.balls,
                                ),
                                _buildAnimatedSummaryCard(
                                  'Extras',
                                  Icons.stars,
                                  Colors.grey,
                                  summary!.extras,
                                ),
                              ]
                            : [],
                      ),
                    ),

                    // 1. Most Runs
                    ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: mostRuns
                          .map(
                            (e) => _buildListTile(
                              e.playerImage,
                              e.displayName,
                              e.teamName,
                              '${e.runs} Runs',
                            ),
                          )
                          .toList(),
                    ),

                    // 2. Most Wickets
                    ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: mostWickets
                          .map(
                            (e) => _buildListTile(
                              e.playerImage,
                              e.displayName,
                              '${e.wickets} Wickets in ${e.innings} Innings',
                              'Avg: ${e.avg}',
                            ),
                          )
                          .toList(),
                    ),

                    // 3. Most Sixes
                    ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: mostSixes
                          .map(
                            (e) => _buildListTile(
                              e.playerImage,
                              e.displayName,
                              e.teamName,
                              '${e.sixes} Sixes',
                            ),
                          )
                          .toList(),
                    ),

                    // 4. Most Fours
                    ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: mostFours
                          .map(
                            (e) => _buildListTile(
                              e.playerImage,
                              e.displayName,
                              e.teamName,
                              '${e.fours} Fours',
                            ),
                          )
                          .toList(),
                    ),

                    // 5. MVPs (count occurrences as points)
                    Builder(
                      builder: (ctx) {
                        final counts = <String, int>{};
                        final details = <String, MVP>{};
                        for (var m in mvps) {
                          counts[m.displayName] =
                              (counts[m.displayName] ?? 0) + 1;
                          details[m.displayName] = m;
                        }
                        final sorted = counts.keys.toList()
                          ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
                        return ListView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          children: sorted.map((name) {
                            final m = details[name]!;
                            return _buildListTile(
                              m.playerImage,
                              m.displayName,
                              m.teamName,
                              '${counts[name]}',
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
