// lib/widget/recent_matches_section.dart
// ✅ Graphics removed. Smooth & lightweight visuals. Logic untouched.

import 'dart:math';
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
      final matches = await MatchService.fetchMatches(type: 'recent', limit: 20);
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
    final shimmerHighlight = isDark ? Colors.grey.shade600 : Colors.grey.shade100;

    if (_isLoading) return _buildShimmerLoader(shimmerBase, shimmerHighlight);
    if (_matches.isEmpty) return const SizedBox.shrink();

    // Keep height logic identical; just a tiny adaptive bump for large text scales
    final textScale = MediaQuery.of(context).textScaleFactor;
    final cardHeight = (240 + (textScale - 1.0) * 48).clamp(240.0, 300.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: cardHeight,
          child: PageView.builder(
            controller: _pageController,
            itemCount: min(_matches.length, _visibleCount),
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              final match = _matches[index];
              final isActive = index == _currentPage;

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => FullMatchDetail(matchId: match.matchId)),
                ),
                child: AnimatedScale(
                  scale: isActive ? 1.0 : 0.97,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: isDark
                          ? null
                          : const LinearGradient(
                        colors: [Color(0xFFE8F4FF), Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      color: isDark ? const Color(0xFF1E1E1E) : null,
                      border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withOpacity(0.20)
                              : Colors.blue.withOpacity(0.10),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
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
                                color: isDark ? Colors.grey[300] : Colors.grey[800],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            _buildTeamRow(
                              match.team1Logo,
                              match.team1Name,
                              match.team1Runs,
                              match.team1Wickets,
                              isDark,
                            ),
                            const SizedBox(height: 6),
                            _buildTeamRow(
                              match.team2Logo,
                              match.team2Name,
                              match.team2Runs,
                              match.team2Wickets,
                              isDark,
                            ),
                            const SizedBox(height: 8),
                            if (match.result.isNotEmpty)
                              Flexible(
                                fit: FlexFit.loose,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.035),
                                    border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                                  ),
                                  child: Text(
                                    "Result: ${match.result}",
                                    style: AppTextStyles.result.copyWith(
                                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
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
      return Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.65), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _logoFallback(name),
          ),
        ),
      );
    }
    return _logoFallback(name);
  }

  Widget _logoFallback(String name) {
    final initials = name
        .split(' ')
        .where((e) => e.isNotEmpty)
        .map((e) => e[0])
        .join()
        .toUpperCase();
    final bg = _getRandomColor(name);
    return CircleAvatar(
      radius: 17,
      backgroundColor: bg,
      child: Text(
        initials.length > 3 ? initials.substring(0, 3) : initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 1)],
        ),
      ),
    );
  }

  Widget _buildShimmerLoader(Color base, Color highlight) {
    return SizedBox(
      height: 250,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: base,
            highlightColor: highlight,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.82,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: base,
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
