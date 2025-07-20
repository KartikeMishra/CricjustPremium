import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../model/tournament_model.dart';
import '../service/tournament_service.dart';
import '../screen/tournament_detail_screen.dart';
import '../theme/color.dart';
import '../theme/text_styles.dart';

class AllTournamentsScreen extends StatefulWidget {
  final String type; // 'live', 'upcoming', or 'recent'
  final bool showAppBar;

  const AllTournamentsScreen({
    super.key,
    required this.type,
    this.showAppBar = true,
  });

  @override
  State<AllTournamentsScreen> createState() => _AllTournamentsScreenState();
}

class _AllTournamentsScreenState extends State<AllTournamentsScreen> {
  final List<TournamentModel> _tournaments = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _limit = 20, _skip = 0;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchTournaments();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _fetchTournaments();
    }
  }

  Future<void> _fetchTournaments() async {
    if (!mounted) return;
    setState(() => _isLoadingMore = true);
    try {
      final list = await TournamentService.fetchTournaments(
        type: widget.type,
        limit: _limit,
        skip: _skip,
      );
      if (!mounted) return;
      setState(() {
        _tournaments.addAll(list);
        _skip += _limit;
        _hasMore = list.length == _limit;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  String _formatDate(String date) {
    try {
      final d = DateFormat('yyyy-MM-dd').parse(date);
      return DateFormat('dd MMM yyyy').format(d);
    } catch (_) {
      return date;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? Theme.of(context).scaffoldBackgroundColor
        : Colors.grey[100]!;

    final titleText =
        'All ${widget.type[0].toUpperCase()}${widget.type.substring(1)} Tournaments';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: widget.showAppBar
          ? PreferredSize(
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
                  title: Text(
                    titleText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  iconTheme: const IconThemeData(color: Colors.white),
                ),
              ),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tournaments.isEmpty
          ? const Center(child: Text("No tournaments available"))
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _tournaments.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, idx) {
                if (idx >= _tournaments.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final t = _tournaments[idx];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TournamentDetailScreen(
                          tournamentId: t.tournamentId,
                        ),
                      ),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: Theme.of(context).cardColor,
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              t.tournamentLogo,
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.tournamentName,
                                  style: AppTextStyles.matchTitle.copyWith(
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (t.tournamentDesc.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      t.tournamentDesc,
                                      style: AppTextStyles.tournamentName,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                Text(
                                  "Start: ${_formatDate(t.startDate)} | Teams: ${t.teams}",
                                  style: AppTextStyles.venue.copyWith(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
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
    );
  }
}
