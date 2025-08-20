// lib/widget/home_graphics.dart
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/color.dart';

/// 1) Aurora-style flowing blobs (soft, premium look)
class AuroraBackdrop extends StatefulWidget {
  const AuroraBackdrop({super.key, this.intensity = 0.9});
  final double intensity; // 0..1
  @override
  State<AuroraBackdrop> createState() => _AuroraBackdropState();
}

class _AuroraBackdropState extends State<AuroraBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 18))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      ignoring: true,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(
            painter: _AuroraPainter(
              t: _c.value,
              dark: isDark,
              intensity: widget.intensity,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double t;
  final bool dark;
  final double intensity;
  _AuroraPainter({required this.t, required this.dark, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    // base gradient background
    final bg = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? const [Color(0xFF0E0E10), Color(0xFF191B22)]
            : const [Color(0xFFF4F8FF), Color(0xFFEFF5FF)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    // blob colors (blend your brand)
    final c1 = AppColors.primary.withOpacity(0.25 * intensity);
    final c2 = const Color(0xFF42A5F5).withOpacity(0.22 * intensity);
    final c3 = const Color(0xFF00E5FF).withOpacity(0.18 * intensity);
    final c4 = const Color(0xFFFF8A65).withOpacity(0.12 * intensity);

    // positions animate in lissajous-ish paths
    Offset lp(double a, double b, double rX, double rY) {
      final x = size.width * (0.5 + rX * math.sin(2 * math.pi * (t + a)));
      final y = size.height * (0.5 + rY * math.cos(2 * math.pi * (t + b)));
      return Offset(x, y);
    }

    void blob(Offset center, double radius, List<Color> colors) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final paint = Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60)
        ..shader = RadialGradient(
          colors: colors,
          stops: const [0.0, 0.6, 1.0],
        ).createShader(rect);
      canvas.drawCircle(center, radius, paint);
    }

    blob(lp(0.00, 0.25, 0.30, 0.22), size.shortestSide * 0.55,
        [c1, c1.withOpacity(0.02), Colors.transparent]);
    blob(lp(0.35, 0.05, 0.28, 0.18), size.shortestSide * 0.48,
        [c2, c2.withOpacity(0.02), Colors.transparent]);
    blob(lp(0.60, 0.70, 0.26, 0.30), size.shortestSide * 0.50,
        [c3, c3.withOpacity(0.02), Colors.transparent]);
    blob(lp(0.88, 0.40, 0.22, 0.26), size.shortestSide * 0.44,
        [c4, c4.withOpacity(0.02), Colors.transparent]);

    // subtle vignette for depth
    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.2,
        colors: [
          Colors.transparent,
          (dark ? Colors.black : Colors.black87).withOpacity(0.06),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) =>
      old.t != t || old.dark != dark || old.intensity != intensity;
}

/// 2) Mesh / candy gradient backdrop (static but classy; very light on CPU)
class MeshGradientBackdrop extends StatelessWidget {
  const MeshGradientBackdrop({super.key});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      ignoring: true,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _MeshPainter(dark: dark),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _MeshPainter extends CustomPainter {
  final bool dark;
  _MeshPainter({required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = LinearGradient(
        colors: dark
            ? const [Color(0xFF121212), Color(0xFF171B22)]
            : const [Color(0xFFF7FAFF), Color(0xFFEFF4FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    void softCircle(Offset c, double r, Color color) {
      final rect = Rect.fromCircle(center: c, radius: r);
      final p = Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50)
        ..shader = RadialGradient(
          colors: [color.withOpacity(0.15), Colors.transparent],
        ).createShader(rect);
      canvas.drawCircle(c, r, p);
    }

    final p = AppColors.primary;
    softCircle(Offset(size.width * 0.25, size.height * 0.20),
        size.shortestSide * 0.36, p);
    softCircle(Offset(size.width * 0.85, size.height * 0.18),
        size.shortestSide * 0.30, const Color(0xFF42A5F5));
    softCircle(Offset(size.width * 0.70, size.height * 0.78),
        size.shortestSide * 0.38, const Color(0xFF00E5FF));
    softCircle(Offset(size.width * 0.18, size.height * 0.75),
        size.shortestSide * 0.34, const Color(0xFFFF8A65));
  }

  @override
  bool shouldRepaint(covariant _MeshPainter oldDelegate) =>
      oldDelegate.dark != dark;
}

/// 3) Floating particles (very subtle movement) — FIXED: no context.size in tick
class ParticlesBackdrop extends StatefulWidget {
  const ParticlesBackdrop({super.key, this.count = 36});
  final int count;
  @override
  State<ParticlesBackdrop> createState() => _ParticlesBackdropState();
}

class _ParticlesBackdropState extends State<ParticlesBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Particle> _ps = List.generate(widget.count, (_) => _Particle.zero());
  late final math.Random _rng = math.Random();

  // Cached layout bounds, updated by LayoutBuilder
  Size _bounds = const Size(400, 800);

  @override
  void initState() {
    super.initState();
    // seed with default bounds; will be updated after first layout
    for (final p in _ps) {
      p.reset(_rng, _bounds);
    }
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 16))
      ..addListener(_tick)
      ..repeat();
  }

  void _tick() {
    for (final p in _ps) {
      p.y -= p.vy;
      p.x += p.vx;
      p.life -= 0.003;
      if (p.life <= 0 || p.y < -20) p.reset(_rng, _bounds);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth.isFinite ? constraints.maxWidth : _bounds.width;
          final h = constraints.maxHeight.isFinite ? constraints.maxHeight : _bounds.height;
          _bounds = Size(w, h); // safe to cache without setState
          return CustomPaint(
            painter: _ParticlesPainter(_ps, dark),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _Particle {
  double x = 0, y = 0, r = 0, vx = 0, vy = 0, life = 1;
  Color color = Colors.white24;
  _Particle.zero();
  void reset(math.Random rng, Size bounds) {
    final w = bounds.width;
    final h = bounds.height;
    x = rng.nextDouble() * w;
    y = h + rng.nextDouble() * 80;
    r = 1.5 + rng.nextDouble() * 2.2;
    vx = (rng.nextDouble() - 0.5) * 0.25;
    vy = 0.3 + rng.nextDouble() * 0.6;
    life = 0.7 + rng.nextDouble() * 0.6;
    color = Colors.white.withOpacity(0.06 + rng.nextDouble() * 0.10);
  }
}

class _ParticlesPainter extends CustomPainter {
  final List<_Particle> ps;
  final bool dark;
  _ParticlesPainter(this.ps, this.dark);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;
    for (final e in ps) {
      p.color = dark ? e.color : e.color.withOpacity(e.color.opacity * 0.8);
      canvas.drawCircle(Offset(e.x, e.y), e.r, p);
    }
  }
  @override
  bool shouldRepaint(covariant _ParticlesPainter old) => true;
}

/// 4) Stadium header ribbon (top curved image + gradient overlay)
class StadiumHeaderBackdrop extends StatelessWidget {
  const StadiumHeaderBackdrop(
      {super.key, this.assetPath = 'lib/asset/images/stadium_header.jpg'});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: ClipPath(
          clipper: _HeaderClipper(),
          child: SizedBox(
            height: 220,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  assetPath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? const [Color(0xFF111318), Color(0xFF1B1E26)]
                            : const [Color(0xFFE8F0FF), Color(0xFFDDEAFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.60),
                        const Color(0xFF42A5F5).withOpacity(0.35),
                        Colors.transparent
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 0.5, sigmaY: 0.5),
                  child: Container(color: Colors.transparent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final p = Path()..lineTo(0, size.height - 60);
    final ctl = Offset(size.width * 0.5, size.height + 40);
    final end = Offset(size.width, size.height - 60);
    p.quadraticBezierTo(ctl.dx, ctl.dy, end.dx, end.dy);
    p.lineTo(size.width, 0);
    p.close();
    return p;
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// 5) Wrapper: easy plug-in for HomeScreen
class HomeGraphicBackdrop extends StatelessWidget {
  /// If false, we render only the static mesh (no CPU-heavy animations)
  final bool animated;
  /// Show the sporty top ribbon (good for Home tab only)
  final bool showStadium;
  /// Particle count when animated=true
  final int particles;

  const HomeGraphicBackdrop({
    super.key,
    this.animated = true,
    this.showStadium = true,
    this.particles = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ultra-light static base
        const MeshGradientBackdrop(),

        // premium animated layer (paused via TickerMode when animated=false)
        TickerMode(
          enabled: animated,
          child: const AuroraBackdrop(intensity: 0.95),
        ),

        // subtle floaters
        if (animated)
          TickerMode(
            enabled: animated,
            child: ParticlesBackdrop(count: particles),
          ),

        // sporty header ribbon on top
        if (showStadium) const StadiumHeaderBackdrop(),
      ],
    );
  }
}
