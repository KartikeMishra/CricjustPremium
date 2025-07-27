enum PlayerRole {
  Player('cricket_player'),
  Umpire('cricket_umpire'),
  Scorer('cricket_scorer'),
  Commentator('cricket_commentator');

  final String value;

  const PlayerRole(this.value);
}

enum SignupGender {
  male('Male'),
  female('Female');

  final String value;

  const SignupGender(this.value);
}
