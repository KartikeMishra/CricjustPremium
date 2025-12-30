import 'package:flutter/material.dart';
import '../model/match_commentary_model.dart';
import '../service/match_commentary_service.dart';

class MatchCommentaryTab extends StatefulWidget {
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
  State<MatchCommentaryTab> createState() => _MatchCommentaryTabState();
}

enum CommFilter { all, wickets, boundaries, singles, doubles, extras }

class _MatchCommentaryTabState extends State<MatchCommentaryTab> {
  late int _selectedTeamId;

  // paging state
  int _skip = 0; // MUST advance by page size
  bool _isLoading = false;
  bool _isFirstLoad = true;
  bool _hasMore = true;
  final int _limit = 10; // backend expects 0,10,20,...

  final ScrollController _scroll = ScrollController();
  final List<CommEvent> _events = [];

  // filter state
  CommFilter _filter = CommFilter.all;

  @override
  void initState() {
    super.initState();
    _selectedTeamId = widget.team1Id;
    _scroll.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoading) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  // If the list can't scroll yet (page too short), fetch the next page automatically.
  void _maybeAutoload() {
    if (!_hasMore || _isLoading) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pos = _scroll.position;
      if (!pos.hasPixels || pos.maxScrollExtent <= 0 || pos.pixels >= pos.maxScrollExtent - 200) {
        _loadMore();
      }
    });
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isFirstLoad = true;
      _isLoading = true;
      _hasMore = true;
      _skip = 0; // reset offset on fresh load
      _events.clear();
    });

    try {
      final page = await CommentaryService.fetchPage(
        matchId: widget.matchId,
        teamId: _selectedTeamId,
        limit: _limit,
        skip: _skip,
      );

      setState(() {
        _events.addAll(page.events);
        _skip += _limit;                // 0 -> 10
        _hasMore = page.itemsCount > 0; // any non-empty page
      });

      _maybeAutoload(); // auto-fetch if the first page doesn't fill the screen
    } catch (_) {
      // Optional: show error UI
    } finally {
      if (mounted) {
        setState(() {
          _isFirstLoad = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    try {
      final page = await CommentaryService.fetchPage(
        matchId: widget.matchId,
        teamId: _selectedTeamId,
        limit: _limit,
        skip: _skip,
      );

      setState(() {
        // For occasional overlaps, you can dedupe here (commented).
        _events.addAll(page.events);
        _skip += _limit;                // 10 -> 20 -> 30 ...
        _hasMore = page.itemsCount > 0; // keep going while API returns items
      });

      _maybeAutoload(); // chain if still not scrollable / near bottom
    } catch (_) {
      // Optional: show error UI
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refresh() async => _loadInitial();

  void _switchTeam(int teamId) {
    if (_selectedTeamId == teamId) return;
    setState(() => _selectedTeamId = teamId);
    _loadInitial();
  }

  // ---------- Filtering helpers ----------

  // Detect non-wide / non-no-ball extras (Byes / Leg Byes) from commentary text
  final RegExp _reByes = RegExp(r'\b(leg\s*bye|byes?|lb)\b', caseSensitive: false);

  bool _isExtraNonWdNb(CommEvent e) {
    final t = e.text.toLowerCase();
    if (t.contains('lbw')) return false; // avoid "LBW" as "LB"
    return _reByes.hasMatch(t);
  }

  bool _matchesFilter(CommEvent e) {
    switch (_filter) {
      case CommFilter.all:
        return true;
      case CommFilter.wickets:
        return e.isWicket;
      case CommFilter.boundaries:
        return e.chip == '4' || e.chip == '6';
      case CommFilter.singles:
        return e.chip == '1' && !_isExtraNonWdNb(e) && !e.isWicket && !e.isWide && !e.isNoBall;
      case CommFilter.doubles:
        return e.chip == '2' && !_isExtraNonWdNb(e) && !e.isWicket && !e.isWide && !e.isNoBall;
      case CommFilter.extras:
        return e.isWide || e.isNoBall || _isExtraNonWdNb(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // First-load spinner
    if (_isFirstLoad) {
      return Column(
        children: [
          const SizedBox(height: 8),
          _teamSelector(isDark),
          const SizedBox(height: 8),
          _filterBar(isDark),
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    }

    // Group events by over, but apply the active filter
    final byOver = <int, List<CommEvent>>{};
    for (final e in _events) {
      if (_matchesFilter(e)) {
        byOver.putIfAbsent(e.over, () => <CommEvent>[]).add(e);
      }
    }
    final overs = byOver.keys.toList()..sort((a, b) => b.compareTo(a)); // latest over first

    final hasFilteredItems = overs.isNotEmpty;

    return Column(
      children: [
        const SizedBox(height: 8),
        _teamSelector(isDark),
        const SizedBox(height: 8),
        _filterBar(isDark),
        const SizedBox(height: 8),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: !hasFilteredItems
                ? _empty(_events.isEmpty ? 'No commentary yet' : 'No events match this filter')
                : NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is ScrollEndNotification) _onScroll();
                return false;
              },
              child: ListView.builder(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                itemCount: overs.length + 1, // +1 for footer
                itemBuilder: (_, i) {
                  if (i == overs.length) {
                    // Footer
                    if (_isLoading) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (!_hasMore) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text(
                            'No more commentary',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      );
                    }
                    return Center(
                      child: TextButton(
                        onPressed: _loadMore,
                        child: const Text('Load more'),
                      ),
                    );
                  }

                  final over = overs[i];
                  final list = byOver[over]!;
                  return _overCard(context, over, list, isDark);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------- UI bits ----------

  Widget _filterBar(bool isDark) {
    final items = <(CommFilter, String, IconData)>[
      (CommFilter.all,        'All',        Icons.filter_alt),
      (CommFilter.wickets,    'Wickets',    Icons.sports_cricket),
      (CommFilter.boundaries, 'Boundaries', Icons.flag),
      (CommFilter.singles,    'Singles',    Icons.looks_one),
      (CommFilter.doubles,    'Doubles',    Icons.looks_two),
      (CommFilter.extras,     'Extras',     Icons.add_circle_outline),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (final (value, label, icon) in items)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: _filter == value,
                onSelected: (_) => setState(() => _filter = value),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16),
                    const SizedBox(width: 6),
                    Text(label),
                  ],
                ),
                selectedColor: isDark ? Colors.blueGrey.shade600 : const Color(0xFF2196F3),
                labelStyle: TextStyle(
                  color: _filter == value
                      ? Colors.white
                      : (isDark ? Colors.grey[300] : const Color(0xFF1976D2)),
                  fontWeight: FontWeight.w700,
                ),
                backgroundColor: isDark ? const Color(0xFF161A22) : Colors.white,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: _filter == value
                        ? Colors.transparent
                        : (isDark ? Colors.white10 : Colors.black12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _teamSelector(bool isDark) {
    final t1Selected = _selectedTeamId == widget.team1Id;
    final t2Selected = _selectedTeamId == widget.team2Id;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161A22) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(.45)
                  : Colors.black.withOpacity(.07),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(6),
        child: Row(
          children: [
            Expanded(
              child: _teamPill(
                label: widget.team1Name,
                selected: t1Selected,
                isDark: isDark,
                onTap: () => _switchTeam(widget.team1Id),
              ),
            ),
            Expanded(
              child: _teamPill(
                label: widget.team2Name,
                selected: t2Selected,
                isDark: isDark,
                onTap: () => _switchTeam(widget.team2Id),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamPill({
    required String label,
    required bool selected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final gradient = selected
        ? (isDark
        ? [Colors.blueGrey.shade600, Colors.blueGrey.shade400]
        : [const Color(0xFF2196F3), const Color(0xFF1976D2)])
        : [Colors.transparent, Colors.transparent];

    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(30),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: selected
                ? Colors.white
                : (isDark ? Colors.grey[300] : const Color(0xFF1976D2)),
          ),
        ),
      ),
    );
  }

  Widget _empty(String msg) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        msg,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );

  Widget _overCard(
      BuildContext context,
      int over,
      List<CommEvent> events,
      bool isDark,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(.45)
                : Colors.black.withOpacity(.07),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + chips (use filtered events list)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Over $over',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _chipsRow(events, isDark)),
            ],
          ),
          const SizedBox(height: 10),

          // events (keep API order; no dedupe)
          Column(children: events.map((e) => _eventTile(e, isDark)).toList()),
        ],
      ),
    );
  }

  Widget _chipsRow(List<CommEvent> events, bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: events.map((e) {
        final (bg, border, fg) = _chipColors(e, isDark);
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: Text(
            e.chip,
            style: TextStyle(fontWeight: FontWeight.w800, color: fg),
          ),
        );
      }).toList(),
    );
  }

  Widget _eventTile(CommEvent e, bool isDark) {
    final badge = _badgeColor(e, isDark);
    final isSix = e.chip == '6';
    final isFour = e.chip == '4';
    final isExtraOther = _isExtraNonWdNb(e);

    final isHighlighted = e.isWicket || e.isWide || e.isNoBall || isSix || isFour || isExtraOther;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x151FFFFFF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Over.Ball badge
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: badge.withOpacity(.1),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: badge.withOpacity(.4)),
            ),
            child: Text(
              e.overDotBall,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: badge,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              e.text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: e.isWicket || isSix || isFour ? FontWeight.w800 : FontWeight.w600,
                color: isHighlighted
                    ? (isDark ? badge.withOpacity(.9) : badge)
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            decoration: BoxDecoration(
              color: badge.withOpacity(.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              e.chip,
              style: TextStyle(fontWeight: FontWeight.w900, color: badge),
            ),
          ),
        ],
      ),
    );
  }

  (Color bg, Color border, Color fg) _chipColors(CommEvent e, bool isDark) {
    // Classification for highlights
    final isSix = e.chip == '6';
    final isFour = e.chip == '4';
    final isExtraOther = _isExtraNonWdNb(e); // Byes/Leg Byes (not WD/NB)

    Color base;
    if (e.isWicket) {
      base = Colors.red;
    } else if (e.isWide) {
      base = Colors.purple;
    } else if (e.isNoBall) {
      base = Colors.pink;
    } else if (isSix) {
      base = Colors.green;   // SIX
    } else if (isFour) {
      base = Colors.teal;    // FOUR
    } else if (isExtraOther) {
      base = Colors.orange;  // Byes / Leg Byes
    } else {
      // neutral run (0/1/2/3)
      return (
      isDark ? Colors.white10 : Colors.black12,
      isDark ? Colors.white10 : Colors.black12,
      isDark ? Colors.white70 : Colors.black87
      );
    }

    return (base.withOpacity(.12), base.withOpacity(.4), base);
  }

  Color _badgeColor(CommEvent e, bool isDark) {
    final isSix = e.chip == '6';
    final isFour = e.chip == '4';
    final isExtraOther = _isExtraNonWdNb(e);

    if (e.isWicket) return Colors.red;
    if (e.isWide) return Colors.purple;
    if (e.isNoBall) return Colors.pink;
    if (isSix) return Colors.green;         // SIX
    if (isFour) return Colors.teal;         // FOUR
    if (isExtraOther) return Colors.orange; // Byes / Leg Byes

    return isDark ? Colors.blueGrey : Colors.blue;
  }
}
