// lib/screen/splash_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/color.dart'; // for AppColors.primary
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward();

  late final Animation<double> _fade =
  CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  late final Animation<double> _scale = Tween(begin: .94, end: 1.0).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
  );
  late final Animation<Offset> _slide =
  Tween(begin: const Offset(0, .08), end: Offset.zero).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
  );

  @override
  void initState() {
    super.initState();
    _precache();
    _navigateToHome();
  }

  void _precache() {
    // Preload images to avoid first-frame jank
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(
        const AssetImage('lib/asset/images/cricjust_logo.png'),
        context,
      );
      precacheImage(
        const AssetImage('lib/asset/images/Theme1.png'),
        context,
      );
    });
  }

  Future<void> _navigateToHome() async {
    // Keep the splash just long enough to feel intentional
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Animated gradient + soft glow graphics (very light on GPU)
  Widget _buildBackground(bool isDark) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value; // 0..1
        // Sweep the gradient origin subtly for a premium feel
        final begin = Alignment(-1 + 2 * t, -1);
        final end = Alignment(1 - 2 * t, 1);

        final colors = isDark
            ? const [Color(0xFF0E1A24), Color(0xFF0F2740)]
            : const [AppColors.primary, Color(0xFF42A5F5)];

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: begin,
              end: end,
              colors: colors,
            ),
          ),
          child: Stack(
            children: [
              // Soft radial glow circles — cheap “graphics”
              const _GlowCircle(
                left: -120,
                top: -80,
                size: 240,
                color: Color(0x33FFFFFF),
              ),
              const _GlowCircle(
                right: -80,
                bottom: -60,
                size: 260,
                color: Color(0x22FFFFFF),
              ),
              // A thin angled light streak
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _LightStreakPainter(
                      opacity: isDark ? 0.05 : 0.08,
                      angle: lerpDouble(18, -12, t)!,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logoPath = isDark
        ? 'lib/asset/images/Theme1.png' // your dark logo
        : 'lib/asset/images/cricjust_logo.png';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light, // white status bar icons
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            _buildBackground(isDark),
            // Foreground content
            Center(
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: ScaleTransition(
                    scale: _scale,
                    child: RepaintBoundary(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo with subtle glow
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.10),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.10),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              logoPath,
                              height: 110,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Gradient brand text
                          ShaderMask(
                            shaderCallback: (r) => const LinearGradient(
                              colors: [Colors.white, Color(0xFFE3F2FD)],
                            ).createShader(r),
                            child: const Text(
                              'Welcome to Cricjust',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white, // masked
                                letterSpacing: .2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          // Lightweight progress bar (cheaper than an indeterminate spinner)
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 1400),
                            curve: Curves.easeInOutCubic,
                            builder: (context, v, _) {
                              return Container(
                                width: 180,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: v,
                                  child: Container(
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Optional version/text at bottom (super light)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: 0.6,
                child: Text(
                  'Loading…',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Lightweight “graphics” helpers ----------

class _GlowCircle extends StatelessWidget {
  final double size;
  final double? left, top, right, bottom;
  final Color color;
  const _GlowCircle({
    required this.size,
    this.left,
    this.top,
    this.right,
    this.bottom,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: size * 0.6,
              spreadRadius: size * 0.30,
            ),
          ],
        ),
      ),
    );
  }
}

class _LightStreakPainter extends CustomPainter {
  final double opacity;
  final double angle; // degrees
  const _LightStreakPainter({required this.opacity, required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Colors.white24, Colors.white10, Colors.transparent],
        stops: [0, 0.5, 1],
      ).createShader(Offset.zero & size)
      ..blendMode = BlendMode.plus
      ..isAntiAlias = true;

    // Draw a thin rotated rectangle as a gentle streak
    final rect = Rect.fromLTWH(0, size.height * 0.25, size.width, 8);
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(angle * math.pi / 180.0);
    canvas.translate(-size.width / 2, -size.height / 2);
    paint.color = paint.color.withValues(alpha: opacity);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LightStreakPainter oldDelegate) {
    return oldDelegate.opacity != opacity || oldDelegate.angle != angle;
  }
}
