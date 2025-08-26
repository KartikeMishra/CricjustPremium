import 'package:flutter/material.dart';
import '../model/ball_event.dart';

class MatchStateData {
  int? strikerId;
  int? nonStrikerId;
  int? bowlerId;
  int totalRuns = 0;
  int totalWickets = 0;
  int currentOver = 0;
  int currentBall = 0; // 0 to 5
  List<BallEvent> ballLog = [];

  MatchStateData();
}

class MatchState extends ChangeNotifier {
  final Map<int, MatchStateData> _matches = {};

  /// Initialize a new match state
  void initMatch(int matchId) {
    _matches[matchId] = MatchStateData();
    notifyListeners();
  }

  /// Get the current match state
  MatchStateData getMatch(int matchId) {
    return _matches[matchId] ?? MatchStateData();
  }

  /// Set selected striker, non-striker or bowler
  void setPlayers({
    required int matchId,
    int? striker,
    int? nonStriker,
    int? bowler,
  }) {
    final match = _matches[matchId];
    if (match != null) {
      if (striker != null) match.strikerId = striker;
      if (nonStriker != null) match.nonStrikerId = nonStriker;
      if (bowler != null) match.bowlerId = bowler;
      notifyListeners();
    }
  }

  /// Submit a ball and update match state
  void submitBall({required int matchId, required BallEvent event}) {
    final match = _matches[matchId];
    if (match == null) return;

    match.ballLog.add(event);
    match.totalRuns += event.runs;
    if (event.isWicket) match.totalWickets += 1;

    if (!event.isExtra) {
      match.currentBall += 1;
      if (match.currentBall >= 6) {
        match.currentOver += 1;
        match.currentBall = 0;

        // Swap striker and non-striker
        final temp = match.strikerId;
        match.strikerId = match.nonStrikerId;
        match.nonStrikerId = temp;
      }
    }

    notifyListeners();
  }

  /// Update score externally (e.g., from AddScoreScreen)
  void updateScore({
    required int matchId,
    required int runs,
    required int wickets,
    required int over,
    required int ball,
  }) {
    final match = _matches[matchId];
    if (match == null) return;

    match.totalRuns = runs;
    match.totalWickets = wickets;
    match.currentOver = over;
    match.currentBall = ball;

    notifyListeners();
  }
}
