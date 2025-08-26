import 'package:flutter/material.dart';

AppBar buildDarkAppBar(String title, {List<Widget>? actions}) {
  return AppBar(
    title: Text(title, style: const TextStyle(color: Colors.white)),
    centerTitle: true,
    backgroundColor: const Color(0xFF1E1E1E),
    elevation: 2,
    actions: actions,
    iconTheme: const IconThemeData(color: Colors.white),
  );
}
