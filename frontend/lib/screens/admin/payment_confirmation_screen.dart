import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../services/api/order_api.dart';
import '../../services/api/contract_api.dart';
import '../../utils/api_error.dart';
import '../../utils/phnom_penh_time.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/app_snackbar.dart';

/// Admin-only manual-confirm fallback queue: every KHQR order still stuck
/// PENDING because automatic Bakong verification couldn't run (daily call
/// cap exhausted, token expired, etc.) — never the primary way payments are
/// tracked, only what admin reaches for when that automatic path can't.
class PaymentConfirmationScreen extends StatefulWidget {
  const PaymentConfirmationScreen({super.key});

  @override
  State<PaymentConfirmationScreen> createState() => _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState extends State<PaymentConfirmationScreen> {
  bool _isLoading = true;
  List<dynamic> _orders = [];
  List<dynamic> _contracts = [];
  List<dynamic> _finalPayments = [];
  String? _error;
  final Set<String> _confirmingIds = {};

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
      final results = await Future.wait([
        OrderApi.fetchPendingKhqrPayments(state.token!),
        ContractApi.fetchPendingDeposits(state.token!),
        ContractApi.fetchPendingFinalPayments(state.token!),
      ]);
      if (!mounted) return;
      setState(() {
        _orders = results[0];
        _contracts = results[1];
        _finalPayments = results[2];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyApiError(state, e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmPayment(Map<String, dynamic> order) async {
    final state = Provider.of<AppState>(context, listen: false);
    final orderId = order['id'].toString();
    final orderRef = orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId;
    final amountLabel = formatCurrencyAmount(
      (order['total_amount'] as num?)?.toDouble() ?? 0.0,
      order['currency']?.toString() ?? 'USD',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          state.translate('confirm_payment_title'),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          state.translate('confirm_payment_body', arguments: {
            'ref': orderRef,
            'amount': amountLabel,
          }),
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(state.translate('cancel'), style: GoogleFonts.inter(color: AppColors.outline)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              state.translate('mark_as_paid'),
              style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || state.token == null) return;

    setState(() => _confirmingIds.add(orderId));
    try {
      await OrderApi.confirmPaymentAsAdmin(state.token!, orderId);
      if (!mounted) return;
      setState(() => _orders = _orders.where((o) => o['id'].toString() != orderId).toList());
      AppSnackBar.success(context, state.translate('payment_marked_paid_success'));
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, friendlyApiError(state, e));
    } finally {
      if (mounted) setState(() => _confirmingIds.remove(orderId));
    }
  }

  Future<void> _confirmContractDeposit(Map<String, dynamic> contract) async {
    final state = Provider.of<AppState>(context, listen: false);
    final contractId = contract['id'].toString();
    final ref = contractId.length > 8 ? contractId.substring(0, 8).toUpperCase() : contractId;
    final amountLabel = formatCurrencyAmount(
      (contract['deposit_amount'] as num?)?.toDouble() ?? 0.0,
      contract['deposit_currency']?.toString() ?? 'USD',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          state.translate('confirm_payment_title'),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          state.translate('confirm_deposit_body', arguments: {'ref': ref, 'amount': amountLabel}),
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(state.translate('cancel'), style: GoogleFonts.inter(color: AppColors.outline)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              state.translate('mark_as_paid'),
              style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || state.token == null) return;

    setState(() => _confirmingIds.add(contractId));
    try {
      await ContractApi.confirmDepositAsAdmin(state.token!, contractId);
      if (!mounted) return;
      setState(() => _contracts = _contracts.where((c) => c['id'].toString() != contractId).toList());
      AppSnackBar.success(context, state.translate('payment_marked_paid_success'));
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, friendlyApiError(state, e));
    } finally {
      if (mounted) setState(() => _confirmingIds.remove(contractId));
    }
  }

  Future<void> _confirmContractFinalPayment(Map<String, dynamic> contract) async {
    final state = Provider.of<AppState>(context, listen: false);
    final contractId = contract['id'].toString();
    final ref = contractId.length > 8 ? contractId.substring(0, 8).toUpperCase() : contractId;
    final amountLabel = formatCurrencyAmount(
      (contract['final_amount'] as num?)?.toDouble() ?? 0.0,
      contract['deposit_currency']?.toString() ?? 'USD',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          state.translate('confirm_payment_title'),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          state.translate('confirm_final_payment_body', arguments: {'ref': ref, 'amount': amountLabel}),
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(state.translate('cancel'), style: GoogleFonts.inter(color: AppColors.outline)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              state.translate('mark_as_paid'),
              style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || state.token == null) return;

    setState(() => _confirmingIds.add(contractId));
    try {
      await ContractApi.confirmFinalPaymentAsAdmin(state.token!, contractId);
      if (!mounted) return;
      setState(() => _finalPayments = _finalPayments.where((c) => c['id'].toString() != contractId).toList());
      AppSnackBar.success(context, state.translate('payment_marked_paid_success'));
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, friendlyApiError(state, e));
    } finally {
      if (mounted) setState(() => _confirmingIds.remove(contractId));
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
          state.translate('payment_confirmation_queue'),
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
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded, size: 18, color: Colors.amber.shade900),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                state.translate('payment_confirmation_queue_notice'),
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.amber.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        state.translate('order_payments'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 10),
                      if (_orders.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            state.translate('no_pending_payments'),
                            style: GoogleFonts.inter(color: AppColors.outline),
                          ),
                        )
                      else
                        ..._orders.map((order) {
                          final String orderId = order['id'].toString();
                          final String orderRef =
                              orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId;
                          final double total = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
                          final String currency = order['currency']?.toString() ?? 'USD';
                          final bool isConfirming = _confirmingIds.contains(orderId);

                          return Container(
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
                                        '${state.translate('order_id')} #$orderRef',
                                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      Text(
                                        formatCurrencyAmount(total, currency),
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${state.translate('buyer')}: ${order['buyer_name'] ?? ''}',
                                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${state.translate('seller')}: ${order['seller_name'] ?? ''}',
                                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    formatPhnomPenhDateTime(order['created_at']?.toString()),
                                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.outline),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: CustomButton(
                                      text: state.translate('mark_as_paid'),
                                      height: 40,
                                      backgroundColor: AppColors.primary,
                                      isLoading: isConfirming,
                                      onPressed: isConfirming ? null : () => _confirmPayment(order),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: 24),
                      Text(
                        state.translate('contract_deposits'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 10),
                      if (_contracts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            state.translate('no_pending_deposits'),
                            style: GoogleFonts.inter(color: AppColors.outline),
                          ),
                        )
                      else
                        ..._contracts.map((contract) {
                          final String contractId = contract['id'].toString();
                          final String ref =
                              contractId.length > 8 ? contractId.substring(0, 8).toUpperCase() : contractId;
                          final double amount = (contract['deposit_amount'] as num?)?.toDouble() ?? 0.0;
                          final String currency = contract['deposit_currency']?.toString() ?? 'USD';
                          final bool isConfirming = _confirmingIds.contains(contractId);

                          return Container(
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
                                        '${state.translate('agreement')} #$ref',
                                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      Text(
                                        formatCurrencyAmount(amount, currency),
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${state.translate('buyer')}: ${contract['buyer_name'] ?? ''}',
                                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${state.translate('seller')}: ${contract['seller_name'] ?? ''}',
                                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: CustomButton(
                                      text: state.translate('mark_as_paid'),
                                      height: 40,
                                      backgroundColor: AppColors.primary,
                                      isLoading: isConfirming,
                                      onPressed: isConfirming ? null : () => _confirmContractDeposit(contract),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: 24),
                      Text(
                        state.translate('contract_final_payments'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 10),
                      if (_finalPayments.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            state.translate('no_pending_final_payments'),
                            style: GoogleFonts.inter(color: AppColors.outline),
                          ),
                        )
                      else
                        ..._finalPayments.map((contract) {
                          final String contractId = contract['id'].toString();
                          final String ref =
                              contractId.length > 8 ? contractId.substring(0, 8).toUpperCase() : contractId;
                          final double amount = (contract['final_amount'] as num?)?.toDouble() ?? 0.0;
                          final String currency = contract['deposit_currency']?.toString() ?? 'USD';
                          final bool isConfirming = _confirmingIds.contains(contractId);

                          return Container(
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
                                        '${state.translate('agreement')} #$ref',
                                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      Text(
                                        formatCurrencyAmount(amount, currency),
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${state.translate('buyer')}: ${contract['buyer_name'] ?? ''}',
                                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${state.translate('seller')}: ${contract['seller_name'] ?? ''}',
                                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: CustomButton(
                                      text: state.translate('mark_as_paid'),
                                      height: 40,
                                      backgroundColor: AppColors.primary,
                                      isLoading: isConfirming,
                                      onPressed: isConfirming ? null : () => _confirmContractFinalPayment(contract),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}
