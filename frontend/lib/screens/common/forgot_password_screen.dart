import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../services/api/auth_api.dart';
import '../../utils/api_error.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_input.dart';
import '../../widgets/app_snackbar.dart';

/// Two-step password reset: request a code by email, then submit that code
/// with a new password. The backend always returns a generic success for
/// step one regardless of whether the email exists, so this screen can't be
/// used to probe which emails are registered.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Separate from _codeFormKey since resending the code (which only needs a
  // valid email) must not be blocked by the code/password fields being
  // empty — they're a different step's requirement.
  final _emailFormKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _codeSent = false;
  bool _isSubmitting = false;

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_isSubmitting || !_emailFormKey.currentState!.validate()) return;
    final state = Provider.of<AppState>(context, listen: false);
    final email = _emailController.text.trim();

    setState(() => _isSubmitting = true);
    try {
      await AuthApi.forgotPassword(email);
      if (!mounted) return;
      setState(() => _codeSent = true);
      AppSnackBar.success(context, state.translate('reset_code_sent_desc'));
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, friendlyApiError(state, e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_isSubmitting ||
        !_emailFormKey.currentState!.validate() ||
        !_codeFormKey.currentState!.validate()) {
      return;
    }
    final state = Provider.of<AppState>(context, listen: false);
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final newPassword = _newPasswordController.text;

    setState(() => _isSubmitting = true);
    try {
      await AuthApi.resetPassword(email, code, newPassword);
      if (!mounted) return;
      AppSnackBar.success(context, state.translate('password_reset_success_msg'));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, friendlyApiError(state, e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.onSurface),
        title: Text(
          state.translate('reset_password_title'),
          style: GoogleFonts.inter(color: AppColors.onSurface, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _codeSent
                  ? state.translate('reset_code_sent_desc')
                  : state.translate('enter_email_for_reset'),
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Form(
              key: _emailFormKey,
              child: CustomInput(
                label: state.translate('email_label'),
                hintText: 'you@example.com',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.email_outlined,
                isRequired: true,
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return state.translate('email_required');
                  if (!_emailPattern.hasMatch(v)) {
                    return state.translate('invalid_email_format');
                  }
                  return null;
                },
              ),
            ),
            if (!_codeSent) ...[
              const SizedBox(height: 24),
              CustomButton(
                text: state.translate('send_reset_code'),
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _sendCode,
              ),
            ] else ...[
              const SizedBox(height: 16),
              Form(
                key: _codeFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomInput(
                      label: state.translate('verification_code_label'),
                      hintText: '000000',
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.pin_outlined,
                      isRequired: true,
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? state.translate('code_required')
                          : null,
                    ),
                    const SizedBox(height: 16),
                    CustomInput(
                      label: state.translate('new_password'),
                      hintText: '••••••••',
                      controller: _newPasswordController,
                      obscureText: true,
                      prefixIcon: Icons.lock_outline_rounded,
                      isRequired: true,
                      validator: (value) {
                        final v = value ?? '';
                        if (v.isEmpty) return state.translate('new_password_required');
                        if (v.length < 8) return state.translate('password_min_length_error');
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: state.translate('reset_password_button'),
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _resetPassword,
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _isSubmitting ? null : _sendCode,
                  child: Text(
                    state.translate('resend_code'),
                    style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
