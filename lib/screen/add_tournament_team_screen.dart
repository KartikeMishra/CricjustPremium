// lib/screen/add_tournament_team_screen.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../service/image_upload_cache.dart';
import '../service/team_service.dart';
import '../service/user_image_service.dart';
import '../theme/color.dart';

class AddTournamentTeamScreen extends StatefulWidget {
  final int tournamentId;
  const AddTournamentTeamScreen({super.key, required this.tournamentId});

  @override
  State<AddTournamentTeamScreen> createState() => _AddTournamentTeamScreenState();
}

class _AddTournamentTeamScreenState extends State<AddTournamentTeamScreen> {
  String? _token;

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  // Hidden logo URL (preview only)
  String? _logoUrl;
  bool _uploadingLogo = false;

  // Players search + selection
  final _playerSearchCtrl = TextEditingController();
  final _playerScroll = ScrollController();
  final _playerRows = <Map<String, dynamic>>[];
  final _selectedPlayerIds = <int>{};
  bool _loadingPlayers = false;
  bool _playersHasMore = true;
  int _playersSkip = 0;
  final int _playersLimit = 20;
  Timer? _playerDebounce;

  bool _saving = false;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _init();

    _playerScroll.addListener(() {
      if (_playerScroll.position.pixels >= _playerScroll.position.maxScrollExtent - 120) {
        if (_playersHasMore && !_loadingPlayers) _loadPlayers();
      }
    });

    _playerSearchCtrl.addListener(() {
      _playerDebounce?.cancel();
      _playerDebounce = Timer(const Duration(milliseconds: 400), _reloadPlayers);
    });
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('api_logged_in_token');
    await _reloadPlayers();
    if (mounted) setState(() => _initializing = false);
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
    if (_token == null) return;
    setState(() => _loadingPlayers = true);
    try {
      final rows = await TeamService.searchPlayers(
        apiToken: _token!,
        query: _playerSearchCtrl.text.trim(),
        limit: _playersLimit,
        skip: _playersSkip,
      );
      setState(() {
        _playerRows.addAll(rows);
        _playersSkip += _playersLimit;
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

  Future<void> _pickAndUploadLogo(ImageSource source) async {
    void log(String m) => debugPrint('🧪 [Picker] $m');

    if (_token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login required')),
      );
      return;
    }

    final picker = ImagePicker();
    final pickSw = Stopwatch()..start();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 75,   // compression
      maxWidth: 1000,     // resize
    );
    pickSw.stop();
    log('pickImage done in ${pickSw.elapsedMilliseconds} ms');
    if (picked == null) return;

    final file = File(picked.path);
    final pathLower = picked.path.toLowerCase();

    // 1) Validate BEFORE spinner
    final sizeBytes = await file.length();
    final sizeMB = sizeBytes / (1024 * 1024);
    log('picked=${picked.path}  size=${sizeMB.toStringAsFixed(2)} MB');

    if (!(pathLower.endsWith('.jpg') || pathLower.endsWith('.jpeg') || pathLower.endsWith('.png'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only JPG and PNG images are allowed')),
      );
      log('Rejected: bad extension');
      return;
    }

    if (sizeMB > 2.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image must be under 2 MB')),
      );
      log('Rejected: too large');
      return;
    }

    // 2) Cache check BEFORE spinner
    try {
      final cached = await ImageUploadCache.getIfUploaded(file);
      if (cached != null && cached.isNotEmpty) {
        if (!mounted) return;
        setState(() => _logoUrl = cached);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Used cached upload ✔️')),
        );
        log('Cache HIT: $cached');
        return;
      } else {
        log('Cache MISS');
      }
    } catch (e) {
      log('Cache error (ignored): $e');
    }

    // 3) Upload WITH spinner and guaranteed reset
    setState(() => _uploadingLogo = true);
    final uploadSw = Stopwatch()..start();
    try {
      final url = await UserImageService
          .uploadAndGetUrl(token: _token!, file: file, postTimeout: const Duration(seconds: 30));

      await ImageUploadCache.save(file, url);

      if (!mounted) return;
      setState(() => _logoUrl = url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logo uploaded ✔️')),
      );
      log('Upload OK in ${uploadSw.elapsedMilliseconds} ms  → $url');
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload timed out. Please try again.')),
      );
      log('Timeout after ${uploadSw.elapsedMilliseconds} ms');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload error: $e')),
      );
      log('Upload error: $e');
    } finally {
      uploadSw.stop();
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }




  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter team name')),
      );
      return;
    }
    if (_token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login required')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final ok = await TeamService.addTeam(
        apiToken: _token!,
        name: name,
        description: _descCtrl.text.trim(),
        logo: _logoUrl ?? '',
        playerIds: _selectedPlayerIds.toList(),
        tournamentId: widget.tournamentId,
      );
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Team created')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Create failed')),
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
    _playerSearchCtrl.dispose();
    _playerScroll.dispose();
    _playerDebounce?.cancel();
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
          'Add Team',
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

      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
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
                const SizedBox(height: 12),

                // Logo preview + buttons (hidden URL)
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

                // search players
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

                // selected chips
                Wrap(
                  spacing: 6,
                  runSpacing: -6,
                  children: _selectedPlayerIds.map((pid) {
                    return Chip(
                      label: Text('ID $pid'),
                      onDeleted: () => setState(() => _selectedPlayerIds.remove(pid)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),

                // players list
                SizedBox(
                  height: 260,
                  child: _loadingPlayers && _playerRows.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : NotificationListener<OverscrollIndicatorNotification>(
                    onNotification: (n) { n.disallowIndicator(); return false; },
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
                            child: Text(name.isNotEmpty ? name.characters.first.toUpperCase() : '?'),
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

          // sticky actions
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
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
