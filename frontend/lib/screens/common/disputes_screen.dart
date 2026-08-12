import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../services/api/dispute_api.dart';
import '../../utils/api_error.dart';
import '../../widgets/custom_card.dart';

class DisputesScreen extends StatefulWidget {
  const DisputesScreen({super.key});

  @override
  State<DisputesScreen> createState() => _DisputesScreenState();
}

class _DisputesScreenState extends State<DisputesScreen> {
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
      final list = await DisputeApi.fetchMyDisputes(state.token!);
      setState(() => _disputes = list);
    } catch (e) {
      setState(() => _error = friendlyApiError(state, e));
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

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.onSurface),
        title: Text(
          state.translate('my_disputes'),
          style: GoogleFonts.inter(color: AppColors.onSurface, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Text(_error!, style: GoogleFonts.inter(color: AppColors.error)))
              : _disputes.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.gavel_outlined, size: 48, color: AppColors.outlineVariant),
                            const SizedBox(height: 12),
                            Text(
                              state.translate('no_disputes_yet'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.onSurface),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              state.translate('no_disputes_hint'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontSize: 13, color: AppColors.outline),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _disputes.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final d = _disputes[index];
                          final String status = d['status'] as String? ?? 'OPEN';
                          return CustomCard(
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
                                        color: _statusColor(status).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _statusLabel(state, status),
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: _statusColor(status),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  d['reason'] as String? ?? '',
                                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant),
                                ),
                                if ((d['resolution_note'] as String?)?.isNotEmpty == true) ...[
                                  const Divider(height: 20),
                                  Text(
                                    d['resolution_note'] as String,
                                    style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.outline),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
