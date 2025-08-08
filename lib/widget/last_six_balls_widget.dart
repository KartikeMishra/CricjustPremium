import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../service/match_score_service.dart';

class LastSixBallsWidget extends StatefulWidget {
  final int matchId;
  final int teamId;
  final Duration? autoRefreshEvery;
  final bool showHeading;
  final double ballSize;
  final Listenable? refresher;

  const LastSixBallsWidget({
    Key? key,
    required this.matchId,
    required this.teamId,
    this.autoRefreshEvery,
    this.showHeading = true,
    this.ballSize = 36,
    this.refresher,
  }) : super(key: key);

  @override
  State<LastSixBallsWidget> createState() => _LastSixBallsWidgetState();
}

class _LastSixBallsWidgetState extends State<LastSixBallsWidget> {
  late Future<List<Map<String, dynamic>>> _future;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _maybeStartTimer();
    widget.refresher?.addListener(_onExternalRefresh);
  }

  @override
  void didUpdateWidget(covariant LastSixBallsWidget old) {
    super.didUpdateWidget(old);
    if (old.matchId != widget.matchId || old.teamId != widget.teamId) {
      _future = _load();
    }
    if (old.autoRefreshEvery != widget.autoRefreshEvery) {
      _maybeStartTimer();
    }
    if (old.refresher != widget.refresher) {
      old.refresher?.removeListener(_onExternalRefresh);
      widget.refresher?.addListener(_onExternalRefresh);
    }
  }

  void _maybeStartTimer() {
    _timer?.cancel();
    if (widget.autoRefreshEvery != null && widget.autoRefreshEvery!.inMilliseconds > 0) {
      _timer = Timer.periodic(widget.autoRefreshEvery!, (_) {
        if (!mounted) return;
        setState(() {
          _future = _load();
        });
      });
    }
  }

  void _onExternalRefresh() {
    if (!mounted) return;
    setState(() {
      _future = _load();
    });
  }

  Future<List<Map<String, dynamic>>> _load() async {
    // 🔍 DEBUG: print what parameters we’re using
    debugPrint('⚙️ LastSixBallsWidget._load(): matchId=${widget.matchId}, teamId=${widget.teamId}');

    try {
      final data = await MatchScoreService.fetchLastSixBalls(
        matchId: widget.matchId,
        teamId: widget.teamId,
      );
      debugPrint('🔍 LastSixBalls raw data: $data');
      return data.take(6).toList();
    } catch (e, st) {
      debugPrint('🔴 Error loading last balls: $e\n$st');
      return [];
    }
  }

  String _label(Map<String, dynamic> ball) {
    final isWicket = ball['is_wicket'] == 1;
    final isExtra  = ball['is_extra']  == 1;
    final runs     = int.tryParse(ball['runs']?.toString() ?? '')      ?? 0;
    final extraRun = int.tryParse(ball['extra_run']?.toString() ?? '') ?? 0;

    if (isWicket) return 'W';

    if (isExtra) {
      // Normalize and uppercase the incoming type
      final rawType = (ball['extra_run_type']?.toString() ?? '').trim().toUpperCase();
      String core;
      switch (rawType) {
        case 'WD':
        case 'WIDE':
          core = 'WD';
          break;
        case 'NB':
        case 'NOBALL':
        case 'NO BALL':
          core = 'NB';
          break;
        case 'LB':
        case 'LEG BYE':
          core = 'Lb';
          break;
        case 'B':
        case 'BYE':
          core = 'B';
          break;
        default:
          core = rawType; // fallback in case something else comes
      }

      final extraPart = extraRun > 0 ? extraRun.toString() : '';
      final runPart   = runs    > 0 ? '+$runs'          : '';
      final label     = '$extraPart$core$runPart';

      debugPrint('🏷️ _label: rawType=$rawType → label=$label');
      return label;
    }

    return runs == 0 ? '•' : runs.toString();
  }


  Color _getBallColor(String v) {
    final value = v.toUpperCase();
    if (value == 'W')       return Colors.redAccent;
    if (value.contains('WD')) return Colors.orange;      // now matches "WD"
    if (value.contains('NB')) return Colors.deepOrange;
    if (value.contains('B')  || value.contains('LB')) return Colors.amber.shade700;
    if (value == '6')       return Colors.green.shade600;
    if (value == '4')       return Colors.blue.shade600;
    if (value == '0' || value == '•') return Colors.grey.shade600;
    return Colors.teal;
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.refresher?.removeListener(_onExternalRefresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _buildSkeleton(context);
        }

        final balls  = snap.data ?? [];
        final labels = balls.map(_label).toList().reversed.toList();

        // Fill up to 6 with dots
        while (labels.length < 6) {
          labels.insert(0, '•');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showHeading)
              const Text('Last 6 Balls', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (widget.showHeading) const SizedBox(height: 8),
            // … inside FutureBuilder’s builder, after computing `labels` …

            Row(
              children: List.generate(labels.length, (i) {
                final lbl   = labels[i];
                final color = _getBallColor(lbl);
                final isLast = i == labels.length - 1;  // true for the 6th ball

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: IntrinsicWidth(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(isLast ? 0.2 : 0.1),       // stronger bg on last ball
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: color,
                          width: isLast ? 2.0 : 1.2,                       // thicker border on last ball
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(isLast ? 0.25 : 0.15),
                            blurRadius: isLast ? 6 : 4,                     // bigger glow on last ball
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Center(
                        child: Text(
                          lbl,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),

          ],
        );
      },
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final baseColor = Theme.of(context).dividerColor.withOpacity(0.2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeading)
          const Text('Last 6 Balls', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        if (widget.showHeading) const SizedBox(height: 8),
        Row(
          children: List.generate(6, (_) {
            return Container(
              width: widget.ballSize,
              height: widget.ballSize,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(shape: BoxShape.circle, color: baseColor),
            );
          }),
        ),
      ],
    );
  }
}
