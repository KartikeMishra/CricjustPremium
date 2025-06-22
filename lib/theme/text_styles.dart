import 'package:flutter/material.dart';
import 'color.dart';

class AppTextStyles {
  static const sectionTitle = TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
  static const matchTitle = TextStyle(fontSize: 14, fontWeight: FontWeight.bold);
  static const tournamentName = TextStyle(fontSize: 12, color: AppColors.textSecondary);
  static const teamName = TextStyle(fontWeight: FontWeight.w500, fontSize: 13);
  static const score = TextStyle(fontWeight: FontWeight.bold, fontSize: 13);
  static const result = TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.green);
  static const venue = TextStyle(fontSize: 12, color: AppColors.textSecondary);
  static const timeLeft = TextStyle(fontSize: 12, color: AppColors.warning);

  static const heading = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Colors.black,
  );

  static const caption = TextStyle(
    fontSize: 13,
    color: AppColors.textSecondary,
  );

  static const appBarTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  // ✅ Added for full_match_detail.dart
  static const label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const bodySmall = TextStyle(
    fontSize: 12,
    color: Colors.black87,
  );

  static const bodyMedium = TextStyle(
    fontSize: 14,
    color: Colors.black,
  );

  static const bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );
}
