import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import '../service/match_detail_service.dart';
import '../model/match_stats_model.dart';

/// Service moved to match_detail_service.dart; remove duplicate definition here

class MatchStatsTab extends StatefulWidget {
  final int matchId;
  final String team1Name;
  final String team2Name;

  const MatchStatsTab({
    super.key,
    required this.matchId,
    required this.team1Name,
    required this.team2Name,
  });

  @override
  State<MatchStatsTab> createState() => _MatchStatsTabState();
}

class _MatchStatsTabState extends State<MatchStatsTab> {
  late Future<MatchStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    // Use the service from match_detail_service.dart
    _statsFuture = MatchStatsService.fetchStats(widget.matchId);
  }

  Widget _buildNoData(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  bool _isRunTypesEmpty(MatchStats s) =>
      (s.runTypesTeam1.ones ?? 0) == 0 &&
          (s.runTypesTeam1.twos ?? 0) == 0 &&
          (s.runTypesTeam1.fours ?? 0) == 0 &&
          (s.runTypesTeam1.sixes ?? 0) == 0 &&
          (s.runTypesTeam1.extras ?? 0) == 0 &&
          (s.runTypesTeam2.ones ?? 0) == 0 &&
          (s.runTypesTeam2.twos ?? 0) == 0 &&
          (s.runTypesTeam2.fours ?? 0) == 0 &&
          (s.runTypesTeam2.sixes ?? 0) == 0 &&
          (s.runTypesTeam2.extras ?? 0) == 0;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MatchStats>(
      future: _statsFuture,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _buildNoData(snap.error.toString());
        }
        final stats = snap.data;
        if (stats == null) {
          return _buildNoData('No stats data available');
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection(
                'Manhattan Chart (Per Over Runs)',
                stats.manhattanTeam1.isNotEmpty || stats.manhattanTeam2.isNotEmpty,
                    () => _buildManhattanChart(stats),
              ),
              const SizedBox(height: 20),
              _buildSection(
                'Worm Chart (Cumulative Runs)',
                stats.wormTeam1.isNotEmpty || stats.wormTeam2.isNotEmpty,
                    () => _buildWormChart(stats),
              ),
              const SizedBox(height: 20),
              _buildSection(
                'Run Types (Bar Chart)',
                !_isRunTypesEmpty(stats),
                    () => _buildRunTypeBarChart(stats),
              ),
              const SizedBox(height: 20),
              _buildSection(
                'Wicket Types (Pie Chart)',
                stats.wicketTypes.isNotEmpty,
                    () => _buildWicketChartAndLegend(stats),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection(String title, bool hasData, Widget Function() chart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        hasData ? chart() : _buildNoData('No $title available'),
      ],
    );
  }

  Widget _buildLegend() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _legendItem(widget.team1Name, Colors.blue),
      const SizedBox(width: 10),
      _legendItem(widget.team2Name, Colors.orange),
    ],
  );

  Widget _legendItem(String label, Color color) => Row(
    children: [
      Container(width: 10, height: 10, color: color),
      const SizedBox(width: 4),
      Text(label),
    ],
  );

  Widget _buildManhattanChart(MatchStats s) {
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          barGroups: List.generate(
            s.manhattanTeam1.length,
                (i) => BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: s.manhattanTeam1[i].totalRuns?.toDouble() ?? 0,
                  width: 7,
                  color: Colors.blue,
                ),
                BarChartRodData(
                  toY: i < s.manhattanTeam2.length
                      ? s.manhattanTeam2[i].totalRuns?.toDouble() ?? 0
                      : 0,
                  width: 7,
                  color: Colors.orange,
                ),
              ],
            ),
          ),
          alignment: BarChartAlignment.spaceAround,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) =>
                    Text((v.toInt() + 1).toString(),
                        style: const TextStyle(fontSize: 10)),
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
        ),
      ),
    );
  }

  Widget _buildWormChart(MatchStats s) {
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: s.wormTeam1
                  .map(
                    (e) => FlSpot(
                  e.overNumber?.toDouble() ?? 0,
                  e.totalRuns?.toDouble() ?? 0,
                ),
              )
                  .toList(),
              isCurved: true,
              color: Colors.blue,
              dotData: FlDotData(show: true),
            ),
            LineChartBarData(
              spots: s.wormTeam2
                  .map(
                    (e) => FlSpot(
                  e.overNumber?.toDouble() ?? 0,
                  e.totalRuns?.toDouble() ?? 0,
                ),
              )
                  .toList(),
              isCurved: true,
              color: Colors.orange,
              dotData: FlDotData(show: true),
            ),
          ],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) =>
                    Text(v.toInt().toString(),
                        style: const TextStyle(fontSize: 10)),
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
          ),
        ),
      ),
    );
  }

  Widget _buildRunTypeBarChart(MatchStats s) {
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          barGroups: List.generate(5, (i) {
            final values1 = [
              s.runTypesTeam1.ones,
              s.runTypesTeam1.twos,
              s.runTypesTeam1.fours,
              s.runTypesTeam1.sixes,
              s.runTypesTeam1.extras
            ];
            final values2 = [
              s.runTypesTeam2.ones,
              s.runTypesTeam2.twos,
              s.runTypesTeam2.fours,
              s.runTypesTeam2.sixes,
              s.runTypesTeam2.extras
            ];
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(toY: values1[i]?.toDouble() ?? 0,
                    color: Colors.blue),
                BarChartRodData(toY: values2[i]?.toDouble() ?? 0,
                    color: Colors.orange),
              ],
            );
          }),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final labels = ["1s", "2s", "4s", "6s", "Extras"];
                  final index = v.toInt();
                  return index >= 0 && index < labels.length
                      ? Text(labels[index],
                      style: const TextStyle(fontSize: 10))
                      : const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
          ),
        ),
      ),
    );
  }

  Widget _buildWicketChartAndLegend(MatchStats s) {
    return Column(
      children: [
        SizedBox(
          height: 250,
          child: PieChart(PieChartData(
            sections: List.generate(s.wicketTypes.length, (i) {
              final item = s.wicketTypes[i];
              final colors = [
                Colors.red,
                Colors.green,
                Colors.purple,
                Colors.teal,
                Colors.amber,
                Colors.brown,
                Colors.indigo,
                Colors.cyan
              ];
              return PieChartSectionData(
                color: colors[i % colors.length],
                value: item.totalWickets?.toDouble() ?? 0,
                title: '${item.totalWickets}',
                titleStyle: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              );
            }),
          )),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          children: List.generate(s.wicketTypes.length, (i) {
            final item = s.wicketTypes[i];
            final colors = [
              Colors.red,
              Colors.green,
              Colors.purple,
              Colors.teal,
              Colors.amber,
              Colors.brown,
              Colors.indigo,
              Colors.cyan,
            ];
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 10,
                    height: 10,
                    color: colors[i % colors.length]),
                const SizedBox(width: 4),
                Text(item.wicketType,
                    style: const TextStyle(fontSize: 12)),
              ],
            );
          }),
        )
      ],
    );
  }
}