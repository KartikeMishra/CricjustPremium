import 'package:flutter/material.dart';
import '../theme/color.dart';
import 'all_matches_screen.dart';

class MatchScreen extends StatelessWidget {
  const MatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor:
        isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF4F6FA),

        // Solid (opaque) segmented TabBar — no transparency
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kTextTabBarHeight + 16),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.hardEdge,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: TabBar(
                    isScrollable: true,
                    dividerColor: Colors.transparent,
                    overlayColor:
                    WidgetStateProperty.all(Colors.transparent),

                    indicatorPadding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: const ShapeDecoration(
                      color: Colors.white,
                      shape: StadiumBorder(),
                      shadows: [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),

                    labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                    labelColor: AppColors.primary,
                    unselectedLabelColor:
                    isDark ? Colors.white70 : Colors.black54,
                    labelStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),

                    tabs: const [
                      Tab(text: 'Live'),
                      Tab(text: 'Upcoming'),
                      Tab(text: 'Recent'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        body: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: TabBarView(
            children: [
              AllMatchesScreen(matchType: 'live'),
              AllMatchesScreen(matchType: 'upcoming'),
              AllMatchesScreen(matchType: 'recent'),
            ],
          ),
        ),
      ),
    );
  }
}
