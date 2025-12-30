// lib/model/match_scorecard_model.dart

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
      scorecard: (json['scorecard'] as List? ?? const [])
          .map((e) => InningScorecard.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      data: json['data'] ?? [],
      matchResult: (json['match_result'] ?? '').toString(),
    );
  }
}

class InningScorecard {
  final TeamScore team1;
  final TeamScore team2;

  InningScorecard({required this.team1, required this.team2});

  factory InningScorecard.fromJson(Map<String, dynamic> json) {
    return InningScorecard(
      team1: TeamScore.fromJson(json['team_1'] as Map<String, dynamic>),
      team2: TeamScore.fromJson(json['team_2'] as Map<String, dynamic>),
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
      teamId: _asInt(json['team_id']),
      teamName: (json['team_name'] ?? '').toString(),
      teamLogo: json['team_logo']?.toString(),
      totalRuns: _asInt(json['total_runs']),
      totalWickets: _asInt(json['total_wickets']),
      extras: (json['extras'] ?? '').toString(),
      oversDone: _asDouble(json['overs_done']),
      ballsDone: _asInt(json['balls_done']),
      // players/bowlers live under "scorecard"
      details: TeamDetails.fromJson((json['scorecard'] ?? const {}) as Map<String, dynamic>),
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
    final rawPlayers = (json['players'] as List? ?? const []);
    final rawYetToBat = (json['yet_to_players'] as List? ?? const []);
    final rawBowlers = (json['bowlers'] as List? ?? const []);

    // Stamp original index from API list
    final players = rawPlayers
        .asMap()
        .entries
        .map((e) => PlayerScore.fromJson(e.value as Map<String, dynamic>)
        .copyWith(orderIndex: e.key))
        .toList(growable: false);

    final yetToBat = rawYetToBat
        .asMap()
        .entries
        .map((e) => YetToBat.fromJson(e.value as Map<String, dynamic>)
        .copyWith(orderIndex: e.key))
        .toList(growable: false);

    final bowlers = rawBowlers
        .asMap()
        .entries
        .map((e) => BowlerStats.fromJson(e.value as Map<String, dynamic>)
        .copyWith(orderIndex: e.key))
        .toList(growable: false);

    return TeamDetails(players: players, yetToBat: yetToBat, bowlers: bowlers);
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

  final int? orderIndex; // original index from API array

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
    this.orderIndex,
  });

  int get playerId => userId;

  factory PlayerScore.fromJson(Map<String, dynamic> json) {
    return PlayerScore(
      userId: _asInt(json['user_id']),
      name: (json['name'] ?? '').toString(),
      order: (json['order'] ?? '').toString(),
      runs: _asInt(json['r']),
      balls: _asInt(json['b']),
      fours: _asInt(json['4s']),
      sixes: _asInt(json['6s']),
      strikeRate: _asDouble(json['sr'] ?? json['strike_rate']),
      isOut: _asInt(json['is_out']) == 1,
      outBy: (json['out_by'] ?? '').toString(),
    );
  }

  PlayerScore copyWith({int? orderIndex}) => PlayerScore(
    userId: userId,
    name: name,
    order: order,
    runs: runs,
    balls: balls,
    fours: fours,
    sixes: sixes,
    strikeRate: strikeRate,
    isOut: isOut,
    outBy: outBy,
    orderIndex: orderIndex ?? this.orderIndex,
  );
}

class YetToBat {
  final int userId;
  final String name;
  final int? orderIndex;

  YetToBat({
    required this.userId,
    required this.name,
    this.orderIndex,
  });

  int get playerId => userId;

  factory YetToBat.fromJson(Map<String, dynamic> json) {
    return YetToBat(
      userId: _asInt(json['user_id']),
      name: (json['name'] ?? '').toString(),
    );
  }

  YetToBat copyWith({int? orderIndex}) =>
      YetToBat(userId: userId, name: name, orderIndex: orderIndex ?? this.orderIndex);
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
  final int? orderIndex;

  BowlerStats({
    required this.bowlerId,
    required this.name,
    required this.overs,
    required this.balls,
    required this.maiden,
    required this.runs,
    required this.wickets,
    required this.economy,
    this.orderIndex,
  });

  int get playerId => int.tryParse(bowlerId) ?? 0;

  factory BowlerStats.fromJson(Map<String, dynamic> json) {
    return BowlerStats(
      bowlerId: (json['bowler_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      overs: _asDouble(json['overs']),
      balls: _asInt(json['balls']),
      maiden: _asInt(json['maiden']),
      runs: _asInt(json['runs']),
      wickets: _asInt(json['wickets']),
      economy: _asDouble(json['economy'] ?? json['econ']),
    );
  }

  BowlerStats copyWith({int? orderIndex}) => BowlerStats(
    bowlerId: bowlerId,
    name: name,
    overs: overs,
    balls: balls,
    maiden: maiden,
    runs: runs,
    wickets: wickets,
    economy: economy,
    orderIndex: orderIndex ?? this.orderIndex,
  );
}

/// --------------------
/// Safe parsing helpers
/// --------------------
int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) {
    final x = int.tryParse(v.trim());
    if (x != null) return x;
    final d = double.tryParse(v.trim());
    if (d != null) return d.toInt();
  }
  return 0;
}

double _asDouble(dynamic v) {
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim()) ?? 0.0;
  return 0.0;
}
