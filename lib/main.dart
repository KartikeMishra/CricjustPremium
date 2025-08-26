import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'screen/home_screen.dart';
import 'screen/login_screen.dart';
import 'provider/match_state.dart';
import 'theme/theme_provider.dart';
import 'theme/theme_manager.dart';
import 'model/offline_ball_event.dart'; // ✅ Hive model import

// 1️⃣ Declare a global RouteObserver
final RouteObserver<ModalRoute<void>> routeObserver =
RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 2️⃣ Initialize Hive and register adapter
  final appDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDir.path);

  Hive.registerAdapter(OfflineBallEventAdapter()); // ✅ Register your adapter
  await Hive.openBox<OfflineBallEvent>('offline_scores'); // ✅ Open the box

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => MatchState()),
      ],
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
      routes: {
        '/login': (context) => const LoginScreen(),
      },
      navigatorObservers: [routeObserver],
      home: const HomeScreen(),
    );
  }
}
