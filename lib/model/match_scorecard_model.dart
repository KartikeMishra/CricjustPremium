class MatchScorecardResponse {
  final List<InningScorecard> scorecard;
  final List<dynamic> data;
  final String matchResult;

  MatchScorecardResponse({
    required this.scorecard,
    required this.data,
    required this.matchResult,
  });

  factory MatchScorecardResponse.fromJson(Map<String, dynamic> json) {
    return MatchScorecardResponse(
      scorecard: (json['scorecard'] as List)
          .map((e) => InningScorecard.fromJson(e))
          .toList(),
      data: json['data'] ?? [],
      matchResult: json['match_result'] ?? '',
    );
  }
}

class InningScorecard {
  final TeamScore team1;
  final TeamScore team2;

  InningScorecard({required this.team1, required this.team2});

  factory InningScorecard.fromJson(Map<String, dynamic> json) {
    return InningScorecard(
      team1: TeamScore.fromJson(json['team_1']),
      team2: TeamScore.fromJson(json['team_2']),
    );
  }
}

class TeamScore {
  final int teamId;
  final String teamName;
  final String? teamLogo;
  final int totalRuns;
  final int totalWickets;
  final String extras;
  final double oversDone;
  final int ballsDone;
  final TeamDetails details;

  TeamScore({
    required this.teamId,
    required this.teamName,
    required this.teamLogo,
    required this.totalRuns,
    required this.totalWickets,
    required this.extras,
    required this.oversDone,
    required this.ballsDone,
    required this.details,
  });

  factory TeamScore.fromJson(Map<String, dynamic> json) {
    return TeamScore(
      teamId: json['team_id'],
      teamName: json['team_name'] ?? '',
      teamLogo: json['team_logo'],
      totalRuns: json['total_runs'],
      totalWickets: json['total_wickets'],
      extras: json['extras'] ?? '',
      oversDone: (json['overs_done'] as num).toDouble(),
      ballsDone: json['balls_done'],
      details: TeamDetails.fromJson(json['scorecard']),
    );
  }
}

class TeamDetails {
  final List<PlayerScore> players;
  final List<YetToBat> yetToBat;
  final List<BowlerStats> bowlers;

  TeamDetails({
    required this.players,
    required this.yetToBat,
    required this.bowlers,
  });

  factory TeamDetails.fromJson(Map<String, dynamic> json) {
    return TeamDetails(
      players: (json['players'] as List)
          .map((e) => PlayerScore.fromJson(e))
          .toList(),
      yetToBat: (json['yet_to_players'] as List)
          .map((e) => YetToBat.fromJson(e))
          .toList(),
      bowlers: (json['bowlers'] as List)
          .map((e) => BowlerStats.fromJson(e))
          .toList(),
    );
  }
}

class PlayerScore {
  final int userId;
  final String name;
  final String order;
  final int runs;
  final int balls;
  final int fours;
  final int sixes;
  final double strikeRate;
  final bool isOut;
  final String outBy;

  PlayerScore({
    required this.userId,
    required this.name,
    required this.order,
    required this.runs,
    required this.balls,
    required this.fours,
    required this.sixes,
    required this.strikeRate,
    required this.isOut,
    required this.outBy,
  });

  int get playerId => userId;

  factory PlayerScore.fromJson(Map<String, dynamic> json) {
    return PlayerScore(
      userId: json['user_id'],
      name: json['name'],
      order: json['order'],
      runs: json['r'],
      balls: json['b'],
      fours: json['4s'],
      sixes: json['6s'],
      strikeRate: (json['sr'] as num).toDouble(),
      isOut: json['is_out'] == 1,
      outBy: json['out_by'],
    );
  }
}

class YetToBat {
  final int userId;
  final String name;

  YetToBat({required this.userId, required this.name});

  int get playerId => userId;

  factory YetToBat.fromJson(Map<String, dynamic> json) {
    return YetToBat(userId: json['user_id'], name: json['name']);
  }
}

class BowlerStats {
  final String bowlerId;
  final String name;
  final double overs;
  final int balls;
  final int maiden;
  final int runs;
  final int wickets;
  final double economy;

  BowlerStats({
    required this.bowlerId,
    required this.name,
    required this.overs,
    required this.balls,
    required this.maiden,
    required this.runs,
    required this.wickets,
    required this.economy,
  });

  int get playerId => int.tryParse(bowlerId) ?? 0;

  factory BowlerStats.fromJson(Map<String, dynamic> json) {
    return BowlerStats(
      bowlerId: json['bowler_id'].toString(),
      name: json['name'],
      overs: (json['overs'] as num).toDouble(),
      balls: json['balls'],
      maiden: json['maiden'],
      runs: int.tryParse(json['runs'].toString()) ?? 0,
      wickets: int.tryParse(json['wickets'].toString()) ?? 0,
      economy: double.tryParse(json['economy'].toString()) ?? 0.0,
    );
  }
}
