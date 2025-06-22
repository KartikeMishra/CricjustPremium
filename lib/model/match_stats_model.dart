class OverStat {
  final int overNumber;
  final int totalRuns;

  OverStat({required this.overNumber, required this.totalRuns});

  factory OverStat.fromJson(Map<String, dynamic> json) {
    return OverStat(
      overNumber: json['over_number'],
      totalRuns: json['total_runs'],
    );
  }
}

class RunTypeStat {
  final int extras;
  final int ones;
  final int twos;
  final int fours;
  final int? sixes;

  RunTypeStat({
    required this.extras,
    required this.ones,
    required this.twos,
    required this.fours,
    this.sixes,
  });

  factory RunTypeStat.fromJson(Map<String, dynamic> json) {
    return RunTypeStat(
      extras: json['extras'],
      ones: json['one'],
      twos: json['twos'],
      fours: json['fours'],
      sixes: json['sixes'] ?? 0,
    );
  }
}

class WicketType {
  final String wicketType;
  final int totalWickets;

  WicketType({required this.wicketType, required this.totalWickets});

  factory WicketType.fromJson(Map<String, dynamic> json) {
    return WicketType(
      wicketType: json['wicket_type'],
      totalWickets: json['total_wickets'],
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
    final stats = json['stats'];

    if (stats == null||stats.isEmpty) {
      return MatchStats(
        manhattanTeam1: [],
        manhattanTeam2: [],
        wormTeam1: [],
        wormTeam2: [],
        runTypesTeam1: RunTypeStat(extras: 0, ones: 0, twos: 0, fours: 0),
        runTypesTeam2: RunTypeStat(extras: 0, ones: 0, twos: 0, fours: 0),
        wicketTypes: [],
      );
    }
    return MatchStats(
      manhattanTeam1:stats['manhattan']['team_1']==null?[]: (stats['manhattan']['team_1'] as List)
          .map((e) => OverStat.fromJson(e))
          .toList(),
      manhattanTeam2:stats['manhattan']['team_2']==null?[]: (stats['manhattan']['team_2'] as List)
          .map((e) => OverStat.fromJson(e))
          .toList(),
      wormTeam1: stats['worms']['team_1']==null?[]:  (stats['worms']['team_1'] as List)
          .map((e) => OverStat.fromJson(e))
          .toList(),
      wormTeam2: stats['worms']['team_2'] ==null?[]: (stats['worms']['team_2'] as List)
          .map((e) => OverStat.fromJson(e))
          .toList(),
      runTypesTeam1: RunTypeStat.fromJson(stats['runs_types']['team_1']),
      runTypesTeam2: RunTypeStat.fromJson(stats['runs_types']['team_2']),
      wicketTypes: stats['wicket_types'] ==null?[]: (stats['wicket_types'] as List)
          .map((e) => WicketType.fromJson(e))
          .toList(),
    );
  }
}
