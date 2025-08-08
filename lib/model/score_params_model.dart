import 'package:flutter/material.dart';

class ScoreParams {
  final BuildContext context;
  final int matchId;
  final int? onStrikePlayerId;
  final int? nonStrikePlayerId;
  final int? bowlerId;
  final String? bowlerName;
  final int overNumber;
  final int ballNumber;
  final int selectedRuns;
  final String? selectedExtra;
  final bool isWicket;
  final String? wicketType;
  final int? currentWicketkeeperId;
  final int teamOneId;
  final int teamTwoId;
  final int? firstInningTeamId;
  final bool firstInningClosed;
  final int matchOvers;
  final int bowlerMaxOvers;
  final String bowlerOversBowled;
  final Set<String> submittedBalls;
  final Set<int> usedBatsmen;
  final Set<int> usedBowlers;
  final String token;
  final Function(String) showError;
  final VoidCallback swapStrike;
  final VoidCallback advanceBall;
  final VoidCallback showBatsmanSelectionAfterWicket;
  final Function(String) showMatchEndDialog;
  final Function(bool) setScoringDisabled;
  final void Function(int, int, int, int) updateScore;
  final VoidCallback refreshScoreData;
  final Function(Map<String, dynamic>) checkMatchResult;
  final List<Map<String, dynamic>> bowlingSidePlayers;

  const ScoreParams({
    required this.context,
    required this.matchId,
    required this.onStrikePlayerId,
    required this.nonStrikePlayerId,
    required this.bowlerId,
    required this.bowlerName,
    required this.overNumber,
    required this.ballNumber,
    required this.selectedRuns,
    required this.selectedExtra,
    required this.isWicket,
    required this.wicketType,
    required this.currentWicketkeeperId,
    required this.teamOneId,
    required this.teamTwoId,
    required this.firstInningTeamId,
    required this.firstInningClosed,
    required this.matchOvers,
    required this.bowlerMaxOvers,
    required this.bowlerOversBowled,
    required this.submittedBalls,
    required this.usedBatsmen,
    required this.usedBowlers,
    required this.token,
    required this.showError,
    required this.swapStrike,
    required this.advanceBall,
    required this.showBatsmanSelectionAfterWicket,
    required this.showMatchEndDialog,
    required this.setScoringDisabled,
    required this.updateScore,
    required this.refreshScoreData,
    required this.checkMatchResult,
    required this.bowlingSidePlayers,
  });
}
