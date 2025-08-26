// lib/screen/add_sponsor_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../model/sponsor_model.dart';
import '../service/sponsor_service.dart';
import '../theme/color.dart';

class AddSponsorScreen extends StatefulWidget {
  const AddSponsorScreen({super.key});

  @override
  State<AddSponsorScreen> createState() => _AddSponsorScreenState();
}

class _AddSponsorScreenState extends State<AddSponsorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _picker = ImagePicker();

  // 'tournament' | 'match'
  String _type = 'tournament';
  bool _isFeatured = false;
  bool _submitting = false;

  // selections
  SimpleTournament? _selectedTournament;
  SimpleMatchItem? _selectedMatch;

  File? _imageFile;
  String? _token;

  @override
  void initState() {
    super.initState();
    _initToken();
  }

  Future<void> _initToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _token = prefs.getString('api_logged_in_token') ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (x != null) setState(() => _imageFile = File(x.path));
    } catch (e) {
      _snack('Failed to pick image: $e', error: true);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (_imageFile == null) {
      _snack('Please select sponsor image', error: true);
      return;
    }
    if ((_token ?? '').isEmpty) {
      _snack('User token missing. Please login again.', error: true);
      return;
    }

    int? matchId;
    int? tournamentId;

    if (_type == 'match') {
      if (_selectedMatch == null) {
        _snack('Please select a Match', error: true);
        return;
      }
      matchId = _selectedMatch!.id;

      // back-fill tournament selection if known
      if (_selectedTournament == null && _selectedMatch!.tournamentId != null) {
        _selectedTournament = SimpleTournament(
          id: _selectedMatch!.tournamentId!,
          name: _selectedMatch!.tournamentName ?? 'Tournament',
          logo: null,
        );
      }
    } else {
      if (_selectedTournament == null) {
        _snack('Please select a Tournament', error: true);
        return;
      }
      tournamentId = _selectedTournament!.id;
    }

    setState(() => _submitting = true);
    try {
      final res = await SponsorService.addSponsor(
        apiLoggedInToken: _token!,
        name: _nameCtrl.text.trim(),
        imageFile: _imageFile!,
        website: _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim(),
        isFeatured: _isFeatured,
        type: _type,
        matchId: matchId,
        tournamentId: tournamentId,
      );

      if (res.ok) {
        _snack(res.message.isNotEmpty ? res.message : 'Sponsor added!');
        // pop with created sponsor (if backend returns it), else local echo
        if (!mounted) return;
        Navigator.pop(
          context,
          res.sponsor ??
              Sponsor(
                id: null,
                name: _nameCtrl.text.trim(),
                imageUrl: null,
                website: _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim(),
                isFeatured: _isFeatured,
                type: _type,
                matchId: matchId,
                tournamentId: tournamentId,
              ),
        );
      } else {
        _snack(res.message.isNotEmpty ? res.message : 'Failed to add sponsor', error: true);
      }
    } catch (e) {
      _snack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : Colors.green),
      );
  }

  // ───────────────────────────────── UI ─────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
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
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: const Text(
              'Add Sponsor',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _imageCard(),
              const SizedBox(height: 16),
              _card(
                child: TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Sponsor Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Please enter sponsor name' : null,
                ),
              ),
              const SizedBox(height: 12),
              _card(
                child: TextFormField(
                  controller: _websiteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Website (optional)',
                    hintText: 'https://example.com',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                ),
              ),
              const SizedBox(height: 12),

              // type selector
              _typeSelectorCard(),
              const SizedBox(height: 12),

              // pickers based on type
              if (_type == 'tournament') _tournamentPickerTile(),
              if (_type == 'match') ...[
                _tournamentPickerTile(hint: 'Filter by Tournament (optional)'),
                const SizedBox(height: 8),
                _matchPickerTile(),
              ],

              const SizedBox(height: 12),
              _featuredCard(),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _saveButton(),
    );
  }

  Widget _imageCard() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _submitting ? null : _pickImage,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.withValues(alpha: 0.15),
                ),
                clipBehavior: Clip.antiAlias,
                child: _imageFile == null
                    ? const Icon(Icons.image_outlined, size: 36)
                    : Image.file(_imageFile!, fit: BoxFit.cover),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _imageFile == null
                      ? 'Tap to select sponsor image (required)'
                      : 'Change selected image',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.upload_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }

  Widget _typeSelectorCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sponsor Type *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            children: [
              _typeChip('tournament'),
              const SizedBox(width: 8),
              _typeChip('match'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _typeChip(String value) {
    final selected = _type == value;
    return ChoiceChip(
      label: Text(value[0].toUpperCase() + value.substring(1)),
      selected: selected,
      onSelected: _submitting
          ? null
          : (_) {
        setState(() {
          _type = value;
          if (value == 'tournament') _selectedMatch = null; // clear dangling match
        });
      },
      selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
    );
  }

  Widget _tournamentPickerTile({String hint = 'Select Tournament *'}) {
    return _card(
      child: ListTile(
        leading: const Icon(Icons.emoji_events),
        title: Text(
          _selectedTournament?.name ?? hint,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: _selectedTournament == null ? Colors.grey : null,
          ),
        ),
        trailing: const Icon(Icons.keyboard_arrow_down),
        onTap: _submitting ? null : _openTournamentPicker,
      ),
    );
  }

  Widget _matchPickerTile() {
    return _card(
      child: ListTile(
        leading: const Icon(Icons.sports_cricket),
        title: Text(
          _selectedMatch?.name ?? 'Select Match *',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: _selectedMatch == null ? Colors.grey : null,
          ),
        ),
        subtitle: _selectedMatch == null
            ? null
            : Text([
          if (_selectedMatch!.tournamentName != null) _selectedMatch!.tournamentName!,
          if (_selectedMatch!.dateStr != null) _selectedMatch!.dateStr!,
        ].join(' • ')),
        trailing: const Icon(Icons.keyboard_arrow_down),
        onTap: _submitting ? null : _openMatchPicker,
      ),
    );
  }

  Widget _featuredCard() {
    return _card(
      child: SwitchListTile(
        value: _isFeatured,
        onChanged: _submitting ? null : (v) => setState(() => _isFeatured = v),
        title: const Text('Featured Sponsor'),
        subtitle: const Text('Enable to mark sponsor as featured'),
      ),
    );
  }

  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ElevatedButton.icon(
          icon: _submitting
              ? const SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
              : const Icon(Icons.check_circle_outline),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(_submitting ? 'Saving...' : 'Save Sponsor',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 6,
          ),
          onPressed: _submitting ? null : _submit,
        ),
      ),
    );
  }

  // ─────────────────────────────── Pickers ───────────────────────────────

  Future<void> _openTournamentPicker() async {
    if ((_token ?? '').isEmpty) {
      _snack('User token missing. Please login again.', error: true);
      return;
    }
    final picked = await showModalBottomSheet<SimpleTournament>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TournamentPickerSheet(token: _token!),
    );
    if (picked != null) {
      setState(() {
        _selectedTournament = picked;
        _selectedMatch = null; // reset match if tournament changed/picked
      });
    }
  }

  Future<void> _openMatchPicker() async {
    final picked = await showModalBottomSheet<SimpleMatchItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MatchPickerSheetV2(
        token: _token, // optional
        filterTournamentId: _selectedTournament?.id,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedMatch = picked;
        // Back-fill tournament if known from match
        if (_selectedMatch!.tournamentId != null &&
            (_selectedTournament == null ||
                _selectedTournament!.id != _selectedMatch!.tournamentId)) {
          _selectedTournament = SimpleTournament(
            id: _selectedMatch!.tournamentId!,
            name: _selectedMatch!.tournamentName ?? 'Tournament',
            logo: null,
          );
        }
      });
    }
  }
}

// ─────────────────────────────── Models ───────────────────────────────

class SimpleTournament {
  final int id;
  final String name;
  final String? logo;

  SimpleTournament({required this.id, required this.name, this.logo});

  factory SimpleTournament.fromJson(Map<String, dynamic> j) {
    final id = _toInt(j['tournament_id']) ?? _toInt(j['id']) ?? 0;
    return SimpleTournament(
      id: id,
      name: (j['tournament_name'] ?? j['name'] ?? 'Tournament').toString(),
      logo: j['tournament_logo']?.toString() ?? j['logo']?.toString(),
    );
  }
}

class SimpleMatchItem {
  final int id;
  final String name;
  final String? dateStr;
  final int? tournamentId;
  final String? tournamentName;

  SimpleMatchItem({
    required this.id,
    required this.name,
    this.dateStr,
    this.tournamentId,
    this.tournamentName,
  });

  factory SimpleMatchItem.fromJson(Map<String, dynamic> j) {
    final id = _toInt(j['match_id']) ?? _toInt(j['id']) ?? 0;
    final tId = _toInt(j['tournament_id']);
    return SimpleMatchItem(
      id: id,
      name: (j['match_name'] ?? j['name'] ?? 'Match').toString(),
      dateStr: (j['match_date'] ?? j['date'] ?? '').toString().trim().isEmpty
          ? null
          : (j['match_date'] ?? j['date']).toString(),
      tournamentId: tId,
      tournamentName: j['tournament_name']?.toString(),
    );
  }
}

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return int.tryParse(s);
}

// ───────────────────── Tournament Picker (paginated) ────────────────────

class TournamentPickerSheet extends StatefulWidget {
  final String token;
  const TournamentPickerSheet({super.key, required this.token});

  @override
  State<TournamentPickerSheet> createState() => _TournamentPickerSheetState();
}

class _TournamentPickerSheetState extends State<TournamentPickerSheet> {
  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();

  final List<SimpleTournament> _items = [];
  bool _loading = false;
  bool _hasMore = true;
  int _skip = 0;
  final int _limit = 20;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 100 &&
          !_loading &&
          _hasMore) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      if (reset) {
        _skip = 0;
        _items.clear();
        _hasMore = true;
      }
      final uri = Uri.parse(
        'https://cricjust.in/wp-json/custom-api-for-cricket/get-tournament'
            '?api_logged_in_token=${widget.token}'
            '&limit=$_limit&skip=$_skip'
            '&search=${Uri.encodeComponent(_searchCtrl.text.trim())}',
      );

      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final jsonData = json.decode(resp.body);
        final list = (jsonData['data'] as List?) ?? [];
        final fetched = list.map((e) => SimpleTournament.fromJson(e)).toList();

        setState(() {
          _items.addAll(fetched);
          _skip += _limit;
          _hasMore = fetched.length == _limit;
        });
      } else {
        setState(() => _hasMore = false);
      }
    } catch (_) {
      setState(() => _hasMore = false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        color: isDark ? const Color(0xFF121212) : Colors.white,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 50, height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                onSubmitted: (_) => _load(reset: true),
                decoration: InputDecoration(
                  hintText: 'Search tournament',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchCtrl.clear();
                      _load(reset: true);
                    },
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _items.isEmpty && !_loading
                  ? const Center(child: Text('No tournaments found'))
                  : ListView.builder(
                controller: _scroll,
                itemCount: _items.length + (_hasMore ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i >= _items.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final t = _items[i];
                  return ListTile(
                    leading: const Icon(Icons.emoji_events),
                    title: Text(t.name),
                    onTap: () => Navigator.pop(context, t),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────── Match Picker (get-matches, paginated) ────────────────────

class MatchPickerSheetV2 extends StatefulWidget {
  final String? token;           // optional
  final int? filterTournamentId; // optional server/local filter

  const MatchPickerSheetV2({
    super.key,
    this.token,
    this.filterTournamentId,
  });

  @override
  State<MatchPickerSheetV2> createState() => _MatchPickerSheetV2State();
}

class _MatchPickerSheetV2State extends State<MatchPickerSheetV2> {
  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();

  // server paging
  static const int _limit = 20;
  int _skip = 0;
  bool _loading = false;
  bool _hasMore = true;

  // API type filter (live | upcoming | recent)
  String _type = 'recent';

  // data
  final List<SimpleMatchItem> _items = [];
  List<SimpleMatchItem> _view = [];

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 120 &&
          !_loading &&
          _hasMore) {
        _load();
      }
    });
    _searchCtrl.addListener(_applyLocalSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Uri _buildUri() {
    final base = 'https://cricjust.in/wp-json/custom-api-for-cricket/get-matches';
    final params = <String, String>{
      'type': _type, // live | upcoming | recent
      'limit': '$_limit',
      'skip': '$_skip',
    };
    if ((widget.token ?? '').isNotEmpty) {
      params['api_logged_in_token'] = widget.token!;
    }
    // If backend supports tournament_id, send it; harmless if ignored
    if (widget.filterTournamentId != null) {
      params['tournament_id'] = widget.filterTournamentId!.toString();
    }
    return Uri.parse(base).replace(queryParameters: params);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      if (reset) {
        _skip = 0;
        _items.clear();
        _hasMore = true;
      }
      final uri = _buildUri();
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final jsonData = json.decode(resp.body);
        final list = (jsonData['data'] as List?) ?? [];
        final fetched = list.map((e) => SimpleMatchItem.fromJson(e)).toList();

        setState(() {
          _items.addAll(fetched);
          _skip += _limit;
          _hasMore = fetched.length == _limit;
        });
        _applyLocalSearch();
      } else {
        setState(() => _hasMore = false);
      }
    } catch (_) {
      setState(() => _hasMore = false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyLocalSearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    List<SimpleMatchItem> items = List.of(_items);

    // local filter if server ignored tournament_id
    if (widget.filterTournamentId != null) {
      items = items.where((m) => m.tournamentId == widget.filterTournamentId).toList();
    }

    if (q.isNotEmpty) {
      items = items.where((m) {
        final name = m.name.toLowerCase();
        final tname = (m.tournamentName ?? '').toLowerCase();
        return name.contains(q) || tname.contains(q);
      }).toList();
    }

    setState(() => _view = items);
  }

  void _changeType(String t) {
    if (_type == t) return;
    setState(() => _type = t);
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        color: isDark ? const Color(0xFF121212) : Colors.white,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 50, height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            const SizedBox(height: 12),

            // Type chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  _typeChip('live', 'Live'),
                  _typeChip('upcoming', 'Upcoming'),
                  _typeChip('recent', 'Recent'),
                ],
              ),
            ),

            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search match or tournament',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchCtrl.clear();
                      _applyLocalSearch();
                    },
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            Expanded(
              child: _loading && _items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : (_view.isEmpty
                  ? const Center(child: Text('No matches found'))
                  : ListView.builder(
                controller: _scroll,
                itemCount: _view.length + (_hasMore ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i >= _view.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final m = _view[i];
                  return ListTile(
                    leading: const Icon(Icons.sports_cricket),
                    title: Text(m.name),
                    subtitle: Text([
                      if (m.tournamentName != null) m.tournamentName!,
                      if (m.dateStr != null) m.dateStr!,
                    ].join(' • ')),
                    onTap: () => Navigator.pop(context, m),
                  );
                },
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeChip(String value, String label) {
    final selected = _type == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _changeType(value),
      selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
    );
  }
}
