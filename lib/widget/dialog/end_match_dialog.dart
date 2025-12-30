import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../service/match_score_service.dart';
import '../../service/player_service.dart';

/// Returned by [showEndMatchDialog] when user cancels/back. Caller must do nothing.
const int kEndMatchCancelled = -1;

class _SimplePlayer {
  final int id;
  final String name;
  final int teamId;
  final String? image;
  _SimplePlayer({required this.id, required this.name, required this.teamId, this.image});
}

Future<int?> showEndMatchDialog({
  required BuildContext context,
  required int matchId,
  required String token,
  required List<Map<String, dynamic>> teams, // [{team_id, team_name}]
  List<Map<String, dynamic>>? allPlayers,    // optional: [{id, name, team_id, image}]
}) async {
  String resultType = 'Win'; // Win | Draw | WinBToss | Tie
  int? winningTeam;
  int? runsOrWickets;
  String? winByType;         // EXACT: Runs | Wickets
  String? drawComment;
  bool superOver = false;
  bool isSubmitting = false;

  List<_SimplePlayer> _players = const [];
  bool _playersLoading = false;
  bool _playersLoadedOnce = false;
  String _playerQuery = '';
  int? _selectedPotmId;

  int toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  bool _shouldPickPotm() => !(resultType == 'Tie' && superOver == true);

  Map<int, String> _teamNames() =>
      {for (final t in teams) toInt(t['team_id']): (t['team_name'] ?? 'Team').toString()};

  Future<Map<String, dynamic>?> _getJson(Uri uri) async {
    try {
      final res = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;

      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;

      final root = Map<String, dynamic>.from(decoded as Map);
      final status = root['status'];
      if (status == 1 || status == '1') return root;
      return null;
    } catch (_) {
      return null;
    }
  }

  List<_SimplePlayer> _extractPlayersFromAny(
      dynamic dataOrList,
      Set<int> limitIds, {
        int? defaultTeamId,
      }) {
    final out = <_SimplePlayer>[];

    int readId(dynamic m) =>
        toInt(m['player_id'] ?? m['ID'] ?? m['id'] ?? m['pid'] ?? m['user_id']);
    String readName(dynamic m, int id) =>
        (m['display_name'] ?? m['name'] ?? m['user_login'] ?? m['username'] ?? 'Player $id')
            .toString();
    String? readImg(dynamic m) =>
        (m['player_image'] ?? m['image'] ?? m['avatar'])?.toString();

    bool looksLikePlayer(dynamic node) {
      if (node is! Map) return false;
      final id = readId(node);
      if (id == 0) return false;
      final name = node['display_name'] ?? node['name'] ?? node['user_login'];
      return name != null;
    }

    final listKeys = <String>{
      'squad','players','team_players','playingxi','playing_xi',
      'bench','benches','subs','substitutes','reserve','reserves',
    };

    void visit(dynamic node, {int? ctxTeamId}) {
      if (node is List) {
        for (final item in node) visit(item, ctxTeamId: ctxTeamId);
        return;
      }
      if (node is Map) {
        final mapNode = Map<String, dynamic>.from(node as Map);
        final localTeamId = toInt(mapNode['team_id'] ?? mapNode['teamId'] ?? mapNode['teamid']);
        final nextCtxTeamId = localTeamId != 0 ? localTeamId : ctxTeamId;

        if (looksLikePlayer(mapNode)) {
          final id = readId(mapNode);
          if (id != 0 && (limitIds.isEmpty || limitIds.contains(id))) {
            int teamId = toInt(mapNode['team_id'] ?? mapNode['teamId']);
            if (teamId == 0) teamId = nextCtxTeamId ?? (defaultTeamId ?? 0);
            final name = readName(mapNode, id);
            final img = readImg(mapNode);
            out.add(_SimplePlayer(id: id, name: name, teamId: teamId, image: img));
          }
        }

        for (final e in mapNode.entries) {
          final k = e.key.toString().toLowerCase();
          final v = e.value;
          if (listKeys.any((lk) => k.contains(lk))) {
            visit(v, ctxTeamId: nextCtxTeamId);
          }
        }
        for (final v in mapNode.values) {
          visit(v, ctxTeamId: nextCtxTeamId);
        }
      }
    }

    visit(dataOrList, ctxTeamId: defaultTeamId);

    final seen = <int>{};
    return out.where((p) => seen.add(p.id)).toList();
  }

  Future<Map<int, (String? name, String? image)>> _rosterMapFromTeam(int teamId) async {
    if (teamId == 0) return {};
    try {
      final list = await PlayerService.fetchTeamPlayers(teamId: teamId, apiToken: token, limit: 200);
      final map = <int, (String?, String?)>{};
      for (final p in list) {
        final id = toInt(p['player_id'] ?? p['id'] ?? p['user_id']);
        if (id == 0) continue;
        final name = (p['display_name'] ?? p['name'] ?? p['user_login'] ?? p['player_name'])?.toString();
        final image = (p['player_image'] ?? p['image'] ?? p['avatar'])?.toString();
        map[id] = (name, image);
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  Future<List<_SimplePlayer>> _loadPlayersPreferSingleMatch() async {
    if (allPlayers != null && allPlayers!.isNotEmpty) {
      final seen = <int>{};
      return allPlayers!
          .map((m) => _SimplePlayer(
        id: toInt(m['id']),
        name: (m['name'] ?? 'Player').toString(),
        teamId: toInt(m['team_id']),
        image: m['image']?.toString(),
      ))
          .where((p) => p.id != 0 && seen.add(p.id))
          .toList();
    }

    final singleUri = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-single-cricket-match'
          '?api_logged_in_token=$token&match_id=$matchId',
    );
    final single = await _getJson(singleUri);

    final dataArr = (single?['data'] as List?)?.cast<dynamic>() ?? const <dynamic>[];
    final row = (dataArr.isNotEmpty && dataArr.first is Map)
        ? Map<String, dynamic>.from(dataArr.first as Map)
        : const <String, dynamic>{};

    final teamOneId = toInt(row['team_one']);
    final teamTwoId = toInt(row['team_two']);

    final teamOneXI = ((row['team_one_11'] ?? '') as String)
        .split(',').map((s) => toInt(s.trim())).where((id) => id != 0).toSet();

    final teamTwoXI = ((row['team_two_11'] ?? '') as String)
        .split(',').map((s) => toInt(s.trim())).where((id) => id != 0).toSet();

    final idsWanted = {...teamOneXI, ...teamTwoXI};

    final Map<int, _SimplePlayer> acc = <int, _SimplePlayer>{};

    Future<void> enrichFrom(Uri uri, {int? defaultTeam}) async {
      final blob = await _getJson(uri);
      if (blob == null) return;
      final dynamic data = blob['data'];
      if (data == null) return;
      final extracted = _extractPlayersFromAny(data, idsWanted, defaultTeamId: defaultTeam);
      for (final p in extracted) {
        final existing = acc[p.id];
        if (existing == null ||
            existing.name.startsWith('Player ') ||
            (existing.image == null && p.image != null)) {
          acc[p.id] = p;
        }
      }
    }

    await enrichFrom(Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-match?match_id=$matchId&type=squad',
    ));

    if (teamOneId != 0 && acc.length < idsWanted.length) {
      for (final u in [
        Uri.parse('https://cricjust.in/wp-json/custom-api-for-cricket/get-team?team_id=$teamOneId'),
        Uri.parse('https://cricjust.in/wp-json/custom-api-for-cricket/get-team-squad?team_id=$teamOneId'),
      ]) {
        if (acc.length == idsWanted.length) break;
        await enrichFrom(u, defaultTeam: teamOneId);
      }
    }
    if (teamTwoId != 0 && acc.length < idsWanted.length) {
      for (final u in [
        Uri.parse('https://cricjust.in/wp-json/custom-api-for-cricket/get-team?team_id=$teamTwoId'),
        Uri.parse('https://cricjust.in/wp-json/custom-api-for-cricket/get-team-squad?team_id=$teamTwoId'),
      ]) {
        if (acc.length == idsWanted.length) break;
        await enrichFrom(u, defaultTeam: teamTwoId);
      }
    }

    final roster1 = await _rosterMapFromTeam(teamOneId);
    final roster2 = await _rosterMapFromTeam(teamTwoId);

    void applyRoster(Map<int, (String?, String?)> roster, int teamId) {
      roster.forEach((id, tuple) {
        if (!idsWanted.contains(id)) return;
        final (name, img) = tuple;
        if (name == null || name.isEmpty) return;
        final existing = acc[id];
        final p = _SimplePlayer(
          id: id,
          name: name,
          teamId: existing?.teamId ?? teamId,
          image: existing?.image ?? img,
        );
        acc[id] = p;
      });
    }

    applyRoster(roster1, teamOneId);
    applyRoster(roster2, teamTwoId);

    final missing = idsWanted.where((id) => acc[id] == null || acc[id]!.name.startsWith('Player ')).toList();
    if (missing.isNotEmpty) {
      await PlayerService.preloadPlayerProfiles(missing);
      for (final id in missing) {
        final name = await PlayerService.getPlayerName(id);
        if (name != null && name.isNotEmpty) {
          final teamId = teamOneXI.contains(id) ? teamOneId : teamTwoId;
          final prev = acc[id];
          acc[id] = _SimplePlayer(
            id: id,
            name: name,
            teamId: prev?.teamId ?? teamId,
            image: prev?.image,
          );
        }
      }
    }

    for (final id in idsWanted) {
      acc[id] = acc[id] ??
          _SimplePlayer(
            id: id,
            name: 'Player $id',
            teamId: teamOneXI.contains(id) ? teamOneId : teamTwoId,
          );
    }

    final list = acc.values.toList();
    final tn = _teamNames();
    list.sort((a, b) {
      final ta = (tn[a.teamId] ?? '').toLowerCase();
      final tb = (tn[b.teamId] ?? '').toLowerCase();
      final tcmp = ta.compareTo(tb);
      if (tcmp != 0) return tcmp;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  Future<void> _ensurePlayersLoaded(void Function(void Function()) setSB) async {
    if (_playersLoadedOnce || !_shouldPickPotm()) return;
    _playersLoadedOnce = true;
    _playersLoading = true;
    setSB(() {});
    _players = await _loadPlayersPreferSingleMatch();
    _playersLoading = false;
    setSB(() {});
  }

  return await showDialog<int?>(
    context: context,
    barrierDismissible: false,
    builder: (_) => WillPopScope(
      onWillPop: () async {
        Navigator.of(context, rootNavigator: true).pop(kEndMatchCancelled);
        return false;
      },
      child: StatefulBuilder(
        builder: (context, setSB) {
          if (_shouldPickPotm()) _ensurePlayersLoaded(setSB);

          final tn = _teamNames();
          final isPotmVisible = _shouldPickPotm();

          final filtered = _players
              .where((p) => _playerQuery.isEmpty
              ? true
              : p.name.toLowerCase().contains(_playerQuery.toLowerCase()))
              .toList()
            ..sort((a, b) {
              final ta = (tn[a.teamId] ?? '').toLowerCase();
              final tb = (tn[b.teamId] ?? '').toLowerCase();
              final tcmp = ta.compareTo(tb);
              if (tcmp != 0) return tcmp;
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            });

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            scrollable: true,
            title: const Text("End Match"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: resultType,
                  items: const ['Win', 'Draw', 'WinBToss', 'Tie']
                      .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) {
                    setSB(() {
                      resultType = v!;
                      winningTeam = null;
                      runsOrWickets = null;
                      winByType = null;
                      drawComment = null;
                      superOver = false;
                      _playersLoadedOnce = false;
                    });
                    if (_shouldPickPotm()) _ensurePlayersLoaded(setSB);
                  },
                  decoration: const InputDecoration(labelText: "Result Type"),
                ),
                const SizedBox(height: 12),

                if (resultType == 'Win' || resultType == 'WinBToss') ...[
                  DropdownButtonFormField<int>(
                    value: winningTeam,
                    decoration: const InputDecoration(labelText: "Winning Team"),
                    items: teams.map((t) {
                      final id = toInt(t['team_id']);
                      final name = (t['team_name'] ?? 'Team').toString();
                      return DropdownMenuItem<int>(value: id, child: Text(name));
                    }).toList(),
                    onChanged: (v) => setSB(() => winningTeam = v),
                  ),
                  const SizedBox(height: 12),
                ],

                if (resultType == 'Win') ...[
                  TextFormField(
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: "Runs or Wickets"),
                    onChanged: (v) => runsOrWickets = int.tryParse(v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: winByType,
                    items: const ['Runs', 'Wickets']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                    onChanged: (v) => setSB(() => winByType = v),
                    decoration: const InputDecoration(labelText: "Win By Type"),
                  ),
                  const SizedBox(height: 12),
                ],

                if (resultType == 'Draw') ...[
                  TextField(
                    decoration: const InputDecoration(labelText: "Draw Comment"),
                    onChanged: (v) => drawComment = v,
                  ),
                  const SizedBox(height: 12),
                ],

                if (resultType == 'Tie')
                  CheckboxListTile(
                    value: superOver,
                    onChanged: (v) => setSB(() => superOver = v ?? false),
                    title: const Text("Use Super Over?"),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),

                if (isPotmVisible) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Player of the Match',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search player...',
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    onChanged: (v) => setSB(() => _playerQuery = v),
                  ),
                  const SizedBox(height: 8),

                  if (_playersLoading)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(),
                    ))
                  else if (_players.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Text(
                        'No players available',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                      ),
                    )
                  else
                    Column(
                      children: [
                        for (final p in filtered)
                          RadioListTile<int>(
                            value: p.id,
                            groupValue: _selectedPotmId,
                            onChanged: (v) => setSB(() => _selectedPotmId = v),
                            title: Text(p.name),
                            subtitle: Text(tn[p.teamId] ?? 'Team'),
                            secondary: (p.image != null && p.image!.isNotEmpty)
                                ? CircleAvatar(backgroundImage: NetworkImage(p.image!))
                                : const CircleAvatar(child: Icon(Icons.person)),
                          ),
                      ],
                    ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(kEndMatchCancelled),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                  if ((resultType == 'Win' || resultType == 'WinBToss') && winningTeam == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select the winning team')),
                    );
                    return;
                  }
                  if (resultType == 'Win') {
                    if (runsOrWickets == null || runsOrWickets! <= 0 || winByType == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter a positive margin and choose Runs/Wickets')),
                      );
                      return;
                    }
                  }
                  if (resultType == 'Draw' &&
                      (drawComment == null || drawComment!.trim().isEmpty)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a reason for the draw')),
                    );
                    return;
                  }
                  if (_shouldPickPotm() && _players.isNotEmpty && _selectedPotmId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Select Player of the Match')),
                    );
                    return;
                  }

                  setSB(() => isSubmitting = true);
                  try {
                    final res = await MatchScoreService.endMatchWithResult(
                      context: context,
                      token: token,
                      matchId: matchId,
                      resultType: resultType,
                      winningTeam: winningTeam,
                      runsOrWicket: runsOrWickets,
                      winByType: winByType,
                      drawComment: drawComment,
                      superOvers: (resultType == 'Tie') ? (superOver ? 'Yes' : null) : null,
                    );

                    if (!res.ok) { // ⬅️ stop here
                      final msg = (res.message?.isNotEmpty == true)
                          ? res.message!
                          : 'Failed to end match. Check inputs.';
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $msg')));
                      setSB(() => isSubmitting = false);
                      return;
                    }


                    final int? superOverId = res.superOverMatchId;
                    if (resultType == 'Tie' && (superOver || superOverId != null)) {
                      Navigator.of(context, rootNavigator: true).pop(superOverId ?? 0);
                      return;
                    }

// Only now, after a successful end-match, save PoTM (if applicable)
                    if (_shouldPickPotm() && _selectedPotmId != null) {
                      await MatchScoreService.savePlayerOfTheMatch(
                        context: context,
                        token: token,
                        matchId: matchId,
                        playerId: _selectedPotmId!,
                      );
                    }

                    Navigator.of(context, rootNavigator: true).pop(null);

                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to end match: $e')),
                    );
                    setSB(() => isSubmitting = false);
                  }
                },
                child: const Text("Submit"),
              ),
            ],
          );
        },
      ),
    ),
  );
}
