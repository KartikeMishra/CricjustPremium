// lib/widget/live_matches_section.dart
//
// Wrapper so your existing imports keep working.
// Uses the single consistent layout from matches_section.dart.

import 'package:flutter/material.dart';
import 'matches_section.dart';

class LiveMatchesSection extends StatelessWidget {
  final void Function(bool hasData)? onDataLoaded;

  const LiveMatchesSection({super.key, this.onDataLoaded});

  @override
  Widget build(BuildContext context) {
    return MatchesSection(
      mode: MatchesMode.live,
      onDataLoaded: onDataLoaded,
    );
  }
}
