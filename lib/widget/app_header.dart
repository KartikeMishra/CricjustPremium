import 'package:flutter/material.dart';
import '../theme/color.dart'; // AppColors.primary

/// Reusable gradient/dark AppBar with rounded bottom and shadow.
/// Use it as: appBar: const AppHeader(title: 'Home')
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final double height;

  const AppHeader({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.height = 64,
  });

  BoxDecoration _barDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? const BoxDecoration(
      color: Color(0xFF1E1E1E),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
    )
        : BoxDecoration(
      gradient: LinearGradient(
        colors: [AppColors.primary, const Color(0xFF42A5F5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x3D2196F3),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _barDecoration(context),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: leading,
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: actions,
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(height);
}
