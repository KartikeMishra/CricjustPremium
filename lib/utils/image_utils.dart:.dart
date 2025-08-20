import 'package:flutter/material.dart';

const String _BASE = 'https://cricjust.in';

bool _bad(String? s) {
  if (s == null) return true;
  final t = s.trim();
  if (t.isEmpty || t == 'null' || t == 'N/A') return true;
  final low = t.toLowerCase();
  return low.startsWith('file:') ||
      low.startsWith('content:') ||
      low.startsWith('data:') ||
      low.startsWith('blob:');
}

String? normalizeImageUrl(String? url) {
  if (_bad(url)) return null;
  final s = url!.trim();
  if (s.startsWith('http://') || s.startsWith('https://')) return s;
  if (s.startsWith('//')) return 'https:$s';
  if (s.startsWith('/')) return '$_BASE$s';
  return '$_BASE/$s';
}

ImageProvider? safeImageProvider(String? url) {
  final u = normalizeImageUrl(url);
  return (u == null) ? null : NetworkImage(u);
}

Widget safeNetImg(
    String? url, {
      double? width,
      double? height,
      BoxFit fit = BoxFit.cover,
      String placeholderAsset = 'lib/asset/images/cricjust_logo.png',
      Key? key,
    }) {
  final u = normalizeImageUrl(url);
  if (u == null) {
    return Image.asset(placeholderAsset, width: width, height: height, fit: fit, key: key);
  }
  return Image.network(
    u,
    width: width,
    height: height,
    fit: fit,
    gaplessPlayback: true,
    key: key ?? ValueKey('net-$u'), // forces state reset on hot reload
    errorBuilder: (_, __, ___) => Image.asset(placeholderAsset, width: width, height: height, fit: fit),
  );
}
