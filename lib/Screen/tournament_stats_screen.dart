import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import '../model/tournament_stats_model.dart';
import '../service/tournament_service.dart';

class TournamentStatsScreen extends StatefulWidget {
  final int tournamentId;
  const TournamentStatsScreen({super.key, required this.tournamentId});

  @override
  State<TournamentStatsScreen> createState() => _TournamentStatsScreenState();
}

class _TournamentStatsScreenState extends State<TournamentStatsScreen>
    with SingleTickerProviderStateMixin {
  bool isLoading = true;
  String? error;
  List<RunStats> mostRuns = [];
  List<WicketStats> mostWickets = [];
  List<SixStats> mostSixes = [];
  List<FourStats> mostFours = [];
  List<MVP> mvps = [];
  List<HighestScore> highestScores = [];
  SummaryStats? summary;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    fetchStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> fetchStats() async {
    try {
      final result = await TournamentService.fetchTournamentStats(widget.tournamentId);
      setState(() {
        mostRuns = result['mostRuns'];
        mostWickets = result['mostWickets'];
        mostSixes = result['mostSixes'];
        mostFours = result['mostFours'];
        mvps = result['mvp'];
        highestScores = result['highestScores'];
        summary = result['summary'];
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Widget _buildListTile(String? image, String name, String subtitle, [String? trailing]) {
    final hasImage = image != null && image.trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          radius: 28,
          backgroundImage: hasImage
              ? NetworkImage(image!)
              : const AssetImage('lib/asset/images/Random_Image.png') as ImageProvider,
        ),
        title: Text(name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        trailing: trailing != null
            ? Text(trailing, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))
            : null,
      ),
    ).animate().fadeIn(duration: 300.ms).slideY();
  }

  Widget _shimmerListLoader() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: List.generate(
        5,
            (index) => Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: CircleAvatar(radius: 28, backgroundColor: Colors.grey[300]),
            title: Container(height: 12, width: 100, color: Colors.white),
            subtitle: Container(height: 10, width: 150, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                const SizedBox(height: 4),
                Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY();
  }

  Widget _buildTabView(List<Widget> tiles) {
    return RefreshIndicator(
      onRefresh: fetchStats,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: tiles,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,
          labelStyle: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Summary'),
            Tab(text: 'Most Runs'),
            Tab(text: 'Most Wickets'),
            Tab(text: 'Most Sixes'),
            Tab(text: 'Most Fours'),
            Tab(text: 'MVPs'),
          ],
        ),
        Expanded(
          child: isLoading
              ? _shimmerListLoader()
              : error != null
              ? Center(child: Text("Error: $error", style: Theme.of(context).textTheme.bodyMedium))
              : TabBarView(
            controller: _tabController,
            children: [
              RefreshIndicator(
                onRefresh: fetchStats,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: summary != null
                      ? [
                    _buildSummaryCard("Matches", "${summary!.matches}", Icons.sports_cricket, Colors.blue),
                    _buildSummaryCard("Runs", "${summary!.runs}", Icons.sports_baseball, Colors.green),
                    _buildSummaryCard("Wickets", "${summary!.wickets}", Icons.sports_handball, Colors.red),
                    _buildSummaryCard("Sixes", "${summary!.sixes}", Icons.sports_martial_arts, Colors.purple),
                    _buildSummaryCard("Fours", "${summary!.fours}", Icons.sports, Colors.orange),
                    _buildSummaryCard("Balls", "${summary!.balls}", Icons.sports_soccer, Colors.teal),
                    _buildSummaryCard("Extras", "${summary!.extras}", Icons.stars, Colors.grey),
                  ]
                      : [],
                ),
              ),
              _buildTabView(mostRuns
                  .map((e) => _buildListTile(
                  e.playerImage,
                  e.displayName,
                  '${e.teamName} • ${e.runs} Runs • Avg: ${e.avg}',
                  'SR: ${e.sr}'))
                  .toList()),
              _buildTabView(mostWickets
                  .map((e) => _buildListTile(
                  e.playerImage,
                  e.displayName,
                  '${e.wickets} Wickets in ${e.innings} Innings',
                  'Avg: ${e.avg}'))
                  .toList()),
              _buildTabView(mostSixes
                  .map((e) => _buildListTile(e.playerImage, e.displayName, '${e.teamName}', '${e.sixes} Sixes'))
                  .toList()),
              _buildTabView(mvps
                  .map((e) => _buildListTile(e.playerImage, e.displayName, e.teamName))
                  .toList()),
            ],
          ),
        ),
      ],
    );
  }
}