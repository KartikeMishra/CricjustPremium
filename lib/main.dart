import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'Screen/home_screen.dart';
import 'theme/theme_provider.dart';
import 'theme/theme_manager.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const CricjustApp(),
    ),
  );
}

class CricjustApp extends StatelessWidget {
  const CricjustApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'Cricjust',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const HomeScreen(),
    );
  }
}
