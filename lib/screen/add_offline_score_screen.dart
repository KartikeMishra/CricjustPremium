// lib/screen/add_offline_score_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../model/offline_score_model.dart';
import '../theme/color.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class AddScoreScreen extends StatefulWidget {
  final int matchId;
  const AddScoreScreen({super.key, required this.matchId});

  @override
  State<AddScoreScreen> createState() => _AddScoreScreenState();
}

class _AddScoreScreenState extends State<AddScoreScreen> {
  int? onStrikePlayerId = 1;
  int? nonStrikePlayerId = 2;
  int? bowlerId = 3;
  int? battingTeamId = 101;
  int onStrikeOrder = 1;
  int nonStrikeOrder = 2;
  int overNumber = 1;
  int ballNumber = 1;
  int runs = 0;
  String? extraRunType;
  int? extraRun;
  bool isWicket = false;
  String? wicketType;
  final TextEditingController _commentaryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _listenToConnectivity();
  }

  void _listenToConnectivity() {
    Connectivity().onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none) {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('api_logged_in_token') ?? '';
        if (token.isNotEmpty) {
          await syncOfflineScores(token);
        }
      }
    });
  }

  Future<bool> _checkInternet() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  Future<void> _submitScore() async {
    final hasInternet = await _checkInternet();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_logged_in_token') ?? '';

    final score = OfflineScore(
      matchId: widget.matchId,
      battingTeamId: battingTeamId!,
      onStrikePlayerId: onStrikePlayerId!,
      onStrikeOrder: onStrikeOrder,
      nonStrikePlayerId: nonStrikePlayerId!,
      nonStrikeOrder: nonStrikeOrder,
      bowlerId: bowlerId!,
      overNumber: overNumber,
      ballNumber: ballNumber,
      runs: runs,
      extraRunType: extraRunType,
      extraRun: extraRun,
      isWicket: isWicket,
      wicketType: wicketType,
      commentary: _commentaryController.text,
    );

    if (hasInternet) {
      final success = await submitScoreToAPI(score, token);
      if (!success) {
        await saveOfflineScore(score);
        _showMessage("Saved offline due to API error");
      } else {
        _showMessage("Score submitted successfully");
      }
    } else {
      await saveOfflineScore(score);
      _showMessage("Offline: Saved locally, will sync later");
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.primary),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Score"),
        backgroundColor: AppColors.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _commentaryController,
              decoration: const InputDecoration(labelText: "Commentary"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitScore,
              child: const Text("Submit Score"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> saveOfflineScore(OfflineScore score) async {
    final box = await Hive.openBox('offline_scores');
    await box.add(score);
  }

  Future<bool> submitScoreToAPI(OfflineScore score, String token) async {
    final uri = Uri.parse(
      "https://cricjust.in/wp-json/custom-api-for-cricket/save-cricket-match-score",
    );
    try {
      final response = await http.post(uri, body: score.toJson(token));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['status'] == 1;
      }
    } catch (e) {
      print("❌ Error syncing score: $e");
    }
    return false;
  }

  Future<void> syncOfflineScores(String token) async {
    final box = await Hive.openBox('offline_scores');
    final scores = box.values.cast<OfflineScore>().toList();

    for (int i = 0; i < scores.length; i++) {
      final score = scores[i];
      final success = await submitScoreToAPI(score, token);
      if (success) {
        await box.deleteAt(i);
      } else {
        break;
      }
    }
  }
}
