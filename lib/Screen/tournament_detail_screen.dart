import 'package:flutter/material.dart';
import '../theme/color.dart';
import '../theme/text_styles.dart';
import 'match_detail_screen.dart';
import 'tournament_overview_screen.dart';
import 'tournament_matches_tab.dart'; // ✅ NEW import

class TournamentDetailScreen extends StatelessWidget {
  final int tournamentId;

  const TournamentDetailScreen({Key? key, required this.tournamentId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          elevation: 2,
          title: const Text(
            'Tournament Details',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Matches'),
              Tab(text: 'Stats'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            TournamentOverviewScreen(tournamentId: tournamentId),
            TournamentMatchesTab(tournamentId: tournamentId), // ✅ Updated
            _buildStatsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Stats', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.insights, size: 60, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(
                    'Coming Soon',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 20),
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
