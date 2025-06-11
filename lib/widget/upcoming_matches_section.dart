import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:shimmer/shimmer.dart';

import '../Screen/all_matches_screen.dart';
import '../model/match_model.dart';
import '../service/match_service.dart';
import '../screen/match_detail_screen.dart';
import '../theme/color.dart';
import '../theme/text_styles.dart';
import '../widget/load_more.dart';

class UpcomingMatchesSection extends StatefulWidget {
  const UpcomingMatchesSection({super.key});

  @override
  State<UpcomingMatchesSection> createState() => _UpcomingMatchesSectionState();
}

class _UpcomingMatchesSectionState extends State<UpcomingMatchesSection> {
  List<MatchModel> _matches = [];
  bool _isLoading = true;
  bool _hasMore = false;
  final int _visibleCount = 5;
  final PageController _pageController = PageController(viewportFraction: 0.92);
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _fetchUpcomingMatches();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchUpcomingMatches() async {
    try {
      final matches = await MatchService.fetchMatches(type: 'upcoming', limit: 20);
      if (!mounted) return;
      setState(() {
        _matches = matches;
        _hasMore = matches.length > _visibleCount;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading upcoming matches: $e");
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String _getTimeLeft(String date, String time) {
    try {
      final matchDateTime = DateFormat('yyyy-MM-dd HH:mm:ss').parse('$date $time');
      final now = DateTime.now();
      final difference = matchDateTime.difference(now);
      if (difference.inSeconds < 0) return 'Starting Soon';
      if (difference.inDays > 0) return '${difference.inDays} day(s) left';
      if (difference.inHours > 0) return '${difference.inHours % 24} hour(s) left';
      return '${difference.inMinutes % 60} minute(s) left';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildShimmerLoader();
    if (_matches.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.schedule, color: Colors.blue, size: 18),
                    SizedBox(width: 6),
                    Text("Upcoming Matches", style: AppTextStyles.sectionTitle),
                  ],
                ),
                LoadMoreArrow(
                  show: _hasMore,
                  onTap: () {
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
              ],
            ),
          ),

          // Match cards
          SizedBox(
            height: 230,
            child: PageView.builder(
              controller: _pageController,
              itemCount: min(_matches.length, _visibleCount),
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) {
                final match = _matches[index];
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MatchDetailScreen(matchId: match.matchId),
                    ),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 210),
                    child: Card(
                      color: AppColors.cardBackground,
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(match.matchName, style: AppTextStyles.matchTitle),
                            const SizedBox(height: 4),
                            Text(match.tournamentName, style: AppTextStyles.tournamentName),
                            const SizedBox(height: 8),
                            _buildTeamRow(match.team1Logo, match.team1Name),
                            const SizedBox(height: 6),
                            _buildTeamRow(match.team2Logo, match.team2Name),
                            const SizedBox(height: 10),
                            Text("Starts: ${_getTimeLeft(match.matchDate, match.matchTime)}", style: AppTextStyles.timeLeft),
                            const Spacer(),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          Center(
            child: SmoothPageIndicator(
              controller: _pageController,
              count: min(_matches.length, _visibleCount),
              effect: const WormEffect(
                dotHeight: 8,
                dotWidth: 8,
                spacing: 8,
                activeDotColor: AppColors.primary,
                dotColor: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _teamLogo(String url, String name) {
    if (url.isNotEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: Colors.grey.shade200,
        backgroundImage: NetworkImage(url),
      );
    }
    final initials = name.split(' ').where((e) => e.isNotEmpty).map((e) => e[0]).join().toUpperCase();
    final bgColor = _getRandomColor(name);
    return CircleAvatar(
      radius: 16,
      backgroundColor: bgColor,
      child: Text(
        initials.length > 4 ? initials.substring(0, 4) : initials,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTeamRow(String logo, String name) {
    return Row(
      children: [
        _teamLogo(logo, name),
        const SizedBox(width: 10),
        Expanded(
          child: Text(name, style: AppTextStyles.teamName, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Color _getRandomColor(String seed) {
    final hash = seed.hashCode;
    final rng = Random(hash);
    return Color.fromARGB(255, 100 + rng.nextInt(155), 100 + rng.nextInt(155), 100 + rng.nextInt(155));
  }

  Widget _buildShimmerLoader() {
    return SizedBox(
      height: 230,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.82,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
      ),
    );
  }
}
