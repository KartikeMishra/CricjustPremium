import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:shimmer/shimmer.dart';

import '../model/match_model.dart';
import '../service/match_service.dart';
import '../screen/full_match_detail.dart';

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

    return Column(
      children: [
        SizedBox(
          height: 270,
          child: PageView.builder(
            controller: _pageController,
            //   itemCount: _matches.length,
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
                    borderRadius: BorderRadius.circular(20),
                    gradient: isDark
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFFE3F2FD), Colors.white],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    color: isDark ? const Color(0xFF2A2A2A) : null,
                    boxShadow: isDark
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMatchHeader(match),
                            const SizedBox(height: 8),
                            Text(
                              match.tournamentName,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Date: ${_formatDate(match.matchDate, match.matchTime)}",
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[700],
                                    fontStyle: FontStyle.italic,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            _buildTeamRow(
                              match.team1Logo,
                              match.team1Name,
                              match.team1Runs,
                              match.team1Wickets,
                              match.team1Overs,
                              match.team1Balls,
                            ),
                            const SizedBox(height: 8),
                            _buildTeamRow(
                              match.team2Logo,
                              match.team2Name,
                              match.team2Runs,
                              match.team2Wickets,
                              match.team2Overs,
                              match.team2Balls,
                            ),
                            const Spacer(),
                            if (match.toss.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  match.toss,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        fontStyle: FontStyle.italic,
                                        color: isDark ? Colors.white60 : null,
                                      ),
                                ),
                              ),
                            if (match.result.isNotEmpty)
                              Text(
                                match.result,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.white70 : null,
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
        SmoothPageIndicator(
          controller: _pageController,
          count: min(_matches.length, _visibleCount),
          effect: WormEffect(
            dotHeight: 10,
            dotWidth: 10,
            spacing: 6,
            activeDotColor: isDark ? Colors.white : Colors.blue.shade600,
            dotColor: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerLoader() {
    final base = Colors.grey[300]!;
    final highlight = Colors.grey[100]!;

    return SizedBox(
      height: 240,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: base,
            highlightColor: highlight,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMatchHeader(MatchModel match) {
    return Row(
      children: [
        Expanded(
          child: Text(
            match.matchName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.blue.shade800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.redAccent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Text(
            "LIVE",
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
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
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        Text(
          "$runs/$wickets",
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          "($overs.$balls)",
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: isDark ? Colors.grey[400] : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _teamLogo(String url, String name) {
    if (url.isNotEmpty) {
      return CircleAvatar(
        radius: 18,
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
      radius: 18,
      backgroundColor: bgColor,
      child: Text(
        initials.length > 4 ? initials.substring(0, 4) : initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 1),
          ],
        ),
      ),
    );
  }

  String _formatDate(String date, String time) {
    try {
      final matchDateTime = DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).parse('$date $time');
      return DateFormat('dd MMM yyyy, hh:mm a').format(matchDateTime);
    } catch (_) {
      return "$date $time";
    }
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
