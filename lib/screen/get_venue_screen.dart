// lib/screen/get_venue_screen.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../model/venue_model.dart';
import '../service/venue_service.dart';
import '../service/session_manager.dart';
import '../theme/color.dart';
import 'login_screen.dart';
import 'add_venue_screen.dart';
import 'update_venue_screen.dart';

class GetVenueScreen extends StatefulWidget {
  const GetVenueScreen({super.key});

  @override
  State<GetVenueScreen> createState() => _GetVenueScreenState();
}

class _GetVenueScreenState extends State<GetVenueScreen> {
  // Data
  final List<Venue> _venues = [];

  // Session
  String? _apiToken;

  // Paging / loading
  final int _limit = 20;
  int _skip = 0;
  bool _hasMore = true;
  bool _loading = true;       // show spinner on first load
  bool _loadingMore = false;  // page loader

  // Search
  String _search = '';
  Timer? _debounce;

  // Controllers
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    _init();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _searchController.removeListener(_onSearchChanged);
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ---------- Session ----------
  Future<bool> _ensureSession() async {
    _apiToken = await SessionManager.getToken();
    if (_apiToken == null || _apiToken!.isEmpty) {
      if (!mounted) return false;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return false;
    }
    return true;
  }

  Future<void> _init() async {
    if (!await _ensureSession()) return;
    // reset paging
    setState(() {
      _skip = 0;
      _hasMore = true;
      _venues.clear();
      _loading = true;
    });
    await _fetchVenues(refresh: true);
    if (mounted) setState(() => _loading = false);
  }

  // ---------- Fetch ----------
  Future<void> _fetchVenues({bool refresh = false}) async {
    if (_loadingMore) return;
    if (!await _ensureSession()) return;

    if (refresh) {
      _skip = 0;
      _hasMore = true;
      _venues.clear();
    }
    if (!_hasMore) return;

    setState(() => _loadingMore = true);
    try {
      final data = await VenueService.fetchVenues(
        apiToken: _apiToken!,
        limit: _limit,
        skip: _skip,
        search: _search,
      );

      setState(() {
        _venues.addAll(data);
        _skip += data.length;
        _hasMore = data.length == _limit; // stop when fewer than limit
      });
    } catch (e) {
      final lower = e.toString().toLowerCase();

      // ✅ Treat "no venue found" (and similar) as an empty page, not an error
      final isNoResults =
          lower.contains('no venue found') ||
              lower.contains('no venues found') ||
              lower.contains('no data') ||
              lower.contains('no record');

      if (isNoResults) {
        if (mounted) {
          setState(() {
            _hasMore = false; // no more pages
            // if this was a refresh and truly empty, make sure list is empty
            if (refresh) _venues.clear();
          });
        }
        // Do not show a snackbar for this case
        return;
      }

      // Auth/session handling
      if (lower.contains('401') ||
          lower.contains('unauthorized') ||
          lower.contains('invalid api logged in token') ||
          lower.contains('session expired')) {
        await SessionManager.clear();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }


  // ---------- Handlers ----------
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        !_loading &&
        _hasMore) {
      _fetchVenues();
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      setState(() => _search = _searchController.text.trim());
      _fetchVenues(refresh: true);
    });
  }

  Future<void> _confirmDelete(Venue venue) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[850] : null,
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete "${venue.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await VenueService.deleteVenue(
        apiToken: _apiToken!,
        venueId: venue.venueId,
      );
      setState(() => _venues.removeWhere((v) => v.venueId == venue.venueId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Venue deleted')),
      );
    } catch (e) {
      final lower = e.toString().toLowerCase();
      if (lower.contains('unauthorized') || lower.contains('session expired')) {
        await SessionManager.clear();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  Future<void> _hardRefresh() async {
    if (!await _ensureSession()) return;
    setState(() {
      _skip = 0;
      _hasMore = true;
      _venues.clear();
      _loading = true;
    });
    await _fetchVenues(refresh: true);
    if (mounted) setState(() => _loading = false);
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.grey[100];
    final cardColor = isDark ? Colors.grey[850] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,

    appBar: AppBar(
    backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,

      // ✅ makes the back arrow (and any AppBar icons) white
      iconTheme: const IconThemeData(color: Colors.white),

      // (optional) force a white back arrow when the route can pop
      leading: Navigator.canPop(context) ? const BackButton(color: Colors.white) : null,

      // (optional) white status bar icons over the gradient
      systemOverlayStyle: SystemUiOverlayStyle.light,

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
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      title: const Text(
        'Manage Venues',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white12 : Colors.white,
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
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Search venues...',
                hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
                border: InputBorder.none,
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ),
        ),
      ),
    ),

    body: _loading && _venues.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _hardRefresh,
        child: _venues.isEmpty
            ? ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 220),
            Center(child: Text('No venues found.')),
            SizedBox(height: 400),
          ],
        )
            : ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _venues.length + (_loadingMore ? 1 : 0),
          itemBuilder: (ctx, i) {
            if (i >= _venues.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final v = _venues[i];
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  if (!isDark)
                    const BoxShadow(
                      color: Colors.black12,
                      blurRadius: 5,
                      offset: Offset(0, 3),
                    ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                title: Text(
                  v.name,
                  style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    v.info,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit,
                          color: isDark ? Colors.white70 : Colors.blueAccent),
                      onPressed: () async {
                        final updated = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UpdateVenueScreen(venue: v),
                          ),
                        );
                        if (updated == true) {
                          await _hardRefresh();
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete,
                          color: isDark ? Colors.red.shade300 : Colors.redAccent),
                      onPressed: () => _confirmDelete(v),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),

      floatingActionButton: isDark
          ? GestureDetector(
        onTap: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const AddVenueScreen()),
          );
          if (created == true) await _hardRefresh();
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.add, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Add Venue',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
      )
          : FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const AddVenueScreen()),
          );
          if (created == true) await _hardRefresh();
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Venue',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
