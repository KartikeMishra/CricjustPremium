// lib/model/tournament_stats_model.dart

class RunStats {
  final String playerImage;
  final String displayName;
  final String teamName;
  final String matches;
  final String innings;
  final String runs;
  final String avg;
  final String sr;

  RunStats({
    required this.playerImage,
    required this.displayName,
    required this.teamName,
    required this.matches,
    required this.innings,
    required this.runs,
    required this.avg,
    required this.sr,
  });

  factory RunStats.fromJson(Map<String, dynamic> json) {
    return RunStats(
      playerImage: json['player_image'] ?? '',
      displayName: json['Display_Name'] ?? '',
      teamName: json['team_name'] ?? '',
      matches: json['total_match'] ?? '',
      innings: json['total_inn'] ?? '',
      runs: json['Total_Runs'] ?? '',
      avg: json['avg'] ?? '',
      sr: json['sr'] ?? '',
    );
  }
}

class WicketStats {
  final String playerImage;
  final String displayName;
  final String matches;
  final String innings;
  final String wickets;
  final String avg;

  WicketStats({
    required this.playerImage,
    required this.displayName,
    required this.matches,
    required this.innings,
    required this.wickets,
    required this.avg,
  });

  factory WicketStats.fromJson(Map<String, dynamic> json) {
    return WicketStats(
      playerImage: json['player_image'] ?? '',
      displayName: json['Display_Name'] ?? '',
      matches: json['total_match'] ?? '',
      innings: json['total_inn'] ?? '',
      wickets: json['Total_Wicket'] ?? '',
      avg: json['avg'] ?? '',
    );
  }
}

class SixStats {
  final String playerImage;
  final String displayName;
  final String teamName;
  final String sixes;

  SixStats({
    required this.playerImage,
    required this.displayName,
    required this.teamName,
    required this.sixes,
  });

  factory SixStats.fromJson(Map<String, dynamic> json) {
    return SixStats(
      playerImage: json['player_image'] ?? '',
      displayName: json['Display_Name'] ?? '',
      teamName: json['team_name'] ?? '',
      sixes: json['total_six']?.toString() ?? '0',
    );
  }
}

class FourStats {
  final String playerImage;
  final String displayName;
  final String teamName;
  final String fours; // ← new

  FourStats({
    required this.playerImage,
    required this.displayName,
    required this.teamName,
    required this.fours, // ← new
  });

  factory FourStats.fromJson(Map<String, dynamic> json) {
    return FourStats(
      playerImage: json['player_image'] ?? '',
      displayName: json['Display_Name'] ?? '',
      teamName: json['team_name'] ?? '',
      fours: json['total_fours']?.toString() ?? '0', // ← pull from JSON
    );
  }
}

class HighestScore {
  final String playerImage;
  final String displayName;
  final String teamName;
  final String runs;
  final String balls;
  final String matchName;
  final String sr;

  HighestScore({
    required this.playerImage,
    required this.displayName,
    required this.teamName,
    required this.runs,
    required this.balls,
    required this.matchName,
    required this.sr,
  });

  factory HighestScore.fromJson(Map<String, dynamic> json) {
    return HighestScore(
      playerImage: json['player_image'] ?? '',
      displayName: json['Display_Name'] ?? '',
      teamName: json['team_name'] ?? '',
      runs: json['Total_Runs'] ?? '',
      balls: json['total_balls'] ?? '',
      matchName: json['Match_Name'] ?? '',
      sr: json['SR'] ?? '',
    );
  }
}

class MVP {
  final String playerImage;
  final String displayName;
  final String teamName;

  MVP({
    required this.playerImage,
    required this.displayName,
    required this.teamName,
  });

  factory MVP.fromJson(Map<String, dynamic> json) {
    return MVP(
      playerImage: json['player_image'] ?? '',
      displayName: json['Display_Name'] ?? '',
      teamName: json['team_name'] ?? '',
    );
  }
}

class SummaryStats {
  final String matches;
  final String runs;
  final String wickets;
  final String sixes;
  final String fours;
  final String balls;
  final String extras;

  SummaryStats({
    required this.matches,
    required this.runs,
    required this.wickets,
    required this.sixes,
    required this.fours,
    required this.balls,
    required this.extras,
  });

  factory SummaryStats.fromJson(Map<String, dynamic> json) {
    return SummaryStats(
      matches: json['total_matches'] ?? '',
      runs: json['total_runs'] ?? '',
      wickets: json['total_wickets'] ?? '',
      sixes: json['total_sixes'] ?? '',
      fours: json['total_fours'] ?? '',
      balls: json['total_balls'] ?? '',
      extras: json['total_extras'] ?? '',
    );
  }
}
