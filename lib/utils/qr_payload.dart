import 'dart:convert';

class ReceiverQrPayload {
  static const String scheme = 'cjp:user:v1:'; // single source of truth

  final String phone;
  final String? name;

  ReceiverQrPayload({required this.phone, this.name});

  String encode() {
    final p = phone.trim();
    if (p.isEmpty) {
      // Safety: return minimal valid payload (or throw if you prefer).
      return '$scheme${base64Url.encode(utf8.encode(jsonEncode({
        'v': 1,
        'kind': 'receiver',
        'phone': '',
      })))}';
    }

    final obj = {
      'v': 1,
      'kind': 'receiver',
      'phone': p,
      if (name != null && name!.trim().isNotEmpty) 'name': name!.trim(),
    };

    final b64 = base64Url.encode(utf8.encode(jsonEncode(obj)));
    return '$scheme$b64';
  }

  static ReceiverQrPayload? tryParse(String raw) {
    raw = raw.trim();
    // Full scheme
    if (raw.startsWith(scheme)) {
      final b64 = raw.substring(scheme.length);
      try {
        // Normalize handles missing '=' padding
        final normalized = base64Url.normalize(b64);
        final jsonStr = utf8.decode(base64Url.decode(normalized));
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        if (map['kind'] == 'receiver' && map['phone'] is String) {
          final phone = (map['phone'] as String).trim();
          final name  = map['name']?.toString();
          if (phone.isNotEmpty) {
            return ReceiverQrPayload(phone: phone, name: name);
          }
        }
      } catch (_) {
        // fall through to phone fallback
      }
    }

    // Fallback: treat QR as plain phone (digits/+)
    final digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.length >= 10) {
      return ReceiverQrPayload(phone: digits);
    }
    return null;
  }
}
