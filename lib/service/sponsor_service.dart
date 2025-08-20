// lib/service/sponsor_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../model/sponsor_model.dart';

class SponsorService {
  static const String _addBaseUrl =
      'https://cricjust.in/wp-json/custom-api-for-cricket/add-user-sponsor';

  static const String _matchSponsorsUrl =
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-match-sponsors';

  // (Optional) If you plan to fetch tournament sponsors directly:
  static const String _tournamentSponsorsUrl =
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-tournament-sponsors';

  /// Add a sponsor (multipart upload).
  ///
  /// Required:
  /// - [apiLoggedInToken] – user token
  /// - [name]
  /// - [imageFile]
  /// - [type] – 'match' or 'tournament'
  /// - [matchId] if type == 'match'
  /// - [tournamentId] if type == 'tournament'
  ///
  /// Optional:
  /// - [website]
  /// - [isFeatured] (default false)
  static Future<AddSponsorResponse> addSponsor({
    required String apiLoggedInToken,
    required String name,
    required File imageFile,
    required String type, // 'match' or 'tournament'
    int? matchId,
    int? tournamentId,
    String? website,
    bool isFeatured = false,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    // ---- Validate inputs
    final t = type.toLowerCase().trim();
    if (t != 'match' && t != 'tournament') {
      throw ArgumentError("type must be 'match' or 'tournament'");
    }
    if (t == 'match' && (matchId == null || matchId <= 0)) {
      throw ArgumentError('match_id is required when type=match');
    }
    if (t == 'tournament' && (tournamentId == null || tournamentId <= 0)) {
      throw ArgumentError('tournament_id is required when type=tournament');
    }
    if (!await imageFile.exists()) {
      throw ArgumentError('image file not found at: ${imageFile.path}');
    }

    // ---- Build URL with token query param
    final uri = Uri.parse('$_addBaseUrl?api_logged_in_token=$apiLoggedInToken');

    final request = http.MultipartRequest('POST', uri);

    // ---- Fields
    request.fields['name'] = name;
    request.fields['type'] = t;
    request.fields['is_featured'] = isFeatured ? '1' : '0';
    if (website != null && website.trim().isNotEmpty) {
      request.fields['website'] = website.trim();
    }
    if (t == 'match') {
      request.fields['match_id'] = matchId!.toString();
    } else {
      request.fields['tournament_id'] = tournamentId!.toString();
    }

    // ---- File
    final imageStream = http.ByteStream(imageFile.openRead());
    final imageLength = await imageFile.length();
    final filename = imageFile.path.split(Platform.pathSeparator).last;

    request.files.add(http.MultipartFile(
      'image', // backend expects 'image'
      imageStream,
      imageLength,
      filename: filename,
    ));

    // ---- Send
    final streamed = await request.send().timeout(timeout);
    final resp = await http.Response.fromStream(streamed);

    // ---- Parse
    Map<String, dynamic> body;
    try {
      body = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      return AddSponsorResponse(
        status: 0,
        message: 'Unexpected response (${resp.statusCode}). Please try again later.',
        sponsor: null,
        raw: {'raw': resp.body},
      );
    }

    // If server included an error message with non-200, surface it
    if (resp.statusCode != 200 && (body['message'] is String)) {
      return AddSponsorResponse(
        status: 0,
        message: body['message'] as String,
        sponsor: null,
        raw: body,
      );
    }

    final parsed = AddSponsorResponse.fromJson(body);

    if (!parsed.ok && parsed.message.isNotEmpty) {
      return parsed;
    }
    if (!parsed.ok) {
      return AddSponsorResponse(
        status: parsed.status,
        message: 'Failed to add sponsor. Please verify input and try again.',
        sponsor: parsed.sponsor,
        raw: body,
      );
    }
    return parsed;
  }

  /// Convenience wrapper if you already have a Sponsor model + image.
  static Future<AddSponsorResponse> addSponsorFromModel({
    required String apiLoggedInToken,
    required Sponsor sponsor,
    required File imageFile,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    return addSponsor(
      apiLoggedInToken: apiLoggedInToken,
      name: sponsor.name,
      imageFile: imageFile,
      type: sponsor.type,
      matchId: sponsor.matchId,
      tournamentId: sponsor.tournamentId,
      website: sponsor.website,
      isFeatured: sponsor.isFeatured,
      timeout: timeout,
    );
  }

  /// Fetch sponsors for a match.
  ///
  /// Example: GET /get-match-sponsors?match_id=210
  static Future<SponsorListResponse> getMatchSponsors({
    required int matchId,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (matchId <= 0) {
      throw ArgumentError('matchId must be > 0');
    }

    final uri = Uri.parse('$_matchSponsorsUrl?match_id=$matchId');
    final resp = await http.get(uri).timeout(timeout);

    Map<String, dynamic> body;
    try {
      body = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      return SponsorListResponse(
        status: 0,
        allSponsors: const [],
        featuredSponsors: const [],
        raw: {'raw': resp.body, 'statusCode': resp.statusCode},
      );
    }

    // Non-200 or backend failure — surface gracefully
    if (resp.statusCode != 200 && (body['status'] ?? 0) != 1) {
      return SponsorListResponse(
        status: 0,
        allSponsors: const [],
        featuredSponsors: const [],
        raw: body,
      );
    }

    return SponsorListResponse.fromJson(body);
  }

  /// (Optional) Fetch sponsors for a tournament.
  ///
  /// Example: GET /get-tournament-sponsors?tournament_id=38
  static Future<SponsorListResponse> getTournamentSponsors({
    required int tournamentId,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (tournamentId <= 0) {
      throw ArgumentError('tournamentId must be > 0');
    }

    final uri = Uri.parse('$_tournamentSponsorsUrl?tournament_id=$tournamentId');
    final resp = await http.get(uri).timeout(timeout);

    Map<String, dynamic> body;
    try {
      body = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      return SponsorListResponse(
        status: 0,
        allSponsors: const [],
        featuredSponsors: const [],
        raw: {'raw': resp.body, 'statusCode': resp.statusCode},
      );
    }

    if (resp.statusCode != 200 && (body['status'] ?? 0) != 1) {
      return SponsorListResponse(
        status: 0,
        allSponsors: const [],
        featuredSponsors: const [],
        raw: body,
      );
    }

    return SponsorListResponse.fromJson(body);
  }
}
