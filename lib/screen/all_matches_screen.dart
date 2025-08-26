import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../model/match_model.dart';
import '../screen/full_match_detail.dart';
import '../service/match_service.dart';
import '../theme/color.dart';
import '../theme/text_styles.dart';
import '../utils/image_utils.dart';

class AllMatchesScreen extends StatefulWidget {
  final String matchType; // recent, live, upcoming
  final String? title;

  const AllMatchesScreen({super.key, required this.matchType, this.title});

  @override
  State<AllMatchesScreen> createState() => _AllMatchesScreenState();
}

class _AllMatchesScreenState extends State<AllMatchesScreen> {
  final List<MatchModel> _matches = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  final int _limit = 20;
  int _skip = 0;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchAllMatches();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _fetchAllMatches();
    }
  }

  Future<void> _fetchAllMatches() async {
    if (_isLoadingMore || !_hasMore) return;
    if (mounted) setState(() => _isLoadingMore = true);

    try {
      final matches = await MatchService.fetchMatches(
        type: widget.matchType,
        limit: _limit,
        skip: _skip,
      );

      if (!mounted) return;
      setState(() {
        _matches.addAll(matches);
        _skip += _limit;
        _hasMore = matches.length == _limit;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor =
    isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.grey[100]!;

    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final cardShadow = isDark
        ? null
        : [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ];

    final subTextColor = isDark ? Colors.grey[300]! : Colors.black54;
    final titleTextColor = isDark ? Colors.white : Colors.white;

    final matchList = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _matches.isEmpty
        ? const Center(child: Text('No matches available'))
        : ListView.builder(
      controller: _scrollController,
      itemCount: _matches.length + (_hasMore ? 1 : 0),
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) {
        if (index >= _matches.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final match = _matches[index];
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    FullMatchDetail(matchId: match.matchId),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: cardShadow,
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(match),
                  const SizedBox(height: 4),
                  Text(
                    match.tournamentName,
                    style: AppTextStyles.tournamentName.copyWith(
                      color: isDark
                          ? Colors.white
                          : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  _buildDate(match.matchDate, match.matchTime),
                  const SizedBox(height: 6),
                  _buildTeamRow(
                    match.team1Logo,
                    match.team1Name,
                    match.team1Runs,
                    match.team1Wickets,
                    match.team1Overs,
                    match.team1Balls,
                    subTextColor,
                  ),
                  const SizedBox(height: 6),
                  _buildTeamRow(
                    match.team2Logo,
                    match.team2Name,
                    match.team2Runs,
                    match.team2Wickets,
                    match.team2Overs,
                    match.team2Balls,
                    subTextColor,
                  ),
                  if (match.toss.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      match.toss,
                      style: AppTextStyles.timeLeft.copyWith(
                        color: isDark
                            ? Colors.white70
                            : Colors.black54,
                      ),
                    ),
                  ],
                  if (match.result.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      match.result,
                      style: AppTextStyles.result.copyWith(
                        color:
                        isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );

    return Scaffold(
      backgroundColor: bgColor,
      appBar: widget.title != null
          ? PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: isDark
              ? const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
          )
              : const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: Text(
              widget.title!,
              style: TextStyle(
                color: titleTextColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            iconTheme: IconThemeData(color: titleTextColor),
          ),
        ),
      )
          : null,
      body: matchList,
    );
  }

  Widget _buildHeader(MatchModel match) {
    return Row(
      children: [
        Expanded(
          child: Text(
            match.matchName,
            style: AppTextStyles.matchTitle.copyWith(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (widget.matchType == 'live')
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.deepOrange,
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

  Widget _buildDate(String date, String time) {
    try {
      final matchDateTime =
      DateFormat('yyyy-MM-dd HH:mm:ss').parse('$date $time');
      final formatted =
      DateFormat('dd MMM yyyy, hh:mm a').format(matchDateTime);
      return Text(
        formatted,
        style: AppTextStyles.matchTitle.copyWith(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white70
              : Colors.black87,
        ),
      );
    } catch (_) {
      return Text(
        '$date $time',
        style: AppTextStyles.matchTitle.copyWith(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white70
              : Colors.black87,
        ),
      );
    }
  }

  Widget _buildTeamRow(
      String logo,
      String name,
      int runs,
      int wickets,
      int overs,
      int balls,
      Color subTextColor,
      ) {
    return Row(
      children: [
        _teamLogo(logo, name),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            style: AppTextStyles.teamName.copyWith(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            ),
          ),
        ),
        Text(
          "$runs/$wickets",
          style: AppTextStyles.score.copyWith(color: subTextColor),
        ),
        Text(
          " ($overs.$balls)",
          style: TextStyle(color: subTextColor, fontSize: 12),
        ),
      ],
    );
  }

  Widget _teamLogo(String url, String name) {
    if (isHttpUrl(url)) {
      // Wrap safeNetworkImage in ClipOval so we still get a circle + error fallback
      return CircleAvatar(
        radius: 14,
        backgroundColor: Colors.grey.shade200,
        child: ClipOval(
          child: safeNetworkImage(
            url,
            width: 28,
            height: 28,
            fit: BoxFit.cover,
            assetFallback: 'lib/asset/images/Random_Image.png',
          ),
        ),
      );
    }

    // Initials fallback
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
