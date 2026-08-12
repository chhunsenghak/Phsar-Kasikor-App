import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../services/api/dispute_api.dart';
import '../../services/api/order_api.dart';
import '../../services/api/contract_api.dart';
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

  @override
  void initState() {
    super.initState();
    _loadDisputeCount();
    _loadPendingPaymentCount();
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
                value: '124',
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
                value: '1',
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
          const SizedBox(height: 24),

          // Platform Activities Log
          Text(
            state.translate('system_activity_log'),
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          CustomCard(
            padding: EdgeInsets.zero,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final logs = [
                  {'event': 'Farmer Chan Sopheap published "Organic Jasmine Rice"', 'time': '10 mins ago', 'type': 'listing'},
                  {'event': 'Buyer Kosal Pich registered new profile', 'time': '40 mins ago', 'type': 'user'},
                  {'event': 'Farmer Rithy Seng uploaded verification certificate', 'time': '1 hour ago', 'type': 'verification'},
                  {'event': 'Listing "Fake Chemicals" flagged for removal', 'time': '3 hours ago', 'type': 'moderation'},
                ];

                final log = logs[index];
                IconData logIcon = Icons.info_outline_rounded;
                Color logColor = AppColors.primary;

                if (log['type'] == 'user') {
                  logIcon = Icons.person_add_outlined;
                  logColor = AppColors.secondary;
                } else if (log['type'] == 'verification') {
                  logIcon = Icons.file_present_rounded;
                  logColor = Colors.amber[800]!;
                } else if (log['type'] == 'moderation') {
                  logIcon = Icons.report_problem_outlined;
                  logColor = AppColors.error;
                }

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: logColor.withValues(alpha: 0.1),
                    child: Icon(logIcon, color: logColor, size: 20),
                  ),
                  title: Text(
                    log['event']!,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  trailing: Text(
                    log['time']!,
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.outline),
                  ),
                );
              },
            ),
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
