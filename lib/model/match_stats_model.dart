// match_stats_model.dart

int _asInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
String _asStr(dynamic v) => v == null ? '' : '$v';

Map<String, dynamic> _asMap(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v as Map) : <String, dynamic>{};

List<Map<String, dynamic>> _asListOfMap(dynamic v) =>
    (v is List) ? v.whereType<Map<String, dynamic>>().toList() : const [];

class OverStat {
  final int overNumber;
  final int totalRuns;

  const OverStat({required this.overNumber, required this.totalRuns});

  factory OverStat.fromJson(Map<String, dynamic> j) => OverStat(
    // accept multiple key variants
    overNumber: _asInt(j['over_number'] ?? j['over'] ?? j['o']),
    totalRuns: _asInt(j['total_runs'] ?? j['runs'] ?? j['r']),
  );
}

class RunTypeStat {
  final int ones;
  final int twos;
  final int fours;
  final int sixes;
  final int extras;

  const RunTypeStat({
    required this.ones,
    required this.twos,
    required this.fours,
    required this.sixes,
    required this.extras,
  });

  factory RunTypeStat.zero() =>
      const RunTypeStat(ones: 0, twos: 0, fours: 0, sixes: 0, extras: 0);

  factory RunTypeStat.fromJson(Map<String, dynamic> j) => RunTypeStat(
    // handle one/ones, two/twos, extra/extras
    ones: _asInt(j['ones'] ?? j['one']),
    twos: _asInt(j['twos'] ?? j['two']),
    fours: _asInt(j['fours'] ?? j['four']),
    sixes: _asInt(j['sixes'] ?? j['six']),
    extras: _asInt(j['extras'] ?? j['extra']),
  );
}

class WicketType {
  final String wicketType;
  final int totalWickets;

  const WicketType({required this.wicketType, required this.totalWickets});

  factory WicketType.fromJson(Map<String, dynamic> j) => WicketType(
    // accept wicket_type/type and total_wickets/count
    wicketType: _asStr(j['wicket_type'] ?? j['type']),
    totalWickets: _asInt(j['total_wickets'] ?? j['count']),
  );
}

class MatchStats {
  final List<OverStat> manhattanTeam1;
  final List<OverStat> manhattanTeam2;
  final List<OverStat> wormTeam1;
  final List<OverStat> wormTeam2;
  final RunTypeStat runTypesTeam1;
  final RunTypeStat runTypesTeam2;
  final List<WicketType> wicketTypes;

  const MatchStats({
    required this.manhattanTeam1,
    required this.manhattanTeam2,
    required this.wormTeam1,
    required this.wormTeam2,
    required this.runTypesTeam1,
    required this.runTypesTeam2,
    required this.wicketTypes,
  });

  factory MatchStats.empty() => MatchStats(
    manhattanTeam1: const [],
    manhattanTeam2: const [],
    wormTeam1: const [],
    wormTeam2: const [],
    runTypesTeam1: RunTypeStat.zero(),
    runTypesTeam2: RunTypeStat.zero(),
    wicketTypes: const [],
  );

  /// Safe parser for ANY root shape (Map with/without `data`, or even a List).
  factory MatchStats.fromAny(dynamic root) {
    if (root is! Map) return MatchStats.empty();

    // some APIs wrap in { data: {...} }
    final map = _asMap(root['data'] ?? root);

    // your API uses "stats"; tolerate alternative naming too
    final stats = _asMap(map['stats'] ?? map['data'] ?? {});

    final man = _asMap(stats['manhattan']);
    final worms = _asMap(stats['worms']);
    final runs =
    _asMap(stats['runs_types'] ?? stats['run_types'] ?? stats['runType']);
    final wicks = stats['wicket_types'];

    return MatchStats(
      manhattanTeam1:
      _asListOfMap(man['team_1']).map(OverStat.fromJson).toList(),
      manhattanTeam2:
      _asListOfMap(man['team_2']).map(OverStat.fromJson).toList(),
      wormTeam1: _asListOfMap(worms['team_1']).map(OverStat.fromJson).toList(),
      wormTeam2: _asListOfMap(worms['team_2']).map(OverStat.fromJson).toList(),
      runTypesTeam1:
      runs.isEmpty ? RunTypeStat.zero() : RunTypeStat.fromJson(_asMap(runs['team_1'])),
      runTypesTeam2:
      runs.isEmpty ? RunTypeStat.zero() : RunTypeStat.fromJson(_asMap(runs['team_2'])),
      wicketTypes: _asListOfMap(wicks).map(WicketType.fromJson).toList(),
    );
  }

  /// Keep the same name your code already calls, but make it tolerant.
  factory MatchStats.fromJson(dynamic json) => MatchStats.fromAny(json);
}
