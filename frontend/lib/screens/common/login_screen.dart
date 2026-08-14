import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/auth/auth_hero.dart';
import '../../widgets/auth/auth_primary_button.dart';
import '../../widgets/auth/auth_underline_field.dart';
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
    final state = Provider.of<AppState>(context);

    return Scaffold(
      backgroundColor: authPaper,
      body: Column(
        children: [
          AuthHero(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.eco_rounded, size: 15, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Text(
                  'Phsar Kasikor',
                  style: GoogleFonts.fraunces(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(26, 22, 26, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.translate('welcome_back'),
                            style: GoogleFonts.fraunces(
                              fontSize: 27,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            state.translate('sign_up_desc'),
                            style: GoogleFonts.inter(fontSize: 13.5, color: authMutedText),
                          ),
                          const SizedBox(height: 26),

                          AuthUnderlineField(
                            label: state.translate('phone_or_email'),
                            hintText: state.translate('enter_phone_email'),
                            controller: _identifierController,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return state.translate('enter_phone_email');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          AuthUnderlineField(
                            label: state.translate('password'),
                            hintText: '••••••••',
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: authFaintText,
                                size: 19,
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
                          const SizedBox(height: 8),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: Checkbox(
                                        value: _rememberMe,
                                        activeColor: AppColors.primary,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                                        style: GoogleFonts.inter(fontSize: 12.5, color: authMutedText),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                                  );
                                },
                                child: Text(
                                  state.translate('forgot_password'),
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          AuthPrimaryButton(
                            text: state.translate('sign_in_button'),
                            isLoading: _isLoading,
                            onPressed: _handleSignIn,
                          ),
                          const SizedBox(height: 20),

                          Row(
                            children: [
                              const Expanded(child: Divider(color: authHairline)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                child: Text(
                                  state.translate('or_continue_with').toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: authFaintText,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                              const Expanded(child: Divider(color: authHairline)),
                            ],
                          ),
                          const SizedBox(height: 16),

                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton(
                              onPressed: _handleGoogleSignIn,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: AppColors.surface,
                                foregroundColor: AppColors.onSurface,
                                side: const BorderSide(color: authHairline, width: 1.3),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgPicture.asset('assets/icons/google_logo.svg', width: 18, height: 18),
                                  const SizedBox(width: 10),
                                  Text(
                                    state.translate('google_sign_in'),
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),

                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  state.translate('no_account'),
                                  style: GoogleFonts.inter(fontSize: 13, color: authMutedText),
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
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
