// lib/service/session_manager.dart
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const _kToken = 'api_logged_in_token';
  static const _kPlayerId = 'player_id';
  static const _kPhone = 'phone';
  static const _kDisplayName = 'display_name';

  // Save session; optionally store phone & name too
  static Future<void> saveSession({
    required String apiToken,
    required int playerId,
    String? phone,
    String? displayName,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kToken, apiToken);
    await sp.setInt(_kPlayerId, playerId);
    if (phone != null && phone.trim().isNotEmpty) {
      await sp.setString(_kPhone, _normalizePhone(phone));
    }
    if (displayName != null && displayName.trim().isNotEmpty) {
      await sp.setString(_kDisplayName, displayName.trim());
    }
  }

  // Update only profile fields later (e.g., after fetching user)
  static Future<void> saveProfile({String? phone, String? displayName}) async {
    final sp = await SharedPreferences.getInstance();
    if (phone != null && phone.trim().isNotEmpty) {
      await sp.setString(_kPhone, _normalizePhone(phone));
    }
    if (displayName != null && displayName.trim().isNotEmpty) {
      await sp.setString(_kDisplayName, displayName.trim());
    }
  }

  static Future<String?> getToken() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kToken);
  }

  static Future<int?> getPlayerId() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_kPlayerId);
  }

  static Future<String?> getPhone() async {
    final sp = await SharedPreferences.getInstance();

    // Try canonical key first; fall back to old keys if you had any
    var phone = sp.getString(_kPhone)
        ?? sp.getString('user_phone')
        ?? sp.getString('mobile')
        ?? sp.getString('phone_number');

    if (phone == null || phone.isEmpty) return null;

    phone = _normalizePhone(phone);
    // write back normalized value to canonical key
    await sp.setString(_kPhone, phone);
    return phone;
  }

  static Future<String?> getUserName() async {
    final sp = await SharedPreferences.getInstance();
    final name = sp.getString(_kDisplayName)
        ?? sp.getString('name')
        ?? sp.getString('full_name')
        ?? sp.getString('user_name');
    if (name != null) {
      await sp.setString(_kDisplayName, name);
    }
    return name;
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kToken);
    await sp.remove(_kPlayerId);
    await sp.remove(_kPhone);
    await sp.remove(_kDisplayName);
  }

  static Future<bool> isLoggedIn() async =>
      (await getToken())?.isNotEmpty == true;

  // Keep only + and digits; minimal normalization for QR/API
  static String _normalizePhone(String p) {
    return p.trim().replaceAll(RegExp(r'[^0-9+]'), '');
  }
}
