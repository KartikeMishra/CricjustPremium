// lib/screen/match_stats_tab.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../service/match_detail_service.dart';
import '../model/match_stats_model.dart';

class MatchStatsTab extends StatefulWidget {
  final int matchId;
  final String team1Name;
  final String team2Name;
  final int refreshTick; // 🔄 will refetch when this changes

  const MatchStatsTab({
    super.key,
    required this.matchId,
    required this.team1Name,
    required this.team2Name,
    this.refreshTick = 0,
  });

  @override
  _MatchStatsTabState createState() => _MatchStatsTabState();
}

class _MatchStatsTabState extends State<MatchStatsTab> {
  late Future<MatchStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = MatchStatsService.fetchStats(widget.matchId);
  }

  @override
  void didUpdateWidget(covariant MatchStatsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) {
      setState(() {
        _statsFuture = MatchStatsService.fetchStats(widget.matchId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : Colors.black87;
    final gridColor = isDark ? Colors.white12 : Colors.grey.shade300;
    final cardBg = isDark ? Colors.grey[900]! : Colors.white;

    return FutureBuilder<MatchStats>(
      future: _statsFuture,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _buildNoData('Error: ${snap.error}');
        }
        final stats = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(), // supports pull-to-refresh gesture
          children: [
            _buildSection(
              title: 'Manhattan (Per-Over Runs)',
              showLegend: true,
              legend: _buildLegend(textColor),
              hasData: stats.manhattanTeam1.isNotEmpty || stats.manhattanTeam2.isNotEmpty,
              child: _buildManhattanChart(stats, textColor, gridColor),
              cardBg: cardBg,
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Worm (Cumulative Runs)',
              showLegend: true,
              legend: _buildLegend(textColor),
              hasData: stats.wormTeam1.isNotEmpty || stats.wormTeam2.isNotEmpty,
              child: _buildWormChart(stats, textColor, gridColor),
              height: 260,
              cardBg: cardBg,
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Run Types',
              showLegend: true,
              legend: _buildLegend(textColor),
              hasData: !_isRunTypesEmpty(stats),
              child: _buildRunTypeChart(stats, textColor, gridColor),
              cardBg: cardBg,
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Wicket Types',
              showLegend: false,
              hasData: stats.wicketTypes.isNotEmpty,
              child: _buildWicketChart(stats, textColor),
              height: 280,
              cardBg: cardBg,
            ),
          ],
        );
      },
    );
  }

  Widget _buildSection({
    required String title,
    required bool hasData,
    required Widget child,
    required Color cardBg,
    double height = 240,
    bool showLegend = false,
    Widget? legend,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        if (showLegend && legend != null) ...[
          const SizedBox(height: 8),
          legend,
        ],
        const SizedBox(height: 8),
        SizedBox(
          height: height,
          child: Card(
            color: cardBg,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: hasData ? child : const Center(child: Text('No data', style: TextStyle(color: Colors.grey))),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegend(Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem(widget.team1Name, Colors.blue, textColor),
        const SizedBox(width: 24),
        _legendItem(widget.team2Name, Colors.orange, textColor),
      ],
    );
  }

  Widget _legendItem(String label, Color color, Color textColor) => Row(
    children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      ),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 13, color: textColor)),
    ],
  );

  bool _isRunTypesEmpty(MatchStats s) =>
      (s.runTypesTeam1.ones +
          s.runTypesTeam1.twos +
          s.runTypesTeam1.fours +
          s.runTypesTeam1.sixes +
          s.runTypesTeam1.extras ==
          0) &&
          (s.runTypesTeam2.ones +
              s.runTypesTeam2.twos +
              s.runTypesTeam2.fours +
              s.runTypesTeam2.sixes +
              s.runTypesTeam2.extras ==
              0);

  Widget _buildManhattanChart(MatchStats s, Color textColor, Color gridColor) {
    final maxOvers = max(s.manhattanTeam1.length, s.manhattanTeam2.length);
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceBetween,
        barGroups: List.generate(maxOvers, (i) {
          final y1 = i < s.manhattanTeam1.length ? s.manhattanTeam1[i].totalRuns.toDouble() : 0.0;
          final y2 = i < s.manhattanTeam2.length ? s.manhattanTeam2[i].totalRuns.toDouble() : 0.0;
          return BarChartGroupData(
            x: i + 1,
            barRods: [
              BarChartRodData(toY: y1, width: 8, color: Colors.blue),
              BarChartRodData(toY: y2, width: 8, color: Colors.orange),
            ],
          );
        }),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (y) => FlLine(color: gridColor, strokeWidth: y == 0 ? 1.2 : 0.6),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, _) => SizedBox(
                width: 24,
                child: Transform.rotate(
                  angle: -pi / 4,
                  child: Text('${value.toInt()}', style: TextStyle(fontSize: 10, color: textColor)),
                ),
              ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) => Text('${v.toInt()}', style: TextStyle(fontSize: 10, color: textColor)),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
      ),
    );
  }

  Widget _buildWormChart(MatchStats s, Color textColor, Color gridColor) {
    return LineChart(
      LineChartData(
        lineTouchData: const LineTouchData(enabled: true),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (y) => FlLine(color: gridColor, strokeWidth: 0.8),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: s.wormTeam1.map((e) => FlSpot(e.overNumber.toDouble(), e.totalRuns.toDouble())).toList(),
            isCurved: true,
            gradient: const LinearGradient(colors: [Colors.blue, Colors.lightBlueAccent]),
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: s.wormTeam2.map((e) => FlSpot(e.overNumber.toDouble(), e.totalRuns.toDouble())).toList(),
            isCurved: true,
            gradient: const LinearGradient(colors: [Colors.orange, Colors.deepOrangeAccent]),
            dotData: const FlDotData(show: false),
          ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, _) => SizedBox(
                width: 24,
                child: Transform.rotate(
                  angle: -pi / 4,
                  child: Text('${value.toInt()}', style: TextStyle(fontSize: 10, color: textColor)),
                ),
              ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) => Text('${v.toInt()}', style: TextStyle(fontSize: 10, color: textColor)),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
      ),
    );
  }

  Widget _buildRunTypeChart(MatchStats s, Color textColor, Color gridColor) {
    final labels = ['1s', '2s', '4s', '6s', 'Extras'];
    final t1 = [
      s.runTypesTeam1.ones,
      s.runTypesTeam1.twos,
      s.runTypesTeam1.fours,
      s.runTypesTeam1.sixes,
      s.runTypesTeam1.extras,
    ].map((v) => v.toDouble()).toList();
    final t2 = [
      s.runTypesTeam2.ones,
      s.runTypesTeam2.twos,
      s.runTypesTeam2.fours,
      s.runTypesTeam2.sixes,
      s.runTypesTeam2.extras,
    ].map((v) => v.toDouble()).toList();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barGroups: List.generate(labels.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(toY: t1[i], width: 10, color: Colors.blue),
              BarChartRodData(toY: t2[i], width: 10, color: Colors.orange),
            ],
          );
        }),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (y) => FlLine(color: gridColor, strokeWidth: 0.6),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (v, _) => SizedBox(
                width: 28,
                child: Transform.rotate(
                  angle: -pi / 4,
                  child: Text(labels[v.toInt()], style: TextStyle(fontSize: 10, color: textColor)),
                ),
              ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) => Text('${v.toInt()}', style: TextStyle(fontSize: 10, color: textColor)),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
      ),
    );
  }

  Widget _buildWicketChart(MatchStats s, Color textColor) {
    const colors = [Colors.red, Colors.green, Colors.purple, Colors.teal, Colors.amber];
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sections: List.generate(s.wicketTypes.length, (i) {
                final w = s.wicketTypes[i];
                return PieChartSectionData(
                  color: colors[i % colors.length],
                  value: w.totalWickets.toDouble(),
                  title: '${w.totalWickets}',
                  radius: 50,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }),
              sectionsSpace: 2,
              centerSpaceRadius: 30,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: List.generate(s.wicketTypes.length, (i) {
            final w = s.wicketTypes[i];
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: colors[i % colors.length],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 6),
                Text(w.wicketType, style: TextStyle(fontSize: 12, color: textColor)),
              ],
            );
          }),
        ),
      ],
    );
  }

  Widget _buildNoData(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 80, color: Colors.grey),
            const SizedBox(height: 12),
            Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
