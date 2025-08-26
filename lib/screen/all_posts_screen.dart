import 'package:flutter/material.dart';
import '../model/post_model.dart';
import '../service/post_service.dart';
import '../widget/post_card.dart';
import '../screen/post_detail_screen.dart';
import '../theme/color.dart';

class AllPostsScreen extends StatefulWidget {
  const AllPostsScreen({super.key});

  @override
  State<AllPostsScreen> createState() => _AllPostsScreenState();
}

class _AllPostsScreenState extends State<AllPostsScreen>
    with SingleTickerProviderStateMixin {
  List<PostModel> _posts = [];
  List<PostModel> _filtered = [];
  List<String> _categories = const ['All'];
  String _selected = 'All';
  bool _loading = true;

  late final AnimationController _animCtrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _fetch();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final posts = await PostService.fetchPosts(limit: 20);

      final set = <String>{};
      for (final p in posts) {
        set.addAll(p.categories);
      }
      final cats = ['All', ...set.toList()..sort((a, b) => a.compareTo(b))];

      setState(() {
        _posts = posts;
        _filtered = posts;
        _categories = cats;
        _loading = false;
      });
      _animCtrl.forward(from: 0);
    } catch (e) {
      debugPrint('Error fetching posts: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter(String cat) {
    setState(() {
      _selected = cat;
      _filtered = cat == 'All'
          ? _posts
          : _posts.where((p) => p.categories.contains(cat)).toList();
    });
    _animCtrl.forward(from: 0);
  }

  Future<void> _refresh() => _fetch();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _refresh,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_categories.length > 1)
              _CategoryBar(
                categories: _categories,
                selected: _selected,
                onTap: _applyFilter,
              ),
            Expanded(
              child: _filtered.isEmpty
                  ? const _EmptyState()
                  : ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(
                    left: 12, right: 12, bottom: 24),
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final post = _filtered[i];
                  // Fade + slight slide up
                  return FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _fade.drive(
                        Tween<Offset>(
                          begin: const Offset(0, .03),
                          end: Offset.zero,
                        ),
                      ),
                      child: Padding(
                        padding:
                        const EdgeInsets.symmetric(vertical: 6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
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
                      ),
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

/* ---------- pretty category bar ---------- */

class _CategoryBar extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onTap;
  const _CategoryBar({
    required this.categories,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: categories.map((cat) {
            final bool active = cat == selected;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => onTap(cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: active
                        ? const LinearGradient(
                      colors: [AppColors.primary, Color(0xFF42A5F5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                        : null,
                    color: active
                        ? null
                        : (isDark ? const Color(0xFF2B2B2B) : const Color(0xFFEFF2F7)),
                    boxShadow: active
                        ? [
                      BoxShadow(
                        color: const Color(0xFF42A5F5).withValues(alpha: .25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ]
                        : null,
                    border: active
                        ? null
                        : Border.all(
                      color: isDark
                          ? Colors.white12
                          : const Color(0xFFE2E7F0),
                    ),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: active
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87),
                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/* ---------- empty state ---------- */

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.article_outlined,
                size: 56, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 10),
            Text(
              'No posts yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Pull down to refresh or try a different category.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
