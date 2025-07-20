import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../model/tournament_overview_model.dart';
import '../screen/full_match_detail.dart';
import '../theme/color.dart';
import '../theme/text_styles.dart';

class TeamMatchesScreen extends StatefulWidget {
  final TeamStanding team;
  const TeamMatchesScreen({super.key, required this.team});

  @override
  State<TeamMatchesScreen> createState() => _TeamMatchesScreenState();
}

class _TeamMatchesScreenState extends State<TeamMatchesScreen> {
  final bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final matches = widget.team.matches;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmerBase = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final shimmerHighlight = isDark
        ? Colors.grey.shade600
        : Colors.grey.shade100;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Row(
          children: [
            ClipOval(
              child: widget.team.teamLogo.isNotEmpty
                  ? Image.network(
                      widget.team.teamLogo,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.person,
                        size: 40,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.person, size: 40, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${widget.team.teamName} Matches',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? _buildShimmerLoader(shimmerBase, shimmerHighlight)
          : matches.isEmpty
          ? const Center(child: Text("No matches found"))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: matches.length,
              itemBuilder: (context, index) {
                final match = matches[index];
                final won = match.matchResult.toLowerCase().contains('won');

                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FullMatchDetail(matchId: match.matchId),
                    ),
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE0F2F1), Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                match.opponent,
                                style: AppTextStyles.matchTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                DateFormat('EEE, dd MMM yyyy').format(
                                  DateTime.tryParse(match.matchDate) ??
                                      DateTime.now(),
                                ),
                                style: const TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: won
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  match.matchResult,
                                  style: TextStyle(
                                    color: won ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildShimmerLoader(Color base, Color highlight) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: base,
          highlightColor: highlight,
          child: Container(
            height: 120,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }
}
