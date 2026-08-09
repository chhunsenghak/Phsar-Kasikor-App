import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../utils/api_error.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/app_snackbar.dart';
import 'admin_verification_detail.dart';

class RefinedFarmerVerificationQueueScreen extends StatelessWidget {
  const RefinedFarmerVerificationQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final pendingVerifications = state.verifications.where((v) => v.status == 'pending').toList();
    final pendingAddresses = state.addressRequests.where((r) => r.status == 'pending').toList();

    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              state.translate('address_change_requests_queue'),
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.outline,
              indicatorColor: AppColors.primary,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 14),
              tabs: [
                Tab(text: state.translate('verifications')),
                Tab(text: state.translate('address_requests')),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                children: [
                  _buildVerificationTab(context, state, pendingVerifications),
                  _buildAddressRequestsTab(context, state, pendingAddresses),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationTab(BuildContext context, AppState state, List<FarmerVerification> pendingVerifications) {
    if (pendingVerifications.isEmpty) {
      return _buildEmptyState(
        state.translate('all_caught_up'),
        state.translate('no_new_alerts'),
      );
    }
    return ListView.separated(
      itemCount: pendingVerifications.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final item = pendingVerifications[index];

        return CustomCard(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AdminVerificationDetailScreen(verification: item),
              ),
            );
          },
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.name,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.onSurface,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      state.translate('pending_audit'),
                      style: GoogleFonts.inter(
                        color: Colors.amber[900],
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoRow(state.translate('farm_name'), item.farmName),
              const SizedBox(height: 6),
              _buildInfoRow(state.translate('location_label'), item.location),
              const SizedBox(height: 6),
              _buildInfoRow(state.translate('crop_focus'), item.cropTypes),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppDesign.borderRadiusSm),
                  border: Border.all(color: AppColors.outlineVariant, width: 0.5),
                ),
                child: Row(
                  children: [
                    Icon(
                      item.resolvedDocUrl.startsWith('http') || item.resolvedDocUrl.startsWith('/')
                          ? Icons.image_rounded
                          : Icons.picture_as_pdf_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.resolvedDocUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      state.translate('preview_label'),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    )
                  ],
                ),
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: state.translate('accept'),
                      height: 44,
                      onPressed: () {
                        state.approveFarmer(item.id);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomButton.secondary(
                      text: state.translate('reject'),
                      height: 44,
                      backgroundColor: AppColors.errorContainer,
                      textColor: AppColors.onErrorContainer,
                      onPressed: () {
                        state.rejectFarmer(item.id);
                      },
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddressRequestsTab(BuildContext context, AppState state, List<AddressChangeRequest> pendingAddresses) {
    if (pendingAddresses.isEmpty) {
      return _buildEmptyState(
        state.translate('all_caught_up'),
        state.translate('no_new_alerts'),
      );
    }
    return ListView.separated(
      itemCount: pendingAddresses.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final item = pendingAddresses[index];
        final oldStreetStr = (item.oldAddress['street_address'] != null && item.oldAddress['street_address']!.isNotEmpty)
            ? ' (${item.oldAddress['street_address']})'
            : '';
        final oldAddr = '${state.translateLocation(item.oldAddress['province'])}, ${state.translateLocation(item.oldAddress['district'])}, ${state.translateLocation(item.oldAddress['commune'])}, ${state.translateLocation(item.oldAddress['village'])}'
            '$oldStreetStr';

        final newStreetStr = (item.newAddress['street_address'] != null && item.newAddress['street_address']!.isNotEmpty)
            ? ' (${item.newAddress['street_address']})'
            : '';
        final newAddr = '${state.translateLocation(item.newAddress['province'])}, ${state.translateLocation(item.newAddress['district'])}, ${state.translateLocation(item.newAddress['commune'])}, ${state.translateLocation(item.newAddress['village'])}'
            '$newStreetStr';

        return CustomCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.username,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.onSurface,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      state.translate('pending_review_badge'),
                      style: GoogleFonts.inter(
                        color: Colors.amber[900],
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildAddressComparisonRow(state.translate('from_address'), oldAddr),
              const SizedBox(height: 8),
              _buildAddressComparisonRow(state.translate('to_address'), newAddr, highlight: true),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: state.translate('accept'),
                      height: 44,
                      onPressed: () async {
                        final errorCode = await state.approveAddressRequest(item.id);
                        if (errorCode != null && context.mounted) {
                          AppSnackBar.error(context, translateErrorCode(state, errorCode));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomButton.secondary(
                      text: state.translate('reject'),
                      height: 44,
                      backgroundColor: AppColors.errorContainer,
                      textColor: AppColors.onErrorContainer,
                      onPressed: () async {
                        final errorCode = await state.rejectAddressRequest(item.id);
                        if (errorCode != null && context.mounted) {
                          AppSnackBar.error(context, translateErrorCode(state, errorCode));
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddressComparisonRow(String label, String value, {bool highlight = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 55,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: highlight ? AppColors.primary : AppColors.outline,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: highlight ? AppColors.primary : AppColors.onSurface,
              fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            '$label:',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.outline, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurface, fontWeight: FontWeight.w600),
          ),
        )
      ],
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              size: 64,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
