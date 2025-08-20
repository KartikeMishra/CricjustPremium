// lib/service/image_upload_cache.dart
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ImageUploadCache {
  static const _k = 'upload_cache_v1'; // hash -> url map (JSON)
  static const bool kDebugCache = true;

  static void _log(String msg) {
    if (kDebugCache) debugPrint('🧪 [UploadCache] $msg');
  }

  static Future<String> _hashFile(File f) async {
    final bytes = await f.readAsBytes();
    final h = sha1.convert(bytes).toString();
    _log('hash=${h.substring(0, 8)}… for ${f.path}');
    return h;
  }

  static Future<String?> getIfUploaded(File file) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_k);
    if (raw == null || raw.isEmpty) return null;
    final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
    final h = await _hashFile(file);
    final v = map[h];
    _log(v == null ? 'MISS' : 'HIT url=$v');
    return (v == null || v.toString().isEmpty) ? null : v.toString();
  }

  static Future<void> save(File file, String url) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_k);
    final map = (raw == null || raw.isEmpty)
        ? <String, dynamic>{}
        : (jsonDecode(raw) as Map).cast<String, dynamic>();
    final h = await _hashFile(file);
    map[h] = url;
    // Optional: cap cache to last 50 entries
    while (map.length > 50) {
      final firstKey = map.keys.first;
      map.remove(firstKey);
    }
    await prefs.setString(_k, jsonEncode(map));
    _log('Saved url for hash=${h.substring(0, 8)}…');
  }
}
