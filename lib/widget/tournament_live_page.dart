import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../model/tournament_model.dart';
import '../service/tournament_service.dart';
import '../screen/tournament_detail_screen.dart';
import '../theme/color.dart';
import '../theme/text_styles.dart';

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
      final data = await TournamentService.fetchTournaments(
        type: 'live',
        limit: 20,
        skip: 0,
      );
      setState(() {
        _tournaments = data;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading tournaments: $e');
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text(
          'All Live Tournaments',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tournaments.isEmpty
          ? const Center(child: Text("No live tournaments available."))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _tournaments.length,
              itemBuilder: (context, index) {
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
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: isDark
                                ? null
                                : const LinearGradient(
                                    colors: [Color(0xFFE3F2FD), Colors.white],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                            color: isDark ? const Color(0xFF2A2A2A) : null,
                            boxShadow: isDark
                                ? []
                                : [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.1),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: tournament.tournamentLogo.isNotEmpty
                                      ? Image.network(
                                          tournament.tournamentLogo,
                                          width: 64,
                                          height: 64,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                                Icons.broken_image,
                                                size: 64,
                                              ),
                                        )
                                      : Container(
                                          width: 64,
                                          height: 64,
                                          color: Colors.grey.shade300,
                                          child: const Icon(
                                            Icons.image_not_supported,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tournament.tournamentName,
                                        style: AppTextStyles.matchTitle
                                            .copyWith(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.blue.shade900,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (tournament.tournamentDesc.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Text(
                                            tournament.tournamentDesc,
                                            style: AppTextStyles.tournamentName
                                                .copyWith(
                                                  fontSize: 13,
                                                  color: isDark
                                                      ? Colors.grey[300]
                                                      : Colors.grey[800],
                                                ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      const SizedBox(height: 6),
                                      Text(
                                        "Strt: ${_formatDate(tournament.startDate)}  •  Teams: ${tournament.teams}",
                                        style: AppTextStyles.venue.copyWith(
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[600],
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
                  ),
                );
              },
            ),
    );
  }
}
