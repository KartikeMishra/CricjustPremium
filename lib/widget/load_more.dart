import 'package:flutter/material.dart';
import '../theme/color.dart';

class LoadMoreArrow extends StatefulWidget {
  final VoidCallback onTap;
  final bool show;
  final Color iconColor; // ✅ New parameter

  const LoadMoreArrow({
    super.key,
    required this.onTap,
    this.show = false,
    this.iconColor = AppColors.primary, // ✅ Default to theme primary
  });

  @override
  State<LoadMoreArrow> createState() => _LoadMoreArrowState();
}

class _LoadMoreArrowState extends State<LoadMoreArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);

    _offsetAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.2, 0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.show) return const SizedBox.shrink();

    return InkWell(
      onTap: widget.onTap,
      child: Row(
        children: [
          Text(
            "Load More",
            style: TextStyle(
              color: widget.iconColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          SlideTransition(
            position: _offsetAnimation,
            child: Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: widget.iconColor,
            ),
          ),
        ],
      ),
    );
  }
}
