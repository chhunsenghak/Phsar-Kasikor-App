import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_input.dart';
import '../../widgets/app_snackbar.dart';
import '../../services/api/farmer_certificate_api.dart';
import '../../services/api/upload_api.dart';
import '../../utils/api_error.dart';

class SubmitCertificateScreen extends StatefulWidget {
  const SubmitCertificateScreen({super.key});

  @override
  State<SubmitCertificateScreen> createState() => _SubmitCertificateScreenState();
}

class _SubmitCertificateScreenState extends State<SubmitCertificateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authorityController = TextEditingController();

  XFile? _selectedImageFile;
  Uint8List? _selectedImageBytes;
  String _selectedCertType = 'organic';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _authorityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageFile = image;
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (!mounted) return;
      final state = Provider.of<AppState>(context, listen: false);
      AppSnackBar.error(context, state.translate('failed_pick_image', arguments: {'error': e.toString()}));
    }
  }

  Future<void> _submit(AppState state) async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImageBytes == null || _selectedImageFile == null) {
      AppSnackBar.error(context, state.translate('please_upload_image_error'));
      return;
    }
    
    final String? token = state.token;
    if (token == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final String docUrl = await UploadApi.uploadImage(
        token,
        _selectedImageBytes!,
        _selectedImageFile!.name,
      );

      await FarmerCertificateApi.submitCertificate(token, {
        'certificate_type': _selectedCertType,
        'issuing_body': _authorityController.text,
        'document_url': docUrl,
      });
      await state.refreshFarmerCertificates();

      if (mounted) {
        AppSnackBar.success(context, state.translate('cert_submit_success'));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, state.translate('cert_submit_failed', arguments: {'error': friendlyApiError(state, e)}));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          state.translate('submit_verification_docs'),
          style: GoogleFonts.inter(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      size: 48,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      state.translate('farmer_identity_verification'),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      state.translate('identity_verification_desc'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildPhotoUploader(state),
              const SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.translate('certification_standard_class'),
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
                      value: _selectedCertType,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: [
                        DropdownMenuItem(value: 'organic', child: Text(state.translate('cert_type_organic'))),
                        DropdownMenuItem(value: 'gap', child: Text(state.translate('cert_type_gap'))),
                        DropdownMenuItem(value: 'gi', child: Text(state.translate('cert_type_gi'))),
                        DropdownMenuItem(value: 'general', child: Text(state.translate('cert_type_general'))),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedCertType = val;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CustomInput(
                label: state.translate('issuing_authority'),
                hintText: state.translate('issuing_authority_hint'),
                controller: _authorityController,
                validator: (val) => val == null || val.isEmpty ? state.translate('please_enter_authority') : null,
              ),
              const SizedBox(height: 32),
              if (_isSubmitting)
                const Center(child: CircularProgressIndicator(color: AppColors.primary))
              else
                CustomButton(
                  text: state.translate('submit_credentials'),
                  icon: Icons.send_rounded,
                  onPressed: () => _submit(state),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoUploader(AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.translate('cert_photo_scan'),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: CustomCard(
            padding: _selectedImageBytes != null
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(vertical: 40),
            backgroundColor: AppColors.surfaceContainerLow,
            borderSide: const BorderSide(color: AppColors.outlineVariant, style: BorderStyle.solid),
            child: _selectedImageBytes != null
                ? SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        Image.memory(
                          _selectedImageBytes!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                        Container(
                          color: Colors.black38,
                          child: const Center(
                            child: Icon(Icons.edit_rounded, color: Colors.white, size: 36),
                          ),
                        ),
                      ],
                    ),
                  )
                : Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.add_photo_alternate_rounded,
                          size: 48,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.translate('upload_license_image'),
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          state.translate('supports_image_specs'),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
