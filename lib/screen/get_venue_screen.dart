// lib/screen/get_venue_screen.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/venue_model.dart';
import '../service/venue_service.dart';
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
  final List<Venue> _venues = [];
  bool _loading = false;
  String _search = '';
  Timer? _debounce;
  String? _apiToken;
  final int _limit = 20;
  int _skip = 0;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkLoginAndInit();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _checkLoginAndInit() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_logged_in_token');
    if (token == null || token.isEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    setState(() => _apiToken = token);
    await _fetchVenues();
  }

  Future<void> _fetchVenues() async {
    if (_loading || _apiToken == null) return;
    setState(() => _loading = true);
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
      });
    } catch (e) {
      debugPrint('Error fetching venues: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 200) {
      _fetchVenues();
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _venues.clear();
        _skip = 0;
        _search = _searchController.text.trim();
      });
      _fetchVenues();
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Venue deleted')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
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
    final cardColor = isDark ? Colors.grey[850] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,

      // ─── Header ─────────────────────────────────────────────
      appBar: AppBar(
        // make the AppBar itself transparent so our gradient shows through
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        // put your gradient here
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
        title: Text(
          'Manage Venues',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        // now attach your search bar as the bottom widget
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
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: AppColors.primary),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),

      // ─── Body ────────────────────────────────────────────────
      body: _loading && _venues.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _venues.length,
              itemBuilder: (ctx, i) {
                final v = _venues[i];
                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    title: Text(
                      v.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
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
                          icon: Icon(
                            Icons.edit,
                            color: isDark ? Colors.white70 : Colors.blueAccent,
                          ),
                          onPressed: () async {
                            final updated = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UpdateVenueScreen(venue: v),
                              ),
                            );
                            if (updated == true) {
                              setState(() {
                                _venues.clear();
                                _skip = 0;
                              });
                              _fetchVenues();
                            }
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete,
                            color: isDark
                                ? Colors.red.shade300
                                : Colors.redAccent,
                          ),
                          onPressed: () => _confirmDelete(v),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

      // ─── FAB ──────────────────────────────────────────────────
      floatingActionButton: isDark
          ? GestureDetector(
              onTap: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const AddVenueScreen()),
                );
                if (result == true) {
                  setState(() {
                    _venues.clear();
                    _skip = 0;
                  });
                  _fetchVenues();
                }
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.add, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Add Venue',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const AddVenueScreen()),
                );
                if (result == true) {
                  setState(() {
                    _venues.clear();
                    _skip = 0;
                  });
                  _fetchVenues();
                }
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Add Venue',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
    );
  }
}
