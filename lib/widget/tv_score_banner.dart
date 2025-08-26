import 'dart:async';

import 'package:flutter/material.dart';
import '../service/match_score_service.dart';

class TVStyleScoreScreen extends StatefulWidget {
  final String teamName;
  final int runs;
  final int wickets;
  final double overs;
  final int extras;
  final int matchId;
  final int teamId;
  final bool isLive;
  final Duration refreshInterval;

  const TVStyleScoreScreen({
    super.key,
    required this.teamName,
    required this.runs,
    required this.wickets,
    required this.overs,
    required this.extras,
    required this.matchId,
    required this.teamId,
    this.isLive = true,
    this.refreshInterval = const Duration(seconds: 10),
  });

  @override
  _TVStyleScoreScreenState createState() => _TVStyleScoreScreenState();
}

class _TVStyleScoreScreenState extends State<TVStyleScoreScreen> {
  String _lastBallLabel = '•';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchAndCompute();
    _timer = Timer.periodic(widget.refreshInterval, (_) => _fetchAndCompute());
  }

  Future<void> _fetchAndCompute() async {
    try {
      final raw = await MatchScoreService.fetchLastSixBalls(
        matchId: widget.matchId,
        teamId: widget.teamId,
      );

      final newLabel = _computeLastBallLabel(raw);
      if (!mounted) return;

      // detect “big moments” by comparing old vs new code
      final oldCode = _extractCode(_lastBallLabel);
      final newCode = _extractCode(newLabel);

      if (newCode != oldCode) {
        // fire-and-forget (don’t block UI). If you prefer to wait, add `await`.
        if (newCode == '6') _showMoment('SIX!', Colors.green);
        if (newCode == '4') _showMoment('FOUR!', Colors.purple);
        // optional:
        if (newCode == 'W') _showMoment('WICKET', Colors.redAccent);
      }

      setState(() => _lastBallLabel = newLabel);
    } catch (_) {
      // ignore errors, keep previous label
    }
  }


  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final match = RegExp(r'^(\d*)([A-Za-z]+)$').firstMatch(_lastBallLabel);
    final count = match?.group(1) ?? '';
    final code = match?.group(2)?.toUpperCase() ?? _lastBallLabel.toUpperCase();

    final display = code;
    final color = _getBallColor(display);
    final isBoundary = display == '4' || display == '6';
    final isExtra = ['WD', 'NB', 'B', 'LB'].contains(display);
    final scoreText =
        "${widget.teamName}  ${widget.runs}-${widget.wickets}  ${widget.overs.toStringAsFixed(1)}";

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: 360,
            height: 260,
            decoration: BoxDecoration(
              gradient: isBoundary
                  ? LinearGradient(
                colors: display == '6'
                    ? [Colors.green.shade400, Colors.green.shade900]
                    : [Colors.purple.shade300, Colors.deepPurple.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
                  : LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E1E1E), Colors.black]
                    : [Colors.white, Colors.blue.shade50],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: isBoundary
                      ? color.withValues(alpha: 0.6)
                      : Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: 4,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: isBoundary ? color : Colors.blueAccent.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      if (widget.isLive)
                        Positioned(
                          top: 12,
                          right: 16,
                          child: Row(
                            children: const [
                              Icon(Icons.circle, size: 10, color: Colors.redAccent),
                              SizedBox(width: 4),
                              Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Last Ball',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // 🎯 AnimatedSwitcher for glowing ball
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 500),
                              transitionBuilder: (child, anim) => ScaleTransition(
                                scale: Tween(begin: 0.8, end: 1.2).animate(
                                  CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                                ),
                                child: child,
                              ),
                              child: Container(
                                key: ValueKey<String>(_lastBallLabel),
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      color.withValues(alpha: 0.8),
                                      color,
                                      color.withValues(alpha: 0.8),
                                    ],
                                    center: Alignment.center,
                                    radius: 0.9,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.7),
                                      blurRadius: isBoundary ? 20 : 10,
                                      spreadRadius: isBoundary ? 6 : 2,
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  display,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            if (isExtra && count.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                '× $count',
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
// Scorebar  ✅ REPLACE THIS WHOLE Container WITH THE ONE BELOW
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isDark
                        ? LinearGradient(
                      colors: [Colors.blueGrey.shade900, Colors.black87],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    )
                        : LinearGradient(
                      colors: [Colors.blue.shade100, Colors.white],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: team name (single line) + score + overs
                      Row(
                        children: [
                          // Team name — one line only
                          Expanded(
                            child: Text(
                              widget.teamName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Score
                          Text(
                            '${widget.runs}-${widget.wickets}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Overs
                          Text(
                            '${widget.overs.toStringAsFixed(1)} ov',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white70 : Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      // Optional: Extras on a second line
                      if (widget.extras > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Extras: ${widget.extras}',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.amber : Colors.deepOrange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // TV Stand
          Container(
            width: 80,
            height: 10,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade800,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  String _extractCode(String label) {
    // returns '6', '4', 'W', 'WD', 'NB', 'B', 'LB', etc.
    final m = RegExp(r'([A-Za-z]+|\d+)').allMatches(label);
    if (m.isEmpty) return label.toUpperCase();
    // prefer letters if present, else the number (for 4/6)
    final letters = RegExp(r'[A-Za-z]+').stringMatch(label);
    return (letters ?? label).toUpperCase();
  }

  OverlayEntry? _momentOverlay;

  void _hideMoment() {
    _momentOverlay?.remove();
    _momentOverlay = null;
  }

  void _showMoment(String text, Color color) {
    if (!mounted) return;

    // remove any previous popup
    _hideMoment();

    final overlay = Overlay.of(context, rootOverlay: true);

    _momentOverlay = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: Stack(
          children: [
            // subtle dim
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: 0.08)),
            ),
            // centered badge
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.9, end: 1.0),
                duration: const Duration(milliseconds: 200),
                builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 24, spreadRadius: 4),
                    ],
                  ),
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    overlay.insert(_momentOverlay!);

    // auto-remove after ~900 ms
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      _hideMoment();
    });
  }

  static String _computeLastBallLabel(List<Map<String, dynamic>> raw) {
    if (raw.isEmpty) return '•';
    final e = raw.first;
    final isWicket = e['is_wicket'] == 1;
    final isExtra  = e['is_extra'] == 1;
    final runs     = int.tryParse('${e['runs']}') ?? 0;
    final extraRun = int.tryParse('${e['extra_run'] ?? 0}') ?? 0;
    final typeRaw  = (e['extra_run_type'] ?? '').toString().toUpperCase().trim();

    if (isWicket) return 'W';
    if (isExtra) {
      String core;
      switch (typeRaw) {
        case 'WD':
        case 'WIDE':    core = 'WD'; break;
        case 'NB':     core = 'NB'; break;
        case 'B':      core = 'B';  break;
        case 'LB':     core = 'LB'; break;
        default:       core = typeRaw;
      }
      final extraPart = extraRun > 0 ? extraRun.toString() : '';
      return '$extraPart$core';
    }
    return runs == 0 ? '•' : runs.toString();
  }

  static Color _getBallColor(String code) {
    switch (code) {
      case 'W':   return Colors.red;
      case '4':   return Colors.purple;
      case '6':   return Colors.green;
      case 'WD':  return Colors.orange;
      case 'NB':  return Colors.deepOrange;
      case 'B':   return Colors.cyan;
      case 'LB':  return Colors.lightBlue;
      default:    return Colors.blueGrey;
    }
  }
}
