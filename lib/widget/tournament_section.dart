// lib/widgets/tournament_section.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../Screen/tournament_overview_screen.dart';
import '../model/tournament_model.dart';
import '../service/tournament_service.dart';
import '../theme/color.dart';
import '../theme/text_styles.dart';

class TournamentSection extends StatefulWidget {
  final String type;
  final int limit;

  const TournamentSection({
    Key? key,
    this.type = 'live',
    this.limit = 10,
  }) : super(key: key);

  @override
  State<TournamentSection> createState() => _TournamentSectionState();
}

class _TournamentSectionState extends State<TournamentSection> {
  bool _isLoading = true;
  List<TournamentModel> _tournaments = [];
  final PageController _pageController = PageController(viewportFraction: 0.9);

  @override
  void initState() {
    super.initState();
    _fetchTournaments();
  }

  Future<void> _fetchTournaments() async {
    try {
      final list = await TournamentService.fetchTournaments(
        type: widget.type,
        limit: widget.limit,
      );
      setState(() {
        _tournaments = list;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading tournaments: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_tournaments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text("Tournaments", style: AppTextStyles.sectionTitle),
        ),
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _tournaments.length,
            itemBuilder: (context, index) {
              final tournament = _tournaments[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TournamentOverviewScreen(
                        tournamentId: tournament.tournamentId,
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          tournament.tournamentLogo,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image, size: 60),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tournament.tournamentName,
                              style: AppTextStyles.matchTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (tournament.tournamentDesc.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  tournament.tournamentDesc,
                                  style: AppTextStyles.tournamentName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              "Start: ${_formatDate(tournament.startDate)} • Teams: ${tournament.teams}",
                              style: AppTextStyles.venue,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: SmoothPageIndicator(
            controller: _pageController,
            count: _tournaments.length,
            effect: const WormEffect(
              dotHeight: 8,
              dotWidth: 8,
              spacing: 8,
              activeDotColor: AppColors.primary,
              dotColor: Colors.grey,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return '';
    try {
      final parsed = DateFormat('yyyy-MM-dd').parse(date);
      return DateFormat('dd MMM yyyy').format(parsed);
    } catch (_) {
      return date;
    }
  }
}
