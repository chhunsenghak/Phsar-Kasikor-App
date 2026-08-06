import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../services/api/dispute_api.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_input.dart';
import '../../widgets/app_snackbar.dart';

class DisputeResolutionScreen extends StatefulWidget {
  const DisputeResolutionScreen({super.key});

  @override
  State<DisputeResolutionScreen> createState() => _DisputeResolutionScreenState();
}

class _DisputeResolutionScreenState extends State<DisputeResolutionScreen> {
  bool _isLoading = true;
  List<dynamic> _disputes = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = Provider.of<AppState>(context, listen: false);
    if (state.token == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await DisputeApi.fetchAllDisputes(state.token!);
      setState(() => _disputes = list);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'RESOLVED_REFUND':
        return AppColors.primary;
      case 'RESOLVED_REJECTED':
        return AppColors.error;
      default:
        return Colors.amber.shade900;
    }
  }

  String _statusLabel(AppState state, String status) {
    switch (status) {
      case 'RESOLVED_REFUND':
        return state.translate('status_resolved_refund');
      case 'RESOLVED_REJECTED':
        return state.translate('status_resolved_rejected');
      default:
        return state.translate('status_open');
    }
  }

  Future<void> _showResolveDialog(Map<String, dynamic> dispute, bool asRefund) async {
    final state = Provider.of<AppState>(context, listen: false);
    final noteController = TextEditingController();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            asRefund ? state.translate('resolve_refund') : state.translate('resolve_reject'),
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: CustomInput(
            label: '',
            hintText: state.translate('resolution_note_hint'),
            controller: noteController,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(state.translate('cancel')),
            ),
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (state.token == null) return;
                      setDialogState(() => isSubmitting = true);
                      try {
                        await DisputeApi.resolveDispute(
                          state.token!,
                          dispute['id'].toString(),
                          status: asRefund ? 'RESOLVED_REFUND' : 'RESOLVED_REJECTED',
                          resolutionNote: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                        );
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        if (!mounted) return;
                        AppSnackBar.success(context, state.translate('dispute_resolved_success'));
                        _load();
                      } catch (e) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() => isSubmitting = false);
                        AppSnackBar.error(dialogContext, e.toString().replaceFirst('Exception: ', ''));
                      }
                    },
              child: Text(asRefund ? state.translate('resolve_refund') : state.translate('resolve_reject')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final openDisputes = _disputes.where((d) => d['status'] == 'OPEN').toList();
    final resolvedDisputes = _disputes.where((d) => d['status'] != 'OPEN').toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.onSurface),
        title: Text(
          state.translate('dispute_resolution_queue'),
          style: GoogleFonts.inter(color: AppColors.onSurface, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Text(_error!, style: GoogleFonts.inter(color: AppColors.error)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (openDisputes.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Text(
                              state.translate('no_open_disputes'),
                              style: GoogleFonts.inter(color: AppColors.outline),
                            ),
                          ),
                        )
                      else
                        ...openDisputes.map((d) => Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: CustomCard(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${state.translate('order_id')} #${(d['order_id'] as String).substring(0, 8).toUpperCase()}',
                                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _statusColor(d['status']).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            _statusLabel(state, d['status']),
                                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _statusColor(d['status'])),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      d['raiser_name']?.toString() ?? '',
                                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.outline),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      d['reason'] as String? ?? '',
                                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: CustomButton.secondary(
                                            text: state.translate('resolve_reject'),
                                            height: 40,
                                            onPressed: () => _showResolveDialog(d, false),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: CustomButton(
                                            text: state.translate('resolve_refund'),
                                            height: 40,
                                            backgroundColor: AppColors.primary,
                                            onPressed: () => _showResolveDialog(d, true),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            )),
                      if (resolvedDisputes.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          state.translate('status_resolved_refund'),
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.outline),
                        ),
                        const SizedBox(height: 8),
                        ...resolvedDisputes.map((d) => Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: CustomCard(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${state.translate('order_id')} #${(d['order_id'] as String).substring(0, 8).toUpperCase()}',
                                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                        Text(
                                          _statusLabel(state, d['status']),
                                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _statusColor(d['status'])),
                                        ),
                                      ],
                                    ),
                                    if ((d['resolution_note'] as String?)?.isNotEmpty == true) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        d['resolution_note'] as String,
                                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.outline, fontStyle: FontStyle.italic),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            )),
                      ],
                    ],
                  ),
                ),
    );
  }
}
