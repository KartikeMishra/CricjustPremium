import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class YoutubeWebView extends StatefulWidget {
  final String videoId;

  const YoutubeWebView({super.key, required this.videoId});

  @override
  State<YoutubeWebView> createState() => _YoutubeWebViewState();
}

class _YoutubeWebViewState extends State<YoutubeWebView> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)

    /// 🔥 IMPORTANT (browser जैसा बनाओ)
      ..setUserAgent(
        "Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 "
            "(KHTML, like Gecko) Chrome/99.0.4844.94 Mobile Safari/537.36",
      )

      ..loadRequest(
        Uri.parse(
          "https://www.youtube.com/embed/${widget.videoId}?playsinline=1&rel=0",
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: WebViewWidget(controller: controller),
      ),
    );
  }
}