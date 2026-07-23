import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../models/app_state.dart';
import '../widgets/custom_card.dart';
import '../widgets/custom_button.dart';
import 'login_screen.dart';

class UserProfileSettingsScreen extends StatefulWidget {
  const UserProfileSettingsScreen({super.key});

  @override
  State<UserProfileSettingsScreen> createState() => _UserProfileSettingsScreenState();
}

class _UserProfileSettingsScreenState extends State<UserProfileSettingsScreen> {
  String _selectedLanguage = 'English';

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final String currentRole = state.currentRole;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(state),
          const SizedBox(height: 24),
          _buildRoleSwitcher(state, currentRole),
          const SizedBox(height: 24),
          _buildSettingsSection(context),
          const SizedBox(height: 32),
          _buildLogoutButton(context, state),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(AppState state) {
    return CustomCard(
      padding: const EdgeInsets.all(24),
      elevationLevel: 2,
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: const Icon(
              Icons.person_rounded,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.userName,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Member since 2026',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRoleSwitcher(AppState state, String currentRole) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prototype Role Switcher',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        CustomCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          borderSide: const BorderSide(color: AppColors.outlineVariant, width: 1),
          child: Column(
            children: [
              _buildRoleRadioRow(
                title: 'Buyer / Consumer Dashboard',
                subtitle: 'Browse products, place bids, negotiate prices, QR checkout.',
                value: 'buyer',
                groupValue: currentRole,
                onChanged: (val) => state.setRole(val!),
              ),
              const Divider(),
              _buildRoleRadioRow(
                title: 'Farmer / Producer Dashboard',
                subtitle: 'Manage products, view sales analytics, add new crop listings.',
                value: 'farmer',
                groupValue: currentRole,
                onChanged: (val) => state.setRole(val!),
              ),
              const Divider(),
              _buildRoleRadioRow(
                title: 'System Admin Dashboard',
                subtitle: 'Verify farmer certificates, moderate listings, handle disputes.',
                value: 'admin',
                groupValue: currentRole,
                onChanged: (val) => state.setRole(val!),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'General Settings',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        CustomCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.language_rounded, color: AppColors.primary),
                title: Text(
                  'App Language',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                trailing: DropdownButton<String>(
                  value: _selectedLanguage,
                  items: const [
                    DropdownMenuItem(value: 'English', child: Text('English')),
                    DropdownMenuItem(value: 'Khmer', child: Text('ភាសាខ្មែរ (Khmer)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedLanguage = val;
                      });
                    }
                  },
                  underline: const SizedBox(),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.settings_suggest_rounded, color: AppColors.primary),
                title: Text(
                  'Verification Documents',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Required for Farmers to sell'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Document upload simulated.')),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.help_outline_rounded, color: AppColors.primary),
                title: Text(
                  'Help & Dispute Resolution',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Dispute & Support center mockup loaded.')),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context, AppState state) {
    return CustomButton.secondary(
      text: 'Logout from App',
      icon: Icons.logout_rounded,
      backgroundColor: AppColors.errorContainer,
      textColor: AppColors.onErrorContainer,
      onPressed: () {
        state.logout();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      },
    );
  }

  Widget _buildRoleRadioRow({
    required String title,
    required String subtitle,
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
  }) {
    final isSelected = value == groupValue;
    return RadioListTile<String>(
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: isSelected ? AppColors.primary : AppColors.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
      ),
      value: value,
      groupValue: groupValue,
      activeColor: AppColors.primary,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}
