import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../model/match_player_model.dart';
import '../service/match_player_service.dart';
import '../theme/color.dart';

class PlayerPublicInfoTab extends StatefulWidget {
  final int playerId;
  const PlayerPublicInfoTab({super.key, required this.playerId});

  @override
  State<PlayerPublicInfoTab> createState() => _PlayerPublicInfoTabState();
}

class _PlayerPublicInfoTabState extends State<PlayerPublicInfoTab> {
  late Future<PlayerPublicInfo> _playerFuture;

  @override
  void initState() {
    super.initState();
    _playerFuture = MatchPlayerService.fetchPlayerInfo(widget.playerId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text(
          'Player Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        elevation: 2,
      ),
      body: FutureBuilder<PlayerPublicInfo>(
        future: _playerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: \${snapshot.error}'));
          }

          final player = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Header
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 24,
                      horizontal: 16,
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: NetworkImage(player.profileImage),
                          onBackgroundImageError: (_, __) {},
                        ).animate().fade(duration: 600.ms).scale(),
                        const SizedBox(height: 12),
                        Text(
                          player.firstName,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ).animate().fade(duration: 500.ms),
                        const SizedBox(height: 4),
                        Text(
                          player.playerType,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (player.batterType != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            player.batterType!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        if (player.bowlerType != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            player.bowlerType!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Teams
                Row(
                  children: [
                    const Icon(Icons.group, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Teams',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ).animate().slideX(begin: -1, duration: 500.ms),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: player.teams
                      .map(
                        (t) => Chip(
                          label: Text(t),
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          labelStyle: const TextStyle(color: Colors.black87),
                        ),
                      )
                      .toList(),
                ),

                const SizedBox(height: 24),

                // Batting Career
                _buildCareerCard(
                  context,
                  title: 'Batting Career',
                  icon: Icons.sports_cricket,
                  rows: {
                    'Matches': player.battingCareer.matches,
                    'Innings': player.battingCareer.innings,
                    'Runs': player.battingCareer.runs,
                    'Avg': player.battingCareer.average,
                    'SR': player.battingCareer.strikeRate,
                    '4s': player.battingCareer.fours,
                    '6s': player.battingCareer.sixes,
                    '50s': player.battingCareer.fifties,
                    '100s': player.battingCareer.hundreds,
                    'Best': player.battingCareer.bestScore,
                  },
                ),

                const SizedBox(height: 16),

                // Bowling Career
                _buildCareerCard(
                  context,
                  title: 'Bowling Career',
                  icon: Icons.sports_baseball,
                  rows: {
                    'Matches': player.bowlingCareer.matches,
                    'Innings': player.bowlingCareer.innings,
                    'Wickets': player.bowlingCareer.wickets,
                    'Avg': player.bowlingCareer.average,
                    'Econ': player.bowlingCareer.economy,
                    'Best': player.bowlingCareer.best,
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCareerCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Map<String, dynamic> rows,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1),
              },
              children: rows.entries.map((e) {
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        e.key,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        e.value.toString(),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    ).animate().fade(duration: 500.ms).slideY();
  }
}
