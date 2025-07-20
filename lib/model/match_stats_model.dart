class OverStat {
  final int overNumber;
  final int totalRuns;

  OverStat({required this.overNumber, required this.totalRuns});

  factory OverStat.fromJson(Map<String, dynamic> json) {
    return OverStat(
      overNumber: (json['over_number'] as num?)?.toInt() ?? 0,
      totalRuns: (json['total_runs'] as num?)?.toInt() ?? 0,
    );
  }
}

class RunTypeStat {
  final int ones;
  final int twos;
  final int fours;
  final int sixes;
  final int extras;

  RunTypeStat({
    required this.ones,
    required this.twos,
    required this.fours,
    required this.sixes,
    required this.extras,
  });

  factory RunTypeStat.fromJson(Map<String, dynamic> json) {
    return RunTypeStat(
      ones: (json['one'] as num?)?.toInt() ?? 0,
      twos: (json['twos'] as num?)?.toInt() ?? 0,
      fours: (json['fours'] as num?)?.toInt() ?? 0,
      sixes: (json['sixes'] as num?)?.toInt() ?? 0,
      extras: (json['extras'] as num?)?.toInt() ?? 0,
    );
  }
}

class WicketType {
  final String wicketType;
  final int totalWickets;

  WicketType({required this.wicketType, required this.totalWickets});

  factory WicketType.fromJson(Map<String, dynamic> json) {
    return WicketType(
      wicketType: json['wicket_type'] as String? ?? '',
      totalWickets: (json['total_wickets'] as num?)?.toInt() ?? 0,
    );
  }
}

class MatchStats {
  final List<OverStat> manhattanTeam1;
  final List<OverStat> manhattanTeam2;
  final List<OverStat> wormTeam1;
  final List<OverStat> wormTeam2;
  final RunTypeStat runTypesTeam1;
  final RunTypeStat runTypesTeam2;
  final List<WicketType> wicketTypes;

  MatchStats({
    required this.manhattanTeam1,
    required this.manhattanTeam2,
    required this.wormTeam1,
    required this.wormTeam2,
    required this.runTypesTeam1,
    required this.runTypesTeam2,
    required this.wicketTypes,
  });

  factory MatchStats.fromJson(Map<String, dynamic> json) {
    final stats = (json['stats'] as Map<String, dynamic>?) ?? {};
    final man = (stats['manhattan'] as Map<String, dynamic>?) ?? {};
    final worms = (stats['worms'] as Map<String, dynamic>?) ?? {};
    final runs = (stats['runs_types'] as Map<String, dynamic>?) ?? {};
    final wicks = (stats['wicket_types'] as List<dynamic>?) ?? [];

    return MatchStats(
      manhattanTeam1: (man['team_1'] as List<dynamic>? ?? [])
          .map((e) => OverStat.fromJson(e as Map<String, dynamic>))
          .toList(),
      manhattanTeam2: (man['team_2'] as List<dynamic>? ?? [])
          .map((e) => OverStat.fromJson(e as Map<String, dynamic>))
          .toList(),
      wormTeam1: (worms['team_1'] as List<dynamic>? ?? [])
          .map((e) => OverStat.fromJson(e as Map<String, dynamic>))
          .toList(),
      wormTeam2: (worms['team_2'] as List<dynamic>? ?? [])
          .map((e) => OverStat.fromJson(e as Map<String, dynamic>))
          .toList(),
      runTypesTeam1: runs['team_1'] != null
          ? RunTypeStat.fromJson(runs['team_1'] as Map<String, dynamic>)
          : RunTypeStat(ones: 0, twos: 0, fours: 0, sixes: 0, extras: 0),
      runTypesTeam2: runs['team_2'] != null
          ? RunTypeStat.fromJson(runs['team_2'] as Map<String, dynamic>)
          : RunTypeStat(ones: 0, twos: 0, fours: 0, sixes: 0, extras: 0),
      wicketTypes: wicks
          .map((e) => WicketType.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
