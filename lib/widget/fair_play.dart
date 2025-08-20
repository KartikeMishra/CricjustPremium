// lib/widget/fair_play.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../model/fair_play_model.dart';
import '../theme/color.dart';

/// ---------- Safe image helpers (prevent NetworkImage("") / file:// crashes) ----------
// Add at the top of the file
const String _kBase = 'https://cricjust.in';
const String _kPlaceholder = 'lib/asset/images/cricjust_logo.png';

bool _isBadUrl(String? s) {
  if (s == null) return true;
  final t = s.trim();
  if (t.isEmpty || t == 'null' || t == 'N/A') return true;
  final low = t.toLowerCase();
  return low.startsWith('file:') ||
      low.startsWith('file:///') ||
      low.startsWith('content:') ||
      low.startsWith('data:') ||
      low.startsWith('blob:');
}

String? _normalizeUrl(String? url) {
  if (_isBadUrl(url)) return null;
  final s = url!.trim();
  if (s.startsWith('http://') || s.startsWith('https://')) return s;
  if (s.startsWith('//')) return 'https:$s';
  if (s.startsWith('/')) return '$_kBase$s';
  return '$_kBase/$s';
}

// Update _tile method:
Widget _tile(
    String? img,
    String name,
    String subtitle, {
      String? trailing,
      VoidCallback? onTap,
    }) {
  final safeImg = _normalizeUrl(img);
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 24,
        backgroundImage: safeImg != null
            ? NetworkImage(safeImg)
            : const AssetImage(_kPlaceholder),
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: trailing == null
          ? null
          : Text(
        trailing,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.1);
}

Widget _safeNetImg(
    String? url, {
      double? width,
      double? height,
      BoxFit fit = BoxFit.cover,
    }) {
  final u = _normalizeUrl(url);
  if (u == null) {
    return Image.asset(_kPlaceholder, width: width, height: height, fit: fit);
  }
  return Image.network(
    u,
    width: width,
    height: height,
    fit: fit,
    gaplessPlayback: true,
    errorBuilder: (_, __, ___) =>
        Image.asset(_kPlaceholder, width: width, height: height, fit: fit),
  );
}
/// -----------------------------------------------------------------------------------------------

class FairPlayTableWidget extends StatelessWidget {
  final List<FairPlayStanding> fairPlayTeams;
  const FairPlayTableWidget({super.key, required this.fairPlayTeams});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Card(
        color: isDark ? Colors.grey[900] : Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Blue header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: const Text(
                'Fair-Play Standings',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            // Table header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      'Team',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'FP',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'M',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: isDark ? Colors.grey[700] : null),

            // Rows
            ...fairPlayTeams.asMap().entries.map((e) {
              final idx = e.key;
              final f = e.value;

              return Container(
                color: idx.isEven
                    ? (isDark ? Colors.grey[900] : Colors.white)
                    : (isDark ? Colors.grey[850] : Colors.grey.shade50),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Row(
                        children: [
                          ClipOval(
                            child: _safeNetImg(
                              f.teamLogo,
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              f.teamName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        // safe formatting even if backend returns int/double
                        (f.fairPlayPoints is num)
                            ? (f.fairPlayPoints as num).toStringAsFixed(1)
                            : f.fairPlayPoints.toString(),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${f.totalMatches}',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
