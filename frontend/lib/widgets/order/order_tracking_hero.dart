import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../wave_divider_painter.dart';

/// The order tracking header: a back button and title like the auth
/// screens, plus the order reference, total, and a live status pill right
/// where the buyer lands instead of only surfacing status further down in
/// the timeline.
class OrderTrackingHero extends StatelessWidget {
  final String title;
  final String orderRef;
  final String totalText;
  final String statusLabel;
  final IconData statusIcon;
  final VoidCallback onBack;

  const OrderTrackingHero({
    super.key,
    required this.title,
    required this.orderRef,
    required this.totalText,
    required this.statusLabel,
    required this.statusIcon,
    required this.onBack,
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
            padding: const EdgeInsets.fromLTRB(18, 14, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Material(
                      color: Colors.white.withValues(alpha: 0.16),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onBack,
                        child: const Padding(
                          padding: EdgeInsets.all(6.0),
                          child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              orderRef,
                              style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.68)),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              totalText,
                              style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 13, color: Colors.white),
                            const SizedBox(width: 5),
                            Text(
                              statusLabel,
                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          CustomPaint(
            size: const Size(double.infinity, 22),
            painter: const WaveDividerPainter(color: AppColors.background),
          ),
        ],
      ),
    );
  }
}
