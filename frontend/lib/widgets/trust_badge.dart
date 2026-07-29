import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TrustBadge extends StatelessWidget {
  final String certType;
  final bool isMini;

  const TrustBadge({
    super.key,
    required this.certType,
    this.isMini = false,
  });

  @override
  Widget build(BuildContext context) {
    if (certType == 'none' || certType.isEmpty) {
      return const SizedBox.shrink();
    }

    Color bgColor;
    Color textColor;
    IconData icon;
    String label;

    switch (certType) {
      case 'organic':
        bgColor = const Color(0xFFE8F5E9); // light green
        textColor = const Color(0xFF2E7D32); // dark green
        icon = Icons.eco_rounded;
        label = 'COrAA Organic';
        break;
      case 'gap':
        bgColor = const Color(0xFFE3F2FD); // light blue
        textColor = const Color(0xFF1565C0); // dark blue
        icon = Icons.verified_user_rounded;
        label = 'CamGAP';
        break;
      case 'gi':
        bgColor = const Color(0xFFFFF8E1); // light gold
        textColor = const Color(0xFFF57F17); // dark gold
        icon = Icons.workspace_premium_rounded;
        label = 'GI Specialty';
        break;
      case 'general':
      default:
        bgColor = const Color(0xFFE0F2F1); // light teal
        textColor = const Color(0xFF00796B); // dark teal
        icon = Icons.check_circle_rounded;
        label = 'Verified Farm';
        break;
    }

    if (isMini) {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: textColor,
          size: 14,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: textColor,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
