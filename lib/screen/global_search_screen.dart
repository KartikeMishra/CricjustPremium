// lib/screen/global_search_screen.dart
// BEAUTIFIED: segmented chips, softer cards, tidy meta chips, better typography.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Screen/player_info.dart';
import '../model/search_result_model.dart';
import '../service/search_service.dart';
import 'full_match_detail.dart';
import 'tournament_detail_screen.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _controller = TextEditingController();
  final _debouncer = _Debouncer(const Duration(milliseconds: 350));

  SearchType _type = SearchType.match; // default to Matches (like your screenshot)
  bool _loading = false;
  String? _error;

  List<Object> _items = const [];

  @override
  void dispose() {
    _controller.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() {
      _error = null;
      _loading = value.trim().isNotEmpty;
    });

    _debouncer(() async {
      final q = value;
      try {
        List<Object> result;
        switch (_type) {
          case SearchType.player:
            result = (await GlobalSearchService.players(q)).cast<Object>();
            break;
          case SearchType.match:
            result = (await GlobalSearchService.matches(q)).cast<Object>();
            break;
          case SearchType.tournament:
            result = (await GlobalSearchService.tournaments(q)).cast<Object>();
            break;
        }
        if (!mounted) return;
        setState(() {
          _items = result;
          _loading = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    });
  }

  void _onTypeChanged(SearchType t) {
    setState(() {
      _type = t;
      _items = const [];
      _error = null;
      _loading = _controller.text.trim().isNotEmpty;
    });
    _onQueryChanged(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        elevation: 0,
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _controller.clear();
                setState(() {
                  _items = const [];
                  _error = null;
                  _loading = false;
                });
              },
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            height: _loading ? 2 : 0.5,
            alignment: Alignment.centerLeft,
            child: _loading
                ? const LinearProgressIndicator(minHeight: 2)
                : Container(
              height: 0.5,
              color: dark ? Colors.white12 : Colors.black12,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          _PrettySegmentedChips(selected: _type, onSelected: _onTypeChanged),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _SearchField(
              controller: _controller,
              hint: _type == SearchType.player
                  ? 'Search players…'
                  : _type == SearchType.match
                  ? 'Search matches…'
                  : 'Search tournaments…',
              onChanged: _onQueryChanged,
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: _ErrorBanner(text: _error!),
            ),
          Expanded(
            child: _items.isEmpty
                ? _EmptyState(isTyping: _controller.text.trim().isNotEmpty, type: _type)
                : ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                switch (_type) {
                  case SearchType.player:
                    final r = _items[i] as PlayerResult;
                    return _PlayerCard(
                      result: r,
                      onTap: () {
                        final id = int.tryParse(r.id);
                        if (id != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PlayerPublicInfoTab(playerId: id),
                            ),
                          );
                        }
                      },
                    );
                  case SearchType.match:
                    final m = _items[i] as MatchResult;
                    return _MatchCard(
                      match: m,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullMatchDetail(matchId: m.matchId),
                        ),
                      ),
                    );
                  case SearchType.tournament:
                    final t = _items[i] as TournamentResult;
                    return _TournamentCard(
                      data: t,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TournamentDetailScreen(
                            tournamentId: t.tournamentId,
                          ),
                        ),
                      ),
                    );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------ Header bits ------------------------ */

class _PrettySegmentedChips extends StatelessWidget {
  final SearchType selected;
  final ValueChanged<SearchType> onSelected;
  const _PrettySegmentedChips({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? Colors.white10 : const Color(0xFFF2F5FA);

    Widget chip(String label, SearchType t, IconData icon) {
      final isSel = selected == t;
      return InkWell(
        onTap: () => onSelected(t),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSel ? Theme.of(context).colorScheme.primary.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSel
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.55)
                  : (dark ? Colors.white24 : Colors.black12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: isSel ? Theme.of(context).colorScheme.primary : (dark ? Colors.white70 : Colors.black54)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isSel ? Theme.of(context).colorScheme.primary : (dark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: dark ? Colors.white12 : Colors.black12),
        ),
        child: Wrap(
          spacing: 8,
          children: [
            chip('Players', SearchType.player, Icons.person_rounded),
            chip('Matches', SearchType.match, Icons.sports_cricket_rounded),
            chip('Tournaments', SearchType.tournament, Icons.emoji_events_rounded),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  const _SearchField({required this.controller, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: dark ? Colors.white10 : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String text;
  const _ErrorBanner({required this.text});
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------ Cards ------------------------ */

class _PlayerCard extends StatelessWidget {
  final PlayerResult result;
  final VoidCallback onTap;
  const _PlayerCard({required this.result, required this.onTap});

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImg = (result.imageUrl ?? '').startsWith('http');

    final prettyRole = (result.playerType ?? '')
        .replaceAll('-', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : (w[0].toUpperCase() + w.substring(1)))
        .join(' ');

    final prettyBat = (result.batterType ?? '').isEmpty
        ? ''
        : (result.batterType![0].toUpperCase() + result.batterType!.substring(1));

    return _CardShell(
      onTap: onTap,
      child: Row(
        children: [
          hasImg
              ? CircleAvatar(radius: 24, backgroundImage: NetworkImage(result.imageUrl!))
              : CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFe3f2fd),
            child: Text(
              _initials(result.name),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1565C0),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (prettyRole.isNotEmpty) _MetaChip(prettyRole),
                    if (prettyBat.isNotEmpty) _MetaChip('$prettyBat-hand bat'),
                    _MetaChip('ID ${result.id}', muted: true),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.black45),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final MatchResult match;
  final VoidCallback onTap;
  const _MatchCard({required this.match, required this.onTap});

  Widget _teamAvatar(String? url, String name) {
    if (url != null && url.startsWith('http')) {
      return CircleAvatar(radius: 18, backgroundImage: NetworkImage(url));
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: const Color(0xFFE3F2FD),
      child: Text(
        name.isNotEmpty ? name.trim()[0].toUpperCase() : '?',
        style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1565C0)),
      ),
    );
  }

  String _score(TeamSnippet t) {
    final r = t.totalRuns;
    final w = t.totalWickets;
    if (r == null || w == null) return '';
    final ov = t.oversDone;
    final bl = t.ballsDone;
    String overs = '';
    if (ov != null) {
      overs = ' (${ov}${bl != null && bl > 0 ? ".${bl}" : ''})';
    }
    return '$r/$w$overs';
  }

  String _prettyDate(String date, String time) {
    final raw = '${date.trim()} ${time.trim()}';
    final fmts = [
      'yyyy-MM-dd HH:mm:ss',
      'yyyy-MM-dd HH:mm',
      'yyyy-MM-dd',
    ];
    DateTime? dt;
    for (final f in fmts) {
      try {
        dt = DateFormat(f).parseStrict(raw);
        break;
      } catch (_) {}
    }
    dt ??= DateTime.tryParse(date) ?? DateTime.now();
    return DateFormat('yyyy-MM-dd · HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _CardShell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Teams + scores
          Row(
            children: [
              _teamAvatar(match.team1.teamLogo, match.team1.teamName),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  match.team1.teamName.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.2),
                ),
              ),
              Text(
                _score(match.team1),
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _teamAvatar(match.team2.teamLogo, match.team2.teamName),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  match.team2.teamName.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.2),
                ),
              ),
              Text(
                _score(match.team2),
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),

          // Meta chips row 1
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(match.matchName.isEmpty ? 'Match' : match.matchName.trim(), bold: true),
              if ((match.tournamentName ?? '').trim().isNotEmpty)
                _MetaChip(match.tournamentName!.trim()),
              _MetaChip(_prettyDate(match.matchDate, match.matchTime)),
            ],
          ),
          const SizedBox(height: 8),

          // Meta chips row 2
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if ((match.venue ?? '').trim().isNotEmpty)
                _MetaChip(match.venue!.trim(), icon: Icons.place_outlined, muted: true),
              if ((match.result ?? '').trim().isNotEmpty)
                _MetaChip(match.result!.trim(), tone: ChipTone.success, icon: Icons.check_circle_outline),
            ],
          ),
        ],
      ),
    );
  }
}

class _TournamentCard extends StatelessWidget {
  final TournamentResult data;
  final VoidCallback onTap;
  const _TournamentCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLogo = (data.logo ?? '').startsWith('http');

    return _CardShell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          hasLogo
              ? CircleAvatar(radius: 24, backgroundImage: NetworkImage(data.logo!))
              : const CircleAvatar(radius: 24, child: Icon(Icons.emoji_events)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if ((data.startDate ?? '').isNotEmpty) _MetaChip(data.startDate!),
                    _MetaChip(data.isGroup == 1 ? 'Group Stage' : 'Knockout', muted: true),
                  ],
                ),
                if ((data.desc ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    data.desc!.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.black45),
        ],
      ),
    );
  }
}

/* ------------------------ Shared UI bits ------------------------ */

class _CardShell extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _CardShell({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: dark ? Colors.white10 : Colors.black.withOpacity(0.06)),
          boxShadow: [
            if (!dark)
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: child,
        ),
      ),
    );
  }
}

enum ChipTone { normal, success }

class _MetaChip extends StatelessWidget {
  final String label;
  final bool bold;
  final bool muted;
  final IconData? icon;
  final ChipTone tone;
  const _MetaChip(
      this.label, {
        this.bold = false,
        this.muted = false,
        this.icon,
        this.tone = ChipTone.normal,
      });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    Color bg;
    Color fg;
    Color border;

    if (tone == ChipTone.success) {
      bg = const Color(0xFF00C853).withOpacity(dark ? 0.18 : 0.10);
      fg = const Color(0xFF00A94F);
      border = const Color(0xFF00C853).withOpacity(0.35);
    } else if (muted) {
      bg = dark ? Colors.white10 : const Color(0xFFF1F5F9);
      fg = dark ? Colors.white70 : const Color(0xFF0D47A1);
      border = dark ? Colors.white12 : Colors.black12;
    } else if (bold) {
      fg = Theme.of(context).colorScheme.primary;
      bg = fg.withOpacity(dark ? 0.18 : 0.10);
      border = fg.withOpacity(0.35);
    } else {
      bg = dark ? Colors.white10 : const Color(0xFFF1F6FE);
      fg = dark ? Colors.white70 : const Color(0xFF0D47A1);
      border = dark ? Colors.white12 : Colors.black12;
    }

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: bold ? 0.25 : 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isTyping;
  final SearchType type;
  const _EmptyState({required this.isTyping, required this.type});

  @override
  Widget build(BuildContext context) {
    final icon = type == SearchType.player
        ? Icons.person_search_rounded
        : type == SearchType.match
        ? Icons.sports_cricket_rounded
        : Icons.emoji_events_rounded;

    final msg = isTyping
        ? 'Searching…'
        : (type == SearchType.player
        ? 'Search players by name'
        : type == SearchType.match
        ? 'Search matches by name or venue'
        : 'Search tournaments by name');

    final dark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: dark ? Colors.white30 : Colors.black26),
            const SizedBox(height: 10),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: dark ? Colors.white60 : Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------ Debouncer ------------------------ */

class _Debouncer {
  final Duration delay;
  Timer? _t;
  _Debouncer(this.delay);
  void call(void Function() action) {
    _t?.cancel();
    _t = Timer(delay, action);
  }
  void dispose() => _t?.cancel();
}
