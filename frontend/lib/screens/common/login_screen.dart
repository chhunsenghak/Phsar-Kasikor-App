import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_input.dart';
import 'registration_screen.dart';
import 'app_shell.dart';
import 'forgot_password_screen.dart';
import '../../services/api/auth_api.dart';
import '../../utils/api_error.dart';
import '../../widgets/app_snackbar.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = true;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSignIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final loginResponse = await AuthApi.login(
          _identifierController.text.trim(),
          _passwordController.text,
        );
        final String token = loginResponse['access_token'];
        final userProfile = await AuthApi.fetchUserProfile(token);

        if (mounted) {
          final state = Provider.of<AppState>(context, listen: false);
          state.loginWithProfile(token, userProfile);

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const AppShell(),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          final state = Provider.of<AppState>(context, listen: false);
          AppSnackBar.error(context, _friendlyLoginError(state, e));
        }
      }
    }
  }

  String _friendlyLoginError(AppState state, Object error) {
    // ACCOUNT_LOCKED / INCORRECT_CREDENTIALS / INACTIVE_USER and anything
    // else the backend can send on login are all covered by the shared
    // map — see utils/api_error.dart.
    return friendlyApiError(state, error);
  }

  void _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final loginResponse = await AuthApi.signInWithGoogle();
      final String token = loginResponse['access_token'];
      final userProfile = await AuthApi.fetchUserProfile(token);

      if (mounted) {
        final state = Provider.of<AppState>(context, listen: false);
        state.loginWithProfile(token, userProfile);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const AppShell(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        final state = Provider.of<AppState>(context, listen: false);
        AppSnackBar.error(context, friendlyApiError(state, e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          // Centered, width-capped column — on a phone this is a no-op (the
          // screen is already narrower than the cap), but it keeps the form
          // from stretching edge-to-edge into unnaturally wide input fields
          // on a tablet or the web build.
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildLogo(),
                  const SizedBox(height: 36),
                  _buildLoginCard(context),
                  const SizedBox(height: 24),
                  _buildDivider(context),
                  const SizedBox(height: 20),
                  _buildSocialButton(context),
                  const SizedBox(height: 28),
                  _buildSignUpLink(context),
                  const SizedBox(height: 32),
                  _buildFooterBadges(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.eco_rounded,
            size: 18,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Phsar Kasikor',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    final state = Provider.of<AppState>(context);
    return CustomCard(
      elevationLevel: 2,
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting Header
            Center(
              child: Column(
                children: [
                  Text(
                    state.translate('welcome_back'),
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.translate('sign_up_desc'),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Form Fields
            CustomInput(
              label: state.translate('phone_or_email'),
              hintText: state.translate('enter_phone_email'),
              controller: _identifierController,
              prefixIcon: Icons.person_outline_rounded,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return state.translate('enter_phone_email');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            CustomInput(
              label: state.translate('password'),
              hintText: '••••••••',
              controller: _passwordController,
              obscureText: _obscurePassword,
              isPassword: true,
              prefixIcon: Icons.lock_outline_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppColors.outline,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return state.translate('enter_password');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Remember Me / Forgot Password Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _rememberMe,
                          activeColor: AppColors.primary,
                          onChanged: (val) {
                            setState(() {
                              _rememberMe = val ?? true;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          state.translate('keep_signed_in'),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                    );
                  },
                  child: Text(
                    state.translate('forgot_password'),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(height: 24),

            // Sign In Button
            CustomButton(
              text: state.translate('sign_in_button'),
              icon: Icons.arrow_forward_rounded,
              isLoading: _isLoading,
              onPressed: _handleSignIn,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    final state = Provider.of<AppState>(context);
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            state.translate('or_continue_with').toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.outline,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.outlineVariant)),
      ],
    );
  }

  Widget _buildSocialButton(BuildContext context) {
    final state = Provider.of<AppState>(context);
    return OutlinedButton(
      onPressed: _handleGoogleSignIn,
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        side: const BorderSide(color: AppColors.outlineVariant),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesign.borderRadiusDefault),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset('assets/icons/google_logo.svg', width: 20, height: 20),
          const SizedBox(width: 8),
          Text(
            state.translate('google_sign_in'),
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpLink(BuildContext context) {
    final state = Provider.of<AppState>(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          state.translate('no_account'),
          style: GoogleFonts.inter(
            fontSize: 15,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RegistrationScreen(),
              ),
            );
          },
          child: Text(
            state.translate('register_now'),
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterBadges() {
    final state = Provider.of<AppState>(context, listen: false);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 6,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_user_outlined, size: 16, color: AppColors.outline),
            const SizedBox(width: 4),
            Text(
              state.translate('secure_connection'),
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.outline),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.outline),
            const SizedBox(width: 4),
            Text(
              state.translate('data_encrypted'),
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.outline),
            ),
          ],
        ),
      ],
    );
  }
}
