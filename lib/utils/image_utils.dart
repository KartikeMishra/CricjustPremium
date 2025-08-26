import 'package:flutter/material.dart';

/// Trim + drop "null"
String _sanitize(String? s) {
  if (s == null) return '';
  final t = s.trim();
  if (t.isEmpty || t.toLowerCase() == 'null') return '';
  return t;
}

/// Expand relative WP paths to absolute. Rejects non-http(s).
String? normalizeImageUrl(String? raw, {String base = 'https://cricjust.in'}) {
  final t = _sanitize(raw);
  if (t.isEmpty) return null;

  if (t.startsWith('http://') || t.startsWith('https://')) return t;
  if (t.startsWith('//')) return 'https:$t';
  if (t.startsWith('/')) return '$base$t';
  if (t.startsWith('wp-content')) return '$base/$t';

  // reject file://, data:, about:blank, etc.
  return null;
}

bool isHttpUrl(String? s) => normalizeImageUrl(s) != null;

/// Safe provider (null if not a proper http/https URL)
ImageProvider? tryNetworkImage(String? raw) {
  final url = normalizeImageUrl(raw);
  return url == null ? null : NetworkImage(url);
}

/// Safe <Image> widget with local fallback (no crashes).
Widget safeNetworkImage(
    String? raw, {
      double? width,
      double? height,
      BoxFit fit = BoxFit.cover,
      String assetFallback = 'lib/asset/images/Random_Image.png',
      int? cacheWidth,
      int? cacheHeight,
    }) {
  final prov = tryNetworkImage(raw);
  if (prov == null) {
    return Image.asset(
      assetFallback,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.low,
    );
  }
  return Image(
    image: prov,
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (_, __, ___) => Image.asset(
      assetFallback,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.low,
    ),
    filterQuality: FilterQuality.low,
  );
}

/// Safe CircleAvatar that uses foregroundImage only when valid.
Widget safeAvatar({
  String? url,
  double radius = 20,
  Widget? fallbackChild,
  String assetFallback = 'lib/asset/images/Random_Image.png',
}) {
  final prov = tryNetworkImage(url);
  return CircleAvatar(
    radius: radius,
    foregroundImage: prov,
    child: prov == null
        ? (fallbackChild ??
        ClipOval(
          child: Image.asset(
            assetFallback,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
          ),
        ))
        : null,
  );
}
