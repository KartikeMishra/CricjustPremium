import 'package:flutter/material.dart';
import '../theme/color.dart';
import 'all_matches_screen.dart';

class MatchScreen extends StatelessWidget {
  const MatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: AppBar(
            elevation: 1,
            backgroundColor: Colors.white,
            centerTitle: true,
            automaticallyImplyLeading: false,
            bottom: const TabBar(
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelColor: AppColors.textPrimary,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: TextStyle(fontWeight: FontWeight.w600),
              tabs: [
                Tab(text: 'Live'),
                Tab(text: 'Upcoming'),
                Tab(text: 'Recent'),
              ],
            ),
          ),
        ),
        body: const Padding(
          padding: EdgeInsets.only(top: 8), // Minimal spacing below tab bar
          child: TabBarView(
            children: [
              AllMatchesScreen(matchType: 'live'),
              AllMatchesScreen(matchType: 'upcoming'),
              AllMatchesScreen(matchType: 'recent'),
            ],
          ),
        ),
      ),
    );
  }
}
