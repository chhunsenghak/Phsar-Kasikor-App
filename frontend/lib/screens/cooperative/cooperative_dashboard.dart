import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../services/api/cooperative_api.dart';
import '../../utils/api_error.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_input.dart';
import '../../widgets/app_snackbar.dart';

class CooperativeDashboardScreen extends StatefulWidget {
  const CooperativeDashboardScreen({super.key});

  @override
  State<CooperativeDashboardScreen> createState() => _CooperativeDashboardScreenState();
}

class _CooperativeDashboardScreenState extends State<CooperativeDashboardScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _members = [];
  List<dynamic> _stockSummary = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final state = Provider.of<AppState>(context, listen: false);
    if (state.token == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        CooperativeApi.fetchMembers(state.token!),
        CooperativeApi.fetchStockSummary(state.token!),
      ]);
      setState(() {
        _members = results[0];
        _stockSummary = results[1];
      });
    } catch (e) {
      setState(() {
        _error = friendlyApiError(state, e);
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _inviteMember() async {
    final state = Provider.of<AppState>(context, listen: false);
    final controller = TextEditingController();
    final identifier = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(state.translate('invite_member'), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: CustomInput(
          label: '',
          controller: controller,
          hintText: state.translate('invite_member_hint'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(state.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(state.translate('send_invite')),
          ),
        ],
      ),
    );

    if (identifier == null || identifier.isEmpty || state.token == null) return;
    try {
      final result = await CooperativeApi.inviteMember(state.token!, identifier);
      if (!mounted) return;
      AppSnackBar.success(context, state.translate('invite_sent_success', arguments: {'name': result['farmer_name'] ?? identifier}));
      _loadData();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, friendlyApiError(state, e));
    }
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    final state = Provider.of<AppState>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(state.translate('remove_member'), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(state.translate('remove_member_confirm', arguments: {'name': member['farmer_name'] ?? ''})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(state.translate('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(state.translate('remove_member'), style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true || state.token == null) return;
    try {
      await CooperativeApi.removeMember(state.token!, member['id']);
      _loadData();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, friendlyApiError(state, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final activeCount = _members.where((m) => m['status'] == 'active').length;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppColors.outline)),
            const SizedBox(height: 12),
            CustomButton.secondary(text: state.translate('retry'), onPressed: _loadData),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.translate('coop_dashboard'),
                      style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.translate('coop_member_count').replaceAll('{count}', activeCount.toString()),
                      style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.primaryContainer, shape: BoxShape.circle),
                  child: const Icon(Icons.group_work_rounded, color: AppColors.onPrimaryContainer, size: 24),
                )
              ],
            ),
            const SizedBox(height: 24),

            // Production Aggregator Section
            Text(
              state.translate('total_coop_stock'),
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface),
            ),
            const SizedBox(height: 12),
            _buildAggregatedStockCard(state),

            const SizedBox(height: 24),

            // Member Directory
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  state.translate('member_directory'),
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                ),
                TextButton.icon(
                  onPressed: _inviteMember,
                  icon: const Icon(Icons.person_add_alt_rounded, size: 18),
                  label: Text(state.translate('invite_member')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_members.isEmpty)
              CustomCard(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    state.translate('no_coop_members_yet'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.outline),
                  ),
                ),
              )
            else
              ..._members.map((member) => _buildMemberCard(context, state, member)),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAggregatedStockCard(AppState state) {
    if (_stockSummary.isEmpty) {
      return CustomCard(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            state.translate('no_coop_members_yet'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.outline),
          ),
        ),
      );
    }

    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: _stockSummary.map((s) {
          final double qty = (s['total_quantity'] as num?)?.toDouble() ?? 0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          s['crop_name'] as String? ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 1)} ${s['unit'] ?? ''}',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${s['farms_count']})',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.outline),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMemberCard(BuildContext context, AppState state, Map<String, dynamic> member) {
    final String status = (member['status'] as String? ?? 'active').toLowerCase();
    final bool isActive = status == 'active';
    final String statusLabel = state.translate('member_status_$status');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: CustomCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: AppColors.secondaryContainer, shape: BoxShape.circle),
              child: const Icon(Icons.person_outline_rounded, color: AppColors.onSecondaryContainer),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member['farmer_name'] as String? ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                    state.translate('crops_count', arguments: {'count': (member['products_count'] ?? 0).toString()}),
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.outline),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primary.withValues(alpha: 0.1) : AppColors.outlineVariant.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: isActive ? AppColors.primary : AppColors.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => _removeMember(member),
                  child: Icon(Icons.remove_circle_outline_rounded, size: 18, color: AppColors.error.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
