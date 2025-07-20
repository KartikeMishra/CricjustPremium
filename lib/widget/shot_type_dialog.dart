import 'package:flutter/material.dart';

Future<String?> showShotTypeDialog(
  BuildContext context,
  String batterName,
  int run,
) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return ShotTypePickerUI(batterName: batterName, run: run);
    },
  );
}

class ShotTypePickerUI extends StatelessWidget {
  final String batterName;
  final int run;

  const ShotTypePickerUI({
    super.key,
    required this.batterName,
    required this.run,
  });

  void _selectShot(BuildContext context, String shot) {
    Navigator.pop(context, shot);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black12)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 🏏 Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context, null),
                child: const Icon(Icons.close, color: Colors.grey),
              ),
              Column(
                children: [
                  Text(
                    batterName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text('$run Run', style: const TextStyle(color: Colors.teal)),
                ],
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'SkipMatch'),
                    child: const Text('Skip Match'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'SkipBall'),
                    child: const Text('Skip Ball'),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 🧭 Field & Zones
          SizedBox(
            height: 320,
            width: 320,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Green circular field
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: Alignment.center,
                      colors: [Colors.green.shade300, Colors.green.shade900],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
                // Yellow pitch
                Container(
                  width: 10,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.yellow[700],
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4),
                    ],
                  ),
                ),

                // Shot Zones
                _buildShotZone(context, "Straight Drive", Alignment.topCenter),
                _buildShotZone(context, "Cover Drive", Alignment.topRight),
                _buildShotZone(context, "Point", Alignment.centerRight),
                _buildShotZone(context, "Third Man", Alignment.bottomRight),
                _buildShotZone(context, "Fine Leg", Alignment.bottomCenter),
                _buildShotZone(context, "Square Leg", Alignment.bottomLeft),
                _buildShotZone(context, "Mid Wicket", Alignment.centerLeft),
                _buildShotZone(context, "Long On", Alignment.topLeft),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShotZone(
    BuildContext context,
    String label,
    Alignment alignment,
  ) {
    return Align(
      alignment: alignment,
      child: GestureDetector(
        onTap: () => _selectShot(context, label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}
