// lib/screen/ui_graphics.dart
import 'dart:ui';
import 'package:flutter/material.dart';

/// ---------- Mesh backdrop (super cheap & safe as a page background) ----------
class MeshBackdrop extends StatelessWidget {
  const MeshBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      ignoring: true,
      child: CustomPaint(
        painter: _MeshPainter(dark: dark),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _MeshPainter extends CustomPainter {
  final bool dark;
  _MeshPainter({required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    // base
    final bg = Paint()
      ..shader = LinearGradient(
        colors: dark
            ? const [Color(0xFF121418), Color(0xFF171C23)]
            : const [Color(0xFFF5F9FF), Color(0xFFEFF5FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    void softCircle(Offset c, double r, Color color) {
      final rect = Rect.fromCircle(center: c, radius: r);
      final p = Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50)
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.16), Colors.transparent],
        ).createShader(rect);
      canvas.drawCircle(c, r, p);
    }

    softCircle(Offset(size.width*0.22, size.height*0.20), size.shortestSide*0.36, const Color(0xFF2196F3));
    softCircle(Offset(size.width*0.86, size.height*0.18), size.shortestSide*0.30, const Color(0xFF42A5F5));
    softCircle(Offset(size.width*0.72, size.height*0.80), size.shortestSide*0.40, const Color(0xFF00E5FF));
    softCircle(Offset(size.width*0.16, size.height*0.78), size.shortestSide*0.34, const Color(0xFFFF8A65));
  }

  @override
  bool shouldRepaint(covariant _MeshPainter old) => old.dark != dark;
}

/// ---------- Glass panel (rounded, blurred, gradient on light; flat on dark) ----------
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Gradient? lightGradient;
  final Color? darkColor;
  final BorderRadiusGeometry borderRadius;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.lightGradient,
    this.darkColor,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 8),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
          child: Container(
            decoration: BoxDecoration(
              gradient: isDark ? null : (lightGradient ?? _defaultLightGradient),
              color: isDark ? (darkColor ?? const Color(0xFF1E1E1E)) : null,
              border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
            ),
            padding: padding ?? const EdgeInsets.all(14),
            child: child,
          ),
        ),
      ),
    );
  }

  static const _defaultLightGradient = LinearGradient(
    colors: [Color(0xFFEAF4FF), Colors.white],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// ---------- Soft card highlights (subtle radial spots) ----------
class CardAuroraOverlay extends StatelessWidget {
  const CardAuroraOverlay({super.key});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      painter: _CardAuroraPainter(isDark: isDark),
      child: const SizedBox.expand(),
    );
  }
}

class _CardAuroraPainter extends CustomPainter {
  final bool isDark;
  _CardAuroraPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    void spot(Offset c, double r, Color c1) {
      final rect = Rect.fromCircle(center: c, radius: r);
      final p = Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40)
        ..shader = RadialGradient(
          colors: [c1.withValues(alpha: 0.22), Colors.transparent],
        ).createShader(rect);
      canvas.drawCircle(c, r, p);
    }
    final a = isDark ? const Color(0xFF64B5F6) : const Color(0xFF2196F3);
    final b = isDark ? const Color(0xFF00E5FF) : const Color(0xFF00BCD4);
    spot(Offset(size.width*0.22, size.height*0.25), 120, a);
    spot(Offset(size.width*0.85, size.height*0.78), 140, b);
  }

  @override
  bool shouldRepaint(covariant _CardAuroraPainter old) => old.isDark != isDark;
}

/// ---------- Watermark icon for big faint background emblem ----------
class WatermarkIcon extends StatelessWidget {
  final IconData icon;
  final Alignment alignment;
  final double size;
  final double opacity;

  const WatermarkIcon({
    super.key,
    required this.icon,
    this.alignment = Alignment.bottomRight,
    this.size = 140,
    this.opacity = 0.06,
  });

  @override
  Widget build(BuildContext context) {
    final color = (Theme.of(context).brightness == Brightness.dark)
        ? Colors.white
        : Colors.black;
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(icon, size: size, color: color.withValues(alpha: opacity)),
      ),
    );
  }
}

/// ---------- Small decorative divider line ----------
class FancyDivider extends StatelessWidget {
  const FancyDivider({super.key});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [Colors.white12, Colors.white30, Colors.white12]
              : [Colors.black12, Colors.black26, Colors.black12],
        ),
      ),
    );
  }
}
