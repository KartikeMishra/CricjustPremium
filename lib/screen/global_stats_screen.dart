import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../model/global_stat_model.dart';
import '../service/global_stat_service.dart';
import '../theme/color.dart';

class GlobalStatsScreen extends StatefulWidget {
  const GlobalStatsScreen({super.key});

  @override
  State<GlobalStatsScreen> createState() => _GlobalStatsScreenState();
}

class _GlobalStatsScreenState extends State<GlobalStatsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final List<String> _tabKeys = const [
    'summary',
    'most_runs',
    'most_wickets',
    'most_fours',
    'most_sixes',
    'highest_score',
  ];
  final List<String> _tabTitles = const [
    'Summary',
    'Most Runs',
    'Most Wickets',
    'Most Fours',
    'Most Sixes',
    'Highest Score',
  ];

  // What to treat as the "primary" stat per tab (with fallbacks to handle API variants)
  final Map<String, List<String>> primaryKeyCandidatesByType = const {
    'most_runs':     ['total_runs', 'Total_Runs', 'runs'],
    'most_wickets':  ['total_wickets', 'Total_Wicket', 'wickets', 'Wickets'],
    'most_fours':    ['total_fours', 'Total_Fours', 'fours'],
    'most_sixes':    ['total_six', 'Total_Sixes', 'sixes', 'six'],
    'highest_score': ['highest_score', 'Highest_Score', 'HS'],
  };

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

  // ------- helpers -------
  String? _firstNonEmpty(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      if (!map.containsKey(k)) continue;
      final v = map[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty && s.toLowerCase() != 'null') return s;
    }
    return null;
  }

  num? _numOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return num.tryParse(s);
  }

  Widget _badge(String label, bool dark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.only(right: 6, top: 6),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF2A2A2A) : const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: dark ? Colors.white12 : const Color(0xFFDCE6FF),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: dark ? Colors.white70 : AppColors.primary,
          height: 1.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? Colors.black : Colors.grey[100],
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(108),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: dark ? 15 : 0, sigmaY: dark ? 15 : 0),
            child: Container(
              decoration: dark
                  ? BoxDecoration(color: Colors.white.withValues(alpha: 0.05))
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
                        children: const [
                          BackButton(color: Colors.white),
                          Expanded(
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
                          SizedBox(width: kToolbarHeight), // keep title centered
                        ],
                      ),
                    ),
                    // TabBar
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
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        if (!snap.hasData) {
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
            final numVal = int.tryParse(entry.value) ?? 0;
            final icon = iconMap[entry.key] ?? Icons.sports;
            return TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: numVal),
              duration: const Duration(milliseconds: 600),
              builder: (_, val, __) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
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
                          color: Colors.blue.withValues(alpha: 0.1),
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
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        if (!snap.hasData || snap.data!.isEmpty) {
          return const Center(child: Text('No data available'));
        }

        // Work on a local copy so we can sort for highest_score without side-effects.
        final items = [...snap.data!];

        // For highest_score, ensure descending by runs (Total_Runs/total_runs/HS/etc.)
        if (type == 'highest_score') {
          num extractRuns(GlobalStat g) {
            final s = g.additionalStats;
            final v = s['Total_Runs'] ?? s['total_runs'] ?? s['highest_score'] ?? s['Highest_Score'] ?? s['HS'];
            if (v == null) return -1;
            if (v is num) return v;
            return num.tryParse(v.toString()) ?? -1;
          }
          items.sort((a, b) => extractRuns(b).compareTo(extractRuns(a)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (c, i) {
            final p = items[i];
            final stats = Map<String, dynamic>.from(p.additionalStats);

            // --- COMMON FIELDS ---
            String? firstNonEmptyLocal(List<String> keys) {
              for (final k in keys) {
                final v = stats[k];
                if (v == null) continue;
                final s = v.toString().trim();
                if (s.isNotEmpty && s.toLowerCase() != 'null') return s;
              }
              return null;
            }

            num? numOrNullLocal(dynamic v) {
              if (v == null) return null;
              if (v is num) return v;
              final s = v.toString().trim();
              if (s.isEmpty) return null;
              return num.tryParse(s);
            }

            // Primary stat (default path for non-highest tabs)
            String? primaryVal = firstNonEmptyLocal(
              primaryKeyCandidatesByType[type] ?? const [],
            );

            // Extra aggregates used as badges (keep original behavior)
            final matchesVal = numOrNullLocal(stats['total_match']);
            final innsVal    = numOrNullLocal(stats['total_inn']);
            final avgVal     = numOrNullLocal(stats['avg'] ?? stats['average']);

            // Image URL sometimes has &amp;
            final imgUrl = p.playerImage.replaceAll('&amp;', '&');

            // --- HIGHEST SCORE SPECIAL HANDLING ---
            String? trailingPrimary;   // the big right-side text
            String? trailingSecond;    // optional second line (SR)
            String? matchName;         // we’ll show match name below primary

            if (type == 'highest_score') {
              final runs = numOrNullLocal(
                stats['Total_Runs'] ??
                    stats['total_runs'] ??
                    stats['highest_score'] ??
                    stats['Highest_Score'] ??
                    stats['HS'],
              );
              final balls = numOrNullLocal(
                stats['total_balls'] ??
                    stats['Balls'] ??
                    stats['B'] ??
                    stats['balls'],
              );
              final srStr = firstNonEmptyLocal(['sr', 'strike_rate', 'SR']);
              matchName = p.matchName ?? firstNonEmptyLocal(['Match_Name', 'match_name', 'Match', 'match']);

              // Format primary: "132 (66)" if balls present else "132"
              if (runs != null) {
                trailingPrimary = balls != null ? '${runs.toString()} (${balls.toString()})' : runs.toString();
              } else {
                // fallback to generic
                trailingPrimary = primaryVal ?? '';
              }

              // Show SR on a second, small line if available
              if (srStr != null && srStr.isNotEmpty) {
                trailingSecond = 'SR: $srStr';
              }
            } else {
              // Non-highest tabs keep your original display rule
              if (type == 'most_wickets' && primaryVal != null) {
                trailingPrimary = '${primaryVal.toString()} Wkts';
              } else {
                trailingPrimary = primaryVal ?? '';
              }
              matchName = p.matchName; // original behavior
            }

            // Build badges:
            final badgeWidgets = <Widget>[];
            if (type == 'highest_score') {
              // Prefer balls+SR as badges if available
              final balls = numOrNullLocal(stats['total_balls'] ?? stats['Balls'] ?? stats['B'] ?? stats['balls']);
              final srStr = firstNonEmptyLocal(['sr', 'strike_rate', 'SR']);
              if (balls != null) badgeWidgets.add(_badge('B: ${balls.toString()}', dark));
              if (srStr != null) badgeWidgets.add(_badge('SR: $srStr', dark));
            } else {
              // Original badges for other tabs
              if (matchesVal != null) badgeWidgets.add(_badge('M: ${matchesVal.toString()}', dark));
              if (innsVal != null)    badgeWidgets.add(_badge('INN: ${innsVal.toString()}', dark));
              if (avgVal != null)     badgeWidgets.add(_badge('AVG: ${avgVal.toString()}', dark));
            }

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
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                leading: CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.blue.shade100,
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: imgUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const Icon(Icons.person, color: Colors.grey),
                      errorWidget:   (_, __, ___) => const Icon(Icons.person, color: Colors.grey),
                    ),
                  ),
                ),
                title: Text(
                  p.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: dark ? Colors.white : Colors.black,
                  ),
                ),
                // If we have badges, show them; otherwise show match name (as before)
                subtitle: badgeWidgets.isNotEmpty
                    ? Wrap(children: badgeWidgets)
                    : (matchName != null
                    ? Text(
                  matchName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: dark ? Colors.grey[400] : Colors.black87,
                  ),
                )
                    : null),
                trailing: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if ((trailingPrimary ?? '').isNotEmpty)
                        Text(
                          trailingPrimary,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            height: 1.1,
                            color: dark ? Colors.white : Colors.black,
                          ),
                        ),
                      if (type == 'highest_score' && (trailingSecond ?? '').isNotEmpty)
                        Text(
                          trailingSecond!,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.1,
                            color: dark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      // Always show match name for highest_score (even if badges exist)
                      if (type == 'highest_score' && matchName != null)
                        Text(
                          matchName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.1,
                            color: dark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      // For other tabs, keep your existing rule (only if no badges)
                      if (type != 'highest_score' && matchName != null && badgeWidgets.isEmpty)
                        Text(
                          matchName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.1,
                            color: dark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

}
