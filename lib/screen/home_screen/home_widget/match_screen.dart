import 'package:flutter/material.dart';
import '../../../theme/color.dart';
import '../../all_matches_screen.dart';

class MatchScreen extends StatelessWidget {
  const MatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final appBarColor =
        Theme.of(context).appBarTheme.backgroundColor ??
        (isDark ? Colors.black : Colors.white);
    final tabTextColor = isDark ? Colors.white : AppColors.textPrimary;
    final unselectedColor = isDark
        ? Colors.grey[400]!
        : AppColors.textSecondary;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: AppBar(
            elevation: 1,
            backgroundColor: appBarColor,
            centerTitle: true,
            automaticallyImplyLeading: false,
            bottom: TabBar(
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelColor: tabTextColor,
              unselectedLabelColor: unselectedColor,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600),
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
