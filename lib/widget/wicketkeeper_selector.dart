import 'package:flutter/material.dart';

class WicketKeeperSelector extends StatelessWidget {
  final String? keeperName;
  final VoidCallback onChange;

  const WicketKeeperSelector({
    super.key,
    required this.keeperName,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Text(
            'Wicketkeeper: ',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          if (keeperName != null)
            Text(keeperName!, style: const TextStyle(fontSize: 16))
          else
            const Text('Not selected',
                style: TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey)),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: onChange,
            icon: const Icon(Icons.switch_account),
            label: const Text('Change'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrangeAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}
