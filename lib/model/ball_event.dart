class BallEvent {
  final int runs;
  final bool isExtra;
  final String? extraType;
  final bool isWicket;
  final String? wicketType;
  final int strikerId;
  final int bowlerId;
  final String? shotType;
  final String? commentary;

  BallEvent({
    required this.runs,
    required this.isExtra,
    this.extraType,
    required this.isWicket,
    this.wicketType,
    required this.strikerId,
    required this.bowlerId,
    this.shotType,
    this.commentary,
  });

  int get totalRuns => isExtra ? runs + 1 : runs;
}
