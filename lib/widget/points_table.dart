// lib/widget/points_table.dart
import 'package:flutter/material.dart';
import 'package:cricjust_premium/widget/tournament_team_matches_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/color.dart';
import '../../model/tournament_overview_model.dart';

/// ---------- Safe image helpers (prevent NetworkImage("") crashes) ----------
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
/// ---------------------------------------------------------------------------

class PointsTableWidget extends StatelessWidget {
  final GroupModel group;
  final List<TeamStanding> teams;

  const PointsTableWidget({
    super.key,
    required this.group,
    required this.teams,
  });

  // Some backends/models may not expose ties/draws/matches; guard access.
  int _ties(TeamStanding t) {
    try { return ((t as dynamic).ties as int?) ?? 0; } catch (_) { return 0; }
  }

  int _draws(TeamStanding t) {
    try { return ((t as dynamic).draws as int?) ?? 0; } catch (_) { return 0; }
  }

  int _matches(TeamStanding t) {
    // Prefer explicit field if present
    try {
      final m = ((t as dynamic).matches as int?);
      if (m != null) return m;
    } catch (_) {}
    // Fallback: W + L + T + D
    return t.wins + t.losses + _ties(t) + _draws(t);
  }

  String _nrr(TeamStanding t) {
    try {
      final v = (t.netRR).toString().trim();
      return v.isEmpty ? '-' : v;
    } catch (_) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = List<TeamStanding>.from(teams)
      ..sort((a, b) => b.points.compareTo(a.points));
    final screenW = MediaQuery.of(context).size.width;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: isDark ? Colors.grey[900] : Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Blue header with group name
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Text(
                    group.groupName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),

                // Scrollable table
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: screenW),
                    child: Table(
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      columnWidths: const {
                        0: FlexColumnWidth(3), // Team
                        1: FlexColumnWidth(1), // M
                        2: FlexColumnWidth(1), // W
                        3: FlexColumnWidth(1), // L
                        4: FlexColumnWidth(1), // T
                        5: FlexColumnWidth(1), // D
                        6: FlexColumnWidth(1), // Pts
                        7: FlexColumnWidth(1), // NRR
                        8: FlexColumnWidth(1), // →
                      },
                      border: const TableBorder.symmetric(inside: BorderSide.none, outside: BorderSide.none),
                      children: [
                        // Header row
                        TableRow(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.grey.shade100,
                          ),
                          children: [
                            _headerCell('Team', isDark),
                            _headerCell('M', isDark),
                            _headerCell('W', isDark),
                            _headerCell('L', isDark),
                            _headerCell('T', isDark),
                            _headerCell('D', isDark),
                            _headerCell('Pts', isDark),
                            _headerCell('NRR', isDark),
                            _headerCell('', isDark),
                          ],
                        ),

                        // Data rows
                        for (int i = 0; i < sorted.length; i++)
                          TableRow(
                            decoration: BoxDecoration(
                              color: i.isEven
                                  ? (isDark ? Colors.grey[900] : Colors.white)
                                  : (isDark ? Colors.grey[850] : Colors.grey.shade50),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                                child: Row(
                                  children: [
                                    ClipOval(
                                      child: _safeNetImg(
                                        sorted[i].teamLogo,
                                        width: 32, height: 32, fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Ellipsize to avoid overflows in table cell
                                    Expanded(
                                      child: Text(
                                        sorted[i].teamName,
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
                              _dataCell('${_matches(sorted[i])}', isDark),
                              _dataCell('${sorted[i].wins}', isDark),
                              _dataCell('${sorted[i].losses}', isDark),
                              _dataCell('${_ties(sorted[i])}', isDark),
                              _dataCell('${_draws(sorted[i])}', isDark),
                              _dataCell('${sorted[i].points}', isDark),
                              _dataCell(_nrr(sorted[i]), isDark),
                              Center(
                                child: IconButton(
                                  icon: Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TeamMatchesScreen(team: sorted[i]),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.bold, fontSize: 14,
            color: isDark ? Colors.white70 : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _dataCell(String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
        ),
      ),
    );
  }
}
