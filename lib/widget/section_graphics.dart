// lib/widget/section_graphics.dart
import 'package:flutter/material.dart';

/// ------------------------------------------------------------
/// LIVE badge: pulsing dot + subtle glow + optional custom text
/// ------------------------------------------------------------
class LiveBadge extends StatefulWidget {
  const LiveBadge({
    super.key,
    this.label = 'LIVE',
    this.color = Colors.redAccent,
    this.textStyle,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    this.onTap,
  });

  /// Text shown next to the dot
  final String label;

  /// Badge base color (also used for glow)
  final Color color;

  /// Optional text style override
  final TextStyle? textStyle;

  /// Outer padding for the capsule
  final EdgeInsetsGeometry padding;

  /// Optional tap (keeps semantics friendly)
  final VoidCallback? onTap;

  @override
  State<LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _pulse = CurvedAnimation(
    parent: _c,
    curve: Curves.easeInOut,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.color;
    final txt = widget.textStyle ??
        const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        );

    final capsule = Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .18)),
        boxShadow: [
          BoxShadow(
            color: bg.withValues(alpha: 0.35),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Glowing dot with animated outer ring
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) {
              final ringScale = 0.9 + (_pulse.value * 0.55);
              final ringOpacity = (1 - _pulse.value) * 0.35;
              return Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: ringScale,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: ringOpacity),
                      ),
                    ),
                  ),
                  ScaleTransition(
                    scale: Tween<double>(begin: 0.85, end: 1.15).animate(_pulse),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(width: 6),
          Text(widget.label, style: txt),
        ],
      ),
    );

    // Slight glass gloss over the capsule top (very subtle)
    final gloss = Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: .12),
                Colors.transparent,
              ],
              stops: const [0, .55],
            ),
          ),
        ),
      ),
    );

    final content = Stack(children: [capsule, gloss]);

    return Semantics(
      label: widget.label,
      button: widget.onTap != null,
      child: widget.onTap == null
          ? content
          : InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(20),
        child: content,
      ),
    );
  }
}

/// ------------------------------------------------------------
/// Soft radial highlights behind a card (subtle, theme-aware)
/// ------------------------------------------------------------
class CardAuroraOverlay extends StatelessWidget {
  const CardAuroraOverlay({
    super.key,
    this.intensity = 1.0,            // 0..1
    this.blendPlus = true,           // additive blend look
    this.spotA = const Offset(0.20, 0.22), // fractional positions
    this.spotB = const Offset(0.85, 0.78),
    this.radiusA = 120,
    this.radiusB = 140,
    this.colorA, // defaults based on theme
    this.colorB,
  });

  final double intensity;
  final bool blendPlus;
  final Offset spotA;
  final Offset spotB;
  final double radiusA;
  final double radiusB;
  final Color? colorA;
  final Color? colorB;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      ignoring: true,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _CardAuroraPainter(
            isDark: isDark,
            intensity: intensity,
            blendPlus: blendPlus,
            spotA: spotA,
            spotB: spotB,
            radiusA: radiusA,
            radiusB: radiusB,
            colorA: colorA,
            colorB: colorB,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _CardAuroraPainter extends CustomPainter {
  final bool isDark;
  final double intensity;
  final bool blendPlus;
  final Offset spotA;
  final Offset spotB;
  final double radiusA;
  final double radiusB;
  final Color? colorA;
  final Color? colorB;

  _CardAuroraPainter({
    required this.isDark,
    required this.intensity,
    required this.blendPlus,
    required this.spotA,
    required this.spotB,
    required this.radiusA,
    required this.radiusB,
    this.colorA,
    this.colorB,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final a = (colorA ??
        (isDark ? const Color(0xFF64B5F6) : const Color(0xFF2196F3)))
        .withValues(alpha: 0.22 * intensity);
    final b = (colorB ??
        (isDark ? const Color(0xFF00E5FF) : const Color(0xFF00BCD4)))
        .withValues(alpha: 0.20 * intensity);

    final rectA = Rect.fromCircle(
      center: Offset(size.width * spotA.dx, size.height * spotA.dy),
      radius: radiusA,
    );
    final rectB = Rect.fromCircle(
      center: Offset(size.width * spotB.dx, size.height * spotB.dy),
      radius: radiusB,
    );

    final pA = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40)
      ..shader = RadialGradient(colors: [a, Colors.transparent]).createShader(rectA);
    final pB = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 42)
      ..shader = RadialGradient(colors: [b, Colors.transparent]).createShader(rectB);

    if (blendPlus) {
      // Additive-ish blend for a premium glow
      canvas.saveLayer(Offset.zero & size, Paint()..blendMode = BlendMode.plus);
      canvas.drawCircle(rectA.center, radiusA, pA);
      canvas.drawCircle(rectB.center, radiusB, pB);
      canvas.restore();
    } else {
      canvas.drawCircle(rectA.center, radiusA, pA);
      canvas.drawCircle(rectB.center, radiusB, pB);
    }
  }

  @override
  bool shouldRepaint(covariant _CardAuroraPainter old) =>
      old.isDark != isDark ||
          old.intensity != intensity ||
          old.blendPlus != blendPlus ||
          old.spotA != spotA ||
          old.spotB != spotB ||
          old.radiusA != radiusA ||
          old.radiusB != radiusB ||
          old.colorA != colorA ||
          old.colorB != colorB;
}

/// ------------------------------------------------------------
/// Watermark icon (gradient fill + optional rotation)
/// ------------------------------------------------------------
class WatermarkIcon extends StatelessWidget {
  const WatermarkIcon({
    super.key,
    required this.icon,
    this.alignment = Alignment.bottomRight,
    this.size = 140,
    this.opacity = 0.06,
    this.gradient,
    this.angleDegrees = 0,
    this.padding = const EdgeInsets.all(8),
  });

  /// The big icon to paint (e.g. Icons.emoji_events_rounded)
  final IconData icon;

  /// Where to place it in the card
  final Alignment alignment;

  /// Icon size
  final double size;

  /// Overall opacity (applied after gradient)
  final double opacity;

  /// Optional gradient fill. If null, uses theme-aware mono color.
  final Gradient? gradient;

  /// Optional rotation (for dynamic composition)
  final double angleDegrees;

  /// Padding around the icon
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final baseColor = (Theme.of(context).brightness == Brightness.dark)
        ? Colors.white
        : Colors.black;

    final iconWidget = Icon(
      icon,
      size: size,
      color: gradient == null ? baseColor.withValues(alpha: opacity) : Colors.white,
    );

    final rotated = angleDegrees == 0
        ? iconWidget
        : Transform.rotate(
      angle: angleDegrees * 3.1415926535 / 180.0,
      child: iconWidget,
    );

    final content = gradient == null
        ? rotated
        : ShaderMask(
      shaderCallback: (Rect r) =>
          gradient!.createShader(Offset.zero & r.size),
      blendMode: BlendMode.srcATop,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: rotated,
      ),
    );

    return IgnorePointer(
      ignoring: true,
      child: Align(
        alignment: alignment,
        child: Padding(padding: padding, child: content),
      ),
    );
  }
}
