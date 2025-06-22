import 'package:flutter/material.dart';
import '../model/post_model.dart';
import '../service/post_service.dart';
import '../widget/post_card.dart';
import '../screen/post_detail_screen.dart';

class AllPostsScreen extends StatefulWidget {
  const AllPostsScreen({super.key});

  @override
  State<AllPostsScreen> createState() => _AllPostsScreenState();
}

class _AllPostsScreenState extends State<AllPostsScreen>
    with SingleTickerProviderStateMixin {
  List<PostModel> _posts = [];
  List<PostModel> _filteredPosts = [];
  List<String> _categories = ['All'];
  String _selectedCategory = 'All';
  bool _isLoading = true;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _fetchPosts();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchPosts() async {
    try {
      final posts = await PostService.fetchPosts(limit: 20);
      final allCategories = <String>{};

      for (var post in posts) {
        allCategories.addAll(post.categories);
      }

      setState(() {
        _posts = posts;
        _filteredPosts = posts;
        _categories = ['All', ...allCategories.toList()];
        _isLoading = false;
      });

      _controller.forward();
    } catch (e) {
      debugPrint("Error fetching posts: $e");
      setState(() => _isLoading = false);
    }
  }

  void _filterPosts(String category) {
    setState(() {
      _selectedCategory = category;
      _filteredPosts = category == 'All'
          ? _posts
          : _posts.where((post) => post.categories.contains(category)).toList();
    });
  }

  Future<void> _handleRefresh() async {
    await _fetchPosts();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _handleRefresh,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_categories.length > 1)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                child: Row(
                  children: _categories.map((cat) {
                    final selected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          cat,
                          style: TextStyle(
                            color: selected ? Colors.white : null,
                          ),
                        ),
                        selected: selected,
                        selectedColor: Colors.blue,
                        backgroundColor:
                        isDark ? Colors.grey[800] : Colors.grey[200],
                        onSelected: (_) => _filterPosts(cat),
                      ),
                    );
                  }).toList(),
                ),
              ),
            Expanded(
              child: _filteredPosts.isEmpty
                  ? const Center(child: Text("No posts available"))
                  : ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: _filteredPosts.length,
                itemBuilder: (context, index) {
                  final post = _filteredPosts[index];
                  return FadeTransition(
                    opacity: _animation,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PostDetailScreen(postId: post.id),
                          ),
                        );
                      },
                      child: PostCard(post: post),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
