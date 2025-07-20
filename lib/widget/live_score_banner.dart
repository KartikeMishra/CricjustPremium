import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:shimmer/shimmer.dart';

import '../model/match_model.dart';
import '../service/match_service.dart';
import '../screen/full_match_detail.dart';

class LiveMatchesSection extends StatefulWidget {
  const LiveMatchesSection({super.key});

  @override
  State<LiveMatchesSection> createState() => _LiveMatchesSectionState();
}

class _LiveMatchesSectionState extends State<LiveMatchesSection> {
  List<MatchModel> _matches = [];
  bool _isLoading = true;
  final PageController _pageController = PageController(viewportFraction: 0.92);
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _fetchLiveMatches();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveMatches() async {
    try {
      final matches = await MatchService.fetchMatches(type: 'live', limit: 20);
      if (!mounted) return;
      setState(() {
        _matches = matches;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading live matches: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    if (_isLoading) return _buildShimmerLoader(cardColor);
    if (_matches.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 260,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _matches.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final match = _matches[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FullMatchDetail(matchId: match.matchId),
                    ),
                  );
                },
                child: Card(
                  color: cardColor,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMatchHeader(match, textColor),
                        const SizedBox(height: 4),
                        Text(
                          match.tournamentName,
                          style: TextStyle(
                            color: textColor.withOpacity(0.85),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Date: ${_formatDate(match.matchDate, match.matchTime)}",
                          style: TextStyle(color: textColor, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        _buildTeamRow(
                          match.team1Logo,
                          match.team1Name,
                          match.team1Runs,
                          match.team1Wickets,
                          match.team1Overs,
                          match.team1Balls,
                          textColor,
                        ),
                        const SizedBox(height: 6),
                        _buildTeamRow(
                          match.team2Logo,
                          match.team2Name,
                          match.team2Runs,
                          match.team2Wickets,
                          match.team2Overs,
                          match.team2Balls,
                          textColor,
                        ),
                        const SizedBox(height: 6),
                        if (match.toss.isNotEmpty)
                          Text(
                            match.toss,
                            style: TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 13,
                            ),
                          ),
                        Text(
                          match.result,
                          style: TextStyle(color: textColor.withOpacity(0.9)),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: SmoothPageIndicator(
            controller: _pageController,
            count: _matches.length,
            effect: WormEffect(
              dotHeight: 8,
              dotWidth: 8,
              spacing: 8,
              activeDotColor: Theme.of(context).colorScheme.primary,
              dotColor: Colors.grey,
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildMatchHeader(MatchModel match, Color textColor) {
    return Row(
      children: [
        Expanded(
          child: Text(
            match.matchName,
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.redAccent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            "LIVE",
            style: TextStyle(color: Colors.white, fontSize: 10),
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
    Color textColor,
  ) {
    return Row(
      children: [
        _teamLogo(logo, name),
        const SizedBox(width: 8),
        Expanded(
          child: Text(name, style: TextStyle(color: textColor)),
        ),
        Text(
          "$runs/$wickets",
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ),
        Text(
          " ($overs.$balls)",
          style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12),
        ),
      ],
    );
  }

  Widget _teamLogo(String url, String name) {
    if (url.isNotEmpty) {
      return CircleAvatar(
        radius: 14,
        backgroundColor: Colors.grey.shade200,
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
      radius: 14,
      backgroundColor: bgColor,
      child: Text(
        initials.length > 4 ? initials.substring(0, 4) : initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildShimmerLoader(Color baseColor) {
    return SizedBox(
      height: 240,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: baseColor.withOpacity(0.4),
            highlightColor: Colors.grey.shade100,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
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
