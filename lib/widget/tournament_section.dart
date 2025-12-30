import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:shimmer/shimmer.dart';

import '../model/tournament_model.dart';
import '../service/tournament_service.dart';
import '../theme/color.dart';

class TournamentSection extends StatefulWidget {
  final String type; // 'live' | 'upcoming' | 'recent'
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
  static const double _kCardHeight = 160;
  static const double _kLogo = 56;

  bool _isLoading = true;
  List<TournamentModel> _tournaments = [];
  final PageController _pageController = PageController(viewportFraction: 0.94);

  @override
  void initState() {
    super.initState();
    _fetchTournaments();
  }

  Future<void> _fetchTournaments() async {
    try {
      // ✅ Use the correct public API
      final list = await TournamentService.fetchPublicTournaments(
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

  Color get _badgeColor {
    switch (widget.type.toLowerCase()) {
      case 'live':
        return Colors.redAccent;
      case 'upcoming':
        return Colors.teal;
      case 'recent':
        return Colors.deepPurple;
      default:
        return AppColors.primary;
    }
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
          height: _kCardHeight,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _tournaments.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final t = _tournaments[index];
              return GestureDetector(
                onTap: () => widget.onTournamentTap?.call(t.tournamentId),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    gradient: isDark
                        ? null
                        : const LinearGradient(
                      colors: [Color(0xFFF0F6FF), Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isDark ? Colors.black : AppColors.primary)
                            .withOpacity(isDark ? 0.35 : 0.10),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      children: [
                        BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 1.2, sigmaY: 1.2),
                          child: const SizedBox.expand(),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: _LogoBox(url: t.tournamentLogo, size: _kLogo),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            t.tournamentName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15.5,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.blue.shade900,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _TypeBadge(color: _badgeColor, label: widget.type),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    if (t.tournamentDesc.isNotEmpty)
                                      Text(
                                        t.tournamentDesc,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          fontSize: 12.5,
                                          color: isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[700],
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Start: ${_formatDate(t.startDate)} • Teams: ${t.teams}",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: isDark
                                            ? Colors.grey[500]
                                            : Colors.grey[600],
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: SmoothPageIndicator(
            controller: _pageController,
            count: _tournaments.isEmpty ? 1 : _tournaments.length,
            effect: WormEffect(
              dotHeight: 7,
              dotWidth: 7,
              spacing: 7,
              activeDotColor: AppColors.primary,
              dotColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey
                  : Colors.grey.shade400,
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildShimmerLoader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlight = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return SizedBox(
      height: _kCardHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 2,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: base,
            highlightColor: highlight,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.86,
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(18),
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

// --- small helpers (UI only) ---

class _LogoBox extends StatelessWidget {
  final String url;
  final double size;
  const _LogoBox({required this.url, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (url.isEmpty) {
      return Container(
        width: size,
        height: size,
        color: isDark ? const Color(0xFF3A3A3A) : Colors.grey.shade200,
        child: const Icon(Icons.image_not_supported, color: Colors.grey),
      );
    }

    final dpr = MediaQuery.of(context).devicePixelRatio;
    final target = (size * dpr).round();

    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      cacheWidth: target,
      loadingBuilder: (ctx, child, progress) {
        if (progress == null) return child;
        return Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade100,
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(
                Theme.of(context).colorScheme.primary.withOpacity(0.9),
              ),
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => Icon(Icons.broken_image, size: size),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final Color color;
  final String label;
  const _TypeBadge({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.25),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
