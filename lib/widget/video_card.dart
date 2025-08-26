import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../model/youtube_video_model.dart';

const String _kPlaceholder = 'lib/asset/images/cricjust_logo.png';

class VideoCard extends StatelessWidget {
  final YoutubeVideo video;
  final double height;
  final EdgeInsetsGeometry margin;

  const VideoCard({
    super.key,
    required this.video,
    this.height = 180,
    this.margin = const EdgeInsets.only(right: 12),
  });

  bool _isBadUrl(String? s) {
    if (s == null) return true;
    final t = s.trim();
    if (t.isEmpty || t == 'null' || t == 'N/A') return true;
    if (!t.startsWith('http')) return true;
    return false;
  }

  Future<void> _openVideo() async {
    final url = video.watchUrl ?? video.embedUrl;
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: _openVideo,
      child: Container(
        width: 300,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.28)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Thumbnail
            SizedBox(
              height: height - 70,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_isBadUrl(video.thumbnailUrl))
                    Image.asset(_kPlaceholder, fit: BoxFit.cover)
                  else
                    Image.network(
                      video.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Image.asset(_kPlaceholder, fit: BoxFit.cover),
                    ),
                  // dark gradient
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.center,
                          colors: [
                            Colors.black.withValues(alpha: 0.35),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Play badge
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow, size: 36, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            // Title + meta
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right,
                        color: isDark ? Colors.white70 : Colors.black38),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
