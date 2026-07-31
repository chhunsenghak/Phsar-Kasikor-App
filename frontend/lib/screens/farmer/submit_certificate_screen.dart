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
import '../../services/api/farmer_certificate_api.dart';
import '../../services/api/upload_api.dart';

class SubmitCertificateScreen extends StatefulWidget {
  const SubmitCertificateScreen({super.key});

  @override
  State<SubmitCertificateScreen> createState() => _SubmitCertificateScreenState();
}

class _SubmitCertificateScreenState extends State<SubmitCertificateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  final _authorityController = TextEditingController();
  final _issueDateController = TextEditingController(text: '2026-01-01');
  final _expiryDateController = TextEditingController(text: '2027-12-31');

  XFile? _selectedImageFile;
  Uint8List? _selectedImageBytes;
  String _selectedCertType = 'organic';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _authorityController.dispose();
    _issueDateController.dispose();
    _expiryDateController.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> _submit(AppState state) async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImageBytes == null || _selectedImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.translate('please_upload_image_error'))),
      );
      return;
    }
    
    setState(() {
      _isSubmitting = true;
    });

    final String? token = state.token;
    String docUrl = '';

    try {
      // Upload certificate image first
      try {
        if (token != null) {
          docUrl = await UploadApi.uploadImage(
            token,
            _selectedImageBytes!,
            _selectedImageFile!.name,
          );
        } else {
          docUrl = _selectedImageFile!.name;
        }
      } catch (e) {
        debugPrint('Image upload failed: $e');
        docUrl = 'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?q=80&w=600';
      }

      if (token != null) {
        await FarmerCertificateApi.submitCertificate(token, {
          'certificate_name': _nameController.text,
          'certificate_number': _numberController.text,
          'issuing_authority': _authorityController.text,
          'issue_date': _issueDateController.text,
          'expiry_date': _expiryDateController.text,
          'validity_status': 'UNDER_REVIEW',
          'doc_url': docUrl,
        });
      }

      // Add to local state so the admin dashboard queue works immediately in prototyping
      final newVerification = FarmerVerification(
        id: 'v_${DateTime.now().millisecondsSinceEpoch}',
        name: state.userName,
        farmName: _authorityController.text.isNotEmpty ? _authorityController.text : 'My Family Farm',
        location: 'Battambang',
        cropTypes: _nameController.text,
        docUrl: docUrl,
        certType: _selectedCertType,
        status: 'pending',
      );
      state.addVerification(newVerification);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.translate('cert_submit_success'))),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.translate('cert_submit_failed', arguments: {'error': e.toString()}))),
        );
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
                label: state.translate('cert_name_type'),
                hintText: state.translate('cert_name_hint'),
                controller: _nameController,
                validator: (val) => val == null || val.isEmpty ? state.translate('please_enter_name') : null,
              ),
              const SizedBox(height: 16),
              CustomInput(
                label: state.translate('cert_number'),
                hintText: state.translate('cert_number_hint'),
                controller: _numberController,
                validator: (val) => val == null || val.isEmpty ? state.translate('please_enter_number') : null,
              ),
              const SizedBox(height: 16),
              CustomInput(
                label: state.translate('issuing_authority'),
                hintText: state.translate('issuing_authority_hint'),
                controller: _authorityController,
                validator: (val) => val == null || val.isEmpty ? state.translate('please_enter_authority') : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CustomInput(
                      label: state.translate('issue_date'),
                      hintText: 'YYYY-MM-DD',
                      controller: _issueDateController,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomInput(
                      label: state.translate('expiry_date'),
                      hintText: 'YYYY-MM-DD',
                      controller: _expiryDateController,
                    ),
                  ),
                ],
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
