import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_input.dart';
import 'login_screen.dart';
import '../farmer/submit_certificate_screen.dart';
import 'order_contract_history_screen.dart';
import '../buyer/farm_profile.dart';

class UserProfileSettingsScreen extends StatefulWidget {
  const UserProfileSettingsScreen({super.key});

  @override
  State<UserProfileSettingsScreen> createState() => _UserProfileSettingsScreenState();
}

class _UserProfileSettingsScreenState extends State<UserProfileSettingsScreen> {
  final _addressFormKey = GlobalKey<FormState>();
  final _provinceController = TextEditingController();
  final _districtController = TextEditingController();
  final _communeController = TextEditingController();
  final _villageController = TextEditingController();
  final _streetController = TextEditingController();

  @override
  void dispose() {
    _provinceController.dispose();
    _districtController.dispose();
    _communeController.dispose();
    _villageController.dispose();
    _streetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(state),
          const SizedBox(height: 20),
          _buildAddressCard(state),
          const SizedBox(height: 24),
          _buildSettingsSection(context, state),
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
                  state.translate('member_since'),
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

  Widget _buildAddressCard(AppState state) {
    final profile = state.userProfile;
    final hasAddress = state.isLocationComplete;

    return CustomCard(
      padding: const EdgeInsets.all(16),
      borderSide: BorderSide(
        color: hasAddress ? AppColors.outlineVariant : AppColors.error.withValues(alpha: 0.5),
        width: 1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                state.translate('farm_location_address'),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.onSurface,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.edit_location_alt_rounded, size: 16),
                label: Text(state.translate('edit_address')),
                onPressed: () => _showAddressEditSheet(state),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!hasAddress)
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.translate('incomplete_address_profile'),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAddressRow(state.translate('province_city'), state.translateLocation(profile?['province'])),
                const Divider(height: 12),
                _buildAddressRow(state.translate('district'), state.translateLocation(profile?['district'])),
                const Divider(height: 12),
                _buildAddressRow(state.translate('commune'), state.translateLocation(profile?['commune'])),
                const Divider(height: 12),
                _buildAddressRow(state.translate('village'), state.translateLocation(profile?['village'])),
                if (profile?['street_address'] != null && profile!['street_address'].toString().trim().isNotEmpty) ...[
                  const Divider(height: 12),
                  _buildAddressRow(state.translate('street_address_optional').replaceAll(' (Optional)', ''), profile['street_address']),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAddressRow(String label, dynamic value) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value?.toString() ?? 'Not specified',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  void _showAddressEditSheet(AppState state) {
    final locations = state.cambodiaLocations;
    final profile = state.userProfile;

    // Resolve initial values from profile or fallback safely to first database items
    String tempProvince = profile?['province']?.toString() ?? locations.keys.first;
    if (!locations.containsKey(tempProvince)) {
      tempProvince = locations.keys.first;
    }

    Map<String, dynamic> districts = locations[tempProvince] as Map<String, dynamic>;
    String tempDistrict = profile?['district']?.toString() ?? districts.keys.first;
    if (!districts.containsKey(tempDistrict)) {
      tempDistrict = districts.keys.first;
    }

    Map<String, dynamic> communes = districts[tempDistrict] as Map<String, dynamic>;
    String tempCommune = profile?['commune']?.toString() ?? communes.keys.first;
    if (!communes.containsKey(tempCommune)) {
      tempCommune = communes.keys.first;
    }

    List<dynamic> villages = communes[tempCommune] as List<dynamic>;
    String tempVillage = profile?['village']?.toString() ?? villages.first.toString();
    if (!villages.contains(tempVillage)) {
      tempVillage = villages.first.toString();
    }

    _streetController.text = profile?['street_address']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          // Cascading fallback resolver for current selections
          final provinceList = locations.keys.toList();

          final Map<String, dynamic> currentDistricts = locations[tempProvince] as Map<String, dynamic>;
          final districtList = currentDistricts.keys.toList();
          if (!districtList.contains(tempDistrict)) {
            tempDistrict = districtList.first;
          }

          final Map<String, dynamic> currentCommunes = currentDistricts[tempDistrict] as Map<String, dynamic>;
          final communeList = currentCommunes.keys.toList();
          if (!communeList.contains(tempCommune)) {
            tempCommune = communeList.first;
          }

          final List<dynamic> currentVillages = currentCommunes[tempCommune] as List<dynamic>;
          final villageList = currentVillages.map((v) => v.toString()).toList();
          if (!villageList.contains(tempVillage)) {
            tempVillage = villageList.first;
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: _addressFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.translate('update_farm_address'),
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Province Dropdown
                    _buildDropdownField(
                      label: state.translate('province_city'),
                      value: tempProvince,
                      items: provinceList,
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() {
                            tempProvince = val;
                            final Map<String, dynamic> nextDistricts = locations[tempProvince] as Map<String, dynamic>;
                            tempDistrict = nextDistricts.keys.first;
                            final Map<String, dynamic> nextCommunes = nextDistricts[tempDistrict] as Map<String, dynamic>;
                            tempCommune = nextCommunes.keys.first;
                            final List<dynamic> nextVillages = nextCommunes[tempCommune] as List<dynamic>;
                            tempVillage = nextVillages.first.toString();
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    // District Dropdown
                    _buildDropdownField(
                      label: state.translate('district'),
                      value: tempDistrict,
                      items: districtList,
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() {
                            tempDistrict = val;
                            final Map<String, dynamic> nextCommunes = currentDistricts[tempDistrict] as Map<String, dynamic>;
                            tempCommune = nextCommunes.keys.first;
                            final List<dynamic> nextVillages = nextCommunes[tempCommune] as List<dynamic>;
                            tempVillage = nextVillages.first.toString();
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    // Commune Dropdown
                    _buildDropdownField(
                      label: state.translate('commune'),
                      value: tempCommune,
                      items: communeList,
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() {
                            tempCommune = val;
                            final List<dynamic> nextVillages = currentCommunes[tempCommune] as List<dynamic>;
                            tempVillage = nextVillages.first.toString();
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    // Village Dropdown
                    _buildDropdownField(
                      label: state.translate('village'),
                      value: tempVillage,
                      items: villageList,
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() {
                            tempVillage = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    CustomInput(
                      label: state.translate('street_address_optional'),
                      hintText: 'e.g. Street 105',
                      controller: _streetController,
                    ),
                    const SizedBox(height: 24),
                    CustomButton(
                      text: state.translate('save_address_details'),
                      onPressed: () {
                        state.updateProfileLocation(
                          province: tempProvince,
                          district: tempDistrict,
                          commune: tempCommune,
                          village: tempVillage,
                          streetAddress: _streetController.text.trim(),
                        );
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${state.translate('save_address_details')} successful')),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppDesign.borderRadiusDefault),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            items: items.map((val) {
              return DropdownMenuItem(
                value: val,
                child: Text(
                  val,
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurface),
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection(BuildContext context, AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.translate('general_settings'),
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
              // App Language Custom Selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.language_rounded, color: AppColors.primary),
                        const SizedBox(width: 16),
                        Text(
                          state.translate('app_language'),
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _buildLangPill(state, 'kh', 'ខ្មែរ'),
                        const SizedBox(width: 8),
                        _buildLangPill(state, 'en', 'English'),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
                title: Text(
                  'Wholesale Transaction History',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: Text(
                  'View invoice orders and contract agreements',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.outline),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OrderContractHistoryScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              if (state.currentRole == 'farmer') ...[
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: const Icon(Icons.storefront_rounded, color: AppColors.primary),
                  title: Text(
                    'View My Farm Profile',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: Text(
                    'See how buyers view your farm and listed products',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.outline),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FarmProfileScreen(
                          farmerName: state.userName,
                          isVerifiedFarmer: true,
                          location: 'Battambang',
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
              ],
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: const Icon(Icons.settings_suggest_rounded, color: AppColors.primary),
                title: Text(
                  state.translate('verification_docs'),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: Text(
                  state.translate('required_for_farmers'),
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.outline),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SubmitCertificateScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: const Icon(Icons.help_outline_rounded, color: AppColors.primary),
                title: Text(
                  state.translate('help_disputes'),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.outline),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.translate('dispute_mock'))),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLangPill(AppState state, String langCode, String label) {
    final isSelected = state.currentLanguage == langCode;
    return GestureDetector(
      onTap: () => state.setLanguage(langCode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, AppState state) {
    return CustomButton.secondary(
      text: state.translate('logout'),
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
}
