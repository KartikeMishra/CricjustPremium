// lib/screen/match_summary_tab.dart
import 'package:flutter/material.dart';
import '../screen/player_info.dart';
import '../utils/image_utils.dart';
import '../widget/scoreboard_card.dart';

class MatchSummaryTab extends StatefulWidget {
  final Map<String, dynamic> summary;
  final Map<String, dynamic> matchData;
  final int matchId;

  /// Called when user pulls to refresh on this tab.
  final Future<void> Function()? onRefresh;

  const MatchSummaryTab({
    super.key,
    required this.matchId,
    required this.summary,
    required this.matchData,
    this.onRefresh,
  });

  @override
  State<MatchSummaryTab> createState() => _MatchSummaryTabState();
}

class _MatchSummaryTabState extends State<MatchSummaryTab>
    with TickerProviderStateMixin {
  AnimationController? _fadeSlide;

  @override
  void initState() {
    super.initState();
    _fadeSlide = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
  }

  @override
  void dispose() {
    _fadeSlide?.dispose();
    super.dispose();
  }

  Color _textColor(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark ? Colors.white : Colors.black87;
  Color _subTextColor(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark ? Colors.white70 : Colors.black54;

  bool _nonEmpty(String? s) => s != null && s != 'null' && s.trim().isNotEmpty;

  // ---------- Helpers ----------
  bool _isFinished(Map<String, dynamic> md) {
    final result = (md['match_result'] ?? '').toString().trim();
    if (result.isNotEmpty) return true;
    final status = (md['status'] ?? md['match_status'] ?? '').toString().toLowerCase();
    return status == 'finished' || status == 'completed' || status == 'result' || status == '2';
  }

  Map<String, dynamic>? _asMap(dynamic v) {
    if (v is Map) {
      try {
        return Map<String, dynamic>.from(v);
      } catch (_) {
        // fallback: keep dynamic map
        return Map<String, dynamic>.from(
          v.map((k, val) => MapEntry(k.toString(), val)),
        );
      }
    }
    return null;
  }

  Widget _awardTile({
    required IconData icon,
    required Color color,
    required String title,
    required Map<String, dynamic>? data,
    String? subtitle,
  }) {
    if (data == null) return const SizedBox.shrink();
    final name = (data['name'] ?? data['Display_Name'] ?? '').toString().trim();
    if (name.isEmpty) return const SizedBox.shrink();

    final img = (data['player_image'] ?? data['image_url'] ?? '').toString();
    final id = int.tryParse((data['player_id'] ?? data['user_id'] ?? '').toString()) ?? 0;

    final trailing = (subtitle ?? '').trim().isEmpty
        ? null
        : Text(
      subtitle!,
      style: TextStyle(
        fontWeight: FontWeight.w800,
        color: color,
      ),
    );

    return InkWell(
      onTap: id > 0
          ? () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlayerPublicInfoTab(playerId: id)),
      )
          : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF121212)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white12
                : Colors.black12.withOpacity(.06),
          ),
          boxShadow: [
            if (Theme.of(context).brightness != Brightness.dark)
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: safeNetworkImage(
                img,
                width: 40,
                height: 40,
                cacheWidth: 96,
                cacheHeight: 96,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _textColor(context),
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _awardsSection(Map<String, dynamic> summary) {
    final motm = _asMap(summary['motm']);
    final sotm = _asMap(summary['sotm']);
    final gmotm = _asMap(summary['gmotm']);
    final fmotm = _asMap(summary['fmotm']);

    // Build subtitles for the three specialty awards if present
    final sotmSub = (sotm?['strike_rate'] != null) ? 'SR: ${sotm!['strike_rate']}' : null;
    final gmotmSub = (gmotm?['wickets_runs'] != null) ? '${gmotm!['wickets_runs']}' : null;
    final fmotmSub = (fmotm?['mvp_points'] != null) ? '${fmotm!['mvp_points']} pts' : null;

    // If nothing to show, return empty
    if (motm == null && sotm == null && gmotm == null && fmotm == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(.08)
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.emoji_events_rounded,
                size: 18,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : const Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Awards',
              style: TextStyle(
                color: _textColor(context),
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Awards list
        _awardTile(
          icon: Icons.emoji_events_rounded,
          color: const Color(0xFFEDB800),
          title: 'Man of the Match',
          data: motm,
        ),
        _awardTile(
          icon: Icons.speed_rounded,
          color: const Color(0xFF0EA5E9),
          title: 'Striker of the Match',
          data: sotm,
          subtitle: sotmSub,
        ),
        _awardTile(
          icon: Icons.sports_cricket_rounded,
          color: const Color(0xFF22C55E),
          title: 'Golden Arm of the Match',
          data: gmotm,
          subtitle: gmotmSub,
        ),
        _awardTile(
          icon: Icons.local_fire_department_rounded,
          color: const Color(0xFFEF4444),
          title: 'Fighter of the Match',
          data: fmotm,
          subtitle: fmotmSub,
        ),
      ],
    );
  }

  // ---------- Stat card helpers (unchanged) ----------
  Widget _statPill(String label, {bool highlight = false}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.only(right: 6, top: 6),
      decoration: BoxDecoration(
        color: highlight
            ? (dark ? const Color(0xFF11334B) : const Color(0xFFE8F3FF))
            : (dark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F4F7)),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlight
              ? (dark ? const Color(0xFF1B5E85) : const Color(0xFFD6E8FF))
              : (dark ? Colors.white10 : Colors.black12),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          height: 1.0,
          color: highlight
              ? (dark ? const Color(0xFF9AD1FF) : const Color(0xFF0D47A1))
              : (dark ? Colors.white70 : Colors.black87),
        ),
      ),
    );
  }

  List<Widget> _buildBatterPills(Map data) {
    final pills = <Widget>[];
    final runs = (data['total_runs'] ?? data['runs'])?.toString();
    final balls = (data['total_balls'] ?? data['balls'])?.toString();
    final sr = data['sr']?.toString();
    final fours = (data['fours'] ?? data['4s'])?.toString();
    final sixes = (data['sixes'] ?? data['6s'])?.toString();

    if (_nonEmpty(runs)) pills.add(_statPill('R: $runs', highlight: true));
    if (_nonEmpty(balls)) pills.add(_statPill('B: $balls'));
    if (_nonEmpty(sr)) pills.add(_statPill('SR: $sr'));
    if (_nonEmpty(fours)) pills.add(_statPill('4s: $fours'));
    if (_nonEmpty(sixes)) pills.add(_statPill('6s: $sixes'));
    return pills;
  }

  List<Widget> _buildBowlerPills(Map data) {
    final pills = <Widget>[];
    final ov = (data['overs'] ?? data['ov'])?.toString();
    final wk = (data['wickets'] ?? data['wkts'] ?? data['Total_Wicket'])?.toString();
    final rn = (data['runs'] ?? data['conceded'])?.toString();
    final ec = (data['ec'] ?? data['econ'] ?? data['economy'])?.toString();

    if (_nonEmpty(wk)) pills.add(_statPill('Wkts: $wk', highlight: true));
    if (_nonEmpty(ov)) pills.add(_statPill('Ov: $ov'));
    if (_nonEmpty(rn)) pills.add(_statPill('R: $rn'));
    if (_nonEmpty(ec)) pills.add(_statPill('Econ: $ec'));
    return pills;
  }

  Widget _playerCard(Map data) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final name = (data['name'] ?? data['Display_Name'] ?? 'N/A').toString();
    final team = (data['team_name'] ?? '').toString();
    final img = (data['player_image'] ?? data['image_url'] ?? '').toString();
    final pts = data['points']?.toString();
    final id = int.tryParse((data['player_id'] ?? data['user_id'] ?? data['id'] ?? '').toString()) ?? 0;

    final isBatter =
        data.containsKey('sr') || data.containsKey('total_runs') || data.containsKey('total_balls');
    final pills = isBatter ? _buildBatterPills(data) : _buildBowlerPills(data);

    return InkWell(
      onTap: id > 0
          ? () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlayerPublicInfoTab(playerId: id)),
      )
          : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF121212) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (!dark)
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
          ],
          border: Border.all(color: dark ? Colors.white10 : Colors.black.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: safeNetworkImage(
                img,
                width: 56,
                height: 56,
                cacheWidth: 128,
                cacheHeight: 128,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _textColor(context), fontWeight: FontWeight.w800, fontSize: 16)),
                  if (team.isNotEmpty)
                    Text(team,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _subTextColor(context), fontSize: 12.5)),
                  if (pills.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(children: pills),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (_nonEmpty(pts))
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF0D3A65) : const Color(0xFFE8F3FF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: dark ? const Color(0xFF0E5CA8) : const Color(0xFFD6E8FF)),
                  ),
                  child: Text('$pts pts',
                      style: TextStyle(
                        color: dark ? const Color(0xFF9CD0FF) : const Color(0xFF0D47A1),
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      )),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Map> items,
      {String emptyText = 'No data available.'}) {
    final Animation<Offset> slide = _fadeSlide == null
        ? const AlwaysStoppedAnimation<Offset>(Offset.zero)
        : Tween<Offset>(begin: const Offset(0, .05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _fadeSlide!, curve: Curves.easeOut));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(.08)
                    : const Color(0xFFEFF4FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : const Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: _textColor(context),
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, color: _subTextColor(context)),
                const SizedBox(width: 8),
                Text(emptyText, style: TextStyle(color: _subTextColor(context))),
              ],
            ),
          )
        else
          SlideTransition(
            position: slide,
            child: Column(
              children: List.generate(items.length, (i) => _playerCard(items[i])),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Safe-unpack
    final t1 = (widget.matchData['team_1'] as Map<String, dynamic>? ?? {});
    final t2 = (widget.matchData['team_2'] as Map<String, dynamic>? ?? {});
    final result = (widget.matchData['match_result'] ?? '').toString().trim();
    final toss = (widget.matchData['match_toss'] ?? '').toString().trim();

    final leftName = (t1['team_name'] ?? 'Team A').toString();
    final rightName = (t2['team_name'] ?? 'Team B').toString();
    final leftLogo = (t1['team_logo'] ?? '').toString();
    final rightLogo = (t2['team_logo'] ?? '').toString();
    final leftScore = '${t1['total_runs'] ?? 0}/${t1['total_wickets'] ?? 0}';
    final rightScore = '${t2['total_runs'] ?? 0}/${t2['total_wickets'] ?? 0}';
    final leftOvers = (t1['overs_done'] ?? 0).toString();
    final rightOvers = (t2['overs_done'] ?? 0).toString();

    final tpBatters =
    (widget.summary['tp_batters'] as List<dynamic>? ?? []).whereType<Map>().toList();
    final tpBowlers =
    (widget.summary['tp_bowlers'] as List<dynamic>? ?? []).whereType<Map>().toList();

    // MVP map or list
    final mvpRaw = widget.summary['mvp'];
    final List<Map> _mvpSource = (mvpRaw is List)
        ? mvpRaw.whereType<Map>().toList()
        : (mvpRaw is Map ? mvpRaw.values.whereType<Map>().toList() : <Map>[]);

    // 🚫 filter out entries where points < 0 (keep 0 and positives, and entries with no points)
    final mvpList = _mvpSource.where((m) {
      final ptsStr = m['points']?.toString();
      final pts = ptsStr == null ? null : double.tryParse(ptsStr);
      return pts == null || pts >= 0;
    }).toList();

    final finished = _isFinished(widget.matchData);

    return RefreshIndicator(
      onRefresh: () async {
        if (widget.onRefresh != null) await widget.onRefresh!();
      },
      color: Theme.of(context).colorScheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScoreboardCard(
              leftName: leftName,
              rightName: rightName,
              leftScore: leftScore,
              rightScore: rightScore,
              leftOvers: leftOvers,
              rightOvers: rightOvers,
              leftLogo: leftLogo,
              rightLogo: rightLogo,
              result: result,
              toss: toss,
            ),

            // ⬇️ Show awards only after match finished and only if any award exists
            if (finished) ...[
              const SizedBox(height: 12),
              _awardsSection(widget.summary),
            ],

            const SizedBox(height: 12),
            Divider(color: Theme.of(context).dividerColor),
            const SizedBox(height: 10),

            _section('Top Batters', Icons.bolt_rounded, tpBatters,
                emptyText: 'No batter stats available.'),
            const SizedBox(height: 12),
            Divider(color: Theme.of(context).dividerColor),
            const SizedBox(height: 10),

            _section('Top Bowlers', Icons.sports_cricket_rounded, tpBowlers,
                emptyText: 'No bowler stats available.'),
            const SizedBox(height: 12),
            Divider(color: Theme.of(context).dividerColor),
            const SizedBox(height: 10),

            _section('MVP Points', Icons.emoji_events_rounded, mvpList,
                emptyText: 'No MVP data available.'),
          ],
        ),
      ),
    );
  }
}
