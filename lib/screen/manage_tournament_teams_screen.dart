// lib/screen/manage_tournament_teams_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/team_model.dart';
import '../service/team_service.dart';
import '../service/user_image_service.dart';
import '../theme/color.dart';
import 'add_tournament_team_screen.dart';
import 'login_screen.dart';

class ManageTournamentTeamsScreen extends StatefulWidget {
  final int tournamentId;
  const ManageTournamentTeamsScreen({super.key, required this.tournamentId});

  @override
  State<ManageTournamentTeamsScreen> createState() => _ManageTournamentTeamsScreenState();
}

class _ManageTournamentTeamsScreenState extends State<ManageTournamentTeamsScreen> {
  String? _token;

  // UI state
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String _errorText = '';

  // Data + paging
  final _items = <TeamModel>[];
  int _skip = 0;
  final int _limit = 20;

  // Search + scroll
  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _init();
    _scroll.addListener(_onScroll);
    _searchCtrl.addListener(_onSearchChanged);
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('api_logged_in_token');
    if (_token == null || _token!.isEmpty) {
      _redirectToLogin('Login required');
      return;
    }
    await _reload();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 160) {
      if (_hasMore && !_loadingMore && !_loading) _load();
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _reload);
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _errorText = '';
      _items.clear();
      _skip = 0;
      _hasMore = true;
    });
    await _load();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _load() async {
    if (_token == null || _token!.isEmpty) {
      _redirectToLogin('Login required');
      return;
    }

    setState(() => _loadingMore = true);
    try {
      final rows = await TeamService.fetchTeams(
        apiToken: _token!,
        tournamentId: widget.tournamentId,
        limit: _limit,
        skip: _skip,
        search: _searchCtrl.text.trim(),
      );

      setState(() {
        _items.addAll(rows);
        _skip += _limit;
        _hasMore = rows.length == _limit;
      });
    } catch (e) {
      final msg = e.toString();
      final lower = msg.toLowerCase();

      // 🔐 Session expired / invalid token → logout + redirect
      if (lower.contains('invalid api logged in token') ||
          lower.contains('session expired') ||
          lower.contains('unauthorized')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('api_logged_in_token');
        if (!mounted) return;
        _redirectToLogin('Session expired. Please login again.');
        return;
      }

      // 🫗 No teams → empty state
      if (lower.contains('no team found') || lower.contains('no teams found')) {
        setState(() {
          _errorText = '';
          _hasMore = false;
        });
      } else {
        // Unexpected error → show message + retry option
        setState(() => _errorText = msg);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load teams: $msg')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _redirectToLogin(String snack) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(snack)));
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scroll.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: const Text(
          'Manage Teams',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
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
          ),
        ),
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _reload,
        child: Column(
          children: [
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    if (!isDark)
                      const BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                  ],
                ),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Search team...',
                    prefixIcon: Icon(Icons.search),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ),

            Expanded(
              child: _errorText.isNotEmpty
                  ? _ErrorView(message: _errorText, onRetry: _reload)
                  : (_items.isEmpty
                  ? const _EmptyView()
                  : NotificationListener<OverscrollIndicatorNotification>(
                onNotification: (n) {
                  n.disallowIndicator();
                  return false;
                },
                child: ListView.builder(
                  controller: _scroll,
                  itemCount: _items.length + (_loadingMore ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i >= _items.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final t = _items[i];
                    final playerCount = t.teamPlayers.length ?? 0;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: (t.teamLogo.isNotEmpty)
                            ? CircleAvatar(backgroundImage: NetworkImage(t.teamLogo))
                            : const CircleAvatar(child: Icon(Icons.groups)),
                        title: Text(
                          t.teamName ?? '—',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text('Players: $playerCount'),
                        trailing: Wrap(
                          spacing: 6,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blueAccent),
                              onPressed: () => _openEditTeamBottomSheet(t),
                              tooltip: 'Edit team',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _deleteTeam(t),
                              tooltip: 'Delete team',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              )),
            ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => AddTournamentTeamScreen(tournamentId: widget.tournamentId),
            ),
          );
          if (created == true) {
            await _reload();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Team'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Future<void> _openEditTeamBottomSheet(TeamModel team) async {
    final token = _token;
    if (token == null) return;

    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditTeamBottomSheet(
        apiToken: token,
        team: team,
      ),
    );
    if (updated == true) {
      await _reload();
    }
  }

  Future<void> _deleteTeam(TeamModel t) async {
    if (_token == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Team'),
        content: Text('Delete "${t.teamName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await TeamService.deleteTeam(t.teamId, _token!);
      setState(() => _items.removeWhere((x) => x.teamId == t.teamId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Team deleted')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.groups_outlined, size: 56, color: isDark ? Colors.white54 : Colors.black38),
            const SizedBox(height: 12),
            const Text('No teams yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              'Create your first team for this tournament.',
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 56, color: isDark ? Colors.red[300] : Colors.red[400]),
            const SizedBox(height: 12),
            Text(
              'Something went wrong',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// Edit Team Bottom Sheet (inline editor)
/// ─────────────────────────────────────────────────────────────
class EditTeamBottomSheet extends StatefulWidget {
  final String apiToken;
  final TeamModel team;

  const EditTeamBottomSheet({
    super.key,
    required this.apiToken,
    required this.team,
  });

  @override
  State<EditTeamBottomSheet> createState() => _EditTeamBottomSheetState();
}

class _EditTeamBottomSheetState extends State<EditTeamBottomSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _originCtrl = TextEditingController();  // REQUIRED by service

  // Cache mapping player IDs to their names
  final Map<int, String> _playerNames = {};

  final _playerSearchCtrl = TextEditingController();
  final _playerScroll = ScrollController();
  final _playerRows = <Map<String, dynamic>>[];
  final _selectedPlayerIds = <int>{};

  String? _logoUrl;   // keep URL internally (no text field shown)
  bool _uploadingLogo = false;

  bool _saving = false;
  bool _loadingPlayers = false;
  bool _playersHasMore = true;
  int _playersSkip = 0;
  final int _playersLimit = 20;
  Timer? _playerDebounce;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.team.teamName ?? '';
    _descCtrl.text = widget.team.teamDescription ?? '';
    _logoUrl = widget.team.teamLogo.trim();
    _originCtrl.text = (widget.team.teamOrigin.toString().trim().isNotEmpty == true)
        ? widget.team.teamOrigin.toString()
        : '0';

    _selectedPlayerIds.addAll(widget.team.teamPlayers.map((e) => e));
    _preloadSelectedNames(); // load names for existing selections
  
    _playerScroll.addListener(() {
      if (_playerScroll.position.pixels >= _playerScroll.position.maxScrollExtent - 120) {
        if (_playersHasMore && !_loadingPlayers) _loadPlayers();
      }
    });

    _playerSearchCtrl.addListener(() {
      if (_playerDebounce?.isActive ?? false) _playerDebounce!.cancel();
      _playerDebounce = Timer(const Duration(milliseconds: 400), () {
        _reloadPlayers();
      });
    });

    _reloadPlayers(); // initial load
  }

  Future<void> _preloadSelectedNames() async {
    if (!mounted || _selectedPlayerIds.isEmpty) return;
    try {
      for (final pid in _selectedPlayerIds) {
        if (_playerNames.containsKey(pid)) continue;
        final rows = await TeamService.searchPlayers(
          apiToken: widget.apiToken,
          query: pid.toString(),
          limit: 1,
          skip: 0,
        );
        if (rows.isNotEmpty) {
          final row = rows.first;
          final name = (row['display_name'] ?? row['user_login'] ?? 'Player').toString();
          _playerNames[pid] = name;
        }
      }
      if (mounted) setState(() {});
    } catch (_) {
      // Silent fail okay; chips will fallback to "ID xxx"
    }
  }

  Future<void> _reloadPlayers() async {
    setState(() {
      _playerRows.clear();
      _playersSkip = 0;
      _playersHasMore = true;
    });
    await _loadPlayers();
  }

  Future<void> _loadPlayers() async {
    setState(() => _loadingPlayers = true);
    try {
      final rows = await TeamService.searchPlayers(
        apiToken: widget.apiToken,
        query: _playerSearchCtrl.text.trim(),
        limit: _playersLimit,
        skip: _playersSkip,
      );

      // De-dup existing
      final existingIds = _playerRows
          .map((r) => int.tryParse(r['ID']?.toString() ?? ''))
          .whereType<int>()
          .toSet();

      final List<Map<String, dynamic>> deduped = [];
      for (final r in rows) {
        final rid = int.tryParse(r['ID']?.toString() ?? '');
        if (rid == null) continue;

        // Cache name for chips
        final rname = (r['display_name'] ?? r['user_login'] ?? 'Player').toString();
        _playerNames[rid] = rname;

        if (!existingIds.contains(rid)) {
          deduped.add(r);
          existingIds.add(rid);
        }
      }

      setState(() {
        _playerRows.addAll(deduped);
        _playersSkip += rows.length; // advance by actual returned count
        _playersHasMore = rows.length == _playersLimit;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load players: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingPlayers = false);
    }
  }

  Future<void> _save() async {
    if ((_nameCtrl.text.trim()).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter team name')),
      );
      return;
    }

    final origin = _originCtrl.text.trim().isEmpty ? '0' : _originCtrl.text.trim();

    setState(() => _saving = true);
    try {
      final ok = await TeamService.updateTeam(
        teamId: widget.team.teamId,
        apiToken: widget.apiToken,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        origin: origin,
        playerIds: _selectedPlayerIds.toList(),
        logoUrl: (_logoUrl?.trim().isNotEmpty ?? false) ? _logoUrl!.trim() : null,
      );

      if (!mounted) return;
      if (ok) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Team updated')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Update failed')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _originCtrl.dispose();
    _playerSearchCtrl.dispose();
    _playerScroll.dispose();
    _playerDebounce?.cancel();
    super.dispose();
  }

  Future<void> _pickAndUploadLogo(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 90, maxWidth: 2400);
    if (picked == null) return;

    setState(() => _uploadingLogo = true);
    try {
      final url = await UserImageService.uploadAndGetUrl(
        token: widget.apiToken,
        file: File(picked.path),
      );
      if (!mounted) return;
      if (url.isNotEmpty != true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logo upload failed')));
        return;
      }
      setState(() {
        _logoUrl = url;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logo uploaded')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload error: $e')));
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 42, height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[500], borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Edit Team', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Team Name'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _descCtrl,
                      decoration: const InputDecoration(labelText: 'Description'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _originCtrl,
                      decoration: const InputDecoration(labelText: 'Origin (e.g., 0)'),
                    ),
                    const SizedBox(height: 10),

                    // Logo preview + upload buttons (NO URL field shown)
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: (_logoUrl != null && _logoUrl!.isNotEmpty)
                              ? Image.network(
                            _logoUrl!,
                            height: 56, width: 56, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(
                              height: 56, width: 56,
                              child: DecoratedBox(
                                decoration: BoxDecoration(color: Colors.black12),
                                child: Icon(Icons.broken_image),
                              ),
                            ),
                          )
                              : Container(
                            height: 56, width: 56,
                            decoration: BoxDecoration(
                              color: Colors.black12,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.image_outlined),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (_logoUrl != null && _logoUrl!.isNotEmpty)
                          IconButton(
                            tooltip: 'Remove logo',
                            onPressed: _uploadingLogo ? null : () => setState(() => _logoUrl = ''),
                            icon: const Icon(Icons.close),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _uploadingLogo ? null : () => _pickAndUploadLogo(ImageSource.gallery),
                          icon: const Icon(Icons.photo),
                          label: const Text('Gallery'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _uploadingLogo ? null : () => _pickAndUploadLogo(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Camera'),
                        ),
                        const SizedBox(width: 12),
                        if (_uploadingLogo)
                          const SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    Text('Players (${_selectedPlayerIds.length})',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),

                    // Search inside bottom sheet
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[850] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _playerSearchCtrl,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search players...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Selected chips — show NAME (fallback to ID while loading)
                    Wrap(
                      spacing: 6,
                      runSpacing: -6,
                      children: _selectedPlayerIds.map((pid) {
                        final label = _playerNames[pid] ?? 'ID $pid';
                        return Chip(
                          label: Text(label),
                          onDeleted: () => setState(() => _selectedPlayerIds.remove(pid)),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 8),

                    // Players list
                    SizedBox(
                      height: 260,
                      child: _loadingPlayers && _playerRows.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : NotificationListener<OverscrollIndicatorNotification>(
                        onNotification: (n) {
                          n.disallowIndicator();
                          return false;
                        },
                        child: ListView.builder(
                          controller: _playerScroll,
                          itemCount: _playerRows.length + (_loadingPlayers ? 1 : 0),
                          itemBuilder: (ctx, i) {
                            if (i >= _playerRows.length) {
                              return const Padding(
                                padding: EdgeInsets.all(12),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            final row = _playerRows[i];
                            final id = int.tryParse(row['ID']?.toString() ?? '') ?? 0;
                            final name = (row['display_name'] ?? row['user_login'] ?? 'Player').toString();
                            final selected = _selectedPlayerIds.contains(id);
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                child: Text(
                                  name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
                                ),
                              ),
                              title: Text(name),
                              subtitle: Text('ID: $id'),
                              trailing: IconButton(
                                icon: Icon(
                                  selected ? Icons.check_circle : Icons.add_circle_outline,
                                  color: selected ? Colors.green : null,
                                ),
                                onPressed: () {
                                  setState(() {
                                    if (selected) {
                                      _selectedPlayerIds.remove(id);
                                    } else {
                                      _selectedPlayerIds.add(id);
                                      _playerNames[id] = name; // cache for chip label immediately
                                    }
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // sticky action bar
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, -2))],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                            : const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
