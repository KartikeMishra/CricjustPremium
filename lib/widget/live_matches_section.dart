// lib/widget/live_matches_section.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:shimmer/shimmer.dart';

import '../model/match_model.dart';
import '../service/match_service.dart';
import '../screen/full_match_detail.dart';
import '../utils/image_utils.dart';
import 'section_graphics.dart'; // kept for LiveBadge only

class LiveMatchesSection extends StatefulWidget {
  final void Function(bool hasData)? onDataLoaded;

  const LiveMatchesSection({super.key, this.onDataLoaded});

  @override
  State<LiveMatchesSection> createState() => _LiveMatchesSectionState();
}

class _LiveMatchesSectionState extends State<LiveMatchesSection> {
  List<MatchModel> _matches = [];
  bool _isLoading = true;
  final int _visibleCount = 5;
  final PageController _pageController = PageController(viewportFraction: 0.92);
  int _currentPage = 0;
  static const double _baseHeight = 290;

  @override
  void initState() {
    super.initState();
    _fetchLiveMatches();
  }

  Future<void> _fetchLiveMatches() async {
    try {
      final matches = await MatchService.fetchMatches(type: 'live', limit: 20);
      if (!mounted) return;
      setState(() {
        _matches = matches;
        _isLoading = false;
      });
      widget.onDataLoaded?.call(matches.isNotEmpty);
    } catch (e) {
      debugPrint("Error loading live matches: $e");
      if (mounted) setState(() => _isLoading = false);
      widget.onDataLoaded?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildShimmerLoader();
    if (_matches.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textScale = MediaQuery.of(context).textScaleFactor;
    final double cardHeight =
    (_baseHeight + (textScale - 1.0) * 52).clamp(280.0, 340.0);

    return Column(
      children: [
        SizedBox(
          height: cardHeight,
          child: PageView.builder(
            controller: _pageController,
            itemCount: min(_matches.length, _visibleCount),
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final match = _matches[index];
              final isActive = index == _currentPage;

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullMatchDetail(matchId: match.matchId),
                  ),
                ),
                child: AnimatedScale(
                  scale: isActive ? 1.0 : 0.97,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
                      border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black12),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.20)
                              : Colors.blue.withValues(alpha: 0.10),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMatchHeader(match),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  match.tournamentName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _chip(
                                icon: Icons.schedule,
                                label: _formatDate(
                                    match.matchDate, match.matchTime),
                                context: context,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildTeamRow(
                            match.team1Logo,
                            match.team1Name,
                            match.team1Runs,
                            match.team1Wickets,
                            match.team1Overs,
                            match.team1Balls,
                          ),
                          const SizedBox(height: 8),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          _buildTeamRow(
                            match.team2Logo,
                            match.team2Name,
                            match.team2Runs,
                            match.team2Wickets,
                            match.team2Overs,
                            match.team2Balls,
                          ),
                          const SizedBox(height: 8),
                          if (match.toss.isNotEmpty || match.result.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: (isDark
                                    ? Colors.white
                                    : Colors.black)
                                    .withValues(alpha: 0.04),
                                border: Border.all(
                                    color: isDark
                                        ? Colors.white12
                                        : Colors.black12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (match.toss.isNotEmpty)
                                    Text(
                                      match.toss,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                        fontStyle: FontStyle.italic,
                                        color: isDark
                                            ? Colors.white60
                                            : Colors.black87,
                                      ),
                                    ),
                                  if (match.result.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        match.result,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white70
                                              : null,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
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
        SmoothPageIndicator(
          controller: _pageController,
          count: min(_matches.length, _visibleCount),
          effect: WormEffect(
            dotHeight: 8,
            dotWidth: 8,
            spacing: 8,
            activeDotColor:
            isDark ? Colors.white : Colors.blue.shade600,
            dotColor:
            isDark ? Colors.grey.shade700 : Colors.grey.shade400,
          ),
        ),
      ],
    );
  }

  // ---- helpers ----
  Widget _buildShimmerLoader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlight = isDark ? Colors.grey[700]! : Colors.grey[100]!;
    return SizedBox(
      height: _baseHeight - 20,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: base,
            highlightColor: highlight,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.88,
              margin:
              const EdgeInsets.only(right: 12, top: 12, bottom: 12),
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

  Widget _buildMatchHeader(MatchModel match) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Text(
            match.matchName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: isDark ? Colors.white : Colors.blue.shade800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const LiveBadge(), // kept lightweight badge
      ],
    );
  }

  Widget _buildTeamRow(
      String logo,
      String name,
      int runs,
      int wickets,
      int overs,
      int balls,
      ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        _teamLogo(logo, name),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        _scoreChip("$runs/$wickets", context),
        const SizedBox(width: 8),
        _oversChip("($overs.$balls)", context),
      ],
    );
  }

  Widget _teamLogo(String url, String name) {
    final initials = name
        .split(' ')
        .where((e) => e.isNotEmpty)
        .map((e) => e[0])
        .join()
        .toUpperCase();

    const w = 36.0;

    return Container(
      width: w,
      height: w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border:
        Border.all(color: Colors.white.withValues(alpha: 0.65), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: ClipOval(
        child: isHttpUrl(url)
            ? safeNetworkImage(
          url,
          width: w,
          height: w,
          cacheWidth: 96,
          cacheHeight: 96,
        )
            : Container(
          color: Colors.blueGrey,
          alignment: Alignment.center,
          child: Text(
            (initials.length > 3 ? initials.substring(0, 3) : initials),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                    color: Colors.black26,
                    offset: Offset(0, 1),
                    blurRadius: 1)
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required BuildContext context,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border:
        Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isDark ? Colors.white70 : Colors.black54),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreChip(String text, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context)
            .colorScheme
            .primary
            .withValues(alpha: 0.08),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white12
              : Colors.blue.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _oversChip(String text, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white70 : Colors.black87,
        ),
      ),
    );
  }

  String _formatDate(String date, String time) {
    try {
      final matchDateTime =
      DateFormat('yyyy-MM-dd HH:mm:ss').parse('$date $time');
      return DateFormat('dd MMM yyyy, hh:mm a').format(matchDateTime);
    } catch (_) {
      return "$date $time";
    }
  }
}
