class CommentaryItem {
  final int? overNumber;
  final dynamic commentryPerBall; // List or Map
  final OverInfo? overInfo;
  final TillOver? tillOver;

  CommentaryItem({
    required this.overNumber,
    required this.commentryPerBall,
    this.overInfo,
    this.tillOver,
  });

  factory CommentaryItem.fromJson(Map<String, dynamic> json) {
    // Fallback for missing over_number at top level
    int? topLevelOver = json['over_number'];

    int? inferredOver;
    final cpb = json['commentry_per_ball'];
    if (topLevelOver == null && cpb != null) {
      if (cpb is List && cpb.isNotEmpty) {
        inferredOver = cpb[0]['over_number'];
      } else if (cpb is Map && cpb.isNotEmpty) {
        inferredOver = cpb.values.first['over_number'];
      }
    }

    return CommentaryItem(
      overNumber: topLevelOver ?? inferredOver,
      commentryPerBall: json['commentry_per_ball'],
      overInfo: json['over_info'] != null ? OverInfo.fromJson(json['over_info']) : null,
      tillOver: json['till_over'] != null ? TillOver.fromJson(json['till_over']) : null,
    );
  }
}

class OverInfo {
  final int? totalRuns;
  final int? totalWickets;
  final List<String> runsPerBall;

  OverInfo({
    required this.totalRuns,
    required this.totalWickets,
    required this.runsPerBall,
  });

  factory OverInfo.fromJson(Map<String, dynamic> json) {
    return OverInfo(
      totalRuns: json['total_runs'],
      totalWickets: json['total_wkts'],
      runsPerBall: List<String>.from(json['runs_per_ball'] ?? []),
    );
  }
}

class TillOver {
  final int? totalRuns;
  final String? totalWickets;
  final Bowler? bowler;
  final Batters? batters;

  TillOver({
    required this.totalRuns,
    required this.totalWickets,
    required this.bowler,
    required this.batters,
  });

  factory TillOver.fromJson(Map<String, dynamic> json) {
    return TillOver(
      totalRuns: json['total_runs'],
      totalWickets: json['total_wickets'],
      bowler: json['bowler'] != null ? Bowler.fromJson(json['bowler']) : null,
      batters: json['batters'] != null ? Batters.fromJson(json['batters']) : null,
    );
  }
}

class Bowler {
  final String? bowlerId;
  final String? name;
  final String? overs;
  final int? runs;
  final int? wickets;

  Bowler({
    required this.bowlerId,
    required this.name,
    required this.overs,
    required this.runs,
    required this.wickets,
  });

  factory Bowler.fromJson(Map<String, dynamic> json) {
    return Bowler(
      bowlerId: json['bowler_id']?.toString(),
      name: json['name'],
      overs: json['overs'] ?? json['0'],
      runs: json['runs'],
      wickets: json['wickets'],
    );
  }
}

class Batters {
  final Batter? striker;
  final Batter? nonStriker;

  Batters({
    required this.striker,
    required this.nonStriker,
  });

  factory Batters.fromJson(Map<String, dynamic> json) {
    return Batters(
      striker: json['striker_batter'] != null ? Batter.fromJson(json['striker_batter']) : null,
      nonStriker: json['non_striker_batter'] != null ? Batter.fromJson(json['non_striker_batter']) : null,
    );
  }
}

class Batter {
  final String? batterId;
  final String? name;
  final String? runs;
  final String? balls;

  Batter({
    required this.batterId,
    required this.name,
    required this.runs,
    required this.balls,
  });

  factory Batter.fromJson(Map<String, dynamic> json) {
    return Batter(
      batterId: json['batter_id']?.toString(),
      name: json['name'],
      runs: json['runs'],
      balls: json['balls'],
    );
  }
}
