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
import '../theme/color.dart'; // AppColors.primary
import '../service/youtube_video_service.dart';
import '../model/youtube_video_model.dart';
import '../widget/video_card.dart';

class HomePageContent extends StatefulWidget {
  final VoidCallback onLoadMoreTap; // non-nullable by design
  const HomePageContent({super.key, required this.onLoadMoreTap});

  @override
  State<HomePageContent> createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent>
    with SingleTickerProviderStateMixin {
  bool _refreshing = false;
  bool _loading = false;
  late final AnimationController _animationController;

  bool _hasLive = true;
  bool _hasTournament = true;
  bool _hasUpcoming = true;
  bool _hasRecent = true;
  bool _hasPosts = true;
  bool _hasVideos = true; // videos visibility flag

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 700),
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
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _refreshing = false;
      _loading = false;
    });
  }

  Widget _skeletonCard({double height = 130}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xFF232323) : const Color(0xFFECEFF4);
    final highlight = dark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F7FA);

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildSection(
      String title,
      IconData icon,
      Widget content, {
        VoidCallback? onSeeAll,
        Color? accent,
      }) {
    return FadeTransition(
      opacity: _animationController.drive(CurveTween(curve: Curves.easeIn)),
      child: SectionCard(
        title: title,
        icon: icon,
        onSeeAll: onSeeAll,
        accent: accent,
        child: _loading ? _skeletonCard(height: 140) : content,
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
          accent: Colors.redAccent,
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
                  builder: (_) => TournamentDetailScreen(tournamentId: tournamentId),
                ),
              );
            },
            onDataLoaded: (hasData) => _onSectionDataLoaded('tournament', hasData),
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

      // Videos (exactly ~5 items)
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
          Icons.schedule_rounded,
          UpcomingMatchesSection(
            onDataLoaded: (hasData) => _onSectionDataLoaded('upcoming', hasData),
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
          Icons.history_rounded,
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
          Icons.article_rounded,
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

/// ---------------------------------------------------------------------------
/// Section Card (reusable, polished to match soft white/blue aesthetic)
/// ---------------------------------------------------------------------------
class SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final VoidCallback? onSeeAll;
  final Color? accent;

  const SectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.onSeeAll,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final headerIconColor =
    title.contains('Live')
        ? (dark ? Colors.redAccent : Colors.red)
        : (accent ?? AppColors.primary);
    final seeAllColor = dark ? Colors.lightBlueAccent : AppColors.primary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: dark ? const Color(0xFF17181B) : Colors.white,
        gradient: dark
            ? null
            : const LinearGradient(
          colors: [Colors.white, Color(0xFFF6FAFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: dark ? Colors.white12 : const Color(0xFFE8F0FB),
          width: 1,
        ),
        boxShadow: [
          if (!dark)
            const BoxShadow(
              color: Color(0x1F96C0FF), // subtle blue glow
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          BoxShadow(
            color: (dark ? Colors.black : const Color(0xFF9BB7DB)).withOpacity(dark ? 0.35 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              icon: icon,
              title: title,
              iconColor: headerIconColor,
              onSeeAll: onSeeAll,
              seeAllColor: seeAllColor,
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color iconColor;
  final VoidCallback? onSeeAll;
  final Color seeAllColor;

  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.seeAllColor,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          Container(
            height: 28,
            width: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: iconColor.withOpacity(dark ? 0.18 : 0.12),
              border: Border.all(
                color: dark ? Colors.white12 : const Color(0xFFE3EEFF),
              ),
              boxShadow: [
                if (!dark)
                  const BoxShadow(
                    color: Color(0x1496C0FF),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
              ],
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: dark ? Colors.white : Colors.black,
            ),
          ),
        ]),
        if (onSeeAll != null)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onSeeAll,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  Text(
                    'See All',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 16),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// Compact videos content for Home: fetch 5 items, show a carousel with dots.
/// ---------------------------------------------------------------------------
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
    final dark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<List<YoutubeVideo>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          // loading skeleton
          return SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemBuilder: (_, __) => Shimmer.fromColors(
                baseColor: dark ? Colors.white10 : Colors.black12,
                highlightColor: dark ? Colors.white24 : Colors.black26,
                child: Container(
                  width: 300,
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF1E1E1E) : Colors.white,
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
          return const _InlineInfo(text: 'Failed to load videos');
        }

        final items = snap.data ?? const <YoutubeVideo>[];
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onDataLoaded?.call(items.isNotEmpty);
        });

        if (items.isEmpty) {
          return const _InlineInfo(text: 'No videos available');
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
            _Dots(count: items.length, index: _index),
          ],
        );
      },
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;
  const _Dots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 6,
          width: active ? 18 : 6,
          decoration: BoxDecoration(
            color: active
                ? (dark ? Colors.white : AppColors.primary)
                : (dark ? Colors.white24 : Colors.black12),
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }
}

class _InlineInfo extends StatelessWidget {
  final String text;
  const _InlineInfo({required this.text});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: TextStyle(
          color: dark ? Colors.white70 : Colors.black54,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
