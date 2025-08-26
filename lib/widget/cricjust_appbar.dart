import 'package:flutter/material.dart';
import '../theme/color.dart';

AppBar buildCricjustAppBar(
  String title, {
  PreferredSizeWidget? bottom,
  Color? backgroundColor,
  Color? titleColor,
  Color? iconColor,
}) {
  return AppBar(
    title: Text(
      title,
      style: TextStyle(
        color: titleColor ?? Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    ),
    backgroundColor: backgroundColor ?? AppColors.primary,
    centerTitle: true,
    elevation: 0.5,
    iconTheme: IconThemeData(color: iconColor ?? Colors.white),
    bottom: bottom,
  );
}
