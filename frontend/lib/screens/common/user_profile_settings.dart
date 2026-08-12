import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_input.dart';
import '../../services/api/auth_api.dart';
import '../../utils/api_error.dart';
import '../../widgets/app_snackbar.dart';
import 'login_screen.dart';
import '../farmer/submit_certificate_screen.dart';
import 'order_contract_history_screen.dart';
import 'help_disputes_screen.dart';

class UserProfileSettingsScreen extends StatefulWidget {
  const UserProfileSettingsScreen({super.key});

  @override
  State<UserProfileSettingsScreen> createState() =>
      _UserProfileSettingsScreenState();
}

class _UserProfileSettingsScreenState extends State<UserProfileSettingsScreen> {
  final _addressFormKey = GlobalKey<FormState>();
  bool _justVerifiedEmail = false;
  bool _isSendingVerification = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = Provider.of<AppState>(context, listen: false);
      state.refreshAddressRequests();
    });
  }

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
          if (!_justVerifiedEmail &&
              state.userProfile?['email'] != null &&
              state.userProfile?['is_verified'] != true) ...[
            const SizedBox(height: 16),
            _buildEmailVerificationCard(state),
          ],
          const SizedBox(height: 20),
          _buildPersonalInfoCard(state),
          const SizedBox(height: 20),
          if (state.currentRole != 'admin') ...[
            _buildAddressCard(state),
            const SizedBox(height: 24),
          ],
          _buildSettingsSection(context, state),
          const SizedBox(height: 32),
          _buildLogoutButton(context, state),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  ImageProvider? _getAvatarImage(AppState state) {
    if (state.profileImageBytes != null) {
      return MemoryImage(state.profileImageBytes!);
    } else if (!kIsWeb &&
        state.profileImagePath != null &&
        state.profileImagePath!.isNotEmpty) {
      return FileImage(File(state.profileImagePath!));
    } else if (state.userProfile?['profile_image_url'] != null &&
        (state.userProfile!['profile_image_url'] as String).isNotEmpty) {
      return NetworkImage(state.userProfile!['profile_image_url']);
    }
    return null;
  }

  Future<void> _pickProfileImage(BuildContext context, AppState state) async {
    final ImagePicker picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_rounded,
                    color: AppColors.primary,
                  ),
                  title: Text(state.translate('choose_from_gallery')),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      final XFile? file = await picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 85,
                      );
                      if (file != null) {
                        if (kIsWeb) {
                          final bytes = await file.readAsBytes();
                          state.updateProfileImage(bytes: bytes);
                        } else {
                          state.updateProfileImage(path: file.path);
                        }
                      }
                    } catch (e) {
                      debugPrint('Error picking image from gallery: $e');
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt_rounded,
                    color: AppColors.primary,
                  ),
                  title: Text(state.translate('take_photo')),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      final XFile? file = await picker.pickImage(
                        source: ImageSource.camera,
                        imageQuality: 85,
                      );
                      if (file != null) {
                        if (kIsWeb) {
                          final bytes = await file.readAsBytes();
                          state.updateProfileImage(bytes: bytes);
                        } else {
                          state.updateProfileImage(path: file.path);
                        }
                      }
                    } catch (e) {
                      debugPrint('Error taking photo: $e');
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmailVerificationCard(AppState state) {
    return CustomCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: Colors.amber.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(Icons.mark_email_unread_outlined, color: Colors.amber.shade900),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.translate('verify_email_title'),
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  state.translate('verify_email_desc'),
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IntrinsicWidth(
            // CustomButton always sizes itself with width: double.infinity,
            // which needs a bounded-width parent (e.g. a Column) to resolve.
            // A bare Row gives unbounded width, so wrap it to constrain it.
            child: CustomButton(
              text: state.translate('verify_button'),
              height: 36,
              isLoading: _isSendingVerification,
              onPressed: _isSendingVerification ? null : () => _startEmailVerification(state),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startEmailVerification(AppState state) async {
    if (state.token == null) return;
    setState(() => _isSendingVerification = true);
    try {
      await AuthApi.sendVerificationEmail(state.token!);
      if (!mounted) return;
      AppSnackBar.success(context, state.translate('verification_email_sent'));
      _showVerifyCodeDialog(state);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, friendlyApiError(state, e));
    } finally {
      if (mounted) setState(() => _isSendingVerification = false);
    }
  }

  void _showVerifyCodeDialog(AppState state) {
    final codeController = TextEditingController();
    bool isVerifying = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(state.translate('verify_email_title'), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(state.translate('enter_verification_code'), style: GoogleFonts.inter(fontSize: 13)),
              const SizedBox(height: 12),
              CustomInput(
                label: '',
                hintText: '000000',
                controller: codeController,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(state.translate('cancel')),
            ),
            TextButton(
              onPressed: isVerifying
                  ? null
                  : () async {
                      final code = codeController.text.trim();
                      if (code.isEmpty || state.token == null) return;
                      setDialogState(() => isVerifying = true);
                      try {
                        await AuthApi.verifyEmail(state.token!, code);
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        if (!mounted) return;
                        setState(() => _justVerifiedEmail = true);
                        _showPremiumStatusDialog(
                          context: context,
                          isSuccess: true,
                          title: state.translate('success'),
                          message: state.translate('email_verified_success'),
                        );
                      } catch (e) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() => isVerifying = false);
                        if (!mounted) return;
                        AppSnackBar.error(context, friendlyApiError(state, e));
                      }
                    },
              child: Text(state.translate('verify_button')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(AppState state) {
    final avatarImage = _getAvatarImage(state);

    return CustomCard(
      padding: const EdgeInsets.all(24),
      elevationLevel: 2,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _pickProfileImage(context, state),
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: avatarImage,
                  child: avatarImage == null
                      ? const Icon(
                          Icons.person_rounded,
                          size: 44,
                          color: AppColors.primary,
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
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
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    state.translate('role_${state.currentRole}').toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoCard(AppState state) {
    final profile = state.userProfile;
    final String email = profile?['email']?.toString() ?? state.translate('no_email');
    final String phone = profile?['phoneNumber']?.toString() ?? state.translate('no_phone');
    final String username = profile?['username'] ?? state.userName;

    return CustomCard(
      padding: const EdgeInsets.all(16),
      borderSide: const BorderSide(color: AppColors.outlineVariant, width: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                state.translate('personal_info'),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.onSurface,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: Text(state.translate('edit')),
                onPressed: () => _showPersonalInfoEditSheet(state),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildAddressRow(state.translate('username_label'), username),
          const Divider(height: 12),
          _buildAddressRow(state.translate('phone_label'), phone),
          const Divider(height: 12),
          _buildAddressRow(state.translate('email_label'), email),
        ],
      ),
    );
  }

  void _showPersonalInfoEditSheet(AppState state) {
    final profile = state.userProfile;
    final nameController = TextEditingController(
      text: profile?['username'] ?? state.userName,
    );
    final phoneController = TextEditingController(
      text: profile?['phoneNumber']?.toString() ?? '',
    );
    final emailController = TextEditingController(
      text: profile?['email']?.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    state.translate('edit_personal_info'),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  CustomInput(
                    label: state.translate('username_label'),
                    hintText: '',
                    controller: nameController,
                    validator: (v) => v == null || v.isEmpty
                        ? state.translate('please_enter_name')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  CustomInput(
                    label: state.translate('phone_label'),
                    hintText: '',
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    validator: (v) => v == null || v.isEmpty
                        ? state.translate('please_enter_name')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  CustomInput(
                    label: state.translate('email_label'),
                    hintText: '',
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v == null || v.isEmpty
                        ? state.translate('please_enter_name')
                        : null,
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: state.translate('save_profile'),
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        await state.updateProfileInfo(
                          username: nameController.text.trim(),
                          phoneNumber: phoneController.text.trim(),
                          email: emailController.text.trim(),
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddressCard(AppState state) {
    final profile = state.userProfile;
    final hasAddress = state.isLocationComplete;

    return CustomCard(
      padding: const EdgeInsets.all(16),
      borderSide: BorderSide(
        color: (hasAddress || state.currentRole == 'buyer')
            ? AppColors.outlineVariant
            : AppColors.error.withValues(alpha: 0.5),
        width: 1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                state.translate('current_address'),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.onSurface,
                ),
              ),
              if (state.currentRole == 'farmer' ||
                  state.currentRole == 'association') ...[
                if (state.hasPendingAddressRequest(state.userName))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.hourglass_empty_rounded,
                          size: 14,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          state.translate('address_change_pending'),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[900],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  TextButton.icon(
                    icon: const Icon(Icons.edit_location_alt_rounded, size: 16),
                    label: Text(state.translate('edit_address')),
                    onPressed: () => _showAddressEditSheet(state),
                  ),
              ] else ...[
                TextButton.icon(
                  icon: const Icon(Icons.edit_location_alt_rounded, size: 16),
                  label: Text(state.translate('edit_address')),
                  onPressed: () => _showAddressEditSheet(state),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (!hasAddress)
            if (state.currentRole == 'buyer')
              Text(
                state.translate('no_address_added'),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.outline,
                ),
              )
            else
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.error,
                    size: 20,
                  ),
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
                _buildAddressRow(
                  state.translate('province_city'),
                  state.translateLocation(profile?['province']),
                ),
                const Divider(height: 12),
                _buildAddressRow(
                  state.translate('district'),
                  state.translateLocation(profile?['district']),
                ),
                const Divider(height: 12),
                _buildAddressRow(
                  state.translate('commune'),
                  state.translateLocation(profile?['commune']),
                ),
                const Divider(height: 12),
                _buildAddressRow(
                  state.translate('village'),
                  state.translateLocation(profile?['village']),
                ),
                if (profile?['street_address'] != null &&
                    profile!['street_address']
                        .toString()
                        .trim()
                        .isNotEmpty) ...[
                  const Divider(height: 12),
                  _buildAddressRow(
                    state.translate('street_no'),
                    profile['street_address'],
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAddressRow(String label, dynamic value) {
    final state = Provider.of<AppState>(context, listen: false);
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
            value?.toString() ?? state.translate('not_specified'),
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
    final profile = state.userProfile;
    _streetController.text = profile?['street_address']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Consumer<AppState>(
        builder: (context, appState, _) {
          final provinces = appState.getProvincesMap();
          if (provinces.isEmpty) {
            appState.loadLocations();
            return Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 20),
                  Text(
                    appState.translate('loading_location_data'),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          }

          // Helper functions to resolve dynamic values (could be English name, Khmer name, or ID)
          // to their standard stable unique IDs.
          String findProvinceId(dynamic val) {
            if (val == null) return provinces.keys.first;
            final String valStr = val.toString().trim();
            if (provinces.containsKey(valStr)) return valStr;

            final rawProvinces =
                appState.rawLocations['provinces'] as List<dynamic>? ?? [];
            for (var p in rawProvinces) {
              final pNames = p['name'] as Map<String, dynamic>?;
              if (pNames?['en'] == valStr ||
                  pNames?['kh'] == valStr ||
                  p['id'] == valStr) {
                return p['id']?.toString() ?? provinces.keys.first;
              }
            }
            return provinces.keys.first;
          }

          String findDistrictId(dynamic val, String provId) {
            final districts = appState.getDistrictsMap(provId);
            if (districts.isEmpty) return '';
            if (val == null) return districts.keys.first;
            final String valStr = val.toString().trim();
            if (districts.containsKey(valStr)) return valStr;

            final rawProvinces =
                appState.rawLocations['provinces'] as List<dynamic>? ?? [];
            for (var p in rawProvinces) {
              if (p['id']?.toString() == provId) {
                for (var d in p['districts'] ?? []) {
                  final dNames = d['name'] as Map<String, dynamic>?;
                  if (dNames?['en'] == valStr ||
                      dNames?['kh'] == valStr ||
                      d['id'] == valStr) {
                    return d['id']?.toString() ?? districts.keys.first;
                  }
                }
              }
            }
            return districts.keys.first;
          }

          String findCommuneId(dynamic val, String distId) {
            final communes = appState.getCommunesMap(distId);
            if (communes.isEmpty) return '';
            if (val == null) return communes.keys.first;
            final String valStr = val.toString().trim();
            if (communes.containsKey(valStr)) return valStr;

            final rawProvinces =
                appState.rawLocations['provinces'] as List<dynamic>? ?? [];
            for (var p in rawProvinces) {
              for (var d in p['districts'] ?? []) {
                if (d['id']?.toString() == distId) {
                  for (var c in d['communes'] ?? []) {
                    final cNames = c['name'] as Map<String, dynamic>?;
                    if (cNames?['en'] == valStr ||
                        cNames?['kh'] == valStr ||
                        c['id'] == valStr) {
                      return c['id']?.toString() ?? communes.keys.first;
                    }
                  }
                }
              }
            }
            return communes.keys.first;
          }

          String findVillageId(dynamic val, String commId) {
            final villages = appState.getVillagesMap(commId);
            if (villages.isEmpty) return '';
            if (val == null) return villages.keys.first;
            final String valStr = val.toString().trim();
            if (villages.containsKey(valStr)) return valStr;

            final rawProvinces =
                appState.rawLocations['provinces'] as List<dynamic>? ?? [];
            for (var p in rawProvinces) {
              for (var d in p['districts'] ?? []) {
                for (var c in d['communes'] ?? []) {
                  if (c['id']?.toString() == commId) {
                    for (var v in c['villages'] ?? []) {
                      final vNames = v['name'] as Map<String, dynamic>?;
                      if (vNames?['en'] == valStr ||
                          vNames?['kh'] == valStr ||
                          v['id'] == valStr) {
                        return v['id']?.toString() ?? villages.keys.first;
                      }
                    }
                  }
                }
              }
            }
            return villages.keys.first;
          }

          String tempProvince = findProvinceId(profile?['province']);
          String tempDistrict = findDistrictId(
            profile?['district'],
            tempProvince,
          );
          String tempCommune = findCommuneId(profile?['commune'], tempDistrict);
          String tempVillage = findVillageId(profile?['village'], tempCommune);

          return StatefulBuilder(
            builder: (context, setSheetState) {
              // Resolve current maps based on cascades
              final provinceMap = state.getProvincesMap();
              if (!provinceMap.containsKey(tempProvince)) {
                tempProvince = provinceMap.isNotEmpty
                    ? provinceMap.keys.first
                    : '';
              }

              final districtMap = state.getDistrictsMap(tempProvince);
              if (!districtMap.containsKey(tempDistrict)) {
                tempDistrict = districtMap.isNotEmpty
                    ? districtMap.keys.first
                    : '';
              }

              final communeMap = state.getCommunesMap(tempDistrict);
              if (!communeMap.containsKey(tempCommune)) {
                tempCommune = communeMap.isNotEmpty
                    ? communeMap.keys.first
                    : '';
              }

              final villageMap = state.getVillagesMap(tempCommune);
              if (!villageMap.containsKey(tempVillage)) {
                tempVillage = villageMap.isNotEmpty
                    ? villageMap.keys.first
                    : '';
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
                          (state.currentRole == 'farmer' ||
                                  state.currentRole == 'association')
                              ? state.translate('update_farm_address')
                              : state.translate('update_current_address'),
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
                          itemsMap: provinceMap,
                          onChanged: (val) {
                            if (val != null) {
                              setSheetState(() {
                                tempProvince = val;
                                final dMap = state.getDistrictsMap(
                                  tempProvince,
                                );
                                tempDistrict = dMap.isNotEmpty
                                    ? dMap.keys.first
                                    : '';
                                final cMap = state.getCommunesMap(tempDistrict);
                                tempCommune = cMap.isNotEmpty
                                    ? cMap.keys.first
                                    : '';
                                final vMap = state.getVillagesMap(tempCommune);
                                tempVillage = vMap.isNotEmpty
                                    ? vMap.keys.first
                                    : '';
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        // District Dropdown
                        _buildDropdownField(
                          label: state.translate('district'),
                          value: tempDistrict,
                          itemsMap: districtMap,
                          onChanged: (val) {
                            if (val != null) {
                              setSheetState(() {
                                tempDistrict = val;
                                final cMap = state.getCommunesMap(tempDistrict);
                                tempCommune = cMap.isNotEmpty
                                    ? cMap.keys.first
                                    : '';
                                final vMap = state.getVillagesMap(tempCommune);
                                tempVillage = vMap.isNotEmpty
                                    ? vMap.keys.first
                                    : '';
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        // Commune Dropdown
                        _buildDropdownField(
                          label: state.translate('commune'),
                          value: tempCommune,
                          itemsMap: communeMap,
                          onChanged: (val) {
                            if (val != null) {
                              setSheetState(() {
                                tempCommune = val;
                                final vMap = state.getVillagesMap(tempCommune);
                                tempVillage = vMap.isNotEmpty
                                    ? vMap.keys.first
                                    : '';
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        // Village Dropdown
                        _buildDropdownField(
                          label: state.translate('village'),
                          value: tempVillage,
                          itemsMap: villageMap,
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
                          label: state.translate('street_no'),
                          hintText: state.translate('street_hint'),
                          controller: _streetController,
                        ),
                        const SizedBox(height: 24),
                        CustomButton(
                          text:
                              (state.currentRole == 'farmer' ||
                                  state.currentRole == 'association')
                              ? state.translate('request_address_update')
                              : state.translate('save_address_details'),
                          onPressed: () async {
                            if (state.currentRole == 'farmer' ||
                                state.currentRole == 'association') {
                              final String? err = await state
                                  .submitAddressRequest(
                                    province: tempProvince,
                                    district: tempDistrict,
                                    commune: tempCommune,
                                    village: tempVillage,
                                    streetAddress: _streetController.text
                                        .trim(),
                                  );
                              if (context.mounted) {
                                if (err != null) {
                                  _showPremiumStatusDialog(
                                    context: context,
                                    isSuccess: false,
                                    title: state.translate(
                                      'err_failed_request',
                                    ),
                                    message:
                                        err ==
                                            'ADDRESS_CHANGE_REQUEST_ALREADY_PENDING'
                                        ? state.translate('err_already_pending')
                                        : translateErrorCode(state, err),
                                  );
                                } else {
                                  _showPremiumStatusDialog(
                                    context: context,
                                    isSuccess: true,
                                    title: state.translate('success'),
                                    message: state.translate(
                                      'address_request_submitted',
                                    ),
                                    onClose: () {
                                      Navigator.pop(context);
                                    },
                                  );
                                }
                              }
                            } else {
                              state.updateProfileLocation(
                                province: tempProvince,
                                district: tempDistrict,
                                commune: tempCommune,
                                village: tempVillage,
                                streetAddress: _streetController.text.trim(),
                              );
                              Navigator.pop(context);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required Map<String, String> itemsMap,
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
            value: value.isEmpty ? null : value,
            isExpanded: true,
            underline: const SizedBox(),
            items: itemsMap.entries.map((entry) {
              return DropdownMenuItem(
                value: entry.key,
                child: Text(
                  entry.value,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.onSurface,
                  ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 14.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.language_rounded,
                          color: AppColors.primary,
                        ),
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
              if (state.currentRole != 'buyer' &&
                  state.currentRole != 'farmer') ...[
                const Divider(height: 1),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: const Icon(
                    Icons.receipt_long_rounded,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    state.translate('wholesale_history'),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    state.translate('wholesale_history_desc'),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.outline,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const OrderContractHistoryScreen(isPushed: true),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
              ],
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                leading: const Icon(
                  Icons.settings_suggest_rounded,
                  color: AppColors.primary,
                ),
                title: Text(
                  state.translate('verification_docs'),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  state.translate('required_for_farmers'),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.outline,
                ),
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                leading: const Icon(
                  Icons.help_outline_rounded,
                  color: AppColors.primary,
                ),
                title: Text(
                  state.translate('help_disputes'),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.outline,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HelpDisputesScreen()),
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

  void _showPremiumStatusDialog({
    required BuildContext context,
    required bool isSuccess,
    required String title,
    required String message,
    VoidCallback? onClose,
  }) {
    final state = Provider.of<AppState>(context, listen: false);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curve,
          child: FadeTransition(
            opacity: anim1,
            child: AlertDialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              contentPadding: EdgeInsets.zero,
              content: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: (isSuccess ? Colors.teal : Colors.redAccent)
                            .withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: (isSuccess ? Colors.teal : Colors.redAccent)
                                .withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isSuccess
                                ? Icons.check_circle_outline_rounded
                                : Icons.error_outline_rounded,
                            size: 52,
                            color: isSuccess ? Colors.teal : Colors.redAccent,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              if (onClose != null) onClose();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSuccess
                                  ? Colors.teal
                                  : Colors.redAccent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              isSuccess ? state.translate('ok') : state.translate('close'),
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
