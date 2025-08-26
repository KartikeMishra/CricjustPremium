// lib/screen/my_matches_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../model/my_matches_model.dart';
import '../screen/full_match_detail.dart';
import '../screen/login_screen.dart';
import '../service/my_matches_service.dart';
import '../service/session_manager.dart';
import '../theme/color.dart'; // Uses AppColors.primary if available

class MyMatchesPage extends StatefulWidget {
  const MyMatchesPage({super.key});

  @override
  State<MyMatchesPage> createState() => _MyMatchesPageState();
}

enum _TabFilter { all, upcoming, completed }

class _MyMatchesPageState extends State<MyMatchesPage> {
  late Future<List<MyMatch>> _future;
  final _searchCtrl = TextEditingController();
  _TabFilter _filter = _TabFilter.all;

  @override
  void initState() {
    super.initState();
    _future = MyMatchesService.fetch();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _future = MyMatchesService.fetch());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 56,
        backgroundColor: Colors.transparent,
        title: const Text(
          'My Matches',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: .3,
          ),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        flexibleSpace: Container(
          decoration: isDark
              ? const BoxDecoration(color: Color(0xFF1E1E1E))
              : const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64), // space for the search
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              height: 44, // constrain to avoid overflow
              child: _GlassSearchBar(
                controller: _searchCtrl,
                hint: 'Search match or team…',
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
        ),
      ),

      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<MyMatch>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const _SkeletonList();
            }

            if (snap.hasError) {
              final msg = snap.error.toString();
              // If not logged-in / missing player_id
              return _ErrorOrLogin(
                message: msg.contains('Not logged in')
                    ? 'Please login to see your matches'
                    : 'Could not load your matches',
                showLogin: msg.contains('Not logged in'),
                onRetry: _refresh,
              );
            }

            final items = (snap.data ?? const <MyMatch>[]);
            final filtered = _applyFilters(items, _searchCtrl.text.trim(), _filter);

            if (filtered.isEmpty) {
              return _EmptyState(
                title: 'No matches found',
                subtitle: _filter == _TabFilter.all
                    ? 'Try a different search'
                    : 'No ${_filter.name} matches match your search',
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _FilterChips(
                  current: _filter,
                  onChanged: (f) => setState(() => _filter = f),
                ),
                const SizedBox(height: 12),
                ...filtered.map((m) => _MatchCard(
                  m: m,
                  onTap: () => _openMatch(m),
                )),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openMatch(MyMatch m) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FullMatchDetail(matchId: m.matchId)),
    );
  }

  // ---------- helpers ----------
  static List<MyMatch> _applyFilters(
      List<MyMatch> list,
      String q,
      _TabFilter filter,
      ) {
    final now = DateTime.now();
    bool containsQ(MyMatch m) {
      if (q.isEmpty) return true;
      final s = q.toLowerCase();
      return m.matchName.toLowerCase().contains(s) ||
          m.teamOneName.toLowerCase().contains(s) ||
          m.teamTwoName.toLowerCase().contains(s);
    }

    bool isCompleted(MyMatch m) =>
        (m.result?.isNotEmpty ?? false) ||
            (m.resultType?.isNotEmpty ?? false) ||
            (m.winningTeam != null);

    bool isUpcoming(MyMatch m) {
      final dt = _parseLocalDateTime(m.matchDate, m.matchTime);
      if (dt == null) return !isCompleted(m);
      return dt.isAfter(now) && !isCompleted(m);
    }

    Iterable<MyMatch> xs = list.where(containsQ);
    switch (filter) {
      case _TabFilter.upcoming:
        xs = xs.where(isUpcoming);
        break;
      case _TabFilter.completed:
        xs = xs.where(isCompleted);
        break;
      case _TabFilter.all:
        break;
    }
    return xs.toList();
  }

  static DateTime? _parseLocalDateTime(String date, String time) {
    try {
      if (date.isEmpty) return null;
      final d = DateFormat('yyyy-MM-dd').parse(date);
      if (time.isEmpty) return d;
      final t = DateFormat('HH:mm:ss').parse(time);
      return DateTime(d.year, d.month, d.day, t.hour, t.minute, t.second);
    } catch (_) {
      return null;
    }
  }
}

class _FilterChips extends StatelessWidget {
  final _TabFilter current;
  final ValueChanged<_TabFilter> onChanged;

  const _FilterChips({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget buildChip(String label, _TabFilter value) { // ← change Chip → Widget
      final selected = current == value;
      return ChoiceChip(
        label: Text(label, overflow: TextOverflow.ellipsis),
        selected: selected,
        onSelected: (_) => onChanged(value),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        labelStyle: TextStyle(
          color: selected
              ? Colors.white
              : Theme.of(context).textTheme.bodyMedium?.color,
          fontWeight: FontWeight.w600,
        ),
        selectedColor: AppColors.primary,
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: selected ? 1 : 0,
      );

    }

    return Wrap(
      spacing: 10,
      children: [
        buildChip('All', _TabFilter.all),
        buildChip('Upcoming', _TabFilter.upcoming),
        buildChip('Completed', _TabFilter.completed),
      ],
    );
  }
}


class _MatchCard extends StatelessWidget {
  final MyMatch m;
  final VoidCallback onTap;

  const _MatchCard({required this.m, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dt = _MyMatchesPageState._parseLocalDateTime(m.matchDate, m.matchTime);
    final when = dt != null ? DateFormat('EEE, d MMM yyyy • h:mm a').format(dt) : null;

    final completed = (m.result?.isNotEmpty ?? false) ||
        (m.resultType?.isNotEmpty ?? false) ||
        (m.winningTeam != null);

    final statusText = completed
        ? (m.result?.isNotEmpty == true ? m.result! : (m.resultType ?? 'Completed'))
        : (when ?? 'Scheduled');

    return Card(
      elevation: isDark ? 0 : 1.5,
      color: Theme.of(context).cardColor,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _TeamAvatar(name: m.teamOneName, url: m.teamOneLogo),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      m.matchName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${m.teamOneName}  vs  ${m.teamTwoName}',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: .8),
                        fontWeight: FontWeight.w600,
                        letterSpacing: .2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _Pill(statusText, filled: completed),
                        if (m.overs != null && m.overs! > 0) _Pill('${m.overs} overs'),
                        if (m.ballType.isNotEmpty) _Pill(m.ballType),
                        if (m.venue?.isNotEmpty == true)
                          _IconPill(Icons.place_rounded, m.venue!),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _TeamAvatar(name: m.teamTwoName, url: m.teamTwoLogo),
            ],
          ),
        ),
      ),
    );
  }
}
class _TeamAvatar extends StatelessWidget {
  final String name;
  final String? url;

  const _TeamAvatar({required this.name, this.url});

  @override
  Widget build(BuildContext context) {
    const radius = 16.0;
    const size = 56.0;
    final hasUrl = url != null && url!.trim().isNotEmpty;

    if (!hasUrl) {
      return SizedBox(width: size, height: size,
        child: _InitialsBadge(name: name, size: size, radius: radius),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            _InitialsBadge(name: name, size: size, radius: radius),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _ShimmerBox(width: size, height: size, radius: radius);
        },
      ),
    );
  }
}

class _InitialsBadge extends StatelessWidget {
  final String name;
  final double size;
  final double radius;

  const _InitialsBadge({required this.name, required this.size, required this.radius});

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: .5,
          ),
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _ShimmerBox({required this.width, required this.height, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).dividerColor.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

String _initials(String s) {
  final parts = s.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return 'T';
  if (parts.length == 1) {
    final p = parts.first.toUpperCase();
    return p.length >= 2 ? p.substring(0, 2) : p;
  }
  return (parts.first[0] + parts.last[0]).toUpperCase();
}


class _TeamBadge extends StatelessWidget {
  final bool left;
  final String label;

  const _TeamBadge({required this.left, required this.label});

  @override
  Widget build(BuildContext context) {
    final initials = _initials(label);
    final align = left ? Alignment.centerLeft : Alignment.centerRight;
    return Container(
      width: 56,
      height: 56,
      alignment: align,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1976D2).withValues(alpha: .25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: .5,
            ),
          ),
        ),
      ),
    );
  }

  static String _initials(String s) {
    final parts = s.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'T';
    if (parts.length == 1) {
      return parts.first.length >= 2 ? parts.first.substring(0, 2).toUpperCase() : parts.first.toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final bool filled;

  const _Pill(this.text, {this.filled = false});

  @override
  Widget build(BuildContext context) {
    final bg = filled ? AppColors.primary : Theme.of(context).cardColor;
    final fg = filled ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: filled ? Colors.transparent : Colors.black12),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: fg),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _IconPill(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}


class _GlassSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  const _GlassSearchBar({
    required this.controller,
    required this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: .15),
            prefixIcon: const Icon(Icons.search, color: Colors.white),
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: 6,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(
          height: 92,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_rounded, size: 64, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: .8)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorOrLogin extends StatelessWidget {
  final String message;
  final bool showLogin;
  final VoidCallback onRetry;

  const _ErrorOrLogin({
    required this.message,
    required this.showLogin,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(showLogin ? Icons.lock_outline_rounded : Icons.error_outline_rounded,
                size: 64, color: Colors.orangeAccent),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (showLogin)
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final token = await SessionManager.getToken();
                  if (token == null) {
                    // Navigate to Login
                    // ignore: use_build_context_synchronously
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                  }
                },
                child: const Text('Login'),
              )
            else
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }
}
