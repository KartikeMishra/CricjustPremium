// lib/model/fair_play_model.dart

class FairPlayStanding {
  final String teamId;
  final String teamName;
  final String teamLogo;
  final String groupId;
  final String tournamentId;
  final double fairPlayPoints;
  final int totalMatches;

  FairPlayStanding({
    required this.teamId,
    required this.teamName,
    required this.teamLogo,
    required this.groupId,
    required this.tournamentId,
    required this.fairPlayPoints,
    required this.totalMatches,
  });

  factory FairPlayStanding.fromJson(Map<String, dynamic> json) {
    return FairPlayStanding(
      teamId         : json['team_id'] as String? ?? '',
      teamName       : json['team_name'] as String? ?? '',
      teamLogo       : json['team_logo'] as String? ?? '',
      groupId        : json['group_id'] as String? ?? '',
      tournamentId   : json['tournament_id'] as String? ?? '',
      fairPlayPoints : double.tryParse(json['fairplay']?.toString() ?? '') ?? 0.0,
      totalMatches   : int.tryParse(json['total_matches']?.toString() ?? '') ?? 0,
    );
  }
}
