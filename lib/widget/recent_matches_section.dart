// ✅ No logic disturbed, only design harmonized

import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../model/match_model.dart';
import '../service/match_service.dart';
import '../screen/full_match_detail.dart';
import '../theme/color.dart';
import '../theme/text_styles.dart';

class RecentMatchesSection extends StatefulWidget {
  final void Function(bool hasData)? onDataLoaded;

  const RecentMatchesSection({super.key, this.onDataLoaded});

  @override
  State<RecentMatchesSection> createState() => _RecentMatchesSectionState();
}

class _RecentMatchesSectionState extends State<RecentMatchesSection> {
  List<MatchModel> _matches = [];
  bool _isLoading = true;
  final int _visibleCount = 5;
  final PageController _pageController = PageController(viewportFraction: 0.92);
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _fetchRecentMatches();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchRecentMatches() async {
    try {
      final matches = await MatchService.fetchMatches(
        type: 'recent',
        limit: 20,
      );
      if (!mounted) return;
      setState(() {
        _matches = matches;
        _isLoading = false;
      });
      widget.onDataLoaded?.call(matches.isNotEmpty);
    } catch (e) {
      debugPrint("Error loading recent matches: $e");
      if (!mounted) return;
      setState(() => _isLoading = false);
      widget.onDataLoaded?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmerBase = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final shimmerHighlight = isDark
        ? Colors.grey.shade600
        : Colors.grey.shade100;

    if (_isLoading) return _buildShimmerLoader(shimmerBase, shimmerHighlight);
    if (_matches.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                    builder: (_) => FullMatchDetail(matchId: match.matchId),
                  ),
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: isDark
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFFE8F4FF), Colors.white],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    color: isDark ? const Color(0xFF2A2A2A) : null,
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black87
                            : Colors.blue.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),

                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              match.matchName,
                              style: AppTextStyles.matchTitle.copyWith(
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              match.tournamentName,
                              style: AppTextStyles.tournamentName.copyWith(
                                color: isDark
                                    ? Colors.grey[300]
                                    : Colors.grey[800],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            _buildTeamRow(
                              match.team1Logo,
                              match.team1Name,
                              match.team1Runs,
                              match.team1Wickets,
                              isDark,
                            ),
                            const SizedBox(height: 8),
                            _buildTeamRow(
                              match.team2Logo,
                              match.team2Name,
                              match.team2Runs,
                              match.team2Wickets,
                              isDark,
                            ),
                            const Spacer(),
                            Text(
                              "Result: ${match.result}",
                              style: AppTextStyles.result.copyWith(
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[800],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
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
            effect: WormEffect(
              dotHeight: 8,
              dotWidth: 8,
              spacing: 8,
              activeDotColor: AppColors.primary,
              dotColor: isDark ? Colors.grey : Colors.grey.shade400,
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildTeamRow(
    String logo,
    String name,
    int runs,
    int wickets,
    bool isDark,
  ) {
    return Row(
      children: [
        _teamLogo(logo, name),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            style: AppTextStyles.teamName.copyWith(
              color: isDark ? Colors.white : Colors.black,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$runs/$wickets',
          style: AppTextStyles.score.copyWith(
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _teamLogo(String url, String name) {
    if (url.isNotEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: Colors.white,
        backgroundImage: NetworkImage(url),
      );
    }
    final initials = name
        .split(' ')
        .where((e) => e.isNotEmpty)
        .map((e) => e[0])
        .join()
        .toUpperCase();
    final bgColor = _getRandomColor(name);
    return CircleAvatar(
      radius: 16,
      backgroundColor: bgColor,
      child: Text(
        initials.length > 4 ? initials.substring(0, 4) : initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoader(Color baseColor, Color highlightColor) {
    return SizedBox(
      height: 230,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.82,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getRandomColor(String seed) {
    final hash = seed.hashCode;
    final rng = Random(hash);
    return Color.fromARGB(
      255,
      100 + rng.nextInt(155),
      100 + rng.nextInt(155),
      100 + rng.nextInt(155),
    );
  }
}
