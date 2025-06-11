import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../model/match_model.dart';
import '../service/match_service.dart';
import '../screen/match_detail_screen.dart';
import '../theme/color.dart';
import '../theme/text_styles.dart';

class AllMatchesScreen extends StatefulWidget {
  final String matchType; // recent, live, upcoming
  final String? title; // Optional: Only show AppBar if provided

  const AllMatchesScreen({
    super.key,
    required this.matchType,
    this.title,
  });

  @override
  State<AllMatchesScreen> createState() => _AllMatchesScreenState();
}

class _AllMatchesScreenState extends State<AllMatchesScreen> {
  List<MatchModel> _matches = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _limit = 20;
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
    setState(() => _isLoadingMore = true);
    try {
      final matches = await MatchService.fetchMatches(
        type: widget.matchType,
        limit: _limit,
        skip: _skip,
      );
      setState(() {
        _matches.addAll(matches);
        _skip += _limit;
        _hasMore = matches.length == _limit;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      print("Error fetching ${widget.matchType} matches: $e");
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                builder: (_) => MatchDetailScreen(matchId: match.matchId),
              ),
            );
          },
          child: Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: AppColors.cardBackground,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(match),
                  const SizedBox(height: 4),
                  Text(
                    match.tournamentName,
                    style: AppTextStyles.tournamentName,
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
                  ),
                  const SizedBox(height: 6),
                  _buildTeamRow(
                    match.team2Logo,
                    match.team2Name,
                    match.team2Runs,
                    match.team2Wickets,
                    match.team2Overs,
                    match.team2Balls,
                  ),
                  if (match.toss.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(match.toss, style: AppTextStyles.timeLeft),
                  ],
                  if (match.result.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(match.result, style: AppTextStyles.result),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );

    return widget.title != null
        ? Scaffold(appBar: AppBar(title: Text(widget.title!)), body: matchList)
        : matchList;
  }

  Widget _buildHeader(MatchModel match) {
    return Row(
      children: [
        Expanded(
          child: Text(
            match.matchName,
            style: AppTextStyles.matchTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (widget.matchType == 'live')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.deepOrange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text("LIVE", style: TextStyle(color: Colors.white, fontSize: 10)),
          ),
      ],
    );
  }

  Widget _buildDate(String date, String time) {
    try {
      final matchDateTime = DateFormat('yyyy-MM-dd HH:mm:ss').parse('$date $time');
      final formatted = DateFormat('dd MMM yyyy, hh:mm a').format(matchDateTime);
      return Text(formatted, style: AppTextStyles.matchTitle);
    } catch (_) {
      return Text('$date $time', style: AppTextStyles.matchTitle);
    }
  }

  Widget _buildTeamRow(String logo, String name, int runs, int wickets, int overs, int balls) {
    return Row(
      children: [
        _teamLogo(logo, name),
        const SizedBox(width: 8),
        Expanded(
          child: Text(name, style: AppTextStyles.teamName),
        ),
        Text("$runs/$wickets", style: AppTextStyles.score),
        Text(" (${overs}.${balls})", style: const TextStyle(color: Colors.black54, fontSize: 12)),
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
    final initials = name.split(' ').where((e) => e.isNotEmpty).map((e) => e[0]).join().toUpperCase();
    final bgColor = _getRandomColor(name);
    return CircleAvatar(
      radius: 14,
      backgroundColor: bgColor,
      child: Text(
        initials.length > 4 ? initials.substring(0, 4) : initials,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Color _getRandomColor(String seed) {
    final hash = seed.hashCode;
    final rng = Random(hash);
    return Color.fromARGB(255, 100 + rng.nextInt(155), 100 + rng.nextInt(155), 100 + rng.nextInt(155));
  }
}
