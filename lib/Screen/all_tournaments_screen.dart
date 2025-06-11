import 'package:cricjust_premium/Screen/tournament_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../model/tournament_model.dart';
import '../service/tournament_service.dart';
import '../theme/color.dart';
import '../theme/text_styles.dart';

class AllTournamentsScreen extends StatefulWidget {
  final String type; // live, upcoming, recent

  const AllTournamentsScreen({super.key, required this.type});

  @override
  State<AllTournamentsScreen> createState() => _AllTournamentsScreenState();
}

class _AllTournamentsScreenState extends State<AllTournamentsScreen> {
  List<TournamentModel> _tournaments = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _limit = 20;
  int _skip = 0;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchTournaments();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _fetchTournaments();
    }
  }

  Future<void> _fetchTournaments() async {
    if (!mounted) return;
    setState(() => _isLoadingMore = true);
    try {
      final data = await TournamentService.fetchTournaments(
        type: widget.type,
        limit: _limit,
        skip: _skip,
      );
      if (!mounted) return;
      setState(() {
        _tournaments.addAll(data);
        _skip += _limit;
        _hasMore = data.length == _limit;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      print("Error fetching tournaments: $e");
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _formatDate(String date) {
    try {
      final parsed = DateFormat('yyyy-MM-dd').parse(date);
      return DateFormat('dd MMM yyyy').format(parsed);
    } catch (_) {
      return date;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _tournaments.isEmpty
        ? const Center(child: Text("No tournaments available"))
        : ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: _tournaments.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _tournaments.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final tournament = _tournaments[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TournamentDetailScreen(
                  tournamentId: tournament.tournamentId,
                ),
              ),
            );
          },
          child: Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: AppColors.cardBackground,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
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
                          "Start: ${_formatDate(tournament.startDate)} | Teams: ${tournament.teams}",
                          style: AppTextStyles.venue,
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
