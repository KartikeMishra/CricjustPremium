// lib/model/match_commentary_model.dart
import 'dart:convert';

/// ===========================================================
/// Top-level parsers
/// ===========================================================

/// Back-compat: parse only flattened events (used by older code)
List<CommEvent> parseCommentaryEventsFromRaw(String raw) {
  final jsonMap = jsonDecode(raw) as Map<String, dynamic>;
  final data = (jsonMap['data'] as List? ?? const []);
  final items = data
      .whereType<Map<String, dynamic>>()
      .map((e) => CommentaryItem.fromJson(e));

  // Flatten to events (keeps API order, no dedupe).
  return items.expand((it) => it.toEvents()).toList(growable: false);
}

/// New: return flattened events plus count of top-level items (for correct paging)
class CommPage {
  final List<CommEvent> events; // flattened for UI
  final int itemsCount;         // top-level `data.length` (page size unit)
  CommPage({required this.events, required this.itemsCount});
}

CommPage parseCommPageFromRaw(String raw) {
  final jsonMap = jsonDecode(raw) as Map<String, dynamic>;
  final data = (jsonMap['data'] as List? ?? const []);

  final items = data
      .whereType<Map<String, dynamic>>()
      .map((e) => CommentaryItem.fromJson(e));

  final events = items.expand((it) => it.toEvents()).toList(growable: false);
  return CommPage(events: events, itemsCount: data.length);
}

/// ===========================================================
/// API data models
/// ===========================================================

class CommentaryItem {
  final int? overNumber;
  final dynamic commentryPerBall; // List or Map (mixed by API)
  final OverInfo? overInfo;
  final TillOver? tillOver;

  CommentaryItem({
    required this.overNumber,
    required this.commentryPerBall,
    this.overInfo,
    this.tillOver,
  });

  factory CommentaryItem.fromJson(Map<String, dynamic> json) {
    final topLevelOver = json['over_number'];
    int? inferredOver;

    // Some payloads omit top-level over_number; infer from commentry_per_ball
    final cpb = json['commentry_per_ball'];
    if (topLevelOver == null && cpb != null) {
      if (cpb is List && cpb.isNotEmpty && cpb.first is Map) {
        final m = (cpb.first as Map);
        inferredOver = _asInt(m['over_number']);
      } else if (cpb is Map && cpb.isNotEmpty) {
        final firstVal = cpb.values.first;
        if (firstVal is Map) {
          inferredOver = _asInt((firstVal as Map)['over_number']);
        }
      }
    }

    return CommentaryItem(
      overNumber: _asInt(topLevelOver) ?? inferredOver,
      commentryPerBall: json['commentry_per_ball'],
      overInfo: (json['over_info'] is Map<String, dynamic>)
          ? OverInfo.fromJson(json['over_info'] as Map<String, dynamic>)
          : null,
      tillOver: (json['till_over'] is Map<String, dynamic>)
          ? TillOver.fromJson(json['till_over'] as Map<String, dynamic>)
          : null,
    );
  }
}

class OverInfo {
  final int? totalRuns;
  final int? totalWickets;
  final List<String> runsPerBall;

  OverInfo({
    required this.totalRuns,
    required this.totalWickets,
    required this.runsPerBall,
  });

  factory OverInfo.fromJson(Map<String, dynamic> json) => OverInfo(
    totalRuns: _asInt(json['total_runs']),
    totalWickets: _asInt(json['total_wkts']),
    runsPerBall: List<String>.from(json['runs_per_ball'] ?? const []),
  );
}

class TillOver {
  final int? totalRuns;
  final String? totalWickets; // API sometimes string (keep as String?)
  final Bowler? bowler;
  final Batters? batters;

  TillOver({
    required this.totalRuns,
    required this.totalWickets,
    required this.bowler,
    required this.batters,
  });

  factory TillOver.fromJson(Map<String, dynamic> json) => TillOver(
    totalRuns: _asInt(json['total_runs']),
    totalWickets: json['total_wickets']?.toString(),
    bowler: (json['bowler'] is Map<String, dynamic>)
        ? Bowler.fromJson(json['bowler'] as Map<String, dynamic>)
        : null,
    batters: (json['batters'] is Map<String, dynamic>)
        ? Batters.fromJson(json['batters'] as Map<String, dynamic>)
        : null,
  );
}

class Bowler {
  final String? bowlerId;
  final String? name;
  final String? overs;
  final int? runs;
  final int? wickets;

  Bowler({
    required this.bowlerId,
    required this.name,
    required this.overs,
    required this.runs,
    required this.wickets,
  });

  factory Bowler.fromJson(Map<String, dynamic> json) => Bowler(
    bowlerId: json['bowler_id']?.toString(),
    name: json['name']?.toString(),
    // Some payloads use key "0" for overs; keep both
    overs: (json['overs'] ?? json['0'])?.toString(),
    runs: _asInt(json['runs']),
    wickets: _asInt(json['wickets']),
  );
}

class Batters {
  final Batter? striker;
  final Batter? nonStriker;

  Batters({required this.striker, required this.nonStriker});

  factory Batters.fromJson(Map<String, dynamic> json) => Batters(
    striker: (json['striker_batter'] is Map<String, dynamic>)
        ? Batter.fromJson(json['striker_batter'] as Map<String, dynamic>)
        : null,
    nonStriker: (json['non_striker_batter'] is Map<String, dynamic>)
        ? Batter.fromJson(json['non_striker_batter'] as Map<String, dynamic>)
        : null,
  );
}

class Batter {
  final String? batterId;
  final String? name;
  final String? runs;
  final String? balls;

  Batter({
    required this.batterId,
    required this.name,
    required this.runs,
    required this.balls,
  });

  factory Batter.fromJson(Map<String, dynamic> json) => Batter(
    batterId: json['batter_id']?.toString(),
    name: json['name']?.toString(),
    runs: json['runs']?.toString(),
    balls: json['balls']?.toString(),
  );
}

/// ===========================================================
/// Flattened event model
/// ===========================================================

String _plainText(String s) => s
    .replaceAll(RegExp(r'<[^>]*>'), ' ')
    .replaceAll('&nbsp;', ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

final _reNoBall = RegExp(r'\bno[-\s]?ball\b', caseSensitive: false);
final _reWide = RegExp(r'\bwide\b', caseSensitive: false);
final _reWicket = RegExp(
  r'(score_wicket|run[-\s]?out|lbw|bowled|caught(?:\s+and\s+bowled)?|stump(?:ed)?|hit\s+wicket)',
  caseSensitive: false,
);
final _reSix = RegExp(r'\b(?:six|6)\b', caseSensitive: false);
final _reFour = RegExp(r'\b(?:four|4)\b', caseSensitive: false);
final _reRuns = RegExp(r'\b(\d+)\s*runs?\b', caseSensitive: false);
final _reNoRun = RegExp(r'\b(no\s+run|dot\s+ball)\b', caseSensitive: false);

class CommEvent {
  final int over;
  final String ball; // as provided by API (can be "")
  final String text; // HTML stripped
  final String chip; // WD / NB / W / 6 / 4 / 3 / 2 / 1 / 0
  final bool isWide;
  final bool isNoBall;
  final bool isWicket;

  CommEvent({
    required this.over,
    required this.ball,
    required this.text,
    required this.chip,
    required this.isWide,
    required this.isNoBall,
    required this.isWicket,
  });

  String get overDotBall => ball.isEmpty ? '$over.·' : '$over.$ball';
}

/// Turn one CommentaryItem into a flat list of CommEvent,
/// preserving API order and NOT de-duping repeated ball numbers.
extension CommentaryItemEvents on CommentaryItem {
  List<CommEvent> toEvents() {
    final List<CommEvent> out = [];

    void addFromMap(Map<String, dynamic> m) {
      final over = _asInt(m['over_number']) ?? (overNumber ?? 0);
      final ball = (m['ball_number'] ?? '').toString();

      final raw = (m['commentry'] ?? m['commentary'] ?? '').toString();
      final txt = _plainText(raw);

      final rawLower = raw.toLowerCase();
      final txtLower = txt.toLowerCase();

      final isWicket = _reWicket.hasMatch(rawLower) || _reWicket.hasMatch(txtLower);
      final isWide = _reWide.hasMatch(rawLower) || _reWide.hasMatch(txtLower);
      final isNoBall = _reNoBall.hasMatch(rawLower) || _reNoBall.hasMatch(txtLower);

      String chip;
      if (isWicket) {
        chip = 'W';
      } else if (isWide) {
        chip = 'WD';
      } else if (isNoBall) {
        chip = 'NB';
      } else if (_reSix.hasMatch(txtLower)) {
        chip = '6';
      } else if (_reFour.hasMatch(txtLower)) {
        chip = '4';
      } else if (_reNoRun.hasMatch(txtLower)) {
        chip = '0';
      } else {
        final mRuns = _reRuns.firstMatch(txt);
        chip = mRuns?.group(1) ?? '0';
      }

      out.add(CommEvent(
        over: over,
        ball: ball,
        text: txt,
        chip: chip,
        isWide: isWide,
        isNoBall: isNoBall,
        isWicket: isWicket,
      ));
    }

    final cpb = commentryPerBall;
    if (cpb is List) {
      for (final e in cpb) {
        if (e is Map<String, dynamic>) addFromMap(e);
      }
    } else if (cpb is Map) {
      // LinkedHashMap preserves insertion order in Dart
      for (final k in cpb.keys) {
        final v = cpb[k];
        if (v is Map<String, dynamic>) addFromMap(v);
      }
    }

    return out;
  }
}

/// ===========================================================
/// Helpers
/// ===========================================================

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return int.tryParse(s);
}
