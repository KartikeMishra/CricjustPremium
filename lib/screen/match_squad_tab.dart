import 'package:flutter/material.dart';
import 'package:cricjust_premium/Screen/player_info.dart';
import '../model/match_squad_model.dart';
import '../service/match_detail_service.dart';

class MatchSquadTab extends StatefulWidget {
  final int matchId;
  const MatchSquadTab({super.key, required this.matchId});

  @override
  State<MatchSquadTab> createState() => _MatchSquadTabState();
}

class _MatchSquadTabState extends State<MatchSquadTab> {
  late Future<MatchSquad> _squadFuture;

  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _squadFuture = MatchSquadService.fetchSquad(widget.matchId);
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.trim();
      if (q != _query) setState(() => _query = q);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<MatchSquad>(
      future: _squadFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError || !snap.hasData) {
          return _buildNoData('Squad not available for this match.');
        }

        final squad = snap.data!;
        // Filter by search query (case-insensitive) across both teams
        List<Player> t1 = squad.team1Players;
        List<Player> t2 = squad.team2Players;
        if (_query.isNotEmpty) {
          bool m(Player p) => p.name.toLowerCase().contains(_query.toLowerCase());
          t1 = t1.where(m).toList();
          t2 = t2.where(m).toList();
        }

        final maxLength = (t1.length > t2.length) ? t1.length : t2.length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(squad, isDark),
              const SizedBox(height: 12),
              _searchBar(isDark),
              const SizedBox(height: 12),
              if (maxLength == 0)
                _buildNoData('No players match your search.')
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: maxLength,
                  itemBuilder: (context, i) {
                    final left  = i < t1.length ? t1[i] : null;
                    final right = i < t2.length ? t2[i] : null;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(child: left != null ? _playerTile(left, isDark) : const SizedBox()),
                          const SizedBox(width: 10),
                          Expanded(child: right != null ? _playerTile(right, isDark) : const SizedBox()),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // ---------- UI bits ----------

  Widget _header(MatchSquad squad, bool isDark) {
    final bg = isDark
        ? const LinearGradient(colors: [Color(0x221ffffff), Color(0x111ffffff)])
        : const LinearGradient(
      colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: bg,
        color: isDark ? null : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? [] : [const BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(child: _teamChip(squad.team1Name, squad.team1Logo)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.white.withValues(alpha: .25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'vs',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: .5,
              ),
            ),
          ),
          Expanded(child: _teamChip(squad.team2Name, squad.team2Logo, alignRight: true)),
        ],
      ),
    );
  }

  Widget _teamChip(String? name, String? logo, {bool alignRight = false}) {
    final label = (name == null || name.trim().isEmpty) ? 'Team' : name.trim();
    final imageProvider = (logo != null && logo.isNotEmpty)
        ? NetworkImage(logo)
        : const AssetImage('lib/asset/images/cricjust_logo.png');

    return Row(
      mainAxisAlignment: alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (alignRight) ...[
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
        ],
        CircleAvatar(radius: 16, backgroundImage: imageProvider as ImageProvider),
        if (!alignRight) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    );
  }

  Widget _searchBar(bool isDark) {
    return TextField(
      controller: _searchCtrl,
      decoration: InputDecoration(
        hintText: 'Search players',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: isDark ? Colors.white10 : Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _playerTile(Player p, bool isDark) {
    final img = (p.playerImage.isNotEmpty) ? NetworkImage(p.playerImage) : null;
    final badges = _badgesFromType(p.playerType);
    final roleColor = _roleColor(p.playerType);

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
      elevation: isDark ? 0 : 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PlayerPublicInfoTab(playerId: p.playerId)),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: img,
                child: img == null
                    ? Text(
                  p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black87),
                )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                        ),
                      ),
                      if (badges.isNotEmpty)
                        Row(
                          children: badges
                              .map((b) => Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: .15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              b,
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.amber),
                            ),
                          ))
                              .toList(),
                        ),
                    ]),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _roleLabel(p.playerType),
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: roleColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, color: isDark ? Colors.white60 : Colors.black45),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoData(String msg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 76, color: isDark ? Colors.grey[600] : Colors.grey),
            const SizedBox(height: 10),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: isDark ? Colors.white70 : Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- helpers ----------

  // pull nice label from any free-form playerType the API returns.
  String _roleLabel(String role) {
    final r = role.toLowerCase();
    if (r.contains('wicket')) return 'Wicket-keeper';
    if (r.contains('batter') || r.contains('batsman')) return 'Batter';
    if (r.contains('bowler')) return 'Bowler';
    if (r.contains('all')) return 'All-rounder';
    return role.isNotEmpty ? role : 'Player';
  }

  Color _roleColor(String role) {
    final r = role.toLowerCase();
    if (r.contains('bowler')) return Colors.blue;
    if (r.contains('batter') || r.contains('batsman')) return Colors.purple;
    if (r.contains('wicket')) return Colors.orange;
    if (r.contains('all')) return Colors.teal;
    return Colors.green;
  }

  // derive CAPTAIN / VC / WK badges from role text, if present
  List<String> _badgesFromType(String role) {
    final r = role.toLowerCase();
    final badges = <String>[];
    if (r.contains('captain') || r.contains('(c)') || r.endsWith(' c')) badges.add('C');
    if (r.contains('vice') || r.contains('(vc)') || r.endsWith(' vc')) badges.add('VC');
    if (r.contains('wicket')) badges.add('WK');
    return badges;
  }
}
