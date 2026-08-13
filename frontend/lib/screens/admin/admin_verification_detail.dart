import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/app_snackbar.dart';
import '../../utils/api_error.dart';

class AdminVerificationDetailScreen extends StatelessWidget {
  final FarmerCertificate verification;

  const AdminVerificationDetailScreen({super.key, required this.verification});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context, listen: false);

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
          state.translate('cert_review_details'),
          style: GoogleFonts.inter(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              verification.farmerName,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  _buildDetailRow(state.translate('certification_standard'), state.translate('cert_type_${verification.certificateType}')),
                  if (verification.issuingBody != null && verification.issuingBody!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildDetailRow(state.translate('issuing_authority'), verification.issuingBody!),
                  ],
                  const SizedBox(height: 12),
                  _buildDetailRow(state.translate('document_file'), verification.resolvedDocumentUrl, isImage: true),
                  const SizedBox(height: 12),
                  _buildDetailRow(state.translate('current_status'), verification.status.toUpperCase()),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              state.translate('review_actions'),
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: state.translate('approve_verify'),
                    icon: Icons.check_circle_outline_rounded,
                    onPressed: () async {
                      final errorCode = await state.reviewFarmerCertificate(verification.id, 'approved');
                      if (!context.mounted) return;
                      if (errorCode != null) {
                        AppSnackBar.error(context, translateErrorCode(state, errorCode));
                        return;
                      }
                      Navigator.pop(context);
                      AppSnackBar.success(context, state.translate('approved_verified_msg', arguments: {'name': verification.farmerName}));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomButton.secondary(
                    text: state.translate('decline'),
                    icon: Icons.cancel_outlined,
                    backgroundColor: AppColors.errorContainer,
                    textColor: AppColors.onErrorContainer,
                    onPressed: () async {
                      final errorCode = await state.reviewFarmerCertificate(verification.id, 'rejected');
                      if (!context.mounted) return;
                      if (errorCode != null) {
                        AppSnackBar.error(context, translateErrorCode(state, errorCode));
                        return;
                      }
                      Navigator.pop(context);
                      AppSnackBar.warning(context, state.translate('declined_verification_msg', arguments: {'name': verification.farmerName}));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isImage = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.outline,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        if (isImage && (value.startsWith('http') || value.startsWith('/')))
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              value,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          )
        else
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}
