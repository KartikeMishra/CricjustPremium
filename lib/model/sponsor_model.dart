// lib/model/sponsor_model.dart
import 'dart:convert';

enum SponsorType { match, tournament, unknown }

SponsorType sponsorTypeFromString(String? v) {
  switch ((v ?? '').toLowerCase().trim()) {
    case 'match':
      return SponsorType.match;
    case 'tournament':
      return SponsorType.tournament;
    default:
      return SponsorType.unknown;
  }
}

/// Represents a Sponsor record.
class Sponsor {
  final int? id;
  final String name;
  final String? imageUrl;
  final String? website;
  final bool isFeatured;
  /// Raw backend string: 'match' or 'tournament'
  final String type;
  final int? matchId;
  final int? tournamentId;

  const Sponsor({
    this.id,
    required this.name,
    this.imageUrl,
    this.website,
    required this.isFeatured,
    required this.type,
    this.matchId,
    this.tournamentId,
  });

  SponsorType get typeEnum => sponsorTypeFromString(type);

  /// Create from API map (lenient with keys)
  factory Sponsor.fromMap(Map<String, dynamic> map) {
    final matchId = _toInt(map['match_id']);
    final tournamentId = _toInt(map['tournament_id']);

    // infer type if missing
    final rawType = (map['type'] ?? '').toString().trim();
    final inferredType = rawType.isNotEmpty
        ? rawType
        : (matchId != null && matchId > 0)
        ? 'match'
        : (tournamentId != null && tournamentId > 0)
        ? 'tournament'
        : 'unknown';

    return Sponsor(
      id: _toInt(map['id']) ?? _toInt(map['sponsor_id']),
      name: (map['name'] ?? map['sponsor_name'] ?? '').toString(),
      imageUrl: map['image']?.toString() ?? map['image_url']?.toString(),
      website: map['website']?.toString(),
      isFeatured: _int(map['is_featured']) == 1,
      type: inferredType,
      matchId: matchId,
      tournamentId: tournamentId,
    );
  }

  /// Convenience when you get a JSON string.
  factory Sponsor.fromJson(String jsonStr) =>
      Sponsor.fromMap(jsonDecode(jsonStr) as Map<String, dynamic>);

  /// Safe int? caster
  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }

  /// Safe int caster with default 0
  static int _int(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '0') ?? 0;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'image_url': imageUrl,
    'website': website,
    'is_featured': isFeatured ? 1 : 0,
    'type': type,
    'match_id': matchId,
    'tournament_id': tournamentId,
  };

  /// Useful for building Multipart form fields (excluding the file itself).
  Map<String, String> toApiFields() {
    final m = <String, String>{
      'name': name,
      'type': type,
      'is_featured': isFeatured ? '1' : '0',
    };
    if ((website ?? '').toString().trim().isNotEmpty) {
      m['website'] = website!.trim();
    }
    if (typeEnum == SponsorType.match && (matchId ?? 0) > 0) {
      m['match_id'] = matchId.toString();
    }
    if (typeEnum == SponsorType.tournament && (tournamentId ?? 0) > 0) {
      m['tournament_id'] = tournamentId.toString();
    }
    return m;
  }

  String toJson() => jsonEncode(toMap());

  Sponsor copyWith({
    int? id,
    String? name,
    String? imageUrl,
    String? website,
    bool? isFeatured,
    String? type,
    int? matchId,
    int? tournamentId,
  }) {
    return Sponsor(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      website: website ?? this.website,
      isFeatured: isFeatured ?? this.isFeatured,
      type: type ?? this.type,
      matchId: matchId ?? this.matchId,
      tournamentId: tournamentId ?? this.tournamentId,
    );
  }

  // Value semantics
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Sponsor &&
        other.id == id &&
        other.name == name &&
        other.imageUrl == imageUrl &&
        other.website == website &&
        other.isFeatured == isFeatured &&
        other.type == type &&
        other.matchId == matchId &&
        other.tournamentId == tournamentId;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    imageUrl,
    website,
    isFeatured,
    type,
    matchId,
    tournamentId,
  );
}

/// Standard response wrapper used by several Cricjust APIs.
class AddSponsorResponse {
  final int status; // 1 = success, 0 = failure
  final String message;
  final Sponsor? sponsor;
  final Map<String, dynamic>? raw;

  AddSponsorResponse({
    required this.status,
    required this.message,
    this.sponsor,
    this.raw,
  });

  bool get ok => status == 1;

  factory AddSponsorResponse.fromJson(Map<String, dynamic> json) {
    // some backends return data or last_inserted
    final data = json['data'];
    Sponsor? s;
    if (data is Map<String, dynamic>) {
      s = Sponsor.fromMap(data);
    } else if (json['last_inserted'] is Map<String, dynamic>) {
      s = Sponsor.fromMap(json['last_inserted'] as Map<String, dynamic>);
    }

    return AddSponsorResponse(
      status: Sponsor._int(json['status']),
      message: (json['message'] ?? '').toString(),
      sponsor: s,
      raw: json,
    );
  }
}

/// Response for get-match-sponsors / get-tournament-sponsors endpoints
class SponsorListResponse {
  final int status; // 1/0
  final List<Sponsor> allSponsors;
  final List<Sponsor> featuredSponsors;
  final Map<String, dynamic>? raw;

  bool get ok => status == 1;

  SponsorListResponse({
    required this.status,
    required this.allSponsors,
    required this.featuredSponsors,
    this.raw,
  });

  factory SponsorListResponse.fromJson(Map<String, dynamic> json) {
    final all = (json['all_sponsors'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Sponsor.fromMap)
        .toList();

    final featured = (json['featured_sponsors'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Sponsor.fromMap)
        .toList();

    return SponsorListResponse(
      status: Sponsor._int(json['status']),
      allSponsors: all,
      featuredSponsors: featured,
      raw: json,
    );
  }
}
