import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../services/api/cooperative_api.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/app_snackbar.dart';
import 'sales_analytics.dart';

class FarmerDashboardScreen extends StatelessWidget {
  const FarmerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);

    final activeBids = state.negotiations.where((n) {
      final p = n.product;
      final isMyId = (p.sellerId != null && state.userProfile != null && p.sellerId == state.userProfile!['id']);
      final isMyName = p.farmerName.toLowerCase().contains('sopheap') ||
                       p.farmerName.toLowerCase().contains('sok_farmer') ||
                       p.farmerName.toLowerCase().contains('sokha') ||
                       p.farmerName.toLowerCase().contains('cooperative') ||
                       (state.userProfile != null && p.farmerName == state.userProfile!['username']);
      return isMyId || isMyName;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 20),
            const _CoopInvitationsBanner(),
            _buildPerformanceStats(context, activeBids),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final state = Provider.of<AppState>(context, listen: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.translate('farmer_dashboard'),
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          state.translate('manage_crops_subtitle'),
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceStats(BuildContext context, List<BidOffer> activeBids) {
    final state = Provider.of<AppState>(context, listen: false);
    return Row(
      children: [
        Expanded(
          child: CustomCard(
            padding: const EdgeInsets.all(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SalesAnalyticsScreen(),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.monetization_on_outlined, color: AppColors.primary, size: 24),
                const SizedBox(height: 8),
                Text(
                  '\$1,420.00',
                  style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                const SizedBox(height: 2),
                Text(
                  state.translate('total_revenue_trend'),
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CustomCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.gavel_outlined, color: AppColors.secondary, size: 24),
                const SizedBox(height: 8),
                Text(
                  '${activeBids.length}',
                  style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.secondary),
                ),
                const SizedBox(height: 2),
                Text(
                  state.translate('active_negotiations'),
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Pending cooperative invitations addressed to the current farmer — lets
/// them accept or decline directly from the dashboard, since there's no
/// dedicated cooperative-membership screen for the farmer side.
class _CoopInvitationsBanner extends StatefulWidget {
  const _CoopInvitationsBanner();

  @override
  State<_CoopInvitationsBanner> createState() => _CoopInvitationsBannerState();
}

class _CoopInvitationsBannerState extends State<_CoopInvitationsBanner> {
  List<dynamic> _invitations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = Provider.of<AppState>(context, listen: false);
    if (state.token == null) return;
    try {
      final list = await CooperativeApi.fetchMyInvitations(state.token!);
      if (mounted) {
        setState(() {
          _invitations = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _respond(String memberId, bool accept) async {
    final state = Provider.of<AppState>(context, listen: false);
    if (state.token == null) return;
    try {
      await CooperativeApi.respondToInvitation(state.token!, memberId, accept);
      _load();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, state.translate('failed_update_status', arguments: {'error': e.toString()}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    if (_isLoading || _invitations.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.translate('my_coop_invitations'),
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface),
          ),
          const SizedBox(height: 12),
          ..._invitations.map((inv) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: CustomCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          state.translate('coop_invitation_prompt', arguments: {'coop': inv['cooperative_name'] ?? ''}),
                          style: GoogleFonts.inter(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => _respond(inv['id'], false),
                        child: Text(state.translate('decline')),
                      ),
                      const SizedBox(width: 4),
                      IntrinsicWidth(
                        // CustomButton always sizes itself with width:
                        // double.infinity, which needs a bounded-width
                        // parent to resolve — a bare Row gives unbounded
                        // width, so wrap it to constrain it.
                        child: CustomButton(
                          text: state.translate('accept'),
                          height: 36,
                          onPressed: () => _respond(inv['id'], true),
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
