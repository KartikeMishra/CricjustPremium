import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../model/tournament_overview_model.dart';
import '../../model/fair_play_model.dart';
import '../../service/tournament_service.dart';
import '../widget/points_table.dart';
import '../widget/fair_play.dart';
import '../../theme/text_styles.dart';

const String _kBase = 'https://cricjust.in';
const String _kPlaceholder = 'lib/asset/images/cricjust_logo.png';
class TournamentOverviewScreen extends StatefulWidget {
  final int tournamentId;

  const TournamentOverviewScreen({super.key, required this.tournamentId});

  @override
  State<TournamentOverviewScreen> createState() =>
      _TournamentOverviewScreenState();
}

class _TournamentOverviewScreenState extends State<TournamentOverviewScreen> {
  // ---------- SAFE IMAGE HELPERS ----------
  // Add at the top of the file


  bool _isBadUrl(String? s) {
    if (s == null) return true;
    final t = s.trim();
    if (t.isEmpty || t == 'null' || t == 'N/A') return true;
    final low = t.toLowerCase();
    return low.startsWith('file:') ||
        low.startsWith('file:///') ||
        low.startsWith('content:') ||
        low.startsWith('data:') ||
        low.startsWith('blob:');
  }

  String? _normalizeUrl(String? url) {
    if (_isBadUrl(url)) return null;
    final s = url!.trim();
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    if (s.startsWith('//')) return 'https:$s';
    if (s.startsWith('/')) return '$_kBase$s';
    return '$_kBase/$s';
  }

// Update _tile method:
  Widget _tile(
      String? img,
      String name,
      String subtitle, {
        String? trailing,
        VoidCallback? onTap,
      }) {
    final safeImg = _normalizeUrl(img);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          radius: 24,
          backgroundImage: safeImg != null
              ? NetworkImage(safeImg)
              : const AssetImage(_kPlaceholder),
        ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: trailing == null
            ? null
            : Text(
          trailing,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.1);
  }
  Widget _safeNetImg(
      String? url, {
        double? width,
        double? height,
        BoxFit fit = BoxFit.cover,
      }) {
    final u = _normalizeUrl(url);
    if (u == null) {
      return Image.asset(_kPlaceholder, width: width, height: height, fit: fit);
    }
    return Image.network(
      u,
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) =>
          Image.asset(_kPlaceholder, width: width, height: height, fit: fit),
    );
  }

  ImageProvider? _safeProvider(String? url) {
    final u = _normalizeUrl(url);
    return u == null ? null : NetworkImage(u);
  }
  // ---------------------------------------

  TournamentOverview? tournament;
  List<TeamStanding> pointsTeams = [];
  List<FairPlayStanding> fairPlayTeams = [];
  List<GroupModel> groups = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => isLoading = true);
    try {
      final overview = await TournamentService.fetchTournamentOverview(
        widget.tournamentId,
      );
      final fp = await TournamentService.fetchFairPlay(widget.tournamentId);

      setState(() {
        tournament = overview['tournament'] as TournamentOverview;
        pointsTeams = overview['pointsTeams'] as List<TeamStanding>;
        groups = overview['groups'] as List<GroupModel>;
        fairPlayTeams = fp;
        errorMessage = null;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (errorMessage != null) {
      return Center(child: Text('Failed to load: $errorMessage'));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBanner(),
              const SizedBox(height: 12),
              if (groups.isEmpty || pointsTeams.isEmpty)
                _buildNoDataCard('No points table data available.')
              else
                ...groups.map(
                      (group) => PointsTableWidget(
                    group: group,
                    teams: group.groupId == '0'
                        ? pointsTeams
                        : pointsTeams
                        .where((t) => t.groupId == group.groupId)
                        .toList(),
                  ),
                ),
              _buildLegendChips(),
              const SizedBox(height: 24),
              if (fairPlayTeams.isEmpty)
                _buildNoDataCard('No fair-play standings available.')
              else
                FairPlayTableWidget(fairPlayTeams: fairPlayTeams),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBanner() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            // ✅ SAFE: never passes "" or invalid to NetworkImage
            child: _safeNetImg(tournament?.tournamentLogo, width: 80, height: 80),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tournament?.tournamentName ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.matchTitle.copyWith(
                    fontSize: 18,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tournament?.tournamentDesc ?? 'No description available.',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: isDark ? Colors.grey[300] : Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: const [
          Chip(label: Text('M = Matches', style: TextStyle(fontSize: 12))),
          Chip(label: Text('W = Wins', style: TextStyle(fontSize: 12))),
          Chip(label: Text('L = Losses', style: TextStyle(fontSize: 12))),
          Chip(label: Text('T = Ties', style: TextStyle(fontSize: 12))),
          Chip(label: Text('D = Draws', style: TextStyle(fontSize: 12))),
          Chip(label: Text('Pts = Points', style: TextStyle(fontSize: 12))),
          Chip(label: Text('NRR = Net Run Rate', style: TextStyle(fontSize: 12))),
          Chip(label: Text('→ = View Matches', style: TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildNoDataCard(String message) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Text(message, textAlign: TextAlign.center),
    );
  }
}
