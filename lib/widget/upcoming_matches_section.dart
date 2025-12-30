// lib/widget/upcoming_matches_section.dart
import 'package:flutter/material.dart';
import 'matches_section.dart';

class UpcomingMatchesSection extends StatefulWidget {
  final void Function(bool hasData)? onDataLoaded;
  const UpcomingMatchesSection({super.key, this.onDataLoaded});

  @override
  State<UpcomingMatchesSection> createState() => _UpcomingMatchesSectionState();
}

class _UpcomingMatchesSectionState extends State<UpcomingMatchesSection> {
  @override
  Widget build(BuildContext context) {
    return MatchesSection(
      mode: MatchesMode.upcoming,
      onDataLoaded: widget.onDataLoaded,
    );
  }
}
