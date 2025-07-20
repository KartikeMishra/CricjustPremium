import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:shimmer/shimmer.dart';
import '../model/tournament_model.dart';
import '../service/tournament_service.dart';
import '../theme/color.dart';

class TournamentSection extends StatefulWidget {
  final String type;
  final int limit;
  final void Function(int tournamentId)? onTournamentTap;
  final void Function(bool hasData)? onDataLoaded;

  const TournamentSection({
    super.key,
    this.type = 'live',
    this.limit = 10,
    this.onTournamentTap,
    this.onDataLoaded,
  });

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
      if (!mounted) return;
      setState(() {
        _tournaments = list;
        _isLoading = false;
      });
      widget.onDataLoaded?.call(list.isNotEmpty);
    } catch (e) {
      debugPrint('Error loading tournaments: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      widget.onDataLoaded?.call(false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildShimmerLoader();
    if (_tournaments.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _tournaments.length,
            itemBuilder: (context, index) {
              final tournament = _tournaments[index];
              return GestureDetector(
                onTap: () =>
                    widget.onTournamentTap?.call(tournament.tournamentId),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withOpacity(0.4)
                            : Colors.blue.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    gradient: isDark
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFFF0F8FF), Colors.white],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: tournament.tournamentLogo.isNotEmpty
                                  ? Image.network(
                                      tournament.tournamentLogo,
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.broken_image,
                                        size: 64,
                                      ),
                                    )
                                  : Container(
                                      width: 64,
                                      height: 64,
                                      color: isDark
                                          ? const Color(0xFF3A3A3A)
                                          : Colors.grey.shade200,
                                      child: const Icon(
                                        Icons.image_not_supported,
                                        color: Colors.grey,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    tournament.tournamentName,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.blue.shade900,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  if (tournament.tournamentDesc.isNotEmpty)
                                    Text(
                                      tournament.tournamentDesc,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[700],
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Start: ${_formatDate(tournament.startDate)} • Teams: ${tournament.teams}",
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: isDark
                                          ? Colors.grey[500]
                                          : Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
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
        ),
        const SizedBox(height: 10),
        Center(
          child: SmoothPageIndicator(
            controller: _pageController,
            count: _tournaments.length,
            effect: WormEffect(
              dotHeight: 8,
              dotWidth: 8,
              spacing: 8,
              activeDotColor: AppColors.primary,
              dotColor: isDark ? Colors.grey : Colors.grey.shade400,
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildShimmerLoader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlight = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 2,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: base,
            highlightColor: highlight,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        },
      ),
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
