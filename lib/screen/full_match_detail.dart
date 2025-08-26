// lib/screen/full_match_detail.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../model/sponsor_model.dart';
import '../service/match_detail_service.dart';
import '../service/match_score_service.dart';
import '../service/sponsor_service.dart';
import '../theme/color.dart';
import '../model/match_summary_model.dart';
import '../widget/tv_score_banner.dart';
import '../widget/youtube_box.dart';

import 'match_summary_tab.dart';
import 'scorecard_screen.dart';
import 'match_squad_tab.dart';
import 'match_stats_tab.dart';
import 'match_info_tab.dart';
import 'match_commentary_tab.dart';

class FullMatchDetail extends StatefulWidget {
  final int matchId;
  const FullMatchDetail({super.key, required this.matchId});

  @override
  _FullMatchDetailState createState() => _FullMatchDetailState();
}

enum _HeaderPanel { none, tv, youtube }

class _FullMatchDetailState extends State<FullMatchDetail>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _autoRefreshTimer;

  MatchSummary? summaryData;
  bool isLoading = true;
  String? error;
  int? _currentUserId;
  Map<String, dynamic>? _liveScore;
  String? _token;

  List<Sponsor> _sponsors = const [];
  bool _loadingSponsors = false;
  String? _sponsorError;

  String? _youtubeUrl; // prefers authed source if present
  bool _loadingYoutube = false;

  // 🔄 pull-to-refresh tick (for Stats tab)
  int _refreshTick = 0;

  final List<Tab> _tabs = const [
    Tab(text: 'Summary'),
    Tab(text: 'Scorecard'),
    Tab(text: 'Squad'),
    Tab(text: 'Stats'),
    Tab(text: 'Info'),
    Tab(text: 'Commentary'),
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadSummaryData();
    _fetchLiveScore();
    _loadSponsors();

    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchLiveScore();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadSummaryData(),
      _fetchLiveScore(),
      _loadSponsors(),
      if ((_token ?? '').isNotEmpty) _loadYoutube(),
    ]);
    if (!mounted) return;
    setState(() => _refreshTick++);
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getInt('user_id');
      _token = prefs.getString('api_logged_in_token');
    });
    _loadYoutube(); // fetch youtube once token available
  }

  Future<void> _loadSummaryData() async {
    try {
      final result = await MatchService.fetchMatchSummary(widget.matchId);
      if (!mounted) return;
      setState(() {
        summaryData = result;
        isLoading = false;
        error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = 'Failed to load match detail.';
        isLoading = false;
      });
    }
  }

  Future<void> _fetchLiveScore() async {
    final url = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-current-match-score?match_id=${widget.matchId}',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 1 &&
            data['current_score']?['current_inning'] != null) {
          final inning = Map<String, dynamic>.from(
            data['current_score']['current_inning'],
          );

          // inject last_ball if missing
          if (inning['score'] != null) {
            inning['score'] = Map<String, dynamic>.from(inning['score'] as Map);
            if (!inning['score'].containsKey('last_ball') ||
                inning['score']['last_ball'] == null) {
              final teamId = inning['team_id'];
              final lastBalls = await MatchScoreService.fetchLastSixBalls(
                matchId: widget.matchId,
                teamId: teamId,
              );
              if (lastBalls.isNotEmpty) {
                final latest = lastBalls.first;
                inning['score']['last_ball'] = latest['runs'].toString();
              } else {
                inning['score']['last_ball'] = '0';
              }
            }
          }

          if (mounted) {
            setState(() => _liveScore = inning);
          }
        }
      }
    } catch (e) {
      debugPrint('❌ _fetchLiveScore error: $e');
    }
  }

  Future<void> _loadSponsors() async {
    setState(() {
      _loadingSponsors = true;
      _sponsorError = null;
    });
    try {
      final res = await SponsorService.getMatchSponsors(matchId: widget.matchId);
      if (!mounted) return;
      if (res.ok) {
        final featured = res.featuredSponsors;
        final all = res.allSponsors;
        setState(() {
          _sponsors = (featured.isNotEmpty ? featured : all);
          _loadingSponsors = false;
        });
      } else {
        setState(() {
          _loadingSponsors = false;
          _sponsorError = 'No sponsors found';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingSponsors = false;
        _sponsorError = 'Failed to load sponsors';
      });
    }
  }

  Future<void> _loadYoutube() async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    setState(() => _loadingYoutube = true);
    try {
      final uri = Uri.parse(
        'https://cricjust.in/wp-json/custom-api-for-cricket/get-single-cricket-match'
            '?api_logged_in_token=$token&match_id=${widget.matchId}',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        if ((json['status'] == 1 || json['status'] == '1') &&
            json['data'] is List &&
            (json['data'] as List).isNotEmpty) {
          final first = (json['data'] as List).first as Map<String, dynamic>;
          final url = _normalizeYoutube(first['youtube']);
          if (mounted) {
            setState(() => _youtubeUrl = (url != null && url.isNotEmpty) ? url : null);
          }
        }
      }
    } catch (e) {
      debugPrint('❌ _loadYoutube error: $e');
    } finally {
      if (mounted) setState(() => _loadingYoutube = false);
    }
  }

  // ---------- Helpers ----------
  double _oversAsDouble(Map<String, dynamic> score) {
    final int oversDone = (score['overs_done'] ?? 0) is int
        ? score['overs_done']
        : int.tryParse(score['overs_done'].toString()) ?? 0;

    final int ballsDone = int.tryParse(score['balls_done'].toString()) ?? 0;
    return double.tryParse('$oversDone.$ballsDone') ?? oversDone.toDouble();
  }

  bool _isLiveValue(dynamic v) {
    final s = v?.toString().trim().toLowerCase();
    return s == 'live' ||
        s == 'inprogress' ||
        s == 'in_progress' ||
        s == 'running' ||
        s == '1';
  }

  bool _isYoutubeUrl(String? u) {
    if (u == null) return false;
    final t = u.trim().toLowerCase();
    return (t.startsWith('http://') || t.startsWith('https://')) &&
        (t.contains('youtube.com') || t.contains('youtu.be'));
  }

  /// Accepts either a plain URL or an <iframe ... src="..."> snippet.
  /// Also normalizes common forms like /live/VIDEO_ID into a watch URL.
  String? _normalizeYoutube(dynamic raw) {
    if (raw == null) return null;
    final s0 = raw.toString().trim();
    if (s0.isEmpty) return null;

    // iframe -> extract src
    if (s0.startsWith('<iframe')) {
      final reg = RegExp(r'''src\s*=\s*["']([^"']+)["']''', caseSensitive: false);
      final m = reg.firstMatch(s0);
      final url = m?.group(1);
      return _normalizeYoutube(url);
    }

    // live -> watch
    String s = s0;
    final live = RegExp(r'https?://(www\.)?youtube\.com/live/([A-Za-z0-9_-]+)');
    final lm = live.firstMatch(s);
    if (lm != null && lm.groupCount >= 2) {
      final id = lm.group(2);
      if (id != null && id.isNotEmpty) {
        s = 'https://www.youtube.com/watch?v=$id';
      }
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SafeArea(
        child: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    if (error != null) {
      return SafeArea(
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            title: const Text('Match Details', style: TextStyle(color: Colors.white)),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(child: Text(error!)),
        ),
      );
    }

    final raw = summaryData!.rawMatchData;

    // Prefer authed youtube if present; else public (normalized)
    final String? youtubeUrlPublic = _normalizeYoutube(raw['youtube']);
    final String? youtubeUrl = _youtubeUrl ?? youtubeUrlPublic;

    final matchDateTime =
    DateFormat('yyyy-MM-dd HH:mm:ss').parse('${raw['match_date']} ${raw['match_time']}');
    final now = DateTime.now();
    final isUpcoming = matchDateTime.isAfter(now);
    final bool isLive = _isLiveValue(raw['status']);
    final ownerId = raw['user_id'] as int?;
    final canEdit = (isUpcoming || isLive) && ownerId != null && ownerId == _currentUserId;

    // ✅ Prefer YouTube whenever it exists; otherwise show TV if we have a live score
    final bool hasYoutube = _isYoutubeUrl(youtubeUrl);
    final _HeaderPanel headerPanel =
    hasYoutube ? _HeaderPanel.youtube : (_liveScore != null ? _HeaderPanel.tv : _HeaderPanel.none);

    final team1Id = raw['team_1']['team_id'] as int;
    final team2Id = raw['team_2']['team_id'] as int;
    final team1Name = summaryData!.teamAName;
    final team2Name = summaryData!.teamBName;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : const Color(0xFFF4F6FA),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + kTextTabBarHeight + 20),
          child: Container(
            decoration: isDark
                ? const BoxDecoration(
              color: Color(0xFF1E1E1E),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            )
                : const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, Color(0xFF42A5F5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: kToolbarHeight,
                    child: Row(
                      children: [
                        const BackButton(color: Colors.white),
                        const Expanded(
                          child: Center(
                            child: Text(
                              'Match Details',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: kToolbarHeight,
                          child: isLive
                              ? const Center(
                              child: Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ))
                              : null,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      clipBehavior: Clip.hardEdge,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.22)),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          isScrollable: true,
                          dividerColor: Colors.transparent,
                          overlayColor: WidgetStateProperty.all(Colors.transparent),
                          indicatorPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                          indicator: const ShapeDecoration(
                            color: Colors.white,
                            shape: StadiumBorder(),
                            shadows: [
                              BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3)),
                            ],
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                          labelColor: AppColors.primary,
                          unselectedLabelColor: Colors.white,
                          labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          unselectedLabelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          tabs: _tabs,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _refreshAll,
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ----- TV panel (graphics removed) -----
                      if (headerPanel == _HeaderPanel.tv && _liveScore != null)
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: TVStyleScoreScreen(
                              teamName: _liveScore!['team_name'] ?? '',
                              runs: int.tryParse(_liveScore!['score']['total_runs'].toString()) ?? 0,
                              wickets: int.tryParse(_liveScore!['score']['total_wkts'].toString()) ?? 0,
                              overs: _oversAsDouble(Map<String, dynamic>.from(_liveScore!['score'] as Map)),
                              extras: int.tryParse(_liveScore!['score']['extra_runs'].toString()) ?? 0,
                              matchId: widget.matchId,
                              teamId: int.parse(_liveScore!['team_id'].toString()),
                              isLive: isLive,
                              refreshInterval: const Duration(seconds: 10),
                            ),
                          ),
                        ),

                      // ----- YouTube panel (graphics removed) -----
                      if (headerPanel == _HeaderPanel.youtube && (youtubeUrl ?? '').isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    'Live Stream / Video',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                  ),
                                ),
                                YouTubeBox(youtubeUrl: youtubeUrl!),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),
                      _buildSponsorStripCard(), // centered title + original carousel
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                MatchSummaryTab(
                  matchId: widget.matchId,
                  summary: summaryData!.rawSummary,
                  matchData: summaryData!.rawMatchData,
                ),
                ScorecardScreen(matchId: widget.matchId),
                MatchSquadTab(matchId: widget.matchId),
                MatchStatsTab(
                  matchId: widget.matchId,
                  team1Name: team1Name,
                  team2Name: team2Name,
                  refreshTick: _refreshTick,
                ),
                MatchInfoTab(matchData: summaryData!.rawMatchData),
                MatchCommentaryTab(
                  matchId: widget.matchId,
                  team1Id: team1Id,
                  team2Id: team2Id,
                  team1Name: team1Name,
                  team2Name: team2Name,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- UI bits (sponsors) ----------
  Widget _buildSponsorStripCard() {
    if (_loadingSponsors) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    if (_sponsors.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 1,
          child: const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Text('Sponsors',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                ),
                SizedBox(height: 8),
              ],
            ),
          ),
        ),
        _SponsorCarousel(sponsors: _sponsors),
      ],
    );
  }
}

// ====== Sponsor widgets (unchanged visuals for centered name) ======
const String _kPlaceholderAsset = 'lib/asset/images/cricjust_logo.png';
bool _looksHttp(String s) => s.startsWith('http://') || s.startsWith('https://');
String _absoluteUrl(String url) {
  final u = url.trim();
  if (_looksHttp(u)) return u;
  if (u.startsWith('/')) return 'https://cricjust.in$u';
  return 'https://cricjust.in/$u';
}
extension _StrBlank on String? {
  bool get isBlank => this == null || this!.trim().isEmpty || this == 'null';
}
ImageProvider<Object> _safeImageProvider(String? url) {
  if (url.isBlank) return const AssetImage(_kPlaceholderAsset);
  return NetworkImage(_absoluteUrl(url!));
}
Widget _safeNetImg(
    String? url, {
      double? width,
      double? height,
      BoxFit fit = BoxFit.cover,
    }) {
  if (url.isBlank) {
    return Image.asset(_kPlaceholderAsset, width: width, height: height, fit: fit);
  }
  return Image.network(
    _absoluteUrl(url!),
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (_, __, ___) =>
        Image.asset(_kPlaceholderAsset, width: width, height: height, fit: fit),
  );
}

class _SponsorCarousel extends StatefulWidget {
  final List<Sponsor> sponsors;
  const _SponsorCarousel({required this.sponsors});

  @override
  State<_SponsorCarousel> createState() => _SponsorCarouselState();
}

class _SponsorCarouselState extends State<_SponsorCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.82, initialPage: 0);

    if (widget.sponsors.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (!mounted) return;
        _index = (_index + 1) % widget.sponsors.length;
        _controller.animateToPage(
          _index,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        SizedBox(
          height: 156,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _index = i),
            itemCount: widget.sponsors.length,
            itemBuilder: (context, i) {
              final s = widget.sponsors[i];
              final hasLink = (s.website ?? '').trim().isNotEmpty;
              final img = s.imageUrl;

              final card = Center(
                child: Container(
                  width: 260,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141414) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                    border: Border.all(color: Colors.black.withOpacity(0.06)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 86,
                        width: double.infinity,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            color: Colors.grey[100],
                            child: _safeNetImg(img, fit: BoxFit.contain),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        s.name,
                        textAlign: TextAlign.center, // keep centered
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );

              return hasLink
                  ? InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  final uri = Uri.tryParse(s.website!.trim());
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: card,
              )
                  : card;
            },
          ),
        ),
        if (widget.sponsors.length > 1) const SizedBox(height: 8),
        if (widget.sponsors.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.sponsors.length, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 10 : 6,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: isDark
                      ? (active ? Colors.white70 : Colors.white30)
                      : (active ? Colors.black.withOpacity(0.65) : Colors.black26),
                ),
              );
            }),
          ),
      ],
    );
  }
}
