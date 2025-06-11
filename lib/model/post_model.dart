class PostModel {
  final int id;
  final String title;
  final String date;
  final String image;
  final List<String> categories;
  final String shortInfo; // Optional (if coming from list API)
  final String description;
  final String author;

  PostModel({
    required this.id,
    required this.title,
    required this.date,
    required this.image,
    required this.categories,
    required this.shortInfo,
    required this.description,
    required this.author,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'],
      title: json['title'],
      date: json['date'],
      image: json['image'],
      categories: List<String>.from(
        (json['category'] as List).map((cat) => cat['cat_name']),
      ),
      shortInfo: json['short_info'] ?? '', // from list API, fallback empty
      description: json['description'] ?? '',
      author: json['author']['author_name'],
    );
  }
}
