import 'package:flutter/material.dart';
import '../../model/tournament_overview_model.dart';
import '../../model/fair_play_model.dart';
import '../../service/tournament_service.dart';
import '../widget/points_table.dart';
import '../widget/fair_play.dart';
import '../../theme/color.dart';
import '../../theme/text_styles.dart';

class TournamentOverviewScreen extends StatefulWidget {
  final int tournamentId;

  const TournamentOverviewScreen({Key? key, required this.tournamentId}) : super(key: key);

  @override
  State<TournamentOverviewScreen> createState() => _TournamentOverviewScreenState();
}

class _TournamentOverviewScreenState extends State<TournamentOverviewScreen> {
  TournamentOverview? tournament;
  List<TeamStanding> pointsTeams = [];
  List<FairPlayStanding> fairPlayTeams = [];
  List<GroupModel> groups = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => isLoading = true);
    try {
      final overview = await TournamentService.fetchTournamentOverview(widget.tournamentId);
      final fp = await TournamentService.fetchFairPlay(widget.tournamentId);

      setState(() {
        tournament = overview['tournament'] as TournamentOverview;
        pointsTeams = overview['pointsTeams'] as List<TeamStanding>;
        groups = overview['groups'] as List<GroupModel>;
        fairPlayTeams = fp;
        errorMessage = null;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (errorMessage != null) {
      return Center(child: Text('Failed to load: $errorMessage'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBanner(),
          const SizedBox(height: 12),
          for (final group in groups)
            PointsTableWidget(
              group: group,
              teams: group.groupId == '0'
                  ? pointsTeams
                  : pointsTeams.where((t) => t.groupId == group.groupId).toList(),
            ),
          _buildLegendChips(),
          const SizedBox(height: 24),
          FairPlayTableWidget(fairPlayTeams: fairPlayTeams),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logoUrl = tournament?.tournamentLogo ?? '';

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: logoUrl.isNotEmpty
                ? Image.network(
              logoUrl,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
              const Icon(Icons.broken_image, size: 80),
            )
                : const Icon(Icons.image_not_supported, size: 80),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tournament?.tournamentName ?? '—',
                  style: AppTextStyles.matchTitle.copyWith(
                    fontSize: 18,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tournament?.tournamentDesc ?? 'No description available.',
                  style: AppTextStyles.caption.copyWith(
                    color: isDark ? Colors.grey[300] : Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Wrap(
        spacing: 8,
        children: const [
          Chip(label: Text('M = Matches', style: TextStyle(fontSize: 12))),
          Chip(label: Text('W = Wins', style: TextStyle(fontSize: 12))),
          Chip(label: Text('L = Losses', style: TextStyle(fontSize: 12))),
          Chip(label: Text('T = Ties', style: TextStyle(fontSize: 12))),
          Chip(label: Text('D = Draws', style: TextStyle(fontSize: 12))),
          Chip(label: Text('Pts = Points', style: TextStyle(fontSize: 12))),
          Chip(label: Text('NRR = Net Run Rate', style: TextStyle(fontSize: 12))),
          Chip(label: Text('→ = View Matches', style: TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}