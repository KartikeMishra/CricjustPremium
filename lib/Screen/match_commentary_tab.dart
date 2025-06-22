import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../model/match_commentary_model.dart';
import '../service/match_commentary_service.dart';

/// Two-team commentary tabs with infinite scroll and proper over grouping
class MatchCommentaryTab extends StatelessWidget {
  final int matchId;
  final int team1Id;
  final int team2Id;
  final String team1Name;
  final String team2Name;

  const MatchCommentaryTab({
    Key? key,
    required this.matchId,
    required this.team1Id,
    required this.team2Id,
    required this.team1Name,
    required this.team2Name,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(25),
            ),
            child: TabBar(
              indicator: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(25),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Theme.of(context).primaryColor,
              tabs: [
                Tab(text: team1Name),
                Tab(text: team2Name),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _CommentaryList(
                  key: PageStorageKey('comm_${team1Id}'),
                  matchId: matchId,
                  teamId: team1Id,
                ),
                _CommentaryList(
                  key: PageStorageKey('comm_${team2Id}'),
                  matchId: matchId,
                  teamId: team2Id,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentaryList extends StatefulWidget {
  final int matchId;
  final int teamId;

  const _CommentaryList({
    Key? key,
    required this.matchId,
    required this.teamId,
  }) : super(key: key);

  @override
  __CommentaryListState createState() => __CommentaryListState();
}

class __CommentaryListState extends State<_CommentaryList> {
  static const int _pageSize = 10;
  final ScrollController _ctr = ScrollController();
  final List<CommentaryItem> _items = [];
  int _skipBalls = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
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
    if (!_isLoading && _hasMore &&
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
      int balls = 0;
      for (var it in page) {
        final data = it.commentryPerBall;
        if (data is Map) balls += data.values.length;
        if (data is List) balls += data.length;
      }
      setState(() {
        _items.addAll(page);
        _skipBalls += balls;
        _hasMore = balls == _pageSize;
      });
    } catch (_) {
      setState(() {
        _error = 'Failed to load commentary';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildShimmer() {
    return ListView.builder(
      controller: _ctr,
      itemCount: 4,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: const ListTile(
          leading: SizedBox(
            width: 30,
            height: 30,
            child: DecoratedBox(
              decoration: BoxDecoration(color: Colors.white),
            ),
          ),
          title: SizedBox(
            height: 14,
            child: DecoratedBox(
              decoration: BoxDecoration(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _error!,
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _loadMore,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoData() {
    return const Center(
      child: Text('No commentary available.'),
    );
  }

  Widget _buildLoader() {
    return _isLoading
        ? const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator()),
    )
        : const SizedBox.shrink();
  }

  List<_OverGroup> _groupByOver() {
    final map = <int, _OverGroup>{};

    for (var item in _items) {
      final ov = item.overNumber;
      if (ov == null) continue;
      map.putIfAbsent(ov, () => _OverGroup(over: ov));
      final grp = map[ov]!;

      if (item.tillOver != null && grp.bowler.isEmpty) {
        grp.bowler = item.tillOver!.bowler?.name ?? '-';
        grp.striker = item.tillOver!.batters?.striker?.name ?? '-';
        grp.nonStriker =
            item.tillOver!.batters?.nonStriker?.name ?? '-';
      }

      final data = item.commentryPerBall;
      if (data is Map) grp.balls.addAll(data.values);
      if (data is List) grp.balls.addAll(data);
    }

    final nameRegex = RegExp(
      r'^([A-Za-z ]+?)(?=\s+\d|\s+wide|\s+with|\$)',
      caseSensitive: false,
    );

    for (var grp in map.values) {
      if ((grp.bowler.isEmpty || grp.striker.isEmpty) && grp.balls.isNotEmpty) {
        final raw0 =
            grp.balls.first['commentry']?.toString() ?? '';
        final clean0 = raw0
            .replaceAll(RegExp(r'<[^>]*>'), '')
            .trim();
        final parts = clean0.split(' to ');
        if (parts.length > 1) {
          grp.bowler = parts[0].trim();
          final rest = parts[1];
          final m = nameRegex.firstMatch(rest);
          if (m != null) grp.striker = m.group(1)!.trim();
        }
      }
      if (grp.nonStriker.isEmpty && grp.balls.isNotEmpty) {
        final names = <String>{};
        for (var e in grp.balls) {
          final r = e['commentry']?.toString() ?? '';
          final c = r
              .replaceAll(RegExp(r'<[^>]*>'), '')
              .trim();
          final parts = c.split(' to ');
          if (parts.length > 1) {
            final m = nameRegex.firstMatch(parts[1]);
            if (m != null) names.add(m.group(1)!.trim());
          }
        }
        names.remove(grp.striker);
        if (names.isNotEmpty) grp.nonStriker = names.first;
      }
    }

    final groups = map.values.toList()
      ..sort((a, b) => b.over.compareTo(a.over));
    for (var grp in groups) {
      grp.balls.sort((a, b) {
        final ai = int.tryParse(a['ball_number']?.toString() ?? '') ?? 0;
        final bi = int.tryParse(b['ball_number']?.toString() ?? '') ?? 0;
        return bi.compareTo(ai);
      });
    }
    return groups;
  }

  Widget _buildBallTile(dynamic e) {
    final raw = e['commentry']?.toString() ?? '';
    final clean = raw.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    final low = clean.toLowerCase();
    final isW = low.contains('wicket') ||
        low.contains('caught') ||
        low.contains('lbw');
    final isB = clean.contains('4 runs') ||
        clean.contains('6 runs');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor:
          Theme.of(context).primaryColor,
          child: Text(
            '\${e["over_number"]}.\${e["ball_number"]}',
            style: const TextStyle(
                fontSize: 12, color: Colors.white),
          ),
        ),
        title: Text(
          clean,
          style: TextStyle(
            fontSize: 14,
            fontWeight:
            isB ? FontWeight.bold : FontWeight.normal,
            color: isW ? Colors.red : Colors.black,
          ),
        ),
      ),
    );
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
        final grp = groups[idx];
        return Card(
          margin:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Over \${grp.over}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  'Bowler: \${grp.bowler}',
                  style:
                  const TextStyle(fontSize: 12),
                ),
                Text(
                  'Striker: \${grp.striker}',
                  style:
                  const TextStyle(fontSize: 12),
                ),
                Text(
                  'Non-Striker: \${grp.nonStriker}',
                  style:
                  const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                ...grp.balls.map(_buildBallTile),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OverGroup {
  final int over;
  String bowler = '';
  String striker = '';
  String nonStriker = '';
  final List<dynamic> balls = [];

  _OverGroup({required this.over});
}