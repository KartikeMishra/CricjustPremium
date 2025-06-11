// lib/screens/tournament_screen.dart

import 'package:flutter/material.dart';
import '../theme/color.dart';
import 'all_tournaments_screen.dart';

class TournamentScreen extends StatelessWidget {
  const TournamentScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: AppBar(
            backgroundColor: AppColors.primary,
            elevation: 2,
            automaticallyImplyLeading: false,
            toolbarHeight: 0, // remove empty title bar
            bottom: TabBar(
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'Live'),
                Tab(text: 'Upcoming'),
                Tab(text: 'Recent'),
              ],
            ),
          ),
        ),
        body: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: TabBarView(
            children: [
              AllTournamentsScreen(type: 'live'),
              AllTournamentsScreen(type: 'upcoming'),
              AllTournamentsScreen(type: 'recent'),
            ],
          ),
        ),
      ),
    );
  }
}
