// lib/widget/recent_matches_section.dart
import 'package:flutter/material.dart';
import 'matches_section.dart';

class RecentMatchesSection extends StatefulWidget {
  final void Function(bool hasData)? onDataLoaded;
  const RecentMatchesSection({super.key, this.onDataLoaded});

  @override
  State<RecentMatchesSection> createState() => _RecentMatchesSectionState();
}

class _RecentMatchesSectionState extends State<RecentMatchesSection> {
  @override
  Widget build(BuildContext context) {
    return MatchesSection(
      mode: MatchesMode.recent,
      onDataLoaded: widget.onDataLoaded,
    );
  }
}
