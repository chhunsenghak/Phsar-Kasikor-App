import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final bool isSecondary;
  final bool isOutline;
  final double? height;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.height,
  })  : isSecondary = false,
        isOutline = false;

  const CustomButton.secondary({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.height,
  })  : isSecondary = true,
        isOutline = false;

  const CustomButton.outline({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.height,
  })  : isSecondary = false,
        isOutline = true;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;

    Color bg;
    Color fg;
    BorderSide border = BorderSide.none;

    if (isOutline) {
      bg = Colors.transparent;
      fg = textColor ?? AppColors.primary;
      border = BorderSide(color: fg, width: 1.5);
    } else if (isSecondary) {
      bg = backgroundColor ?? AppColors.secondaryContainer;
      fg = textColor ?? AppColors.onSecondaryContainer;
    } else {
      bg = backgroundColor ?? AppColors.primary;
      fg = textColor ?? AppColors.onPrimary;
    }

    if (disabled) {
      if (!isOutline) {
        bg = bg.withValues(alpha: 0.4);
      }
      fg = fg.withValues(alpha: 0.4);
    }

    Widget content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          ),
          const SizedBox(width: 8),
        ] else if (icon != null) ...[
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ],
    );

    return SizedBox(
      height: height ?? 56.0,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: disabled ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          side: border,
          shape: const StadiumBorder(),
          elevation: isOutline || isSecondary || disabled ? 0 : 2,
          shadowColor: AppColors.primary.withValues(alpha: 0.2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        child: content,
      ),
    );
  }
}
