import 'dart:async';
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
    Key? key,
    required this.matchId,
    required this.teamId,
    this.autoRefreshEvery,
    this.showHeading = true,
    this.ballSize = 36,
    this.refresher,
  }) : super(key: key);

  @override
  _LastSixBallsWidgetState createState() => _LastSixBallsWidgetState();
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

  void _onExternalRefresh() {
    if (!mounted) return;
    setState(() {
      _future = _load();
    });
  }

  void _maybeStartTimer() {
    _timer?.cancel();
    if (widget.autoRefreshEvery != null && widget.autoRefreshEvery!.inMilliseconds > 0) {
      _timer = Timer.periodic(widget.autoRefreshEvery!, (_) async {
        if (!mounted) return;
        final newFuture = _load();
        setState(() {
          _future = newFuture;
        });
      });
    }
  }

  Future<List<Map<String, dynamic>>> _load() async {
    try {
      final data = await MatchScoreService.fetchLastSixBalls(
        matchId: widget.matchId,
        teamId: widget.teamId,
      );
      debugPrint('📦 LastSixBalls → ${data.length} entries');
      return data.take(6).toList();
    } catch (e, st) {
      debugPrint('🔴 Error loading last balls: $e\n$st');
      return [];
    }
  }

  String _label(Map<String, dynamic> ball) {
    final isWicket = ball['is_wicket'] == 1;
    final isExtra = ball['is_extra'] == 1;
    final runs = int.tryParse(ball['runs'].toString()) ?? 0;
    final extraRun = int.tryParse(ball['extra_run']?.toString() ?? '1') ?? 1;
    final type = (ball['extra_run_type'] ?? '').toString().toUpperCase();

    if (isWicket) return 'W';

    if (isExtra) {
      if (type == 'WD') return '${extraRun > 1 ? extraRun.toString() : ''}Wd';
      if (type == 'NB') return '${extraRun > 1 ? extraRun.toString() : ''}Nb';
      if (type == 'LB') return '${extraRun > 1 ? extraRun.toString() : ''}Lb';
      if (type == 'B') return '${extraRun > 1 ? extraRun.toString() : ''}B';
      return 'Ex';
    }

    return runs.toString();
  }

  Color _getBallColor(String v) {
    final value = v.toUpperCase();
    if (value == 'W') return Colors.redAccent;
    if (value.contains('WD') || value.contains('NB')) return Colors.orange;
    if (value == '6') return Colors.green;
    if (value == '4') return Colors.blue;
    if (value == '0') return Colors.grey.shade600;
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

        final List<Map<String, dynamic>> balls = snap.hasError
            ? <Map<String, dynamic>>[]
            : (snap.data as List<Map<String, dynamic>>? ?? <Map<String, dynamic>>[]);

        final List<String> labels = balls.reversed.map((ball) => _label(ball)).toList();

        while (labels.length < 6) {
          labels.insert(0, '0');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showHeading)
              const Text(
                'Last 6 Balls',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            if (widget.showHeading) const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: labels.map((lbl) {
                final color = _getBallColor(lbl);
                return Container(
                  width: widget.ballSize,
                  height: widget.ballSize,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.12),
                    border: Border.all(color: color, width: 1.4),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    lbl,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                );
              }).toList(),
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
