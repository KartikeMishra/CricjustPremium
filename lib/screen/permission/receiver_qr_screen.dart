import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

// 🔹 Reusable visuals (MeshBackdrop, GlassPanel, CardAuroraOverlay, WatermarkIcon)
import 'package:cricjust_premium/screen/ui_graphics.dart';

import '../../utils/qr_payload.dart';

class ReceiverQrScreen extends StatelessWidget {
  final String phone; // pass from your session/user profile
  final String? name;
  const ReceiverQrScreen({super.key, required this.phone, this.name});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final payload = ReceiverQrPayload(phone: phone, name: name).encode();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1115) : const Color(0xFFF6F9FC),

      // ✅ Rounded, gradient header to match FullMatchDetail
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 8),
        child: Container(
          decoration: isDark
              ? const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          )
              : const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            leading: const BackButton(color: Colors.white),
            title: const Text('My Receive QR',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ),
      ),

      body: Stack(
        children: [
          const MeshBackdrop(), // 🌫️ soft background

          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // ---------- QR Card ----------
              GlassPanel(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                lightGradient: const LinearGradient(
                  colors: [Color(0xFFFFFFFF), Color(0xFFF7FBFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                darkColor: const Color(0xFF15171B),
                child: Stack(
                  children: [
                    const Positioned.fill(child: CardAuroraOverlay()),
                    const Positioned(
                      right: -6,
                      bottom: -6,
                      child: WatermarkIcon(
                        icon: Icons.qr_code_2_rounded,
                        size: 120,
                        opacity: 0.06,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // subtle label
                        Text(
                          'Show this QR to the sender',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Always give a white tile behind the QR for contrast
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(blurRadius: 10, color: Colors.black12, offset: Offset(0, 3)),
                              ],
                            ),
                            child: LayoutBuilder(
                              builder: (context, c) {
                                final size = math.min(c.maxWidth, 320.0) * 0.8; // responsive, max ~256
                                return QrImageView(
                                  data: payload.isEmpty ? 'cjp:test' : payload, // fallback if ever empty
                                  version: QrVersions.auto,
                                  size: size.clamp(200.0, 280.0),
                                  backgroundColor: Colors.white, // ✅ key: avoid transparent on dark bg
                                  errorStateBuilder: (context, err) => SizedBox(
                                    width: size,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.error_outline, color: Colors.red),
                                        const SizedBox(height: 8),
                                        Text('QR error: $err', textAlign: TextAlign.center),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // name / phone
                        Text(
                          (name?.trim().isNotEmpty ?? false) ? name!.trim() : '—',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          phone,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ---------- Info & Tips ----------
              GlassPanel(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                lightGradient: const LinearGradient(
                  colors: [Color(0xFFF9FBFF), Color(0xFFFFFFFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                darkColor: const Color(0xFF15171B),
                child: Stack(
                  children: [
                    const Positioned.fill(child: CardAuroraOverlay()),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.blue).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: isDark ? Colors.white70 : Colors.blue.shade800,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Ask the sender to scan this code to grant you match/team permissions.',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Optional: tiny helper row (copy/share stubs – no extra deps)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _miniAction(
                    context,
                    icon: Icons.copy_rounded,
                    label: 'Copy Phone',
                    onTap: () => _copyText(context, phone),
                  ),
                  const SizedBox(width: 12),
                  _miniAction(
                    context,
                    icon: Icons.share_rounded,
                    label: 'Share',
                    onTap: () => _shareHint(context),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniAction(BuildContext context,
      {required IconData icon, required String label, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isDark ? Colors.white70 : Colors.black87),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.black87,
                )),
          ],
        ),
      ),
    );
  }

  void _copyText(BuildContext context, String text) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied!')),
    );
    // Clipboard.setData(ClipboardData(text: text)); // uncomment if you’ve imported services.dart
  }

  void _shareHint(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Implement share with share_plus if needed.')),
    );
  }
}
