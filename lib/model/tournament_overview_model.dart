// lib/model/tournament_overview_model.dart

class TournamentOverview {
  final int tournamentId;
  final String tournamentName;
  final String tournamentLogo;
  final String tournamentDesc;

  TournamentOverview({
    required this.tournamentId,
    required this.tournamentName,
    required this.tournamentLogo,
    required this.tournamentDesc,
  });

  factory TournamentOverview.fromJson(Map<String, dynamic> json) {
    return TournamentOverview(
      tournamentId: json['tournament_id'] as int,
      tournamentName: json['tournament_name'] as String? ?? '',
      tournamentLogo: json['tournament_logo'] as String? ?? '',
      tournamentDesc: json['tournament_desc'] as String? ?? '',
    );
  }
}

class GroupModel {
  final String groupId;
  final String groupName;

  GroupModel({
    required this.groupId,
    required this.groupName,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      groupId: json['group_id'] as String? ?? '',
      groupName: json['group_name'] as String? ?? '',
    );
  }
}

class MatchModel {
  final int matchId;
  final String matchDate;
  final String matchResult;
  final String opponent;

  MatchModel({
    required this.matchId,
    required this.matchDate,
    required this.matchResult,
    required this.opponent,
  });

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    return MatchModel(
      matchId: int.tryParse(json['match_id']?.toString() ?? '') ?? 0,
      matchDate: json['match_date'] as String? ?? '',
      matchResult: json['match_result'] as String? ?? '',
      opponent: json['opponent'] as String? ?? '',
    );
  }
}

class TeamStanding {
  final String teamId;
  final String teamName;
  final String teamLogo;
  final String groupId;
  final int wins;
  final int losses;
  final int ties;
  final int draws;
  final int points;
  final String netRR;
  final List<MatchModel> matches;

  TeamStanding({
    required this.teamId,
    required this.teamName,
    required this.teamLogo,
    required this.groupId,
    required this.wins,
    required this.losses,
    required this.ties,
    required this.draws,
    required this.points,
    required this.netRR,
    required this.matches,
  });

  factory TeamStanding.fromJson(Map<String, dynamic> json) {
    final rawMatches = (json['matches'] as List<dynamic>?) ?? [];
    return TeamStanding(
      teamId: json['team_id'] as String? ?? '',
      teamName: json['team_name'] as String? ?? '',
      teamLogo: json['team_logo'] as String? ?? '',
      groupId: json['group_id']?.toString() ?? '',
      wins: int.tryParse(json['wins']?.toString() ?? '') ?? 0,
      losses: int.tryParse(json['lost']?.toString() ?? '') ?? 0,
      ties: int.tryParse(json['tie']?.toString() ?? '') ?? 0,
      draws: int.tryParse(json['draw']?.toString() ?? '') ?? 0,
      points: int.tryParse(json['points']?.toString() ?? '') ?? 0,
      netRR: json['net_rr']?.toString() ?? '',
      matches: rawMatches
          .map((m) => MatchModel.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}
