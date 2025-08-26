// lib/widget/home_page_content.dart

import 'package:cricjust_premium/screen/video_gallery_screen.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../screen/all_tournaments_screen.dart';
import '../screen/all_matches_screen.dart';
import '../screen/tournament_detail_screen.dart';
import '../widget/live_matches_section.dart';
import '../widget/tournament_section.dart';
import '../widget/upcoming_matches_section.dart';
import '../widget/recent_matches_section.dart';
import '../widget/posts_section.dart';
import '../theme/color.dart'; // for AppColors.primary
import '../service/youtube_video_service.dart';
import '../model/youtube_video_model.dart';
import '../widget/video_card.dart';

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

  bool _hasLive = true;
  bool _hasTournament = true;
  bool _hasUpcoming = true;
  bool _hasRecent = true;
  bool _hasPosts = true;

  // ⬇️ NEW: videos visibility flag
  bool _hasVideos = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
  }

  void _onSectionDataLoaded(String section, bool hasData) {
    setState(() {
      switch (section) {
        case 'live':
          _hasLive = hasData;
          break;
        case 'tournament':
          _hasTournament = hasData;
          break;
        case 'upcoming':
          _hasUpcoming = hasData;
          break;
        case 'recent':
          _hasRecent = hasData;
          break;
        case 'posts':
          _hasPosts = hasData;
          break;
      // ⬇️ NEW
        case 'videos':
          _hasVideos = hasData;
          break;
      }
    });
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _refreshing = true;
      _loading = true;
      _hasLive = _hasTournament = _hasUpcoming = _hasRecent = _hasPosts = _hasVideos = true;
    });
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _refreshing = false;
      _loading = false;
    });
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
        height: 130,
        width: double.infinity,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _buildSection(
      String title,
      IconData icon,
      Widget content, {
        VoidCallback? onSeeAll,
      }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final iconColor = title.contains('Live')
        ? (isDark ? Colors.redAccent : Colors.red)
        : AppColors.primary;

    final seeAllColor = isDark ? Colors.lightBlueAccent : AppColors.primary;

    return FadeTransition(
      opacity: _animationController.drive(CurveTween(curve: Curves.easeIn)),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: isDark
              ? []
              : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 20, color: iconColor),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                  if (onSeeAll != null)
                    InkWell(
                      onTap: onSeeAll,
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Text(
                          'See All',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: seeAllColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _loading ? _buildShimmer() : content,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      if (_hasLive)
        _buildSection(
          'Live Matches',
          Icons.live_tv,
          LiveMatchesSection(
            onDataLoaded: (hasData) => _onSectionDataLoaded('live', hasData),
          ),
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
      if (_hasTournament)
        _buildSection(
          'Tournaments',
          Icons.emoji_events,
          TournamentSection(
            type: 'live',
            limit: 10,
            onTournamentTap: (tournamentId) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      TournamentDetailScreen(tournamentId: tournamentId),
                ),
              );
            },
            onDataLoaded: (hasData) =>
                _onSectionDataLoaded('tournament', hasData),
          ),
          onSeeAll: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AllTournamentsScreen(type: 'live'),
              ),
            );
          },
        ),

      // ⬇️ NEW: Videos section (exactly 5 items)
      if (_hasVideos)
        _buildSection(
          'Videos',
          Icons.ondemand_video_rounded,
          _VideosFive(
            onDataLoaded: (hasData) => _onSectionDataLoaded('videos', hasData),
          ),
          onSeeAll: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VideoGalleryScreen()),
            );
          },
        ),

      if (_hasUpcoming)
        _buildSection(
          'Upcoming Matches',
          Icons.schedule,
          UpcomingMatchesSection(
            onDataLoaded: (hasData) =>
                _onSectionDataLoaded('upcoming', hasData),
          ),
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
      if (_hasRecent)
        _buildSection(
          'Recent Matches',
          Icons.history,
          RecentMatchesSection(
            onDataLoaded: (hasData) => _onSectionDataLoaded('recent', hasData),
          ),
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
      if (_hasPosts)
        _buildSection(
          'News & Posts',
          Icons.article,
          PostsSection(
            onLoadMore: widget.onLoadMoreTap,
            onDataLoaded: (hasData) => _onSectionDataLoaded('posts', hasData),
          ),
          onSeeAll: widget.onLoadMoreTap,
        ),
    ];

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: 10,
          bottom: MediaQuery.of(context).viewPadding.bottom + 80,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: sections,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

// -----------------------------------------------------------------------------
// Compact videos content for Home: fetch 5 items, show a carousel with dots.
// -----------------------------------------------------------------------------
class _VideosFive extends StatefulWidget {
  final ValueChanged<bool>? onDataLoaded;
  const _VideosFive({this.onDataLoaded});

  @override
  State<_VideosFive> createState() => _VideosFiveState();
}

class _VideosFiveState extends State<_VideosFive> {
  late Future<List<YoutubeVideo>> _future;
  final _page = PageController(viewportFraction: 0.90);
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _future = YoutubeVideoService.fetch(limit: 5, skip: 0);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<List<YoutubeVideo>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          // simple loading skeleton
          return SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemBuilder: (_, __) => Shimmer.fromColors(
                baseColor: isDark ? Colors.white10 : Colors.black12,
                highlightColor: isDark ? Colors.white24 : Colors.black26,
                child: Container(
                  width: 300,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemCount: 3,
            ),
          );
        }

        if (snap.hasError) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onDataLoaded?.call(false);
          });
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Failed to load videos'),
          );
        }

        final items = snap.data ?? const <YoutubeVideo>[];
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onDataLoaded?.call(items.isNotEmpty);
        });

        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text('No videos available'),
          );
        }

        return Column(
          children: [
            SizedBox(
              height: 210,
              child: PageView.builder(
                controller: _page,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: items.length,
                itemBuilder: (_, i) => VideoCard(video: items[i]),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(items.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 6,
                  width: active ? 18 : 6,
                  decoration: BoxDecoration(
                    color: active
                        ? (isDark ? Colors.white : AppColors.primary)
                        : (isDark ? Colors.white24 : Colors.black12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}
