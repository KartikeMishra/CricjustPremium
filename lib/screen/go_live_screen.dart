import 'dart:async';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CricJustApp());
}

class CricJustApp extends StatelessWidget {
  const CricJustApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CricJust Go Live',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.redAccent, useMaterial3: true),
      home: const GoLivePage(matchId: 351), // Pass your real match ID
    );
  }
}

class GoLivePage extends StatefulWidget {
  final int matchId;
  const GoLivePage({super.key, required this.matchId});

  @override
  State<GoLivePage> createState() => _GoLivePageState();
}

class _GoLivePageState extends State<GoLivePage> {
  static const String apiKey = "pxu05VOeYDRunxJ5bjG5";
  static const String baseUrl = "https://cricjust.in/wp-json/cricjust/v1/yt";
  static const String scoreUrl = "https://cricjust.in/custom-score/?match_id=MzU1";

  CameraController? _cam;
  WebViewController? _webCtrl;

  bool _busy = false;
  bool _live = false;
  String _status = "Ready";
  String? _broadcastId, _rtmpsUrl, _watchUrl;

  Timer? _timer, _refreshTimer;
  int _secondsElapsed = 0;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  // 🧠 Initialize
  Future<void> _boot() async {
    setState(() => _status = 'Requesting permissions…');
    await _askPermissions();

    setState(() => _status = 'Opening camera…');
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      final cam = CameraController(back, ResolutionPreset.high, enableAudio: true);
      await cam.initialize();
      _cam = cam;
      await WakelockPlus.enable();
      _status = 'Camera Ready ✅';
    } catch (e) {
      _status = 'Camera failed';
      _snack('Camera init failed: $e');
    }

    _initWebView();
    setState(() {});
  }

  Future<void> _askPermissions() async {
    final res = await [Permission.camera, Permission.microphone].request();
    if (res[Permission.camera]!.isDenied || res[Permission.microphone]!.isDenied) {
      _snack("Camera & Mic permission required.", error: true);
    }
  }

  void _initWebView() {
    _webCtrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(scoreUrl));
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _webCtrl?.runJavaScript("window.location.reload();");
    });
  }

  // 🚀 Start match stream via API
  Future<void> _startStream() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = 'Creating YouTube Stream…';
    });

    try {
      final res = await http.post(
        Uri.parse("$baseUrl/start-match"),
        headers: {
          "x-api-key": apiKey,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: {
          "matchId": widget.matchId.toString(),
          "privacy": "public",
          "latency": "ultraLow",
        },
      );

      final data = jsonDecode(res.body);
      debugPrint("Start API: ${res.body}");
      if (res.statusCode == 200 && (data["ok"] == true || data["success"] == true)) {
        _broadcastId = data["broadcastId"];
        _rtmpsUrl = data["rtmpsUrl"];
        _watchUrl = data["watchUrl"];
        _snack("✅ Stream created!");
        setState(() {
          _status = "YouTube Stream Created";
        });
        await _goLive();
      } else {
        _snack("Failed to start stream: ${data["message"] ?? res.body}", error: true);
      }
    } catch (e) {
      _snack("Error: $e", error: true);
    } finally {
      setState(() => _busy = false);
    }
  }

  // 🔴 Go live via API
  Future<void> _goLive() async {
    if (_broadcastId == null) return;
    setState(() => _status = "Going LIVE…");

    try {
      final res = await http.post(
        Uri.parse("$baseUrl/live-match"),
        headers: {
          "x-api-key": apiKey,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: {"broadcastId": _broadcastId!},
      );

      final data = jsonDecode(res.body);
      debugPrint("GoLive API: ${res.body}");
      if (res.statusCode == 200 && (data["ok"] == true || data["success"] == true)) {
        setState(() {
          _live = true;
          _status = "LIVE 🔴";
        });
        _startTimer();
        _snack("🚀 Live on YouTube!");
      } else {
        _snack("Live failed: ${data["message"] ?? res.body}", error: true);
      }
    } catch (e) {
      _snack("Error: $e", error: true);
    }
  }

  // 🛑 Stop stream via API
  Future<void> _stopStream() async {
    if (_broadcastId == null) return;
    setState(() {
      _busy = true;
      _status = 'Stopping…';
    });

    try {
      final res = await http.post(
        Uri.parse("$baseUrl/stop-match"),
        headers: {
          "x-api-key": apiKey,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: {"broadcastId": _broadcastId!},
      );
      debugPrint("Stop API: ${res.body}");
      _snack("🛑 Stream stopped");
      setState(() {
        _live = false;
        _status = "Stopped 🟥";
      });
    } catch (e) {
      _snack("Stop error: $e", error: true);
    } finally {
      setState(() => _busy = false);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsElapsed = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _secondsElapsed++);
    });
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.redAccent : Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _cam?.dispose();
    _timer?.cancel();
    _refreshTimer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cam = _cam;

    return Scaffold(
      appBar: AppBar(
        title: const Text("CricJust Go Live"),
        backgroundColor: Colors.redAccent,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // 🎥 Camera feed
          Positioned.fill(
            child: cam == null || !cam.value.isInitialized
                ? const Center(
                child: Text("📸 Initializing camera...", style: TextStyle(color: Colors.white70)))
                : CameraPreview(cam),
          ),

          // 🏏 CricJust score overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 100,
            child: _webCtrl == null
                ? const SizedBox()
                : ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: WebViewWidget(controller: _webCtrl!),
            ),
          ),

          // ⏱ Status
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Text(
              "🟢 $_status | ⏱ ${_secondsElapsed ~/ 60}:${(_secondsElapsed % 60).toString().padLeft(2, '0')}",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _live ? Colors.red : Colors.green,
        onPressed: _busy
            ? null
            : _live
            ? _stopStream
            : _startStream,
        label: Text(_live ? "Stop Live" : "Start Live"),
        icon: Icon(_live ? Icons.stop : Icons.videocam),
      ),
    );
  }
}
