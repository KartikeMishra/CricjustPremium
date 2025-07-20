// lib/screen/tournament_detail_screen.dart

import 'package:flutter/material.dart';
import '../theme/color.dart';
import 'tournament_overview_screen.dart';
import 'tournament_matches_tab.dart';
import 'tournament_stats_screen.dart';

class TournamentDetailScreen extends StatelessWidget {
  final int tournamentId;
  const TournamentDetailScreen({super.key, required this.tournamentId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: isDark
            ? Theme.of(context).scaffoldBackgroundColor
            : Colors.grey[100],

        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Container(
            decoration: isDark
                ? const BoxDecoration(
                    color: Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                  )
                : const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, Color(0xFF42A5F5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                  ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Tournament Details',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const TabBar(
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    labelStyle: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    tabs: [
                      Tab(text: 'Overview'),
                      Tab(text: 'Matches'),
                      Tab(text: 'Stats'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        body: TabBarView(
          children: [
            TournamentOverviewScreen(tournamentId: tournamentId),
            TournamentMatchesTab(tournamentId: tournamentId),
            TournamentStatsScreen(tournamentId: tournamentId),
          ],
        ),
      ),
    );
  }
}
