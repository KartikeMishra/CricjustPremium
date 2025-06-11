// lib/screens/tournament_overview_screen.dart

import 'package:flutter/material.dart';
import '../../model/tournament_overview_model.dart';
import '../../model/fair_play_model.dart';
import '../../service/tournament_service.dart';
import '../widget/points_table.dart';
import '../widget/fair_play.dart';

class TournamentOverviewScreen extends StatefulWidget {
  final int tournamentId;
  const TournamentOverviewScreen({Key? key, required this.tournamentId})
      : super(key: key);

  @override
  State<TournamentOverviewScreen> createState() =>
      _TournamentOverviewScreenState();
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
      // fetch points and groups
      final overview =
      await TournamentService.fetchTournamentOverview(widget.tournamentId);
      // fetch fair-play
      final fp =
      await TournamentService.fetchFairPlay(widget.tournamentId);

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

          // Points tables per group
          for (final group in groups)
            PointsTableWidget(
              group: group,
              teams: group.groupId == '0'
                  ? pointsTeams
                  : pointsTeams
                  .where((t) => t.groupId == group.groupId)
                  .toList(),
            ),

          // Fair-play section
          const SizedBox(height: 24),
          FairPlayTableWidget(fairPlayTeams: fairPlayTeams),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    final logoUrl = tournament?.tournamentLogo ?? '';
    return Container(
      color: Colors.blue[50],
      padding: const EdgeInsets.all(16),
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
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  tournament?.tournamentDesc ?? 'No description.',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
