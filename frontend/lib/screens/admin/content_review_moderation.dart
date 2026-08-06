import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../services/api/reports_api.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/app_snackbar.dart';

class ContentReviewModerationScreen extends StatefulWidget {
  const ContentReviewModerationScreen({super.key});

  @override
  State<ContentReviewModerationScreen> createState() => _ContentReviewModerationScreenState();
}

class _ContentReviewModerationScreenState extends State<ContentReviewModerationScreen> {
  List<dynamic> _reports = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    final state = Provider.of<AppState>(context, listen: false);
    if (state.token == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await ReportsApi.fetchAdminReports(state.token!);
      setState(() {
        // The endpoint returns full report history; the active queue only
        // needs ones nobody has acted on yet.
        _reports = list.where((r) => r['status'] == 'pending').toList();
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resolveReport(String reportId, String status, String actionLabel) async {
    final state = Provider.of<AppState>(context, listen: false);
    if (state.token == null) return;
    try {
      await ReportsApi.resolveReport(state.token!, reportId, status);
      if (!mounted) return;
      setState(() {
        _reports.removeWhere((r) => r['id'] == reportId);
      });
      AppSnackBar.success(context, state.translate('item_action_completed', arguments: {'action': actionLabel}));
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, state.translate('failed_update_status', arguments: {'error': e.toString()}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            state.translate('content_moderation'),
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            state.translate('content_moderation_subtitle'),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                            const SizedBox(height: 12),
                            Text(
                              state.translate('failed_update_status', arguments: {'error': _error!}),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(color: AppColors.outline),
                            ),
                            const SizedBox(height: 12),
                            CustomButton.secondary(
                              text: state.translate('retry'),
                              onPressed: _loadReports,
                            ),
                          ],
                        ),
                      )
                : _reports.isEmpty
                ? Center(
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
                            Icons.done_all_rounded,
                            size: 64,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          state.translate('moderation_queue_empty'),
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          state.translate('all_listings_meet_criteria'),
                          style: GoogleFonts.inter(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadReports,
                    child: ListView.separated(
                    itemCount: _reports.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final item = _reports[index];
                      final String reportId = item['id'] as String;
                      final bool isProduct = item['product_id'] != null;
                      final String title = (isProduct
                              ? item['product_name']
                              : item['post_title']) as String? ??
                          state.translate('crop_listing');
                      final String reportedBy = item['reporter_name'] as String? ?? state.translate('registered_buyer');

                      return CustomCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.errorContainer,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    state.translate('flagged_badge'),
                                    style: GoogleFonts.inter(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              state.translate('violation_reason'),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.error,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['reason'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.outline),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    state.translate('reported_by_note', arguments: {
                                      'by': reportedBy,
                                      'note': item['reason'] as String,
                                    }),
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColors.outline,
                                    ),
                                  ),
                                )
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: CustomButton(
                                    text: isProduct
                                        ? state.translate('remove_product')
                                        : state.translate('remove_content'),
                                    height: 44,
                                    backgroundColor: AppColors.error,
                                    onPressed: () {
                                      _resolveReport(reportId, 'resolved', state.translate('removed_listing'));
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: CustomButton.secondary(
                                    text: state.translate('dismiss_report'),
                                    height: 44,
                                    onPressed: () {
                                      _resolveReport(reportId, 'dismissed', state.translate('dismissed_report'));
                                    },
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      );
                    },
                  ),
                  ),
          ),
        ],
      ),
    );
  }
}
