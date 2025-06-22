// lib/widget/points_table.dart

import 'package:flutter/material.dart';
import 'package:cricjust_premium/widget/tournament_team_matches_screen.dart';
import '../theme/color.dart';
import '../../model/tournament_overview_model.dart';

class PointsTableWidget extends StatelessWidget {
  final GroupModel group;
  final List<TeamStanding> teams;

  const PointsTableWidget({
    Key? key,
    required this.group,
    required this.teams,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final sorted = List<TeamStanding>.from(teams)
      ..sort((a, b) => b.points.compareTo(a.points));
    final width = MediaQuery.of(context).size.width;
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
                    borderRadius:
                    BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Text(
                    group.groupName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Scrollable table
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: width),
                    child: Table(
                      defaultVerticalAlignment:
                      TableCellVerticalAlignment.middle,
                      columnWidths: const {
                        0: FlexColumnWidth(3),
                        1: FlexColumnWidth(1),
                        2: FlexColumnWidth(1),
                        3: FlexColumnWidth(1),
                        4: FlexColumnWidth(1),
                        5: FlexColumnWidth(1),
                        6: FlexColumnWidth(1),
                        7: FlexColumnWidth(1),
                        8: FlexColumnWidth(1),
                      },
                      border: TableBorder.symmetric(
                        inside: BorderSide.none,
                        outside: BorderSide.none,
                      ),
                      children: [
                        // Header row
                        TableRow(
                          decoration:
                          BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey.shade100),
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
                        for (int i = 0; i < sorted.length; i++)
                          TableRow(
                            decoration: BoxDecoration(
                              color: i.isEven
                                  ? (isDark ? Colors.grey[900] : Colors.white)
                                  : (isDark ? Colors.grey[850] : Colors.grey.shade50),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 4),
                                child: Row(
                                  children: [
                                    ClipOval(
                                      child: sorted[i].teamLogo.isNotEmpty
                                          ? Image.network(
                                        sorted[i].teamLogo,
                                        width: 32,
                                        height: 32,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (_, __, ___) => const Icon(Icons.person, size: 32),
                                      )
                                          : const Icon(Icons.person, size: 32),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        sorted[i].teamName,
                                        overflow: TextOverflow.visible,
                                        softWrap: true,
                                        style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _dataCell(
                                '${sorted[i].wins + sorted[i].losses + (sorted[i] as dynamic).ties + (sorted[i] as dynamic).draws}',
                                isDark,
                              ),
                              _dataCell('${sorted[i].wins}', isDark),
                              _dataCell('${sorted[i].losses}', isDark),
                              _dataCell('${(sorted[i] as dynamic).ties}', isDark),
                              _dataCell('${(sorted[i] as dynamic).draws}', isDark),
                              _dataCell('${sorted[i].points}', isDark),
                              _dataCell(sorted[i].netRR, isDark),
                              Center(
                                child: IconButton(
                                  icon: Icon(Icons.arrow_forward_ios, size: 16, color: isDark ? Colors.white70 : Colors.black54),
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
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white70 : Colors.black),
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
          style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
        ),
      ),
    );
  }
}
