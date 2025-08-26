import 'dart:convert';

class CreateUserRequest {
  final String userPhone;       // 10 digits
  final String firstName;       // required
  final String? userEmail;      // optional, if present must be valid
  final String userType;        // cricket_player / cricket_umpire / cricket_scorer / cricket_commentator
  final String? playerType;     // required if userType == cricket_player: all-rounder / batter / bowler / wicket-keeper
  final String? batterType;     // required for batter, all-rounder, wicket-keeper: left / right
  final String? bowlerType;     // required for bowler, all-rounder: pace / spin

  CreateUserRequest({
    required this.userPhone,
    required this.firstName,
    required this.userType,
    this.userEmail,
    this.playerType,
    this.batterType,
    this.bowlerType,
  });

  /// Returns a map of fieldName -> errorText (empty if valid)
  Map<String, String> validate() {
    final errors = <String, String>{};

    final phone = userPhone.trim();
    if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
      errors['user_phone'] = 'Enter a valid 10-digit phone number';
    }

    if (firstName.trim().isEmpty) {
      errors['first_name'] = 'First name is required';
    }

    const userTypes = {
      'cricket_player',
      'cricket_umpire',
      'cricket_scorer',
      'cricket_commentator',
    };
    if (!userTypes.contains(userType)) {
      errors['user_type'] = 'Invalid user type';
    }

    if ((userEmail ?? '').trim().isNotEmpty) {
      final email = userEmail!.trim();
      final ok = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
      if (!ok) errors['user_email'] = 'Enter a valid email address';
    }

    // Player-specific validations
    if (userType == 'cricket_player') {
      const playerTypes = {'all-rounder', 'batter', 'bowler', 'wicket-keeper'};
      if (playerType == null || !playerTypes.contains(playerType)) {
        errors['player_type'] = 'Select player type';
      } else {
        // batter_type required for batter/all-rounder/wicket-keeper
        if (playerType == 'batter' || playerType == 'all-rounder' || playerType == 'wicket-keeper') {
          if (batterType == null || !(batterType == 'left' || batterType == 'right')) {
            errors['batter_type'] = 'Select batter type (left/right)';
          }
        }
        // bowler_type required for bowler/all-rounder
        if (playerType == 'bowler' || playerType == 'all-rounder') {
          if (bowlerType == null || !(bowlerType == 'pace' || bowlerType == 'spin')) {
            errors['bowler_type'] = 'Select bowler type (pace/spin)';
          }
        }
      }
    }

    return errors;
  }

  Map<String, String> toFormFields() {
    final map = <String, String>{
      'user_phone': userPhone.trim(),
      'first_name': firstName.trim(),
      'user_type': userType.trim(),
    };
    if ((userEmail ?? '').trim().isNotEmpty) map['user_email'] = userEmail!.trim();

    if (userType == 'cricket_player') {
      if ((playerType ?? '').trim().isNotEmpty) map['player_type'] = playerType!.trim();
      if ((batterType ?? '').trim().isNotEmpty) map['batter_type'] = batterType!.trim();
      if ((bowlerType ?? '').trim().isNotEmpty) map['bowler_type'] = bowlerType!.trim();
    }
    return map;
  }
}

class CreateUserResponse {
  final bool ok;
  final String message;
  final int? userId;
  final Map<String, dynamic> raw;

  CreateUserResponse({
    required this.ok,
    required this.message,
    this.userId,
    required this.raw,
  });

  factory CreateUserResponse.fromJson(Map<String, dynamic> json) {
    final ok = (json['status'] == 1 || json['status'] == '1' || json['success'] == true);
    final message = json['message']?.toString() ?? (ok ? 'User created' : 'Failed to create user');
    final id = _parseInt(json['user_id'] ?? json['id'] ?? json['data']?['user_id']);
    return CreateUserResponse(ok: ok, message: message, userId: id, raw: json);
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  @override
  String toString() => jsonEncode(raw);
}
