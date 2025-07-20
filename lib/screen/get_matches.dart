import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screen/match_scoring_screen.dart';
import '../service/match_service.dart';
import '../theme/color.dart';
import '../widget/toss_dialog.dart';
import 'add_match_screen.dart';
import 'update_match_screen.dart';
import 'login_screen.dart';

class GetMatchScreen extends StatefulWidget {
  const GetMatchScreen({super.key});

  @override
  State<GetMatchScreen> createState() => _GetMatchScreenState();
}

class _GetMatchScreenState extends State<GetMatchScreen> {
  List<Map<String, dynamic>> _matches = [];
  bool _loading = true;
  int? _currentUserId;
  String? _token;
  bool _isNavigatingToScoreScreen = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_logged_in_token');
    if (token == null || token.isEmpty) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
      return;
    }
    _token = token;
    _currentUserId = prefs.getInt('user_id');
    await _loadMatches();
  }

  Future<void> _loadMatches() async {
    setState(() => _loading = true);
    try {
      const adminIds = [12];
      final data = (_currentUserId != null && adminIds.contains(_currentUserId))
          ? await MatchService.fetchAllMatchesForAdmin()
          : await MatchService.fetchUserMatches(context: context);


      setState(() => _matches = data);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Session expired')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteMatch(int matchId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Match'),
        content: const Text('Are you sure you want to delete this match?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await MatchService.deleteMatch(matchId);
      setState(() => _matches.removeWhere((m) => m['match_id'] == matchId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Match deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  Widget _actionIcon({
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.15),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> match) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const adminUserIds = [12];
    final canEdit =
        _currentUserId != null &&
        (match['user_id'] == _currentUserId ||
            adminUserIds.contains(_currentUserId));

    final matchId = match['match_id'] as int?;
    final teamAId = match['team_one'] as int?;
    final teamBId = match['team_two'] as int?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        color: isDark ? Colors.grey[850] : Colors.white,
        elevation: isDark ? 1 : 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                match['match_name'] ?? 'Match',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${match['team_one_name']} vs ${match['team_two_name']}',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              Text(
                '${match['match_date']} at ${match['match_time']}',
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              if (canEdit)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      _actionIcon(
                        icon: Icons.edit,
                        color: AppColors.primary,
                        onTap: matchId == null
                            ? null
                            : () {
                                Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        UpdateMatchScreen(matchId: matchId),
                                  ),
                                ).then((updated) {
                                  if (updated == true) _loadMatches();
                                });
                              },
                      ),
                      _actionIcon(
                        icon: Icons.delete,
                        color: Colors.red,
                        onTap: matchId == null
                            ? null
                            : () => _deleteMatch(matchId),
                      ),
                      _actionIcon(
                        icon: Icons.sports_cricket,
                        color: Colors.green,
                        onTap: () async {
                          if (matchId != null &&
                              teamAId != null &&
                              teamBId != null) {
                            final current = _matches.firstWhere(
                              (m) => m['match_id'] == matchId,
                            );
                            final tossWinner = current['toss_win'];
                            final tossDecision = current['toss_win_chooses'];

                            if (tossWinner != null && tossDecision != null) {
                              final currentScoreData =
                                  await MatchService.fetchCurrentScore(matchId);

                              if (_isNavigatingToScoreScreen) return;
                              setState(() => _isNavigatingToScoreScreen = true);

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddScoreScreen(
                                    matchId: matchId,
                                    token: _token!,
                                  ),
                                ),
                              ).then((_) {
                                if (mounted) {
                                  setState(
                                    () => _isNavigatingToScoreScreen = false,
                                  );
                                }
                              });
                            } else {
                              final tossSuccess = await showDialog<bool>(
                                context: context,
                                builder: (_) => TossDialog(
                                  matchId: matchId,
                                  teamAId: teamAId,
                                  teamBId: teamBId,
                                  token: _token!,
                                  teamAName: match['team_one_name'] ?? 'Team A',
                                  teamBName: match['team_two_name'] ?? 'Team B',
                                ),
                              );
                              if (tossSuccess == true) {
                                await _loadMatches();
                                final refreshed = _matches.firstWhere(
                                  (m) => m['match_id'] == matchId,
                                );
                                if (refreshed['toss_win'] != null &&
                                    refreshed['toss_win_chooses'] != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AddScoreScreen(
                                        matchId: matchId,
                                        token: _token!,
                                      ),
                                    ),
                                  );
                                }
                              }
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Missing team data for scoring screen.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[100],
      appBar: PreferredSize(
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
            automaticallyImplyLeading: true,
            title: const Text(
              'Manage Matches',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMatches,
              child: _matches.isEmpty
                  ? Center(
                      child: Text(
                        'No matches available',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: _matches.length,
                      itemBuilder: (context, i) => _buildCard(_matches[i]),
                    ),
            ),
      floatingActionButton: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: FloatingActionButton.extended(
            backgroundColor: isDark
                ? Colors.white.withOpacity(0.1)
                : AppColors.primary,
            foregroundColor: Colors.white,
            elevation: isDark ? 2 : 4,
            icon: const Icon(Icons.add),
            label: const Text(
              'Add Match',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () async {
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const MatchUIScreen()),
              );
              if (created == true) _loadMatches();
            },
          ),
        ),
      ),
    );
  }
}
