// lib/widget/matches_section.dart
//
// ONE WIDGET for Live / Recent / Upcoming with a single, consistent card layout.
// Usage:
//   MatchesSection(mode: MatchesMode.live)
//   MatchesSection(mode: MatchesMode.recent)
//   MatchesSection(mode: MatchesMode.upcoming)

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../model/match_model.dart';
import '../service/match_service.dart';
import '../screen/full_match_detail.dart';

enum MatchesMode { live, recent, upcoming }

class MatchesSection extends StatefulWidget {
  final MatchesMode mode;
  final void Function(bool hasData)? onDataLoaded;

  const MatchesSection({
    super.key,
    required this.mode,
    this.onDataLoaded,
  });

  @override
  State<MatchesSection> createState() => _MatchesSectionState();
}

class _MatchesSectionState extends State<MatchesSection> {
  // Fuller width like the reference UI
  final PageController _pageController = PageController(viewportFraction: 0.94);
  static const int _visibleCount = 5;

  List<MatchModel> _matches = [];
  bool _isLoading = true;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final type = switch (widget.mode) {
        MatchesMode.live => 'live',
        MatchesMode.recent => 'recent',
        MatchesMode.upcoming => 'upcoming',
      };
      final matches = await MatchService.fetchMatches(type: type, limit: 20);
      if (!mounted) return;
      setState(() {
        _matches = matches;
        _isLoading = false;
      });
      widget.onDataLoaded?.call(matches.isNotEmpty);
    } catch (e) {
      debugPrint('Error loading ${widget.mode} matches: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      widget.onDataLoaded?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) return _buildShimmerLoader();
    if (_matches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text(
          widget.mode == MatchesMode.live
              ? 'No live matches right now'
              : widget.mode == MatchesMode.upcoming
              ? 'No upcoming matches'
              : 'No recent matches',
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    // Headroom to avoid overflow on larger fonts
    final textScale = MediaQuery.of(context).textScaleFactor;
    final base = 230.0;
    final extra = (textScale - 1.0) * 100.0;
    final cardHeight = (base + extra).clamp(340.0, 460.0);

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
              return AnimatedScale(
                scale: isActive ? 1.0 : 0.97,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: _MatchCard(
                  match: match,
                  mode: widget.mode,
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
              activeDotColor: const Color(0xFF3B82F6),                 // strong blue
              dotColor:
              isDark ? Colors.white24 : const Color(0xFFD5E3FF),    // pale blue
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildShimmerLoader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF232323) : const Color(0xFFECEFF4);
    final highlight = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F7FA);

    return SizedBox(
      height: 320, // match card silhouette
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: base,
            highlightColor: highlight,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.90,
              margin: const EdgeInsets.only(right: 12, top: 12, bottom: 12),
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Card
// -----------------------------------------------------------------------------

class _MatchCard extends StatelessWidget {
  final MatchModel match;
  final MatchesMode mode;

  const _MatchCard({required this.match, required this.mode});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FullMatchDetail(matchId: match.matchId),
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24), // chunkier like ref UI
          gradient: isDark
              ? null
              : const LinearGradient(
            colors: [Color(0xFFEEF4FF), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          color: isDark ? const Color(0xFF1A1C1F) : null,
          // soft shadow instead of border
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B82F6).withOpacity(0.12),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min, // shrink if needed
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      match.matchName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900, // a bit heavier
                        fontSize: 17.5,
                        color: isDark
                            ? Colors.white
                            : Colors.blueGrey.shade800,
                      ),
                    ),
                  ),
                  if (mode == MatchesMode.live) const _LivePill(),
                ],
              ),
              const SizedBox(height: 10),

              // Tournament + date chip
              Row(
                children: [
                  Expanded(
                    child: Text(
                      match.tournamentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white70
                            : Colors.black.withOpacity(0.8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (mode != MatchesMode.recent)
                    _chip(
                      icon: Icons.schedule_rounded,
                      label: mode == MatchesMode.live
                          ? _formatDate(match.matchDate, match.matchTime)
                          : _timeLeft(match.matchDate, match.matchTime),
                      context: context,
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Teams
              _TeamRow(
                logo: match.team1Logo,
                name: match.team1Name,
                score: mode == MatchesMode.upcoming
                    ? null
                    : _formatScore(match.team1Runs, match.team1Wickets),
                overs: mode == MatchesMode.upcoming
                    ? null
                    : _formatOvers(match.team1Overs, match.team1Balls),
              ),
              const SizedBox(height: 8),
              if (mode != MatchesMode.upcoming) const Divider(height: 1),
              if (mode != MatchesMode.upcoming) const SizedBox(height: 8),
              _TeamRow(
                logo: match.team2Logo,
                name: match.team2Name,
                score: mode == MatchesMode.upcoming
                    ? null
                    : _formatScore(match.team2Runs, match.team2Wickets),
                overs: mode == MatchesMode.upcoming
                    ? null
                    : _formatOvers(match.team2Overs, match.team2Balls),
              ),
              const SizedBox(height: 12),

              // Info strips (shrinkable + capped height)
              if (mode == MatchesMode.live &&
                  (match.toss.isNotEmpty || match.result.isNotEmpty))
                Flexible(
                  fit: FlexFit.loose,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 56),
                    child: _InfoStrip(children: [
                      if (match.toss.isNotEmpty)
                        Text(
                          match.toss,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: isDark
                                ? Colors.white60
                                : Colors.black87,
                          ),
                        ),
                      if (match.result.isNotEmpty)
                        Text(
                          match.result,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white70
                                : Colors.black87,
                          ),
                        ),
                    ]),
                  ),
                ),

              if (mode == MatchesMode.recent && match.result.isNotEmpty)
                Flexible(
                  fit: FlexFit.loose,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 56),
                    child: _InfoStrip(children: [
                      Text(
                        'Result: ${match.result}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                        Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white70
                              : Colors.black87,
                        ),
                      ),
                    ]),
                  ),
                ),

              if (mode == MatchesMode.upcoming)
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Starts: ${_timeLeft(match.matchDate, match.matchTime)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                        Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? Colors.white70
                              : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Sub-widgets & helpers
// -----------------------------------------------------------------------------

class _TeamRow extends StatelessWidget {
  final String logo;
  final String name;
  final String? score;
  final String? overs;

  const _TeamRow({
    required this.logo,
    required this.name,
    this.score,
    this.overs,
  });

  @override
  Widget build(BuildContext context) {
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
        if (score != null) _scoreChip(score!, context),
        if (overs != null) ...[
          const SizedBox(width: 8),
          _oversChip(overs!, context),
        ],
      ],
    );
  }
}

class _InfoStrip extends StatelessWidget {
  final List<Widget> children;
  const _InfoStrip({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

// Green LIVE pill (reference look)
class _LivePill extends StatelessWidget {
  const _LivePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF34C759), // iOS-style green
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          _LiveDot(color: Colors.white),
          SizedBox(width: 6),
          Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  final Color color;
  const _LiveDot({this.color = const Color(0xFF34C759)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8, height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
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
      color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isDark ? Colors.white12 : const Color(0xFFCCE0FF),
      ),
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
  final c = Theme.of(context);
  final isDark = c.brightness == Brightness.dark;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      color: isDark ? const Color(0xFF2A2D32) : const Color(0xFFEFF6FF),
      border: Border.all(
        color: isDark ? Colors.white12 : const Color(0xFFCCE0FF),
      ),
    ),
    child: Text(
      text,
      style: c.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w800,
        color: isDark ? Colors.white : Colors.blueGrey.shade800,
      ),
    ),
  );
}

Widget _oversChip(String text, BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      color:
      isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
      border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
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

Widget _teamLogo(String url, String name) {
  const w = 36.0;
  if (url.isNotEmpty) {
    return Container(
      width: w,
      height: w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.65), width: 1),
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
  final bg = _colorFromSeed(name);
  return CircleAvatar(
    radius: 18,
    backgroundColor: bg,
    child: Text(
      initials.length > 3 ? initials.substring(0, 3) : initials,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 1),
        ],
      ),
    ),
  );
}

Color _colorFromSeed(String seed) {
  final hash = seed.hashCode;
  final r = 100 + (hash & 0xFF) % 155;
  final g = 100 + ((hash >> 8) & 0xFF) % 155;
  final b = 100 + ((hash >> 16) & 0xFF) % 155;
  return Color.fromARGB(255, r, g, b);
}

String _formatScore(dynamic runs, dynamic wkts) {
  try {
    final r = int.tryParse(runs.toString()) ?? 0;
    final w = int.tryParse(wkts.toString()) ?? 0;
    return '$r/$w';
  } catch (_) {
    return '$runs/$wkts';
  }
}

String _formatOvers(dynamic overs, dynamic balls) {
  try {
    final o = int.tryParse(overs.toString()) ?? 0;
    final b = int.tryParse(balls.toString()) ?? 0;
    return '(${o}.${b.clamp(0, 6)})';
  } catch (_) {
    return '($overs.$balls)';
  }
}

String _formatDate(String date, String time) {
  try {
    final dt = DateFormat('yyyy-MM-dd HH:mm:ss').parse('$date $time');
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  } catch (_) {
    return '$date $time';
  }
}

String _timeLeft(String date, String time) {
  try {
    final dt = DateFormat('yyyy-MM-dd HH:mm:ss').parse('$date $time');
    final diff = dt.difference(DateTime.now());
    if (diff.inSeconds < 0) return 'Starting Soon';
    if (diff.inDays > 0) return '${diff.inDays} day(s) left';
    if (diff.inHours > 0) return '${diff.inHours % 24} hour(s) left';
    return '${diff.inMinutes % 60} minute(s) left';
  } catch (_) {
    return '';
  }
}
