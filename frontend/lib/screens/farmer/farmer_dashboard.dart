import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../services/api/analytics_api.dart';
import '../../services/api/cooperative_api.dart';
import '../../services/api/order_api.dart';
import '../../utils/api_error.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/dashboard/dashboard_hero_header.dart';
import '../../utils/currency_format.dart';
import '../common/chat_inbox_screen.dart';
import 'sales_analytics.dart';

class FarmerDashboardScreen extends StatefulWidget {
  const FarmerDashboardScreen({super.key});

  @override
  State<FarmerDashboardScreen> createState() => _FarmerDashboardScreenState();
}

class _FarmerDashboardScreenState extends State<FarmerDashboardScreen> {
  bool _isLoadingStats = true;
  // {currency: total} — see sales_analytics.dart for why USD and KHR
  // revenue is never blended into one number.
  Map<String, double> _revenueByCurrency = {};
  List<dynamic> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final state = Provider.of<AppState>(context, listen: false);
    if (state.token == null) {
      setState(() => _isLoadingStats = false);
      return;
    }
    try {
      final results = await Future.wait([
        AnalyticsApi.fetchFarmerSalesAnalytics(state.token!),
        OrderApi.fetchOrders(state.token!),
      ]);
      final analytics = results[0] as Map<String, dynamic>;
      final orders = results[1] as List<dynamic>;

      final revenueByCurrency = <String, double>{};
      for (final entry in (analytics['revenue_by_currency'] as List? ?? [])) {
        revenueByCurrency[entry['currency']?.toString() ?? 'USD'] = (entry['amount'] as num?)?.toDouble() ?? 0.0;
      }

      if (mounted) {
        setState(() {
          _revenueByCurrency = revenueByCurrency;
          _orders = orders;
          _isLoadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);

    final myId = state.userProfile?['id'];
    final myContracts = state.negotiations.where((n) => n.sellerId != null && n.sellerId == myId).toList();
    // "Active" excludes deals that are already fully done or fell through —
    // COMPLETED/TERMINATED contracts still count toward totalContracts
    // below, but they're not something the farmer needs to act on anymore.
    const closedStatuses = {'COMPLETED', 'TERMINATED'};
    final activeBids = myContracts.where((n) => !closedStatuses.contains(n.contractStatus)).toList();

    final myOrders = _orders.where((o) => (o as Map<String, dynamic>)['seller_id'] == myId).toList();
    // Mirrors the same gating the order-history sheet uses before it'll
    // show a farmer a "next step" action button: paid, and still short of
    // DELIVERED — anything else needs no attention from them right now.
    const actionableStatuses = {'PLACED', 'CONFIRMED', 'SHIPPED'};
    final pendingActionsCount = myOrders
        .where((o) => (o as Map<String, dynamic>)['payment_status'] == 'PAID' && actionableStatuses.contains(o['order_status']))
        .length;

    // Every distinct buyer this farmer has ever done business with, across
    // both one-off orders and wholesale contracts.
    final customerIds = <String>{
      ...myOrders.map((o) => (o as Map<String, dynamic>)['buyer_id']?.toString()).whereType<String>(),
      ...myContracts.map((n) => n.buyerId).whereType<String>(),
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Full-bleed, unlike the padded content below — the hero motif
            // only reads as a hero when it spans edge to edge.
            _buildHeroHeader(context),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _CoopInvitationsBanner(),
                  _buildPerformanceStats(
                    context,
                    activeBids: activeBids,
                    totalContracts: myContracts.length,
                    totalCustomers: customerIds.length,
                    pendingActionsCount: pendingActionsCount,
                  ),
                  const SizedBox(height: 24),
                  _buildQuickActions(context),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context) {
    final state = Provider.of<AppState>(context, listen: false);
    return DashboardHeroHeader(
      title: state.translate('farmer_dashboard'),
      subtitle: state.translate('manage_crops_subtitle'),
      metricIcon: Icons.monetization_on_rounded,
      metricLabel: state.translate('yearly_sales_revenue'),
      onTapMetric: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SalesAnalyticsScreen()),
      ),
      metric: _isLoadingStats
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          // Both currencies, always — even at $0/៛0 — since Cambodia trades
          // in both and a farmer with only KHR orders so far shouldn't look
          // like USD isn't tracked at all. Never blended into one number:
          // there's no exchange rate anywhere in this app. Always on
          // separate lines, not side by side, so neither currency reads as
          // an afterthought.
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatCurrency(_revenueByCurrency['USD'] ?? 0.0, 'USD'),
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  formatCurrency(_revenueByCurrency['KHR'] ?? 0.0, 'KHR'),
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final state = Provider.of<AppState>(context, listen: false);
    return CustomCard(
      padding: const EdgeInsets.all(4),
      elevationLevel: 2,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ChatInboxScreen()),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary),
        ),
        title: Text(
          state.translate('open_chat'),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.onSurface),
        ),
        subtitle: Text(
          state.translate('open_chat_subtitle'),
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceVariant),
      ),
    );
  }

  Widget _buildPerformanceStats(
    BuildContext context, {
    required List<BidOffer> activeBids,
    required int totalContracts,
    required int totalCustomers,
    required int pendingActionsCount,
  }) {
    final state = Provider.of<AppState>(context, listen: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.gavel_outlined,
                iconColor: AppColors.secondary,
                value: '${activeBids.length}',
                label: state.translate('active_negotiations'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.description_outlined,
                iconColor: AppColors.tertiary,
                value: '$totalContracts',
                label: state.translate('total_contracts'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.people_outline_rounded,
                iconColor: AppColors.primary,
                value: '$totalCustomers',
                label: state.translate('total_customers'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.local_shipping_outlined,
                iconColor: AppColors.warning,
                value: _isLoadingStats ? '-' : '$pendingActionsCount',
                label: state.translate('pending_actions'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    VoidCallback? onTap,
  }) {
    return CustomCard(
      padding: const EdgeInsets.all(16),
      elevationLevel: 2,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: iconColor),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
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
      AppSnackBar.error(context, friendlyApiError(state, e));
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
