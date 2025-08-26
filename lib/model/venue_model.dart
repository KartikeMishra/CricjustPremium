class Venue {
  final int venueId;
  final int userId;
  final String name;
  final String info;
  final String? link;
  final int status;
  final DateTime created;

  Venue({
    required this.venueId,
    required this.userId,
    required this.name,
    required this.info,
    this.link,
    required this.status,
    required this.created,
  });

  /// Safe parsing from API
  factory Venue.fromJson(Map<String, dynamic> json) {
    return Venue(
      venueId: int.tryParse(json['venue_id'].toString()) ?? 0,
      userId: int.tryParse(json['user_id'].toString()) ?? 0,
      name: json['venue_name']?.toString() ?? '',
      info: json['venue_info']?.toString() ?? '',
      link: json['venue_link']?.toString(),
      status: int.tryParse(json['status'].toString()) ?? 0,
      created: DateTime.tryParse(json['created'].toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'venue_id': venueId,
      'user_id': userId,
      'venue_name': name,
      'venue_info': info,
      'venue_link': link,
      'status': status,
      'created': created.toIso8601String(),
    };
  }
}
