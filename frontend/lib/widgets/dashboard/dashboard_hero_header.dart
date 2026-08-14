import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../wave_divider_painter.dart';

/// A dashboard's header and its single most important metric, merged into
/// one hero instead of a plain title row followed by a separate gradient
/// card — reuses the wave motif from login/register/profile so every
/// screen in the app reads as part of the same product.
class DashboardHeroHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData metricIcon;
  final Widget metric;
  final String metricLabel;
  final VoidCallback? onTapMetric;

  const DashboardHeroHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.metricIcon,
    required this.metric,
    required this.metricLabel,
    this.onTapMetric,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, Color(0xFF1E5F42), AppColors.primaryContainer],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.72)),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onTapMetric,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(metricIcon, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                metric,
                                const SizedBox(height: 2),
                                Text(
                                  metricLabel,
                                  style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.72)),
                                ),
                              ],
                            ),
                          ),
                          if (onTapMetric != null)
                            const Icon(Icons.chevron_right_rounded, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          CustomPaint(
            size: const Size(double.infinity, 24),
            painter: const WaveDividerPainter(color: AppColors.background),
          ),
        ],
      ),
    );
  }
}
