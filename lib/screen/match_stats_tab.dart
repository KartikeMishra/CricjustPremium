import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../service/match_detail_service.dart';
import '../model/match_stats_model.dart';

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

  // consistent team colors (dark/light friendly)
  Color get _t1 => Colors.blue;
  Color get _t1Light => Colors.lightBlueAccent;
  Color get _t2 => Colors.orange;
  Color get _t2Light => Colors.deepOrangeAccent;

  @override
  void initState() {
    super.initState();
    _statsFuture = MatchStatsService.fetchStats(widget.matchId);
  }

  Future<void> _refresh() async {
    setState(() {
      _statsFuture = MatchStatsService.fetchStats(widget.matchId);
    });
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

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSection(
                title: 'Manhattan (Per-Over Runs)',
                legend: _buildLegend(textColor),
                hasData:
                stats.manhattanTeam1.isNotEmpty ||
                    stats.manhattanTeam2.isNotEmpty,
                cardBg: cardBg,
                child: _buildManhattanChart(stats, textColor, gridColor),
              ),
              const SizedBox(height: 24),
              _buildSection(
                title: 'Worm (Cumulative Runs)',
                legend: _buildLegend(textColor),
                hasData: stats.wormTeam1.isNotEmpty ||
                    stats.wormTeam2.isNotEmpty,
                height: 260,
                cardBg: cardBg,
                child: _buildWormChart(stats, textColor, gridColor),
              ),
              const SizedBox(height: 24),
              _buildSection(
                title: 'Run Types',
                legend: _buildLegend(textColor),
                hasData: !_isRunTypesEmpty(stats),
                cardBg: cardBg,
                child: _buildRunTypeChart(stats, textColor, gridColor),
              ),
              const SizedBox(height: 24),
              _buildSection(
                title: 'Wicket Types',
                hasData: stats.wicketTypes.isNotEmpty,
                height: 300,
                cardBg: cardBg,
                child: _buildWicketChart(stats, textColor),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------- Section ----------

  Widget _buildSection({
    required String title,
    required bool hasData,
    required Widget child,
    required Color cardBg,
    double height = 240,
    Widget? legend,
  }) {
    final titleStyle =
    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: titleStyle),
        if (legend != null) ...[
          const SizedBox(height: 8),
          legend,
        ],
        const SizedBox(height: 8),
        SizedBox(
          height: height,
          child: Card(
            clipBehavior: Clip.antiAlias,
            color: cardBg,
            elevation: 4,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: hasData
                  ? child
                  : const Center(
                child:
                Text('No data', style: TextStyle(color: Colors.grey)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegend(Color textColor) {
    return LayoutBuilder(
      builder: (context, c) {
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            _legendItem(widget.team1Name, _t1, textColor, c.maxWidth),
            _legendItem(widget.team2Name, _t2, textColor, c.maxWidth),
          ],
        );
      },
    );
  }

  Widget _legendItem(String label, Color color, Color textColor, double maxW) {
    final name = (label.isEmpty) ? 'Team' : label;
    // cap each chip so two can fit side-by-side; fall back to 80% if space is tight
    final cap = maxW >= 360 ? maxW * 0.44 : maxW * 0.8;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: cap),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: textColor),
                softWrap: false,
              ),
            ),
          ],
        ),
      ),
    );
  }


  // ---------- Helpers ----------

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

  double _maxY(Iterable<double> values) {
    final m = values.isEmpty ? 0 : values.reduce(max);
    if (m == 0) return 6; // small headroom base
    return (m * 1.15).ceilToDouble(); // 15% headroom
  }

  // ---------- Charts ----------

  Widget _buildManhattanChart(MatchStats s, Color textColor, Color gridColor) {
    final maxOvers = max(s.manhattanTeam1.length, s.manhattanTeam2.length);

    final allY = <double>[
      ...s.manhattanTeam1.map((e) => e.totalRuns.toDouble()),
      ...s.manhattanTeam2.map((e) => e.totalRuns.toDouble()),
    ];
    final maxY = _maxY(allY);

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.black.withOpacity(.75),
            getTooltipItem: (group, _, rod, __) => BarTooltipItem(
              'Over ${group.x}\n${rod.toY.toInt()} runs',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        alignment: BarChartAlignment.spaceBetween,
        groupsSpace: 8,
        barGroups: List.generate(maxOvers, (i) {
          final y1 = i < s.manhattanTeam1.length
              ? s.manhattanTeam1[i].totalRuns.toDouble()
              : 0.0;
          final y2 = i < s.manhattanTeam2.length
              ? s.manhattanTeam2[i].totalRuns.toDouble()
              : 0.0;
          return BarChartGroupData(
            x: i + 1,
            barsSpace: 6,
            barRods: [
              BarChartRodData(toY: y1, width: 9, color: _t1),
              BarChartRodData(toY: y2, width: 9, color: _t2),
            ],
          );
        }),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (y) =>
              FlLine(color: gridColor, strokeWidth: 0.6),
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
                  child: Text('${value.toInt()}',
                      style: TextStyle(fontSize: 10, color: textColor)),
                ),
              ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, _) => Text('${v.toInt()}',
                  style: TextStyle(fontSize: 10, color: textColor)),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _buildWormChart(MatchStats s, Color textColor, Color gridColor) {
    final allY = <double>[
      ...s.wormTeam1.map((e) => e.totalRuns.toDouble()),
      ...s.wormTeam2.map((e) => e.totalRuns.toDouble()),
    ];
    final maxY = _maxY(allY);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: Colors.black.withOpacity(.75),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (y) =>
              FlLine(color: gridColor, strokeWidth: 0.8),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, _) => SizedBox(
                width: 24,
                child: Transform.rotate(
                  angle: -pi / 4,
                  child: Text('${value.toInt()}',
                      style: TextStyle(fontSize: 10, color: textColor)),
                ),
              ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, _) => Text('${v.toInt()}',
                  style: TextStyle(fontSize: 10, color: textColor)),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: s.wormTeam1
                .map((e) => FlSpot(
              e.overNumber.toDouble(),
              e.totalRuns.toDouble(),
            ))
                .toList(),
            isCurved: true,
            gradient: LinearGradient(colors: [_t1, _t1Light]),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [_t1.withOpacity(.18), _t1Light.withOpacity(.05)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: s.wormTeam2
                .map((e) => FlSpot(
              e.overNumber.toDouble(),
              e.totalRuns.toDouble(),
            ))
                .toList(),
            isCurved: true,
            gradient: LinearGradient(colors: [_t2, _t2Light]),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [_t2.withOpacity(.18), _t2Light.withOpacity(.05)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            dotData: const FlDotData(show: false),
          ),
        ],
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

    final allY = <double>[...t1, ...t2];
    final maxY = _maxY(allY);

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.black.withOpacity(.75),
            getTooltipItem: (group, _, rod, __) => BarTooltipItem(
              '${labels[group.x]} • ${rod.color == _t1 ? widget.team1Name : widget.team2Name}\n${rod.toY.toInt()}',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        alignment: BarChartAlignment.spaceAround,
        barGroups: List.generate(labels.length, (i) {
          return BarChartGroupData(
            x: i,
            barsSpace: 8,
            barRods: [
              BarChartRodData(toY: t1[i], width: 10, color: _t1),
              BarChartRodData(toY: t2[i], width: 10, color: _t2),
            ],
          );
        }),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (y) =>
              FlLine(color: gridColor, strokeWidth: 0.6),
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
                  child: Text(labels[v.toInt()],
                      style: TextStyle(fontSize: 10, color: textColor)),
                ),
              ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, _) => Text('${v.toInt()}',
                  style: TextStyle(fontSize: 10, color: textColor)),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _buildWicketChart(MatchStats s, Color textColor) {
    if (s.wicketTypes.isEmpty) {
      return const SizedBox.shrink();
    }
    const colors = [
      Colors.red,
      Colors.green,
      Colors.purple,
      Colors.teal,
      Colors.amber,
      Colors.indigo,
      Colors.cyan,
    ];

    final total = s.wicketTypes.fold<int>(0, (a, w) => a + w.totalWickets);

    return Column(
      children: [
        SizedBox(
          height: 190,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 42,
              sections: List.generate(s.wicketTypes.length, (i) {
                final w = s.wicketTypes[i];
                return PieChartSectionData(
                  color: colors[i % colors.length],
                  value: w.totalWickets.toDouble(),
                  title: '${w.totalWickets}',
                  radius: 56,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }),
            ),
          ),
        ),
        Text('Total Wickets: $total',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: List.generate(s.wicketTypes.length, (i) {
            final w = s.wicketTypes[i];
// in the Wrap children builder:
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 14, height: 14,
                  decoration: BoxDecoration(
                    color: colors[i % colors.length],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible( // <-- add Flexible so long text can shrink
                  child: Text(
                    w.wicketType,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: textColor),
                    softWrap: false,
                  ),
                ),
              ],
            );

          }),
        ),
      ],
    );
  }

  // ---------- Empty state ----------

  Widget _buildNoData(String msg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights_outlined,
                size: 80, color: isDark ? Colors.grey[600] : Colors.grey),
            const SizedBox(height: 12),
            Text(msg,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white70 : Colors.black87,
                )),
          ],
        ),
      ),
    );
  }
}
