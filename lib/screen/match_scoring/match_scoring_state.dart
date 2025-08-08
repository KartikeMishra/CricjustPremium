import 'package:flutter/material.dart';

enum OutBatsman { striker, nonStriker }

class MatchScoringState {
  // Players
  int? onStrikePlayerId, nonStrikePlayerId, bowlerId;
  String? onStrikeName, nonStrikeName, bowlerName;
  int onStrikeRuns = 0, onStrikeBalls = 0;
  int nonStrikeRuns = 0, nonStrikeBalls = 0;

  // ✅ Wicketkeeper (private fields + getter/setter)
  int? _currentWicketKeeperId;
  String? _currentWicketKeeperName;

  int? get currentWicketkeeperId => _currentWicketKeeperId;
  String? get currentWicketkeeperName => _currentWicketKeeperName;

  void setWicketkeeper(int id, String name) {
    _currentWicketKeeperId = id;
    _currentWicketKeeperName = name;
  }

  // Match IDs & team info
  int? teamOneId, teamTwoId, firstInningTeamId;
  List<int> teamOneXI = [], teamTwoXI = [];
  bool firstInningClosed = false;
  String teamName = '';
  String? matchName;

  // Score
  int runs = 0, wickets = 0;
  int overNumber = 0, ballNumber = 1;
  int totalExtras = 0;
  double currentRunRate = 0.0;

  // Bowler stats
  int bowlerRunsConceded = 0;
  int bowlerWickets = 0;
  int bowlerMaidens = 0;
  String bowlerOversBowled = '';
  double bowlerEconomy = 0.0;

  // Submission
  bool isWicket = false;
  bool isFreeHit = false;
  int? selectedRuns;
  String? selectedExtra;
  String? wicketType;
  bool isSubmitting = false;
  bool isScoringDisabled = false;
  bool isEnding = false;
  Set<int> usedBatsmen = {};
  Set<int> usedBowlers = {};
  Set<String> submittedBalls = {};
  Map<int, double> bowlerOversMap = {};
  int? lastBowlerId;

  // Match Config
  int matchOvers = 0;
  int bowlerMaxOvers = 0;

  // Innings Control
  bool isSecondInning = false;
  int firstInningScore = 0;
  double requiredRunRate = 0.0;
  String? matchResultStatus;
  Color? matchResultColor;
  bool isCloseMatch = false;

  // Playing XI
  List<int> teamOne11 = [];
  List<int> teamTwo11 = [];

  // Timeline & squads
  List<String> timeline = [];
  List<int> dismissedBatters = [];
  late List<Map<String, dynamic>> team1Squad;
  late List<Map<String, dynamic>> team2Squad;
  List<Map<String, dynamic>> battingSidePlayers = [];
  List<Map<String, dynamic>> bowlingSidePlayers = [];

  // Other
  Map<int, Map<String, dynamic>> bowlerStatsMap = {};
  final ChangeNotifier lastSixBallsRefresher = ChangeNotifier();

  void dispose() => lastSixBallsRefresher.dispose();
}
