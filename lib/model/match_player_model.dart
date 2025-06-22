class PlayerPublicInfo {
  final int id;
  final String firstName;
  final String profileImage;
  final String playerType;
  final String? batterType;
  final String? bowlerType;
  final List<String> teams;
  final BattingCareer battingCareer;
  final BowlingCareer bowlingCareer;

  PlayerPublicInfo({
    required this.id,
    required this.firstName,
    required this.profileImage,
    required this.playerType,
    this.batterType,
    this.bowlerType,
    required this.teams,
    required this.battingCareer,
    required this.bowlingCareer,
  });

  factory PlayerPublicInfo.fromJson(Map<String, dynamic> json) {
    final info = json['player_info'] as Map<String, dynamic>;
    // parse id robustly
    final rawId = info['id'];
    final id = rawId is num ? rawId.toInt() : int.tryParse(rawId.toString()) ?? 0;

    return PlayerPublicInfo(
      id: id,
      firstName: info['first_name'] as String? ?? '',
      profileImage: info['user_profile_image'] as String? ?? '',
      playerType: info['player_type'] as String? ?? '',
      batterType: info['batter_type'] as String?,
      bowlerType: info['bowler_type'] as String?,
      teams: (info['teams'] as List<dynamic>?)
          ?.map((t) => (t as Map<String, dynamic>)['team_name'] as String? ?? '')
          .where((t) => t.isNotEmpty)
          .toList() ??
          [],
      battingCareer: BattingCareer.fromJson(
          (info['batting_career'] as Map<String, dynamic>?) ?? {}),
      bowlingCareer: BowlingCareer.fromJson(
          (info['bowling_career'] as Map<String, dynamic>?) ?? {}),
    );
  }
}

class BattingCareer {
  final int matches;
  final int innings;
  final int runs;
  final int average;
  final int strikeRate;
  final int sixes;
  final int fours;
  final int hundreds;
  final int fifties;
  final int bestScore;

  BattingCareer({
    required this.matches,
    required this.innings,
    required this.runs,
    required this.average,
    required this.strikeRate,
    required this.sixes,
    required this.fours,
    required this.hundreds,
    required this.fifties,
    required this.bestScore,
  });

  factory BattingCareer.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) => v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0;

    return BattingCareer(
      matches: parseInt(json['total_match']),
      innings: parseInt(json['total_innings']),
      runs: parseInt(json['total_runs']),
      average: parseInt(json['average']),
      strikeRate: parseInt(json['strike_rate']),
      sixes: parseInt(json['total_sixes']),
      fours: parseInt(json['total_fours']),
      hundreds: parseInt(json['total_100']),
      fifties: parseInt(json['total_50']),
      bestScore: parseInt(json['best_score']),
    );
  }
}

class BowlingCareer {
  final int matches;
  final int innings;
  final int wickets;
  final int average;
  final int economy;
  final String best;

  BowlingCareer({
    required this.matches,
    required this.innings,
    required this.wickets,
    required this.average,
    required this.economy,
    required this.best,
  });

  factory BowlingCareer.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) => v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0;

    return BowlingCareer(
      matches: parseInt(json['total_match']),
      innings: parseInt(json['total_innings']),
      wickets: parseInt(json['total_b_wkt']),
      average: parseInt(json['avg']),
      economy: parseInt(json['economy']),
      best: json['best'] as String? ?? '',
    );
  }
}
