import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../model/global_stat_model.dart';
import '../service/global_stat_service.dart';
import '../theme/color.dart';
import 'dart:ui';

class GlobalStatsScreen extends StatefulWidget {
  const GlobalStatsScreen({super.key});

  @override
  State<GlobalStatsScreen> createState() => _GlobalStatsScreenState();
}

class _GlobalStatsScreenState extends State<GlobalStatsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final List<String> _tabKeys = [
    'summary',
    'most_runs',
    'most_wickets',
    'most_fours',
    'most_sixes',
    'highest_score',
  ];
  final List<String> _tabTitles = [
    'Summary',
    'Most Runs',
    'Most Wickets',
    'Most Fours',
    'Most Sixes',
    'Highest Score',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabKeys.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? Colors.black : Colors.grey[100],
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(108),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: dark ? 15 : 0,
              sigmaY: dark ? 15 : 0,
            ),
            child: Container(
              decoration: dark
                  ? BoxDecoration(color: Colors.white.withOpacity(0.05))
                  : const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, Color(0xFF42A5F5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title row
                    SizedBox(
                      height: kToolbarHeight,
                      child: Row(
                        children: [
                          BackButton(color: Colors.white),
                          const Expanded(
                            child: Center(
                              child: Text(
                                'Global Stats',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ),
                          // placeholder to keep title centered
                          const SizedBox(width: kToolbarHeight),
                        ],
                      ),
                    ),
                    // TabBar row
                    SizedBox(
                      height: kTextTabBarHeight,
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        indicatorColor: Colors.white,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white70,
                        labelStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        tabs: _tabTitles.map((t) => Tab(text: t)).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabKeys.map((key) {
          return key == 'summary'
              ? _buildSummaryTab(dark)
              : _buildListTab(key, dark);
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryTab(bool dark) {
    return FutureBuilder<Map<String, String>>(
      future: GlobalStatService.fetchOverallStats(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        } else if (!snap.hasData) {
          return const Center(child: Text('No data found'));
        }
        final stats = snap.data!;
        final iconMap = {
          'total_extras': Icons.exposure,
          'total_balls': Icons.sports_baseball,
          'total_runs': Icons.sports_cricket,
          'total_wickets': Icons.sports_mma,
          'total_fours': Icons.looks_4,
          'total_sixes': Icons.filter_6,
          'total_matches': Icons.event_note,
        };
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          itemCount: stats.length,
          itemBuilder: (c, i) {
            final entry = stats.entries.elementAt(i);
            final num = int.tryParse(entry.value) ?? 0;
            final icon = iconMap[entry.key] ?? Icons.sports;
            return TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: num),
              duration: const Duration(milliseconds: 600),
              builder: (_, val, __) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 18),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: dark
                        ? null
                        : LinearGradient(
                            colors: [Colors.white, Colors.grey.shade100],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    color: dark ? const Color(0xFF1C1C1E) : null,
                    boxShadow: [
                      BoxShadow(
                        color: dark ? Colors.black54 : Colors.grey.shade300,
                        offset: const Offset(4, 4),
                        blurRadius: 8,
                      ),
                      BoxShadow(
                        color: dark ? Colors.white10 : Colors.white,
                        offset: const Offset(-4, -4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Icon(icon, size: 26, color: Colors.blueAccent),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          entry.key.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: dark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        NumberFormat.decimalPattern().format(val),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: dark ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildListTab(String type, bool dark) {
    return FutureBuilder<List<GlobalStat>>(
      future: GlobalStatService.fetchStats(type: type),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        } else if (!snap.hasData || snap.data!.isEmpty) {
          return const Center(child: Text('No data available'));
        }
        final players = snap.data!;
        final keyMap = {
          'most_runs': 'total_runs',
          'most_wickets': 'total_wickets',
          'most_fours': 'total_fours',
          'most_sixes': 'total_six',
          'highest_score': 'highest_score',
        };
        final primaryKey = keyMap[type];
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: players.length,
          itemBuilder: (c, i) {
            final p = players[i];
            final primaryVal = p.additionalStats[primaryKey] ?? '';
            final secondary = p.additionalStats.entries
                .where((e) => e.key != primaryKey)
                .take(2);
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: dark ? Colors.grey[900] : Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: dark ? Colors.black45 : Colors.grey.shade300,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                leading: CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.blue.shade100,
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: p.playerImage,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          const Icon(Icons.person, color: Colors.grey),
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.person, color: Colors.grey),
                    ),
                  ),
                ),
                title: Text(
                  p.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: dark ? Colors.white : Colors.black,
                  ),
                ),
                subtitle: p.matchName != null
                    ? Text(
                        p.matchName!,
                        style: TextStyle(
                          fontSize: 13,
                          color: dark ? Colors.grey[400] : Colors.black87,
                        ),
                      )
                    : null,
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (primaryVal != null)
                      Text(
                        '$primaryVal',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: dark ? Colors.white : Colors.black,
                        ),
                      ),
                    for (final e in secondary)
                      Text(
                        '${e.key.replaceAll('_', ' ').toUpperCase()}: ${e.value}',
                        style: TextStyle(
                          fontSize: 12,
                          color: dark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
