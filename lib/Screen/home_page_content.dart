import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../widget/live_matches_section.dart';
import '../widget/tournament_section.dart';
import '../widget/upcoming_matches_section.dart';
import '../widget/recent_matches_section.dart';
import '../widget/posts_section.dart';
import '../screen/all_matches_screen.dart';

class HomePageContent extends StatefulWidget {
  final VoidCallback onLoadMoreTap;
  const HomePageContent({super.key, required this.onLoadMoreTap});

  @override
  State<HomePageContent> createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent>
    with SingleTickerProviderStateMixin {
  bool _refreshing = false;
  bool _loading = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _refreshing = true;
      _loading = true;
    });
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() {
      _refreshing = false;
      _loading = false;
    });
  }

  Widget _buildSection(String title, IconData icon, Widget child, {VoidCallback? onSeeAll}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FadeTransition(
      opacity: _animationController.drive(CurveTween(curve: Curves.easeIn)),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 18, color: isDark ? Colors.redAccent : Colors.red),
                      const SizedBox(width: 6),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                  if (onSeeAll != null)
                    InkWell(
                      onTap: onSeeAll,
                      child: Text(
                        'See All',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.blue[200] : Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                ],
              ),
              const SizedBox(height: 10),
              _loading ? _buildShimmer() : child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    final base = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[800]!
        : Colors.grey[300]!;
    final highlight = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[700]!
        : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        height: 100,
        width: double.infinity,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: Theme.of(context).colorScheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 20, top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'Live Matches',
              Icons.live_tv,
              const LiveMatchesSection(),
              onSeeAll: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AllMatchesScreen(
                      matchType: 'live',
                      title: 'All Live Matches',
                    ),
                  ),
                );
              },
            ),
          _buildSection(
            'Tournaments',
            Icons.emoji_events,
            const TournamentSection(),
            onSeeAll: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AllMatchesScreen(
                    matchType: 'tournament',
                    title: 'All Tournaments',
                  ),
                ),
              );
            },
          ),

            _buildSection(
              'Upcoming Matches',
              Icons.schedule,
              const UpcomingMatchesSection(),
              onSeeAll: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AllMatchesScreen(
                      matchType: 'upcoming',
                      title: 'All Upcoming Matches',
                    ),
                  ),
                );
              },
            ),
            _buildSection(
              'Recent Matches',
              Icons.history,
              const RecentMatchesSection(),
              onSeeAll: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AllMatchesScreen(
                      matchType: 'recent',
                      title: 'All Recent Matches',
                    ),
                  ),
                );
              },
            ),
        _buildSection(
          'News & Posts',
          Icons.article,
          PostsSection(onLoadMore: widget.onLoadMoreTap),
          onSeeAll: widget.onLoadMoreTap,
        ),

          ],
        ),
      ),
    );
  }
}
