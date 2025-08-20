import 'dart:ui';
import 'package:cricjust_premium/screen/ui_graphics.dart';
import 'package:flutter/material.dart';
import '../screen/player_info.dart';
import '../widget/scoreboard_card.dart';

class MatchSummaryTab extends StatefulWidget {
  final Map<String, dynamic> summary;
  final Map<String, dynamic> matchData;
  final int matchId;

  const MatchSummaryTab({
    super.key,
    required this.matchId,
    required this.summary,
    required this.matchData,
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
      duration: const Duration(milliseconds: 420),
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

  // ---------- Scoreboard header (now using GlassPanel) ----------
  Widget _matchHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final t1 = widget.matchData['team_1'] as Map<String, dynamic>? ?? {};
    final t2 = widget.matchData['team_2'] as Map<String, dynamic>? ?? {};
    final result = (widget.matchData['match_result'] ?? '').toString().trim();
    final toss   = (widget.matchData['match_toss'] ?? '').toString().trim();

    final t1Name  = (t1['team_name'] ?? 'Team A').toString();
    final t2Name  = (t2['team_name'] ?? 'Team B').toString();
    final t1Logo  = (t1['team_logo'] ?? '').toString();
    final t2Logo  = (t2['team_logo'] ?? '').toString();
    final t1Score = '${t1['total_runs'] ?? 0}/${t1['total_wickets'] ?? 0}';
    final t2Score = '${t2['total_runs'] ?? 0}/${t2['total_wickets'] ?? 0}';
    final t1Ov    = (t1['overs_done'] ?? 0).toString();
    final t2Ov    = (t2['overs_done'] ?? 0).toString();

    Widget teamCol(String logo, String name, String score, String overs) {
      final text = _textColor(context);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white.withOpacity(0.15),
            backgroundImage: logo.isNotEmpty ? NetworkImage(logo) : null,
            child: logo.isEmpty
                ? Icon(Icons.sports_cricket, size: 22, color: Colors.white.withOpacity(0.85))
                : null,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 110, // prevents long names from pushing VS button
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: text, fontWeight: FontWeight.w700, fontSize: 14, height: 1.1),
            ),
          ),
          const SizedBox(height: 4),
          Text(score, style: TextStyle(color: text, fontWeight: FontWeight.w800, fontSize: 16, height: 1.0)),
          const SizedBox(height: 2),
          Text('$overs ov', style: TextStyle(color: _subTextColor(context), fontSize: 12, height: 1.0)),
        ],
      );
    }

    Widget chip(String label, {IconData? icon}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(isDark ? 0.12 : 0.22),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5)),
        ]),
      );
    }

    return GlassPanel(
      // extra top margin so the rounded card doesn't collide with the tab bar
      margin: const EdgeInsets.fromLTRB(2, 8, 2, 0),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      lightGradient: const LinearGradient(
        colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      darkColor: const Color(0xFF1E1E1E),
      child: Stack(
        children: [
          const Positioned.fill(child: CardAuroraOverlay()),
          const Positioned(
            right: -4,
            bottom: -2,
            child: WatermarkIcon(icon: Icons.sports_cricket, size: 110, opacity: 0.08),
          ),
          // Content
          Column(
            children: [
              Row(
                children: [
                  Expanded(child: teamCol(t1Logo, t1Name, t1Score, t1Ov)),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(isDark ? 0.1 : 0.25),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: const Text('VS',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  ),
                  Expanded(child: teamCol(t2Logo, t2Name, t2Score, t2Ov)),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (result.isNotEmpty) chip(result, icon: Icons.emoji_events_rounded),
                  if (toss.isNotEmpty) chip(toss, icon: Icons.casino_rounded),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- Player card ----------
  bool _nonEmpty(String? s) => s != null && s != 'null' && s.trim().isNotEmpty;

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
    final runs  = (data['total_runs'] ?? data['runs'])?.toString();
    final balls = (data['total_balls'] ?? data['balls'])?.toString();
    final sr    = data['sr']?.toString();
    final fours = (data['fours'] ?? data['4s'])?.toString();
    final sixes = (data['sixes'] ?? data['6s'])?.toString();

    if (_nonEmpty(runs))  pills.add(_statPill('R: $runs', highlight: true));
    if (_nonEmpty(balls)) pills.add(_statPill('B: $balls'));
    if (_nonEmpty(sr))    pills.add(_statPill('SR: $sr'));
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
    final img  = (data['player_image'] ?? data['image_url'] ?? '').toString();
    final pts  = data['points']?.toString();
    final id   = int.tryParse((data['player_id'] ?? data['user_id'] ?? data['id'] ?? '').toString()) ?? 0;

    final isBatter = data.containsKey('sr') || data.containsKey('total_runs') || data.containsKey('total_balls');
    final pills = isBatter ? _buildBatterPills(data) : _buildBowlerPills(data);

    return InkWell(
      onTap: id > 0
          ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerPublicInfoTab(playerId: id)))
          : null,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
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
          border: Border.all(color: dark ? Colors.white10 : Colors.black.withOpacity(0.04)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.network(
                img,
                width: 56, height: 56, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Image.asset(
                  'lib/asset/images/Random_Image.png',
                  width: 56, height: 56, fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _textColor(context), fontWeight: FontWeight.w800, fontSize: 16, height: 1.1),
                  ),
                  if (team.isNotEmpty)
                    Text(
                      team,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _subTextColor(context), fontSize: 12.5, height: 1.1),
                    ),
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
                  child: Text(
                    '$pts pts',
                    style: TextStyle(
                      color: dark ? const Color(0xFF9CD0FF) : const Color(0xFF0D47A1),
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      height: 1.0,
                    ),
                  ),
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
                    ? Colors.white.withOpacity(0.08)
                    : const Color(0xFFEFF4FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon, size: 18,
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
    // ----- unpack data safely -----
    final t1 = (widget.matchData['team_1'] as Map<String, dynamic>? ?? {});
    final t2 = (widget.matchData['team_2'] as Map<String, dynamic>? ?? {});
    final result = (widget.matchData['match_result'] ?? '').toString().trim();
    final toss   = (widget.matchData['match_toss'] ?? '').toString().trim();

    final leftName   = (t1['team_name'] ?? 'Team A').toString();
    final rightName  = (t2['team_name'] ?? 'Team B').toString();
    final leftLogo   = (t1['team_logo'] ?? '').toString();
    final rightLogo  = (t2['team_logo'] ?? '').toString();
    final leftScore  = '${t1['total_runs'] ?? 0}/${t1['total_wickets'] ?? 0}';
    final rightScore = '${t2['total_runs'] ?? 0}/${t2['total_wickets'] ?? 0}';
    final leftOvers  = (t1['overs_done'] ?? 0).toString();
    final rightOvers = (t2['overs_done'] ?? 0).toString();

    // ----- lists for sections -----
    final tpBatters = (widget.summary['tp_batters'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .toList();
    final tpBowlers = (widget.summary['tp_bowlers'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .toList();
    final mvpRaw = widget.summary['mvp'];
    final mvpList = (mvpRaw is List)
        ? mvpRaw.whereType<Map>().toList()
        : (mvpRaw is Map ? mvpRaw.values.whereType<Map>().toList() : <Map>[]);

    return Stack(
      children: [
        const MeshBackdrop(), // pretty reusable background
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ reusable header card
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

              const SizedBox(height: 16),
              const FancyDivider(),
              const SizedBox(height: 10),
              _section('Top Batters', Icons.bolt_rounded, tpBatters,
                  emptyText: 'No batter stats available.'),
              const SizedBox(height: 16),
              const FancyDivider(),
              const SizedBox(height: 10),
              _section('Top Bowlers', Icons.sports_cricket_rounded, tpBowlers,
                  emptyText: 'No bowler stats available.'),
              const SizedBox(height: 16),
              const FancyDivider(),
              const SizedBox(height: 10),
              _section('MVP Points', Icons.emoji_events_rounded, mvpList,
                  emptyText: 'No MVP data available.'),
            ],
          ),
        ),
      ],
    );
  }
}
