import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/colors.dart';
import '../wave_divider_painter.dart';

/// Aliases kept so the auth screens read as their own vocabulary — both now
/// equal the app-wide warm-neutral tokens in [AppColors].
const Color authPaper = AppColors.background;
const Color authHairline = AppColors.outlineVariant;
const Color authMutedText = Color(0xFF5C6459);
const Color authFaintText = Color(0xFF9AA097);
const Color authLabelText = Color(0xFF8A9188);

/// The gradient hero band shared by the login and register screens: a green
/// gradient panel that curves into the paper-colored form sheet below via a
/// wave cut, edge-to-edge behind the status bar.
class AuthHero extends StatelessWidget {
  final Widget child;
  final bool showBackButton;
  final VoidCallback? onBack;
  final EdgeInsetsGeometry contentPadding;

  const AuthHero({
    super.key,
    required this.child,
    this.showBackButton = false,
    this.onBack,
    this.contentPadding = const EdgeInsets.fromLTRB(26, 22, 26, 0),
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
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
            SizedBox(height: topInset),
            Padding(
              padding: contentPadding,
              child: showBackButton
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _BackButton(onTap: onBack ?? () => Navigator.pop(context)),
                        Expanded(child: Center(child: child)),
                        // Mirrors the back button's width so the title centers
                        // on the full row instead of drifting toward it.
                        const SizedBox(width: 32),
                      ],
                    )
                  : child,
            ),
            const SizedBox(height: 22),
            CustomPaint(
              size: const Size(double.infinity, 30),
              painter: WaveDividerPainter(color: authPaper),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(7.0),
          child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}
