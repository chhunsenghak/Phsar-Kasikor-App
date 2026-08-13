import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../services/api/dispute_api.dart';
import '../../services/api/order_api.dart';
import '../../services/api/contract_api.dart';
import '../../services/api/reports_api.dart';
import '../../services/api/user_api.dart';
import '../../widgets/custom_card.dart';
import 'dispute_resolution_screen.dart';
import 'payment_confirmation_screen.dart';

class AdminDashboardOverviewScreen extends StatefulWidget {
  const AdminDashboardOverviewScreen({super.key});

  @override
  State<AdminDashboardOverviewScreen> createState() => _AdminDashboardOverviewScreenState();
}

class _AdminDashboardOverviewScreenState extends State<AdminDashboardOverviewScreen> {
  int _openDisputeCount = 0;
  int _pendingPaymentCount = 0;
  int _totalFarmerCount = 0;
  int _flaggedContentCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDisputeCount();
    _loadPendingPaymentCount();
    _loadFarmerCount();
    _loadFlaggedContentCount();
  }

  Future<void> _loadFarmerCount() async {
    final state = Provider.of<AppState>(context, listen: false);
    if (state.token == null) return;
    try {
      final users = await UserApi.fetchAllUsers(state.token!);
      if (!mounted) return;
      // role_id 3 == FARMER — the same convention AppState already uses to
      // resolve a logged-in user's role (see base_app_state.dart).
      setState(() {
        _totalFarmerCount = users.where((u) => u['role_id'] == 3).length;
      });
    } catch (_) {
      // Stat card just keeps showing 0 if this fails — not critical to the
      // rest of the dashboard.
    }
  }

  Future<void> _loadFlaggedContentCount() async {
    final state = Provider.of<AppState>(context, listen: false);
    if (state.token == null) return;
    try {
      final reports = await ReportsApi.fetchAdminReports(state.token!);
      if (!mounted) return;
      setState(() {
        _flaggedContentCount = reports.where((r) => r['status'] == 'pending').length;
      });
    } catch (_) {
      // Stat card just keeps showing 0 if this fails — not critical to the
      // rest of the dashboard.
    }
  }

  Future<void> _loadDisputeCount() async {
    final state = Provider.of<AppState>(context, listen: false);
    if (state.token == null) return;
    try {
      final disputes = await DisputeApi.fetchAllDisputes(state.token!);
      if (!mounted) return;
      setState(() {
        _openDisputeCount = disputes.where((d) => d['status'] == 'OPEN').length;
      });
    } catch (_) {
      // Stat card just keeps showing 0 if this fails — not critical to the
      // rest of the dashboard.
    }
  }

  Future<void> _loadPendingPaymentCount() async {
    final state = Provider.of<AppState>(context, listen: false);
    if (state.token == null) return;
    try {
      final results = await Future.wait([
        OrderApi.fetchPendingKhqrPayments(state.token!),
        ContractApi.fetchPendingDeposits(state.token!),
        ContractApi.fetchPendingFinalPayments(state.token!),
      ]);
      if (!mounted) return;
      setState(() => _pendingPaymentCount = results[0].length + results[1].length + results[2].length);
    } catch (_) {
      // Stat card just keeps showing 0 if this fails — not critical to the
      // rest of the dashboard.
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final verifications = state.verifications.where((v) => v.status == 'pending').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hello Header
          Text(
            state.translate('system_control_panel'),
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            state.translate('system_control_subtitle'),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),

          // Overview stats
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _buildAdminStatCard(
                label: state.translate('total_farmers'),
                value: '$_totalFarmerCount',
                icon: Icons.agriculture_rounded,
                color: AppColors.primary,
              ),
              _buildAdminStatCard(
                label: state.translate('pending_reviews'),
                value: '${verifications.length}',
                icon: Icons.hourglass_empty_rounded,
                color: Colors.amber[900]!,
              ),
              _buildAdminStatCard(
                label: state.translate('flagged_content'),
                value: '$_flaggedContentCount',
                icon: Icons.flag_rounded,
                color: AppColors.error,
              ),
              _buildAdminStatCard(
                label: state.translate('open_disputes'),
                value: '$_openDisputeCount',
                icon: Icons.gavel_rounded,
                color: AppColors.tertiary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DisputeResolutionScreen()),
                  ).then((_) => _loadDisputeCount());
                },
              ),
              _buildAdminStatCard(
                label: state.translate('pending_payments'),
                value: '$_pendingPaymentCount',
                icon: Icons.qr_code_2_rounded,
                color: Colors.blue.shade700,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PaymentConfirmationScreen()),
                  ).then((_) => _loadPendingPaymentCount());
                },
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAdminStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return CustomCard(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              const Icon(Icons.arrow_outward_rounded, size: 16, color: AppColors.outline),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
