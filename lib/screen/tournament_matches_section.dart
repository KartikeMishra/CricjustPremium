import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../model/tournament_match_detail_model.dart';
import '../service/tournament_service.dart';
import '../screen/full_match_detail.dart'; // Updated import
import '../theme/text_styles.dart';

class TournamentMatchesSection extends StatefulWidget {
  final int tournamentId;
  final String type;

  const TournamentMatchesSection({
    super.key,
    required this.tournamentId,
    required this.type,
  });

  @override
  State<TournamentMatchesSection> createState() =>
      _TournamentMatchesSectionState();
}

class _TournamentMatchesSectionState extends State<TournamentMatchesSection>
    with SingleTickerProviderStateMixin {
  List<TournamentMatchDetail> _matches = [];
  bool _isLoading = true;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fetchMatches();
  }

  @override
  void didUpdateWidget(covariant TournamentMatchesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.type != oldWidget.type) {
      setState(() {
        _matches.clear();
        _isLoading = true;
      });
      _fetchMatches();
    }
  }

  Future<void> _fetchMatches() async {
    setState(() => _isLoading = true);
    try {
      final result = await TournamentService.fetchTournamentMatches(
        widget.tournamentId,
        type: widget.type,
      );
      setState(() {
        _matches = result;
        _isLoading = false;
        _animationController.forward(from: 0);
      });
    } catch (e) {
      debugPrint("Error loading matches: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
        },
      );
    }

    if (_matches.isEmpty) {
      return const Center(child: Text('No matches found'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _matches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final m = _matches[index];
        final dt =
            DateTime.tryParse('${m.matchDate} ${m.matchTime}') ??
            DateTime.now();

        final animation = Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Interval(index / _matches.length, 1, curve: Curves.easeOut),
          ),
        );

        return FadeTransition(
          opacity: animation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade100,
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
              color: Colors.white,
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              title: Text(
                m.matchName.toUpperCase(),
                style: AppTextStyles.matchTitle.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.5,
                  color: const Color(0xFF0D47A1),
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 16,
                        color: Color(0xFF90A4AE),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('dd MMM yyyy, hh:mm a').format(dt),
                        style: AppTextStyles.caption.copyWith(
                          color: const Color(0xFF546E7A),
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    m.matchResult,
                    style: AppTextStyles.caption.copyWith(
                      fontStyle: FontStyle.italic,
                      color: const Color(0xFF607D8B),
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
              trailing: const Icon(
                Icons.chevron_right,
                size: 20,
                color: Colors.grey,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullMatchDetail(
                      matchId: int.parse(m.matchId),
                    ), // ✅ Updated line
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
