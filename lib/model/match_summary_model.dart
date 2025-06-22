// File: lib/model/match_detail_model.dart

import 'dart:convert';

/// Combined model for match summary and scorecard

// ------------------------ SUMMARY ------------------------
class MatchSummary {
  final String matchStatus;
  final String matchResult;
  final String tossInfo;
  final String teamAName;
  final String teamBName;
  final String teamAScore;
  final String teamBScore;

  // Raw data from API
  final Map<String, dynamic> rawSummary;
  final Map<String, dynamic> rawMatchData;

  MatchSummary({
    required this.matchStatus,
    required this.matchResult,
    required this.tossInfo,
    required this.teamAName,
    required this.teamBName,
    required this.teamAScore,
    required this.teamBScore,
    required this.rawSummary,
    required this.rawMatchData,
  });

  factory MatchSummary.fromJson(Map<String, dynamic> json) {
    final match = json['data'][0] as Map<String, dynamic>;
    final team1 = match['team_1'] as Map<String, dynamic>?;
    final team2 = match['team_2'] as Map<String, dynamic>?;

    String formatScore(Map<String, dynamic>? team) {
      if (team == null) return '';
      return '${team['total_runs']}/${team['total_wickets']} (${team['overs_done']}.${team['balls_done']})';
    }

    return MatchSummary(
      matchStatus: (match['match_result'] as String?)?.isNotEmpty == true
          ? 'completed'
          : 'live',
      matchResult: match['match_result'] as String? ?? '',
      tossInfo: match['match_toss'] as String? ?? '',
      teamAName: (team1?['team_name'] as String?)?.trim() ?? 'Team A',
      teamBName: (team2?['team_name'] as String?)?.trim() ?? 'Team B',
      teamAScore: formatScore(team1),
      teamBScore: formatScore(team2),
      rawSummary: json['summary'] as Map<String, dynamic>? ?? {},
      rawMatchData: match,
    );
  }
}
