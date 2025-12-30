// lib/model/global_search_models.dart
// ONE MODEL FILE: shared models + JSON parsing helpers

import 'dart:convert';

enum SearchType { player, match, tournament }

String searchTypeParam(SearchType t) {
  switch (t) {
    case SearchType.player:
      return 'player';
    case SearchType.match:
      return 'match';
    case SearchType.tournament:
      return 'tournament';
  }
}

// ---------- Player ----------
class PlayerResult {
  final String id;
  final String name;
  final String? playerType; // all-rounder / batter / bowler / wicket-keeper
  final String? batterType; // left / right
  final String? imageUrl;   // often delivered via bowler_type URL (escaped)

  const PlayerResult({
    required this.id,
    required this.name,
    this.playerType,
    this.batterType,
    this.imageUrl,
  });

  factory PlayerResult.fromJson(Map<String, dynamic> j) {
    String? _norm(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      return s.replaceAll('_', '-');
    }

    String? _imageFrom(dynamic v) {
      if (v is String && v.startsWith('http')) {
        return v.replaceAll('&amp;', '&');
      }
      return null;
    }

    return PlayerResult(
      id: (j['ID'] ?? '').toString(),
      name: (j['display_name'] ?? '').toString(),
      playerType: _norm(j['player_type']),
      batterType: _norm(j['batter_type']),
      imageUrl: _imageFrom(j['bowler_type']),
    );
  }
}

// ---------- Match ----------
class TeamSnippet {
  final int teamId;
  final String teamName;
  final String? teamLogo;
  final int? totalRuns;
  final int? totalWickets;
  final int? oversDone;
  final int? ballsDone;

  const TeamSnippet({
    required this.teamId,
    required this.teamName,
    this.teamLogo,
    this.totalRuns,
    this.totalWickets,
    this.oversDone,
    this.ballsDone,
  });

  factory TeamSnippet.fromJson(Map<String, dynamic> j) => TeamSnippet(
    teamId: (j['team_id'] ?? 0) is int
        ? j['team_id'] as int
        : int.tryParse('${j['team_id'] ?? 0}') ?? 0,
    teamName: (j['team_name'] ?? '').toString().trim(),
    teamLogo: (() {
      final s = (j['team_logo'] ?? '').toString();
      return s.isEmpty ? null : s.replaceAll('&amp;', '&');
    })(),
    totalRuns: j['total_runs'] is int ? j['total_runs'] as int : int.tryParse('${j['total_runs'] ?? ''}'),
    totalWickets: j['total_wickets'] is int ? j['total_wickets'] as int : int.tryParse('${j['total_wickets'] ?? ''}'),
    oversDone: j['overs_done'] is int ? j['overs_done'] as int : int.tryParse('${j['overs_done'] ?? ''}'),
    ballsDone: j['balls_done'] is int ? j['balls_done'] as int : int.tryParse('${j['balls_done'] ?? ''}'),
  );
}

class MatchResult {
  final int matchId;
  final String matchName;
  final String? tournamentName;
  final String matchDate; // yyyy-MM-dd
  final String matchTime; // HH:mm:ss
  final String? ballType;
  final int? matchOvers;
  final String? venue;
  final TeamSnippet team1;
  final TeamSnippet team2;
  final String? toss;
  final String? result;

  const MatchResult({
    required this.matchId,
    required this.matchName,
    required this.matchDate,
    required this.matchTime,
    required this.team1,
    required this.team2,
    this.tournamentName,
    this.ballType,
    this.matchOvers,
    this.venue,
    this.toss,
    this.result,
  });

  factory MatchResult.fromJson(Map<String, dynamic> j) => MatchResult(
    matchId: (j['match_id'] ?? 0) is int
        ? j['match_id'] as int
        : int.tryParse('${j['match_id'] ?? 0}') ?? 0,
    matchName: (j['match_name'] ?? '').toString().trim(),
    tournamentName: j['tournament_name']?.toString(),
    matchDate: (j['match_date'] ?? '').toString(),
    matchTime: (j['match_time'] ?? '').toString(),
    ballType: j['ball_type']?.toString(),
    matchOvers: j['match_overs'] is int ? j['match_overs'] as int : int.tryParse('${j['match_overs'] ?? ''}'),
    venue: j['venue']?.toString(),
    team1: TeamSnippet.fromJson(Map<String, dynamic>.from(j['team_1'] ?? {})),
    team2: TeamSnippet.fromJson(Map<String, dynamic>.from(j['team_2'] ?? {})),
    toss: j['match_toss']?.toString(),
    result: j['match_result']?.toString(),
  );
}

// ---------- Tournament ----------
class TournamentResult {
  final int tournamentId;
  final String name;
  final String? logo;
  final String? desc;
  final String? startDate; // yyyy-MM-dd
  final int? isGroup; // 0/1

  const TournamentResult({
    required this.tournamentId,
    required this.name,
    this.logo,
    this.desc,
    this.startDate,
    this.isGroup,
  });

  factory TournamentResult.fromJson(Map<String, dynamic> j) => TournamentResult(
    tournamentId: (j['tournament_id'] ?? 0) is int
        ? j['tournament_id'] as int
        : int.tryParse('${j['tournament_id'] ?? 0}') ?? 0,
    name: (j['tournament_name'] ?? '').toString().trim(),
    logo: (() {
      final s = (j['tournament_logo'] ?? '').toString();
      return s.isEmpty ? null : s.replaceAll('&amp;', '&');
    })(),
    desc: j['tournament_desc']?.toString(),
    startDate: j['start_date']?.toString(),
    isGroup: j['is_group'] is int ? j['is_group'] as int : int.tryParse('${j['is_group'] ?? ''}'),
  );
}

// ---------- Response parsers ----------
class SearchResponseParser {
  static List<PlayerResult> parsePlayers(String body) {
    final Map<String, dynamic> json = jsonDecode(body);
    final List data = (json['data'] ?? []) as List;
    return data.map((e) => PlayerResult.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static List<MatchResult> parseMatches(String body) {
    final Map<String, dynamic> json = jsonDecode(body);
    final List data = (json['data'] ?? []) as List;
    return data.map((e) => MatchResult.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static List<TournamentResult> parseTournaments(String body) {
    final Map<String, dynamic> json = jsonDecode(body);
    final List data = (json['data'] ?? []) as List;
    return data.map((e) => TournamentResult.fromJson(Map<String, dynamic>.from(e))).toList();
  }
}
