import 'package:flutter/material.dart';
import '../widget/live_matches_section.dart';
import '../widget/tournament_section.dart';
import '../widget/upcoming_matches_section.dart';
import '../widget/recent_matches_section.dart';
import '../widget/posts_section.dart';

class HomePageContent extends StatefulWidget {
  final VoidCallback onLoadMoreTap;
  const HomePageContent({super.key, required this.onLoadMoreTap});

  @override
  State<HomePageContent> createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> {
  bool _refreshing = false;

  Future<void> _handleRefresh() async {
    setState(() => _refreshing = true);
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() => _refreshing = false);
  }

  Widget _buildCardSection(Widget child) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.only(top: 10, bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 20, top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardSection(const LiveMatchesSection()),
            _buildCardSection(const TournamentSection()),
            _buildCardSection(const UpcomingMatchesSection()),
            _buildCardSection(const RecentMatchesSection()),
            _buildCardSection(PostsSection(onLoadMore: widget.onLoadMoreTap)),
          ],
        ),
      ),
    );
  }
}
