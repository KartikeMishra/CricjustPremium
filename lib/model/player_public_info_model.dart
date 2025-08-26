// lib/model/player_public_info.dart

class PlayerPersonalInfo {
  final int id;
  final String firstName;
  final String? imageUrl;     // <-- exists
  final String? playerType;
  final String? batterType;
  final String? bowlerType;
  final List<String> teams;
  final BattingCareer? batting; // <-- exists
  final BowlingCareer? bowling; // <-- exists

  PlayerPersonalInfo({
    required this.id,
    required this.firstName,
    required this.imageUrl,
    required this.playerType,
    required this.batterType,
    required this.bowlerType,
    required this.teams,
    required this.batting,
    required this.bowling,
  });

  factory PlayerPersonalInfo.fromJson(Map<String, dynamic> json) {
    final info = (json['player_info'] ?? {}) as Map<String, dynamic>;
    final teamsRaw = (info['teams'] as List?) ?? [];

    return PlayerPersonalInfo(
      id: info['id'] ?? 0,
      firstName: (info['first_name'] ?? '').toString(),
      imageUrl: _str(info['user_profile_image']),
      playerType: _str(info['player_type']),
      batterType: _str(info['batter_type']),
      bowlerType: _str(info['bowler_type']),
      teams: teamsRaw
          .map((e) => (e is Map && e['team_name'] != null)
          ? e['team_name'].toString().trim()
          : '')
          .where((s) => s.isNotEmpty)
          .cast<String>()
          .toList(),
      batting: info['batting_career'] == null
          ? null
          : BattingCareer.fromJson(
          info['batting_career'] as Map<String, dynamic>),
      bowling: info['bowling_career'] == null
          ? null
          : BowlingCareer.fromJson(
          info['bowling_career'] as Map<String, dynamic>),
    );
  }
}

class BattingCareer {
  final int totalMatch;     // <-- exists
  final int totalInnings;   // <-- exists
  final int totalRuns;      // <-- exists
  final num average;
  final num strikeRate;
  final int totalSixes;
  final int totalFours;
  final int total100;
  final int total50;
  final int bestScore;

  BattingCareer({
    required this.totalMatch,
    required this.totalInnings,
    required this.totalRuns,
    required this.average,
    required this.strikeRate,
    required this.totalSixes,
    required this.totalFours,
    required this.total100,
    required this.total50,
    required this.bestScore,
  });

  factory BattingCareer.fromJson(Map<String, dynamic> j) => BattingCareer(
    totalMatch: (j['total_match'] ?? 0) as int,
    totalInnings: (j['total_innings'] ?? 0) as int,
    totalRuns: (j['total_runs'] ?? 0) as int,
    average: j['average'] ?? 0,
    strikeRate: j['strike_rate'] ?? 0,
    totalSixes: (j['total_sixes'] ?? 0) as int,
    totalFours: (j['total_fours'] ?? 0) as int,
    total100: (j['total_100'] ?? 0) as int,
    total50: (j['total_50'] ?? 0) as int,
    bestScore: (j['best_score'] ?? 0) as int,
  );
}

class BowlingCareer {
  final int totalMatch;
  final int totalInnings;
  final int totalWickets;
  final num average;
  final num economy;
  final String best;

  BowlingCareer({
    required this.totalMatch,
    required this.totalInnings,
    required this.totalWickets,
    required this.average,
    required this.economy,
    required this.best,
  });

  factory BowlingCareer.fromJson(Map<String, dynamic> j) => BowlingCareer(
    totalMatch: (j['total_match'] ?? 0) as int,
    totalInnings: (j['total_innings'] ?? 0) as int,
    totalWickets: (j['total_b_wkt'] ?? 0) as int,
    average: j['avg'] ?? 0,
    economy: j['economy'] ?? 0,
    best: _str(j['best']) ?? '-',
  );
}

String? _str(dynamic v) =>
    v == null ? null : v.toString().trim().isEmpty ? null : v.toString().trim();
