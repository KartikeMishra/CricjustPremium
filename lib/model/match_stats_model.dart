import 'dart:convert';

/// ---------- helpers ----------
int _asInt(dynamic v, {int def = 0}) {
  if (v == null) return def;
  if (v is int) return v;
  if (v is double) return v.round();
  final s = v.toString().trim();
  if (s.isEmpty) return def;
  return int.tryParse(s) ?? def;
}

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map) {
    return v.map((k, val) => MapEntry(k.toString(), val));
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _listOfMaps(dynamic v) {
  if (v is List) {
    return v
        .where((e) => e is Map)
        .map((e) => (e as Map).map((k, val) => MapEntry(k.toString(), val)))
        .toList();
  }
  return const <Map<String, dynamic>>[];
}

/// ---------- data classes ----------
class ManhattanPoint {
  final int overNumber;
  final int totalRuns;

  ManhattanPoint({required this.overNumber, required this.totalRuns});

  factory ManhattanPoint.fromJson(Map<String, dynamic> json) => ManhattanPoint(
    overNumber: _asInt(json['over_number']),
    totalRuns: _asInt(json['total_runs']),
  );
}

class WormPoint {
  final int overNumber;
  final int totalRuns;

  WormPoint({required this.overNumber, required this.totalRuns});

  factory WormPoint.fromJson(Map<String, dynamic> json) => WormPoint(
    overNumber: _asInt(json['over_number']),
    totalRuns: _asInt(json['total_runs']),
  );
}

class RunTypes {
  final int ones;
  final int twos;
  final int fours;
  final int sixes;
  final int extras;

  const RunTypes({
    required this.ones,
    required this.twos,
    required this.fours,
    required this.sixes,
    required this.extras,
  });

  factory RunTypes.fromJson(Map<String, dynamic> json) => RunTypes(
    // API sometimes uses "one" instead of "ones"
    ones: _asInt(json['ones'] ?? json['one']),
    twos: _asInt(json['twos']),
    fours: _asInt(json['fours']),
    sixes: _asInt(json['sixes']),
    extras: _asInt(json['extras']),
  );
}

class WicketTypeStat {
  final String wicketType;
  final int totalWickets;

  WicketTypeStat({required this.wicketType, required this.totalWickets});

  factory WicketTypeStat.fromJson(Map<String, dynamic> json) => WicketTypeStat(
    wicketType: (json['wicket_type'] ?? '').toString(),
    totalWickets: _asInt(json['total_wickets']),
  );
}

class MatchStats {
  final List<ManhattanPoint> manhattanTeam1;
  final List<ManhattanPoint> manhattanTeam2;
  final List<WormPoint> wormTeam1;
  final List<WormPoint> wormTeam2;
  final RunTypes runTypesTeam1;
  final RunTypes runTypesTeam2;
  final List<WicketTypeStat> wicketTypes;

  MatchStats({
    required this.manhattanTeam1,
    required this.manhattanTeam2,
    required this.wormTeam1,
    required this.wormTeam2,
    required this.runTypesTeam1,
    required this.runTypesTeam2,
    required this.wicketTypes,
  });

  /// Accepts a *dynamic* map (what jsonDecode returns) and normalizes it.
  factory MatchStats.fromStatsJson(Map statsAny) {
    final stats = _asMap(statsAny);

    final manhattan = _asMap(stats['manhattan']);
    final worms = _asMap(stats['worms']);
    final runsTypes = _asMap(stats['runs_types']);
    final wickets = stats['wicket_types'];

    List<ManhattanPoint> _mapManhattan(dynamic list) =>
        _listOfMaps(list).map(ManhattanPoint.fromJson).toList();

    List<WormPoint> _mapWorm(dynamic list) =>
        _listOfMaps(list).map(WormPoint.fromJson).toList();

    return MatchStats(
      manhattanTeam1: _mapManhattan(manhattan['team_1']),
      manhattanTeam2: _mapManhattan(manhattan['team_2']),
      wormTeam1: _mapWorm(worms['team_1']),
      wormTeam2: _mapWorm(worms['team_2']),
      runTypesTeam1: RunTypes.fromJson(_asMap(runsTypes['team_1'])),
      runTypesTeam2: RunTypes.fromJson(_asMap(runsTypes['team_2'])),
      wicketTypes: _listOfMaps(wickets).map(WicketTypeStat.fromJson).toList(),
    );
  }

  /// Convenience for quick manual testing
  static MatchStats fromJsonString(String jsonString) {
    final root = json.decode(jsonString);
    final stats = (root is Map) ? root['stats'] : null;
    return MatchStats.fromStatsJson(_asMap(stats));
  }
}
