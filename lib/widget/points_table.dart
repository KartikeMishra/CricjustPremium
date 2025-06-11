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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Card(
        color: Colors.white,
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
            // Legend
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                children: const [
                  Chip(label: Text('M = Matches', style: TextStyle(fontSize: 12))),
                  Chip(label: Text('W = Wins', style: TextStyle(fontSize: 12))),
                  Chip(label: Text('L = Losses', style: TextStyle(fontSize: 12))),
                  Chip(label: Text('T = Ties', style: TextStyle(fontSize: 12))),
                  Chip(label: Text('D = Draws', style: TextStyle(fontSize: 12))),
                  Chip(label: Text('Pts = Points', style: TextStyle(fontSize: 12))),
                  Chip(label: Text('NRR = Net Run Rate', style: TextStyle(fontSize: 12))),
                  Chip(label: Text('→ = View Matches', style: TextStyle(fontSize: 12))),
                ],
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
                  border: TableBorder(
                    top: BorderSide(color: Colors.grey.shade300),
                    bottom: BorderSide(color: Colors.grey.shade300),
                    horizontalInside:
                    BorderSide(color: Colors.grey.shade200),
                    verticalInside:
                    BorderSide(color: Colors.grey.shade200),
                  ),
                  columnWidths: const {
                    0: FlexColumnWidth(3), // Team
                    1: FlexColumnWidth(1), // M
                    2: FlexColumnWidth(1), // W
                    3: FlexColumnWidth(1), // L
                    4: FlexColumnWidth(1), // T
                    5: FlexColumnWidth(1), // D
                    6: FlexColumnWidth(1), // Pts
                    7: FlexColumnWidth(1), // NRR
                    8: FlexColumnWidth(1), // View
                  },
                  children: [
                    // Header row
                    TableRow(
                      decoration:
                      BoxDecoration(color: Colors.grey.shade100),
                      children: [
                        _headerCell('Team'),
                        _headerCell('M'),
                        _headerCell('W'),
                        _headerCell('L'),
                        _headerCell('T'),
                        _headerCell('D'),
                        _headerCell('Pts'),
                        _headerCell('NRR'),
                        _headerCell(''),
                      ],
                    ),
                    // Data rows
                    for (int i = 0; i < sorted.length; i++)
                      TableRow(
                        decoration: BoxDecoration(
                          color: i.isEven
                              ? Colors.white
                              : Colors.grey.shade50,
                        ),
                        children: [
                          // Team cell with logo
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
                                Expanded(
                                  child: Text(
                                    sorted[i].teamName,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _dataCell(
                            '${sorted[i].wins + sorted[i].losses + (sorted[i] as dynamic).ties + (sorted[i] as dynamic).draws}',
                          ),
                          _dataCell('${sorted[i].wins}'),
                          _dataCell('${sorted[i].losses}'),
                          _dataCell('${(sorted[i] as dynamic).ties}'),
                          _dataCell('${(sorted[i] as dynamic).draws}'),
                          _dataCell('${sorted[i].points}'),
                          _dataCell(sorted[i].netRR),
                          // Arrow button
                          Center(
                            child: IconButton(
                              icon: const Icon(Icons.arrow_forward_ios, size: 16),
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
    );
  }

  Widget _headerCell(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  Widget _dataCell(String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          value,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
      ),
    );
  }

  Widget _legendChip(BuildContext context, String label, String meaning) {
    return Chip(
      label: Text(
        '$label = $meaning',
        style: const TextStyle(fontSize: 12, color: Colors.black54),
      ),
      backgroundColor: AppColors.primary.withOpacity(0.1),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
