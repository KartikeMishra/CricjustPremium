
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../model/match_commentary_model.dart';
import '../service/match_commentary_service.dart';

class MatchCommentaryTab extends StatelessWidget {
  final int matchId;
  final int team1Id;
  final int team2Id;
  final String team1Name;
  final String team2Name;

  const MatchCommentaryTab({
    super.key,
    required this.matchId,
    required this.team1Id,
    required this.team2Id,
    required this.team1Name,
    required this.team2Name,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  color: const Color(0xFF1976D2),
                  borderRadius: BorderRadius.circular(30),
                ),
                indicatorColor: Colors.transparent,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                splashFactory: NoSplash.splashFactory,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF1976D2),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(
                    child: FittedBox(
                      child: Row(
                        children: [
                          const Icon(Icons.sports_cricket, size: 16),
                          const SizedBox(width: 6),
                          Text(team1Name),
                        ],
                      ),
                    ),
                  ),
                  Tab(
                    child: FittedBox(
                      child: Row(
                        children: [
                          const Icon(Icons.sports_cricket_outlined, size: 16),
                          const SizedBox(width: 6),
                          Text(team2Name),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _CommentaryList(matchId: matchId, teamId: team1Id),
                _CommentaryList(matchId: matchId, teamId: team2Id),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverGroup {
  final int over;
  final List<Map<String, dynamic>> balls = [];
  _OverGroup({required this.over});
}

class _CommentaryList extends StatefulWidget {
  final int matchId;
  final int teamId;

  const _CommentaryList({required this.matchId, required this.teamId});

  @override
  State<_CommentaryList> createState() => _CommentaryListState();
}

class _CommentaryListState extends State<_CommentaryList> {
  final ScrollController _ctr = ScrollController();
  final List<CommentaryItem> _items = [];
  int _skipBalls = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    print('📋 Commentary for Match ID: ${widget.matchId}, Team ID: ${widget.teamId}');
    _ctr.addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    _ctr.removeListener(_onScroll);
    _ctr.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_isLoading &&
        _hasMore &&
        _ctr.position.pixels >= _ctr.position.maxScrollExtent - 50) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final page = await MatchCommentaryService.fetchCommentary(
        matchId: widget.matchId,
        teamId: widget.teamId,
        limit: _pageSize,
        skip: _skipBalls,
      );

      int ballsReturned = 0;
      for (var it in page) {
        final data = it.commentryPerBall;
        if (data is Map) ballsReturned += data.values.length;
        if (data is List) ballsReturned += data.length;
      }

      setState(() {
        _items.addAll(page);
        _skipBalls += ballsReturned;
        _hasMore = ballsReturned == _pageSize;
      });
    } catch (_) {
      setState(() => _error = 'Failed to load commentary');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<_OverGroup> _groupByOver() {
    final map = <int, _OverGroup>{};
    final seenBalls = <String>{};

    for (var item in _items) {
      final overNum = item.overNumber ?? 0;
      final group = map.putIfAbsent(overNum, () => _OverGroup(over: overNum));
      final cpb = item.commentryPerBall;

      if (cpb is Map) {
        for (var value in cpb.values) {
          if (value is Map<String, dynamic>) {
            final key = '${value['over_number']}.${value['ball_number']}';
            if (seenBalls.add(key)) group.balls.add(value);
          }
        }
      } else if (cpb is List) {
        for (var value in cpb) {
          if (value is Map<String, dynamic>) {
            final key = '${value['over_number']}.${value['ball_number']}';
            if (seenBalls.add(key)) group.balls.add(value);
          }
        }
      }
    }

    for (var g in map.values) {
      g.balls.sort((a, b) {
        final aN = int.tryParse(a['ball_number'].toString()) ?? 0;
        final bN = int.tryParse(b['ball_number'].toString()) ?? 0;
        return bN.compareTo(aN); // 👈 reverse order: 6 → 1
      });
    }

    final result = map.values.toList();
    result.sort((a, b) => b.over.compareTo(a.over));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _items.isEmpty) return _buildShimmer();
    if (_error != null && _items.isEmpty) return _buildError();
    if (!_isLoading && _items.isEmpty) return _buildNoData();

    final groups = _groupByOver();

    return ListView.builder(
      controller: _ctr,
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: groups.length + (_hasMore ? 1 : 0),
      itemBuilder: (ctx, idx) {
        if (idx == groups.length) return _buildLoader();
        return OverCard(group: groups[idx]);
      },
    );
  }

  Widget _buildShimmer() => ListView.builder(
    controller: _ctr,
    itemCount: 4,
    itemBuilder: (_, __) => Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: const ListTile(
        leading: CircleAvatar(radius: 18, backgroundColor: Colors.white),
        title: SizedBox(
          height: 14,
          child: DecoratedBox(decoration: BoxDecoration(color: Colors.white)),
        ),
      ),
    ),
  );

  Widget _buildError() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_error!, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 8),
        ElevatedButton(onPressed: _loadMore, child: const Text('Retry')),
      ],
    ),
  );

  Widget _buildNoData() =>
      const Center(child: Text('No commentary available.'));
  Widget _buildLoader() => _isLoading
      ? const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        )
      : const SizedBox.shrink();
}

class OverCard extends StatelessWidget {
  final _OverGroup group;
  const OverCard({super.key, required this.group});

  Color _ballColor(String badge) {
    final b = badge.toLowerCase();
    if (b == 'wd') return Colors.orange;
    if (b == 'nb') return Colors.pinkAccent;
    if (b.endsWith('b')) return Colors.yellow;
    if (b == 'w') return Colors.red;

    final n = int.tryParse(b);
    if (n != null) {
      switch (n) {
        case 0:
          return Colors.grey;
        case 1:
          return Colors.blue;
        case 2:
          return Colors.purple;
        case 4:
          return Colors.green;
        case 6:
          return Colors.lightGreen;
      }
    }
    return Colors.black26;
  }

  @override
  Widget build(BuildContext context) {

    final badges = group.balls.map((e) {
      final raw = (e['commentry'] ?? '').toString();
      final plainText = raw.replaceAll(RegExp(r'<[^>]*>'), '').toLowerCase();

      if (plainText.contains('wide')) return 'wd';
      if (plainText.contains('no ball')) return 'nb';
      if (plainText.contains('bye')) return 'b';
      if (plainText.contains('wicket') || plainText.contains('caught') || plainText.contains('run out')) return 'w';
      if (plainText.contains('6 run')) return '6';
      if (plainText.contains('4 run')) return '4';

      final m = RegExp(r'(\d+)\s+runs?').firstMatch(plainText);
      return m != null ? m.group(1)! : '0';
    }).toList();


    final runs = badges.fold<int>(0, (s, b) => s + (int.tryParse(b) ?? 0));
    final wkts = badges.where((b) => b == 'w').length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Over ${group.over}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: badges.map((b) {
                final color = _ballColor(b);
                return Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    b.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              'This over: $runs runs, $wkts wkts',
              style: const TextStyle(fontSize: 12),
            ),
            ...group.balls.map((e) {
              final text = (e['commentry'] ?? '').toString().replaceAll(
                RegExp(r'<[^>]*>'),
                '',
              );
              final ballNum = '${e['over_number']}.${e['ball_number']}';
              final lowerText = text.toLowerCase();
              final isWkt =
                  lowerText.contains('wicket') || lowerText.contains('caught');
              final isBoundary =
                  lowerText.contains('4 runs') || lowerText.contains('6 runs');
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    ballNum,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                title: Text(
                  text.trim(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: (isWkt || isBoundary)
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isWkt
                        ? Colors.red
                        : isBoundary
                        ? Colors.green
                        : Theme.of(context).textTheme.bodyMedium?.color ??
                              Colors.black87,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
