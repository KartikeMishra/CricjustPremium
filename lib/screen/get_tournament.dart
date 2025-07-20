import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/tournament_model.dart';
import '../screen/add_tournament_screen.dart';
import '../screen/login_screen.dart';
import '../screen/manage_groups_screen.dart';
import '../screen/update_tournament_screen.dart';
import '../service/tournament_service.dart';
import '../theme/color.dart';

class TournamentListScreen extends StatefulWidget {
  const TournamentListScreen({super.key});

  @override
  State<TournamentListScreen> createState() => _TournamentListScreenState();
}

class _TournamentListScreenState extends State<TournamentListScreen> {
  final List<TournamentModel> _tournaments = [];
  bool _isLoading = true;
  String _search = '';
  Timer? _debounce;
  String? _apiToken;
  int? _currentUserId;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _checkLoginAndFetch();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _currentUserId = prefs.getInt('user_id'));
  }

  Future<void> _checkLoginAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_logged_in_token');
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    setState(() => _apiToken = token);
    await _fetchTournaments();
  }

  Future<void> _fetchTournaments() async {
    if (_apiToken == null) return;
    setState(() => _isLoading = true);
    try {
      final data = await TournamentService.fetchAllTournamentsRaw(
        apiToken: _apiToken!,
      );
      setState(() {
        _tournaments
          ..clear()
          ..addAll(data);
      });
    } catch (e) {
      if (e.toString().contains('401')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() => _search = _searchController.text.trim());
      _fetchTournaments();
    });
  }

  Future<void> _confirmDelete(int tournamentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Tournament'),
        content: const Text('Are you sure you want to delete this tournament?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || _apiToken == null) return;

    try {
      await TournamentService.deleteTournament(tournamentId, _apiToken!);
      setState(
        () => _tournaments.removeWhere((t) => t.tournamentId == tournamentId),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Deleted successfully')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  Widget _buildTournamentCard(TournamentModel t, bool isDark) {
    final bool isCompleted = t.winner != null && t.winner != 0;
    final bool isAdmin = _currentUserId == 12;
    final bool isCreator = _currentUserId == t.userId;
    final bool canEdit = isAdmin || (!isCompleted && isCreator);
    final bool canDelete = isAdmin || (!isCompleted && isCreator);

    final textColor = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? Colors.grey[900]! : Colors.white;
    final subTextColor = isDark ? Colors.grey[300]! : Colors.black87;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            const BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 4),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                backgroundImage: t.tournamentLogo.isNotEmpty
                    ? NetworkImage(t.tournamentLogo)
                    : null,
                child: t.tournamentLogo.isEmpty
                    ? const Icon(
                        Icons.emoji_events,
                        size: 26,
                        color: AppColors.primary,
                      )
                    : null,
              ),
              title: Text(
                t.tournamentName,
                style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.tournamentDesc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: subTextColor),
                    ),
                    if (isCompleted)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.emoji_events,
                              size: 18,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Winner: Team ID ${t.winner}", // You can replace with team name lookup logic
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              trailing: canEdit || canDelete
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (canEdit)
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              color: Colors.blueAccent,
                            ),
                            onPressed: () async {
                              final updated = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      UpdateTournamentScreen(tournament: t),
                                ),
                              );
                              if (updated == true) _fetchTournaments();
                            },
                          ),
                        if (canDelete)
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => _confirmDelete(t.tournamentId),
                          ),
                      ],
                    )
                  : null,
            ),
            if (t.isGroup == true && !isCompleted)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ManageGroupsScreen(tournamentId: t.tournamentId),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.groups,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  label: const Text(
                    'Manage Groups',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.grey[100];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(124),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 56,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: isDark
                  ? null
                  : const LinearGradient(
                      colors: [AppColors.primary, Color(0xFF42A5F5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              color: isDark ? const Color(0xFF1E1E1E) : null,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
          ),
          title: const Text(
            'Manage Tournaments',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(68),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black26 : Colors.black12,
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search tournaments...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white54 : Colors.grey,
                    ),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search, color: AppColors.primary),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tournaments.isEmpty
          ? const Center(child: Text('No tournaments found.'))
          : RefreshIndicator(
              onRefresh: _fetchTournaments,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: _tournaments.length,
                itemBuilder: (_, i) =>
                    _buildTournamentCard(_tournaments[i], isDark),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const AddTournamentScreen()),
          );
          if (created == true) _fetchTournaments();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Tournament'),
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
