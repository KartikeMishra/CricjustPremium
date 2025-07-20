import 'package:cricjust_premium/provider/match_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'model/offline_score_model.dart';
import 'screen/home_screen.dart';
import 'theme/theme_provider.dart';
import 'theme/theme_manager.dart';
import 'package:hive_flutter/hive_flutter.dart';

// 1️⃣ Declare a global RouteObserver:
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  final appDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDir.path);
  Hive.registerAdapter(OfflineScoreAdapter());

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
      // 2️⃣ Register the observer here:
      navigatorObservers: [routeObserver],
      home: const HomeScreen(),
    );
  }
}
