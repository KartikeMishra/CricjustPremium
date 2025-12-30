// lib/screen/all_live_tournaments_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../model/tournament_model.dart';
import '../service/tournament_service.dart';
import '../screen/tournament_detail_screen.dart';
import '../theme/color.dart';
import '../theme/text_styles.dart';

// 🔹 Subtle card graphics (glow + watermark)
import '../widget/section_graphics.dart';

class AllLiveTournamentsScreen extends StatefulWidget {
  const AllLiveTournamentsScreen({super.key});

  @override
  State<AllLiveTournamentsScreen> createState() =>
      _AllLiveTournamentsScreenState();
}

class _AllLiveTournamentsScreenState extends State<AllLiveTournamentsScreen> {
  List<TournamentModel> _tournaments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTournaments();
  }

  Future<void> _fetchTournaments() async {
    try {
      // ✅ Use the correct public API (no token needed)
      final data = await TournamentService.fetchPublicTournaments(
        type: 'live',
        limit: 20,
        skip: 0,
      );

      if (!mounted) return;
      setState(() {
        _tournaments = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading tournaments: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(String date) {
    try {
      final parsed = DateFormat('yyyy-MM-dd').parse(date);
      return DateFormat('dd MMM yyyy').format(parsed);
    } catch (_) {
      return date;
    }
  }

  PreferredSizeWidget _buildConsistentHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: Container(
        decoration: isDark
            ? const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        )
            : const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, Color(0xFF42A5F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.maybePop(context),
            tooltip: 'Back',
          ),
          title: const Text(
            'All Live Tournaments',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () {
                setState(() => _isLoading = true);
                _fetchTournaments();
              },
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF111111) : const Color(0xFFF5F7FA),
      appBar: _buildConsistentHeader(),
      body: _isLoading
          ? _buildShimmerList(isDark)
          : (_tournaments.isEmpty
          ? _emptyState(isDark)
          : RefreshIndicator(
        onRefresh: _fetchTournaments,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          itemCount: _tournaments.length,
          itemBuilder: (context, index) {
            final t = _tournaments[index];
            return _TournamentCard(
              tournament: t,
              startLabel: _formatDate(t.startDate),
              isDark: isDark,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TournamentDetailScreen(
                    tournamentId: t.tournamentId,
                  ),
                ),
              ),
            );
          },
        ),
      )),
    );
  }

  Widget _emptyState(bool isDark) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.28),
        Icon(Icons.emoji_events_outlined,
            size: 64, color: isDark ? Colors.white24 : Colors.black26),
        const SizedBox(height: 12),
        Text(
          'No live tournaments',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 16, color: isDark ? Colors.white70 : Colors.black54),
        ),
        const SizedBox(height: 6),
        Text(
          'Pull down to refresh.',
          textAlign: TextAlign.center,
          style: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
        ),
      ],
    );
  }

  Widget _buildShimmerList(bool isDark) {
    final base = isDark ? Colors.white10 : Colors.grey[300]!;
    final highlight = isDark ? Colors.white24 : Colors.grey[100]!;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      itemCount: 6,
      itemBuilder: (_, __) {
        return Shimmer.fromColors(
          baseColor: base,
          highlightColor: highlight,
          child: Container(
            height: 92,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Tournament Card
// -----------------------------------------------------------------------------
class _TournamentCard extends StatelessWidget {
  final TournamentModel tournament;
  final String startLabel;
  final bool isDark;
  final VoidCallback onTap;

  const _TournamentCard({
    required this.tournament,
    required this.startLabel,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cache = (72 * dpr).round();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              const Positioned.fill(child: CardAuroraOverlay()),
              const Positioned.fill(
                child: WatermarkIcon(
                  icon: Icons.emoji_events_rounded,
                  alignment: Alignment.bottomRight,
                  size: 120,
                  opacity: 0.05,
                ),
              ),
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: isDark
                        ? null
                        : const LinearGradient(
                      colors: [Color(0xFFEAF4FF), Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    color: isDark ? const Color(0xFF1E1E1E) : null,
                    boxShadow: isDark
                        ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 10),
                      )
                    ]
                        : [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.10),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                        color: isDark ? Colors.white12 : Colors.black12),
                  ),
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
                            cacheWidth: cache,
                            errorBuilder: (_, __, ___) => _logoFallback(),
                          )
                              : _logoFallback(),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      tournament.tournamentName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.matchTitle.copyWith(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.blue.shade900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _livePill(),
                                ],
                              ),
                              if (tournament.tournamentDesc.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    tournament.tournamentDesc,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.tournamentName
                                        .copyWith(
                                      fontSize: 13,
                                      color: isDark
                                          ? Colors.grey[300]
                                          : Colors.grey[800],
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _metaChip(
                                    icon: Icons.calendar_today,
                                    label: 'Start: $startLabel',
                                    isDark: isDark,
                                  ),
                                  _metaChip(
                                    icon: Icons.groups_2_outlined,
                                    label: 'Teams: ${tournament.teams}',
                                    isDark: isDark,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right,
                            color: isDark ? Colors.white54 : Colors.black38),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logoFallback() => Container(
    width: 64,
    height: 64,
    decoration: BoxDecoration(
      color: isDark ? Colors.white10 : Colors.grey.shade200,
      borderRadius: BorderRadius.circular(12),
      border:
      Border.all(color: isDark ? Colors.white12 : Colors.black12),
    ),
    child: Icon(Icons.image_not_supported_outlined,
        color: isDark ? Colors.white38 : Colors.black38),
  );

  Widget _metaChip({
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border:
        Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 14, color: isDark ? Colors.white70 : Colors.black54),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _livePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFFE53935), Color(0xFFEF5350)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Row(
        children: [
          _BlinkDot(),
          SizedBox(width: 6),
          Text(
            "LIVE",
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlinkDot extends StatefulWidget {
  const _BlinkDot();
  @override
  State<_BlinkDot> createState() => _BlinkDotState();
}

class _BlinkDotState extends State<_BlinkDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Color(0x66FFFFFF), blurRadius: 6, spreadRadius: 1)
          ],
        ),
      ),
    );
  }
}
