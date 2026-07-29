import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';

class AdminVerificationDetailScreen extends StatelessWidget {
  final FarmerVerification verification;

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
          'Certificate Review Details',
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
                              verification.name,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Location: ${verification.location}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  _buildDetailRow('Farm Name', verification.farmName),
                  const SizedBox(height: 12),
                  _buildDetailRow('Cultivated Crops', verification.cropTypes),
                  const SizedBox(height: 12),
                  _buildDetailRow('Certification Standard', verification.certType.toUpperCase()),
                  const SizedBox(height: 12),
                  _buildDetailRow('Document File', verification.resolvedDocUrl),
                  const SizedBox(height: 12),
                  _buildDetailRow('Current Status', verification.status.toUpperCase()),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Review Actions',
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
                    text: 'Approve & Verify',
                    icon: Icons.check_circle_outline_rounded,
                    onPressed: () {
                      state.approveFarmer(verification.id);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Approved and verified ${verification.name}')),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomButton.secondary(
                    text: 'Decline',
                    icon: Icons.cancel_outlined,
                    backgroundColor: AppColors.errorContainer,
                    textColor: AppColors.onErrorContainer,
                    onPressed: () {
                      state.rejectFarmer(verification.id);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Declined verification for ${verification.name}')),
                      );
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

  Widget _buildDetailRow(String label, String value) {
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
        if (label == 'Document File' && (value.startsWith('http') || value.startsWith('/')))
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
