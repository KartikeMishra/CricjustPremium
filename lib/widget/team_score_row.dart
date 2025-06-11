import 'package:flutter/material.dart';
import '../theme/text_styles.dart';

class TeamScoreRow extends StatelessWidget {
  final String logo;
  final String teamName;
  final int? runs;
  final int? wickets;
  final Color? logoBg;

  const TeamScoreRow({
    super.key,
    required this.logo,
    required this.teamName,
    this.runs,
    this.wickets,
    this.logoBg,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _teamLogo(),
        const SizedBox(width: 10),
        Expanded(child: Text(teamName, style: AppTextStyles.teamName)),
        if (runs != null && wickets != null) ...[
          const SizedBox(width: 10),
          Text('$runs/$wickets', style: AppTextStyles.score),
        ]
      ],
    );
  }

  Widget _teamLogo() {
    if (logo.isNotEmpty) {
      return CircleAvatar(
        radius: 14,
        backgroundColor: Colors.grey.shade200,
        backgroundImage: NetworkImage(logo),
      );
    }
    final initials = teamName.split(' ').where((e) => e.isNotEmpty).map((e) => e[0]).join().toUpperCase();
    return CircleAvatar(
      radius: 14,
      backgroundColor: logoBg ?? Colors.blueGrey,
      child: Text(
        initials.length > 4 ? initials.substring(0, 4) : initials,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
