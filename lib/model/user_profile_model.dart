// lib/model/user_profile_model.dart

class UserProfile {
  final String id;
  final String login;
  final String email;
  final String displayName;
  final String nickname;
  final String firstName;
  final String lastName;
  final String description;
  final String gender;
  final String dob;
  final String profileImage;

  UserProfile({
    required this.id,
    required this.login,
    required this.email,
    required this.displayName,
    required this.nickname,
    required this.firstName,
    required this.lastName,
    required this.description,
    required this.gender,
    required this.dob,
    required this.profileImage,
  });

  /// API returns two maps: `data` (core fields) and `extra` (meta fields)
  factory UserProfile.fromJson(
      Map<String, dynamic> data,
      Map<String, dynamic> extra,
      ) {
    return UserProfile(
      id: data['ID']?.toString() ?? '',
      login: data['user_login'] as String? ?? '',
      email: data['user_email'] as String? ?? '',
      displayName: data['display_name'] as String? ?? '',
      nickname: extra['nickname'] as String? ?? '',
      firstName: extra['first_name'] as String? ?? '',
      lastName: extra['last_name'] as String? ?? '',
      description: extra['description'] as String? ?? '',
      gender: extra['user_gender'] as String? ?? '',
      dob: extra['user_dob'] as String? ?? '',
      profileImage: extra['user_profile_image'] as String? ?? '',
    );
  }

  UserProfile copyWith({
    String? id,
    String? login,
    String? email,
    String? displayName,
    String? nickname,
    String? firstName,
    String? lastName,
    String? description,
    String? gender,
    String? dob,
    String? profileImage,
  }) {
    return UserProfile(
      id: id ?? this.id,
      login: login ?? this.login,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      nickname: nickname ?? this.nickname,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      description: description ?? this.description,
      gender: gender ?? this.gender,
      dob: dob ?? this.dob,
      profileImage: profileImage ?? this.profileImage,
    );
  }

  Map<String, String> toMap() {
    return {
      'ID': id,
      'user_login': login,
      'user_email': email,
      'display_name': displayName,
      'nickname': nickname,
      'first_name': firstName,
      'last_name': lastName,
      'description': description,
      'user_gender': gender,
      'user_dob': dob,
      'user_profile_image': profileImage,
    };
  }
}
