class TossUpdateRequest {
  final int tossWin; // 🏏 Team ID who won the toss
  final int tossWinChooses; // 🎯 0 = Bat First, 1 = Bowl First

  TossUpdateRequest({required this.tossWin, required this.tossWinChooses});

  Map<String, String> toJson() {
    return {
      'toss_win': tossWin.toString(),
      'toss_win_chooses': tossWinChooses.toString(),
    };
  }
}
