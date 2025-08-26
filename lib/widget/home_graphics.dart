import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/color.dart';

class HomeGraphicBackdrop extends StatefulWidget {
  final bool animate; // turn animation on/off
  const HomeGraphicBackdrop({super.key, this.animate = true});

  @override
  State<HomeGraphicBackdrop> createState() => _HomeGraphicBackdropState();
}

class _HomeGraphicBackdropState extends State<HomeGraphicBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  int _lastMarkMs = 0;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..addListener(_throttledTick);
    if (widget.animate) _c.repeat();
  }

  @override
  void didUpdateWidget(HomeGraphicBackdrop old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.animate && _c.isAnimating) {
      _c.stop(canceled: false);
    }
  }

  void _throttledTick() {
    // ~8 fps is plenty for a soft background
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastMarkMs >= 120) {
      _lastMarkMs = now;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = widget.animate ? _c.value : 0.0;

    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _AuroraPainter(
            t: t,
            isDark: isDark,
            colorA: AppColors.primary,
            colorB: const Color(0xFF42A5F5),
          ),
          isComplex: true,
          willChange: widget.animate,
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double t;
  final bool isDark;
  final Color colorA, colorB;

  _AuroraPainter({
    required this.t,
    required this.isDark,
    required this.colorA,
    required this.colorB,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final bg = isDark ? const Color(0xFF0E1217) : const Color(0xFFF5F7FA);
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);

    // gentle moving blobs (no saveLayer, no blur filters)
    void blob(Color c, double cx, double cy, double r) {
      final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
      final grad = RadialGradient(
        colors: [c.withOpacity(isDark ? 0.22 : 0.18), Colors.transparent],
        stops: const [0.0, 1.0],
      );
      canvas.drawRect(
        rect.inflate(r),
        Paint()..shader = grad.createShader(rect),
      );
    }

    final s1 = 0.5 + 0.5 * math.sin(2 * math.pi * (t));
    final s2 = 0.5 + 0.5 * math.cos(2 * math.pi * (t * 0.9));
    final s3 = 0.5 + 0.5 * math.sin(2 * math.pi * (t * 0.7 + 0.3));

    blob(colorA, w * (0.15 + 0.1 * s1), h * (0.20 + 0.05 * s2), math.max(w, h) * 0.45);
    blob(colorB, w * (0.85 - 0.1 * s2), h * (0.30 + 0.07 * s3), math.max(w, h) * 0.42);
    blob(colorA, w * (0.50 + 0.12 * s3), h * (0.85 - 0.08 * s1), math.max(w, h) * 0.38);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) =>
      old.t != t || old.isDark != isDark || old.colorA != colorA || old.colorB != colorB;
}
