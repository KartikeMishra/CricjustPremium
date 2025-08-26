// lib/model/login_result.dart
class LoginResult {
  final int status;
  final String apiToken; // api_logged_in_token
  final int userId;      // data.ID
  final String userLogin;
  final String email;
  final String displayName;

  LoginResult({
    required this.status,
    required this.apiToken,
    required this.userId,
    required this.userLogin,
    required this.email,
    required this.displayName,
  });

  factory LoginResult.fromJson(Map<String, dynamic> body) {
    final data = (body['data'] ?? {}) as Map<String, dynamic>;
    return LoginResult(
      status: (body['status'] ?? 0) as int,
      apiToken: (body['api_logged_in_token'] ?? '').toString(),
      userId: int.tryParse('${data['ID'] ?? ''}') ?? 0,
      userLogin: (data['user_login'] ?? '').toString(),
      email: (data['user_email'] ?? '').toString(),
      displayName: (data['display_name'] ?? '').toString(),
    );
  }
}
