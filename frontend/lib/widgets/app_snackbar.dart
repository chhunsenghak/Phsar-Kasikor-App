import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';

/// A floating, card-styled snackbar used in place of the default Material one.
///
/// The default [SnackBar] renders as a plain dark bar, which reads as a generic
/// system toast rather than something belonging to this app. This wraps the
/// same [ScaffoldMessenger] mechanism with an icon badge, rounded card and an
/// optional pill-shaped action, themed with [AppColors].
class AppSnackBar {
  AppSnackBar._();

  static void showSuccess(
    ScaffoldMessengerState messenger, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _show(
      messenger,
      message: message,
      icon: Icons.check_circle_rounded,
      iconColor: AppColors.primary,
      iconBackground: AppColors.primary.withValues(alpha: 0.12),
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// For non-blocking heads-up notices, e.g. a quantity was capped to stock.
  static void showNotice(
    ScaffoldMessengerState messenger, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _show(
      messenger,
      message: message,
      icon: Icons.info_rounded,
      iconColor: Colors.amber[800]!,
      iconBackground: Colors.amber.withValues(alpha: 0.15),
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void _show(
    ScaffoldMessengerState messenger, {
    required String message,
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 4),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDesign.borderRadiusDefault),
            boxShadow: AppDesign.level2Shadow,
            border: Border.all(color: AppColors.outlineVariant, width: 0.6),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                    height: 1.3,
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    messenger.hideCurrentSnackBar();
                    onAction();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    actionLabel,
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
