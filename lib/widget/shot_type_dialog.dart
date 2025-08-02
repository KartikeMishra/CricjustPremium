import 'package:flutter/material.dart';

Future<Map<String, String>?> showShotTypeDialog(
    BuildContext context,
    String batterName,
    int run,
    ) {
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ShotTypePickerUI(batterName: batterName, run: run),
  );
}

class ShotTypePickerUI extends StatefulWidget {
  final String batterName;
  final int run;

  const ShotTypePickerUI({
    super.key,
    required this.batterName,
    required this.run,
  });

  @override
  State<ShotTypePickerUI> createState() => _ShotTypePickerUIState();
}

class _ShotTypePickerUIState extends State<ShotTypePickerUI> {
  String? _selectedShot;
  String? _selectedZone;

  void _submit() {
    Navigator.pop(context, {
      'shot': _selectedShot ?? '',
      'shot_area': _selectedZone ?? '',
    });
  }

  void _selectShot(String shot) {
    setState(() => _selectedShot = shot);
  }

  void _selectZone(String zone) {
    setState(() => _selectedZone = zone);
  }

  static const _groundZones = <_Zone>[
    _Zone('Long Off', Alignment.topCenter, Icons.north),
    _Zone('Cover', Alignment.topRight, Icons.north_east),
    _Zone('Point', Alignment.centerRight, Icons.east),
    _Zone('Third Man', Alignment.bottomRight, Icons.south_east),
    _Zone('Fine Leg', Alignment.bottomCenter, Icons.south),
    _Zone('Square Leg', Alignment.bottomLeft, Icons.south_west),
    _Zone('Mid Wicket', Alignment.centerLeft, Icons.west),
    _Zone('Long On', Alignment.topLeft, Icons.north_west),
  ];

  static const _topShots = [
    _Shot('Straight Drive', Icons.straight),
    _Shot('Cover Drive', Icons.trending_up),
    _Shot('Lofted On Drive', Icons.flight),
  ];

  static const _sideShots = [
    _Shot('Cut', Icons.cut),
    _Shot('Late Cut', Icons.timelapse),
    _Shot('Square Drive', Icons.crop_square),
    _Shot('Upper Cut', Icons.arrow_upward),
  ];

  static const _bottomShots = [
    _Shot('Pull', Icons.swap_vert),
    _Shot('Hook', Icons.rotate_left),
    _Shot('Sweep', Icons.swipe),
    _Shot('Reverse Sweep', Icons.undo),
    _Shot('Slog Sweep', Icons.bolt),
    _Shot('Helicopter', Icons.refresh),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: const [BoxShadow(blurRadius: 16, color: Colors.black26)],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _header(context, isDark),
              const SizedBox(height: 12),
              _groundField(isDark),
              const SizedBox(height: 18),
              _groupedRow('Top Shots', _topShots, isDark),
              _groupedRow('Side Shots', _sideShots, isDark),
              _groupedRow('Bottom Shots', _bottomShots, isDark),
              const SizedBox(height: 20),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.close, color: Colors.grey),
          onPressed: () => Navigator.pop(context),
        ),
        Column(
          children: [
            Text(
              widget.batterName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            Text(
              '${widget.run} Run${widget.run == 1 ? '' : 's'}',
              style: const TextStyle(
                color: Colors.teal,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, {
            'shot': '',
            'shot_area': '',
          }),
          child: const Text('Skip'),
        ),
      ],
    );
  }

  Widget _groundField(bool isDark) {
    return SizedBox(
      height: 280,
      width: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _fieldCircle(isDark),
          _pitch(),
          ..._groundZones.map((z) => _zoneButton(z, isDark)),
        ],
      ),
    );
  }

  Widget _fieldCircle(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: isDark
              ? [Colors.green.shade800, Colors.green.shade900]
              : [Colors.green.shade300, Colors.green.shade700],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
          )
        ],
      ),
    );
  }

  Widget _pitch() {
    return Container(
      width: 12,
      height: 90,
      decoration: BoxDecoration(
        color: Colors.yellow[700],
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
    );
  }

  Widget _zoneButton(_Zone zone, bool isDark) {
    final isSelected = _selectedZone == zone.label;
    return Align(
      alignment: zone.alignment,
      child: GestureDetector(
        onTap: () => _selectZone(zone.label),
        child: Container(
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.blueAccent
                : (isDark ? Colors.grey[850] : Colors.white)?.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
            border: Border.all(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(zone.icon, size: 14, color: isDark ? Colors.white70 : Colors.black87),
              const SizedBox(width: 4),
              Text(
                zone.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupedRow(String title, List<_Shot> shots, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.grey[300] : Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: shots
              .map((shot) => GestureDetector(
            onTap: () => _selectShot(shot.label),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [Colors.grey.shade900, Colors.grey.shade800]
                      : [Colors.grey.shade100, Colors.white],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
                border: Border.all(
                  color: _selectedShot == shot.label ? Colors.blue : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(shot.icon, size: 14, color: isDark ? Colors.white : Colors.black87),
                  const SizedBox(width: 4),
                  Text(
                    shot.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ))
              .toList(),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildSubmitButton() {
    final isReady = _selectedShot != null && _selectedZone != null;
    return isReady
        ? ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      icon: const Icon(Icons.check_circle_outline),
      label: const Text("Submit Shot & Area"),
      onPressed: _submit,
    )
        : const Text(
      "Select a shot and a zone to continue",
      style: TextStyle(color: Colors.grey),
    );
  }
}

class _Zone {
  final String label;
  final Alignment alignment;
  final IconData icon;
  const _Zone(this.label, this.alignment, this.icon);
}

class _Shot {
  final String label;
  final IconData icon;
  const _Shot(this.label, this.icon);
}
