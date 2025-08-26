import 'package:flutter/material.dart';
import 'color.dart';

class AppTextStyles {
  // Section & Headers
  static const sectionTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );
  static const heading = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Colors.black,
  );
  static const appBarTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  // Match & Tournament Info
  static const matchTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
  );
  static const tournamentName = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );
  static const teamName = TextStyle(fontSize: 13, fontWeight: FontWeight.w500);
  static const score = TextStyle(fontSize: 13, fontWeight: FontWeight.bold);
  static const result = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.bold,
    color: AppColors.green,
  );
  static const venue = TextStyle(fontSize: 12, color: AppColors.textSecondary);
  static const timeLeft = TextStyle(fontSize: 12, color: AppColors.warning);

  // Captions & Labels
  static const caption = TextStyle(
    fontSize: 13,
    color: AppColors.textSecondary,
  );
  static const label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  // Body Texts
  static const bodySmall = TextStyle(fontSize: 12, color: Colors.black87);
  static const bodyMedium = TextStyle(fontSize: 14, color: Colors.black);
  static const bodyLarge = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);

  // Optional: Add error, success, and disabled text styles
  static const error = TextStyle(fontSize: 13, color: Colors.red);
  static const success = TextStyle(fontSize: 13, color: Colors.green);
  static const disabled = TextStyle(fontSize: 13, color: Colors.grey);
}
