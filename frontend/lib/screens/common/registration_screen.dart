import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/auth/auth_hero.dart';
import '../../widgets/auth/auth_primary_button.dart';
import '../../widgets/auth/auth_role_segment.dart';
import '../../widgets/auth/auth_underline_field.dart';
import 'app_shell.dart';
import '../../services/api/auth_api.dart';
import '../../utils/api_error.dart';
import '../../widgets/app_snackbar.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String _selectedRole = 'buyer'; // 'buyer' or 'farmer'
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      final state = Provider.of<AppState>(context, listen: false);
      setState(() {
        _isLoading = true;
      });

      try {
        final int roleId = _selectedRole == 'farmer' ? 3 : 6;

        await AuthApi.register(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          password: _passwordController.text,
          roleId: roleId,
          email: _emailController.text.trim(),
        );

        final loginResponse = await AuthApi.login(
          _phoneController.text.trim(),
          _passwordController.text,
        );

        final String token = loginResponse['access_token'];
        final userProfile = await AuthApi.fetchUserProfile(token);

        if (mounted) {
          state.loginWithProfile(token, userProfile);

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const AppShell()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          AppSnackBar.error(context, friendlyApiError(state, e));
        }
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
            showBackButton: true,
            child: Text(
              state.translate('create_account'),
              style: GoogleFonts.fraunces(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(26, 20, 26, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.translate('join_community'),
                            style: GoogleFonts.inter(fontSize: 13.5, color: authMutedText),
                          ),
                          const SizedBox(height: 18),

                          Text(
                            state.translate('join_as'),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: authMutedText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          AuthRoleSegment(
                            options: [
                              AuthRoleOption('buyer', state.translate('buyer_role_btn')),
                              AuthRoleOption('farmer', state.translate('farmer_role_btn')),
                            ],
                            selected: _selectedRole,
                            onChanged: (value) => setState(() => _selectedRole = value),
                          ),
                          const SizedBox(height: 22),

                          AuthUnderlineField(
                            label: state.translate('full_name'),
                            hintText: state.translate('enter_name'),
                            controller: _nameController,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return state.translate('enter_name');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          AuthUnderlineField(
                            label: state.translate('phone_number'),
                            hintText: state.translate('enter_phone'),
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return state.translate('enter_phone');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          AuthUnderlineField(
                            label: state.translate('email_optional'),
                            hintText: state.translate('enter_email'),
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
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
                              if (value == null || value.length < 6) {
                                return state.translate('enter_password');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 26),

                          AuthPrimaryButton(
                            text: state.translate('register_button'),
                            isLoading: _isLoading,
                            onPressed: _handleRegister,
                          ),
                          const SizedBox(height: 22),

                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  state.translate('already_member'),
                                  style: GoogleFonts.inter(fontSize: 13, color: authMutedText),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Text(
                                    state.translate('sign_in'),
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
