class PostDetailModel {
  final int id;
  final String title;
  final String date;
  final String image;
  final List<String> categories;
  final String description;
  final String author;

  PostDetailModel({
    required this.id,
    required this.title,
    required this.date,
    required this.image,
    required this.categories,
    required this.description,
    required this.author,
  });

  factory PostDetailModel.fromJson(Map<String, dynamic> json) {
    return PostDetailModel(
      id: json['id'],
      title: json['title'],
      date: json['date'],
      image: json['image'],
      categories: (json['category'] as List)
          .map((cat) => cat['cat_name'].toString())
          .toList(),
      description: json['description'],
      author: json['author']['author_name'],
    );
  }
}
