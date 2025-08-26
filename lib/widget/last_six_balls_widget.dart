import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import '../service/match_score_service.dart';

class LastSixBallsWidget extends StatefulWidget {
  final int matchId;
  final int teamId;
  final Duration? autoRefreshEvery;
  final bool showHeading;
  final double ballSize;
  final Listenable? refresher;

  const LastSixBallsWidget({
    super.key,
    required this.matchId,
    required this.teamId,
    this.autoRefreshEvery,
    this.showHeading = true,
    this.ballSize = 36,
    this.refresher,
  });

  @override
  State<LastSixBallsWidget> createState() => _LastSixBallsWidgetState();
}

class _LastSixBallsWidgetState extends State<LastSixBallsWidget> {
  // ✅ fix 1: correct generics and allow reassignment later
  late Future<List<Map<String, dynamic>>> _bootstrapFuture;

  // ✅ fix 2: typed empty list to avoid inference issues
  List<Map<String, dynamic>> _lastData = const <Map<String, dynamic>>[];
  String? _lastDigest;

  Timer? _timer;
  Timer? _debounce;
  bool _inFlight = false;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _loadOnce();
    _maybeStartTimer();
    widget.refresher?.addListener(_onExternalRefresh);
  }

  @override
  void didUpdateWidget(covariant LastSixBallsWidget old) {
    super.didUpdateWidget(old);

    if (old.matchId != widget.matchId || old.teamId != widget.teamId) {
      setState(() {
        _lastData = const <Map<String, dynamic>>[];
        _lastDigest = null;
        _bootstrapFuture = _loadOnce(); // allowed because it's not final
      });
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
    final d = widget.autoRefreshEvery;
    if (d != null && d.inMilliseconds > 0) {
      _timer = Timer.periodic(d, (_) => _silentRefresh());
      _silentRefresh();
    }
  }

  void _onExternalRefresh() {
    if (!mounted) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _silentRefresh);
  }

  Future<List<Map<String, dynamic>>> _loadOnce() async {
    dev.Timeline.startSync('last-six-balls bootstrap');
    try {
      final data = await MatchScoreService.fetchLastSixBalls(
        matchId: widget.matchId,
        teamId: widget.teamId,
      );
      final six = data.take(6).toList();
      _lastData = six;
      _lastDigest = _digest(six);
      return six;
    } catch (e, st) {
      debugPrint('🔴 LastSixBalls bootstrap error: $e\n$st');
      return const <Map<String, dynamic>>[];
    } finally {
      dev.Timeline.finishSync();
    }
  }

  Future<void> _silentRefresh() async {
    if (!mounted || _inFlight) return;
    _inFlight = true;
    dev.Timeline.startSync('last-six-balls refresh');
    try {
      final data = await MatchScoreService.fetchLastSixBalls(
        matchId: widget.matchId,
        teamId: widget.teamId,
      );
      final six = data.take(6).toList();
      final dig = _digest(six);
      if (dig != _lastDigest) {
        _lastDigest = dig;
        if (mounted) setState(() => _lastData = six);
      }
    } catch (e, st) {
      debugPrint('🔴 LastSixBalls refresh error: $e\n$st');
    } finally {
      _inFlight = false;
      dev.Timeline.finishSync();
    }
  }

  String _digest(List<Map<String, dynamic>> balls) {
    final buf = StringBuffer();
    for (final b in balls) {
      buf
        ..write(b['is_wicket'])
        ..write('|')
        ..write(b['is_extra'])
        ..write('|')
        ..write(b['extra_run_type'])
        ..write('|')
        ..write(b['runs'])
        ..write('|')
        ..write(b['extra_run'])
        ..write(';');
    }
    return buf.toString();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _debounce?.cancel();
    widget.refresher?.removeListener(_onExternalRefresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _bootstrapFuture,
      builder: (context, snap) {
        final waiting = snap.connectionState == ConnectionState.waiting;
        final balls = _lastData.isNotEmpty
            ? _lastData
            : (snap.data ?? const <Map<String, dynamic>>[]);

        if (balls.isEmpty && waiting) {
          return _buildSkeleton(context);
        }

        final labels = balls.map(_label).toList().reversed.toList();
        while (labels.length < 6) {
          labels.insert(0, '•');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showHeading)
              const Text('Last 6 Balls',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (widget.showHeading) const SizedBox(height: 8),
            RepaintBoundary(
              child: Row(
                children: List.generate(labels.length, (i) {
                  final lbl = labels[i];
                  final color = _getBallColor(lbl);
                  final isLast = i == labels.length - 1;

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: isLast ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                            color: color, width: isLast ? 2.0 : 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: isLast ? 0.25 : 0.15),
                            blurRadius: isLast ? 6 : 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        lbl,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        );
      },
    );
  }

  bool _isOne(dynamic v) => v == 1 || v?.toString() == '1';

  String _label(Map<String, dynamic> ball) {
    final isWicket = _isOne(ball['is_wicket']);
    final isExtra  = _isOne(ball['is_extra']);
    final runs     = int.tryParse(ball['runs']?.toString() ?? '') ?? 0;
    final extraRun = int.tryParse(ball['extra_run']?.toString() ?? '') ?? 0;

    if (isWicket) return 'W';

    if (isExtra) {
      final rawType = (ball['extra_run_type']?.toString() ?? '').trim().toUpperCase();
      String core;
      switch (rawType) {
        case 'WD':
        case 'WIDE': core = 'WD'; break;
        case 'NB':
        case 'NOBALL':
        case 'NO BALL': core = 'NB'; break;
        case 'LB':
        case 'LEG BYE': core = 'Lb'; break;
        case 'B':
        case 'BYE': core = 'B'; break;
        default: core = rawType;
      }
      // Hide the implicit single for WD/NB, keep numbers for 2+ wides/no-balls or other extras.
      final showNumber = (core == 'WD' || core == 'NB') ? (extraRun > 1) : (extraRun > 0);
      final extraPart = showNumber ? extraRun.toString() : '';
      final runPart   = runs > 0 ? '+$runs' : '';
      return '$extraPart$core$runPart';
    }

    return runs == 0 ? '•' : runs.toString();
  }


  Color _getBallColor(String v) {
    final value = v.toUpperCase();
    if (value == 'W') return Colors.redAccent;
    if (value.contains('WD')) return Colors.orange;
    if (value.contains('NB')) return Colors.deepOrange;
    if (value.contains('B') || value.contains('LB')) return Colors.amber.shade700;
    if (value == '6') return Colors.green.shade600;
    if (value == '4') return Colors.blue.shade600;
    if (value == '0' || value == '•') return Colors.grey.shade600;
    return Colors.teal;
  }

  Widget _buildSkeleton(BuildContext context) {
    final baseColor = Theme.of(context).dividerColor.withValues(alpha: 0.2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeading)
          const Text('Last 6 Balls',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        if (widget.showHeading) const SizedBox(height: 8),
        Row(
          children: List.generate(6, (_) {
            return Container(
              width: widget.ballSize,
              height: widget.ballSize,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: baseColor,
              ),
            );
          }),
        ),
      ],
    );
  }
}
