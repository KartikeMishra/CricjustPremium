import 'package:flutter/material.dart';
import '../theme/color.dart';

Widget buildCricjustFAB({
  required VoidCallback onPressed,
  IconData icon = Icons.add,
  String label = 'Add',
  required bool isDark,
}) {
  return FloatingActionButton.extended(
    backgroundColor: isDark ? Colors.grey[850] : AppColors.primary,
    foregroundColor: Colors.white,
    elevation: 6,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    icon: Icon(icon),
    label: Text(label),
    onPressed: onPressed,
  );
}
