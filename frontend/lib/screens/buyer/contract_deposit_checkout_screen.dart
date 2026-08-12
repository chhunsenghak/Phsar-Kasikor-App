import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/app_snackbar.dart';
import '../../utils/khqr_polling_mixin.dart';

/// Which of a contract's two KHQR settlements this screen is handling —
/// the booking deposit (before ACTIVE) or the remaining final balance
/// (before COMPLETED). Both share the exact same generate/poll/confirm
/// shape, just against different [AppState] methods and copy, so one
/// screen serves both rather than duplicating it.
enum ContractPaymentKind { deposit, finalPayment }

/// Bakong KHQR settlement for a contract's booking deposit or final
/// balance. Mirrors [KHQRCheckoutScreen]'s minimal design and shares its
/// polling/settlement logic via [KhqrPollingMixin] rather than re-deriving
/// it.
class ContractDepositCheckoutScreen extends StatefulWidget {
  final String contractId;
  final double depositAmount;
  final String depositCurrency;
  final String sellerName;
  final ContractPaymentKind kind;

  const ContractDepositCheckoutScreen({
    super.key,
    required this.contractId,
    required this.depositAmount,
    required this.depositCurrency,
    required this.sellerName,
    this.kind = ContractPaymentKind.deposit,
  });

  @override
  State<ContractDepositCheckoutScreen> createState() => _ContractDepositCheckoutScreenState();
}

class _ContractDepositCheckoutScreenState extends State<ContractDepositCheckoutScreen>
    with KhqrPollingMixin<ContractDepositCheckoutScreen> {
  Map<String, dynamic>? _qr;
  bool _qrError = false;
  bool _isGeneratingQr = true;

  bool get _isFinal => widget.kind == ContractPaymentKind.finalPayment;

  @override
  void initState() {
    super.initState();
    _generateQr();
    startPolling();
  }

  Future<void> _generateQr() async {
    final state = Provider.of<AppState>(context, listen: false);
    if (state.token == null) return;
    setState(() {
      _isGeneratingQr = true;
      _qrError = false;
    });
    try {
      final result = _isFinal
          ? await state.generateContractFinalPaymentQr(widget.contractId)
          : await state.generateContractDepositQr(widget.contractId);
      if (!mounted) return;
      setState(() => _qr = result);
    } catch (_) {
      if (!mounted) return;
      setState(() => _qrError = true);
    } finally {
      if (mounted) setState(() => _isGeneratingQr = false);
    }
  }

  /// Same "only a verified Bakong result ever settles or leaves this
  /// screen" rule as the order checkout — see khqr_checkout.dart.
  @override
  Future<bool> checkPayment({required bool silent}) async {
    final state = Provider.of<AppState>(context, listen: false);
    final md5 = _qr?['md5']?.toString();
    if (state.token == null || md5 == null) return false;

    String status;
    try {
      status = _isFinal
          ? await state.confirmContractFinalPayment(widget.contractId, md5)
          : await state.confirmContractDeposit(widget.contractId, md5);
    } catch (_) {
      status = 'unavailable';
    }

    if (!mounted) return false;

    if (status == 'paid') {
      state.addNotification(
        state.translate(_isFinal ? 'contract_final_payment_paid_title' : 'contract_deposit_paid_title'),
        state.translate(
          _isFinal ? 'contract_final_payment_paid_msg' : 'contract_deposit_paid_msg',
          arguments: {'name': widget.sellerName},
        ),
      );
      Navigator.pop(context, true);
      return true;
    }

    if (silent) return false;
    AppSnackBar.warning(
      context,
      state.translate(status == 'unpaid' ? 'payment_not_confirmed_yet' : 'payment_check_unavailable'),
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final amountLabel = formatCurrencyAmount(widget.depositAmount, widget.depositCurrency);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.onSurface),
          onPressed: isCheckingPayment ? null : () => Navigator.pop(context),
        ),
        title: Text(
          state.translate(_isFinal ? 'pay_final_balance' : 'pay_deposit'),
          style: GoogleFonts.inter(color: AppColors.onSurface, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            CustomCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.translate(_isFinal ? 'final_balance' : 'booking_deposit'),
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.translate(
                      _isFinal ? 'final_balance_to_seller' : 'deposit_to_seller',
                      arguments: {'name': widget.sellerName},
                    ),
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildQrCard(state, amountLabel),
            const SizedBox(height: 16),
            CustomButton(
              text: isCheckingPayment
                  ? state.translate('settling_payment')
                  : state.translate('confirm_payment_done'),
              icon: Icons.check_circle_outline_rounded,
              isLoading: isCheckingPayment,
              onPressed: (isCheckingPayment || _isGeneratingQr) ? null : checkPaymentManually,
            ),
            const SizedBox(height: 12),
            Text(
              state.translate('bakong_notice'),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.outline),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildQrCard(AppState state, String amountLabel) {
    return CustomCard(
      borderSide: const BorderSide(color: AppColors.outlineVariant),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        children: [
          Text(
            amountLabel,
            style: GoogleFonts.inter(color: AppColors.onSurface, fontWeight: FontWeight.bold, fontSize: 22),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final double qrSize = constraints.maxWidth.clamp(200.0, 320.0);
              return SizedBox(width: qrSize, height: qrSize, child: _buildQrContent(state));
            },
          ),
          const SizedBox(height: 16),
          Text(
            state.translate('scan_with_bakong_app'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildQrContent(AppState state) {
    if (_qrError) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 32),
          const SizedBox(height: 8),
          Text(
            state.translate('qr_generation_failed'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.error),
          ),
          const SizedBox(height: 4),
          TextButton(onPressed: _generateQr, child: Text(state.translate('retry'))),
        ],
      );
    }

    if (_qr == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 12),
          Text(
            state.translate('generating_qr'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.outline),
          ),
        ],
      );
    }

    try {
      String raw = _qr!['qr_image_base64'] as String;
      final commaIndex = raw.indexOf(',');
      if (raw.startsWith('data:') && commaIndex != -1) {
        raw = raw.substring(commaIndex + 1);
      }
      return Image.memory(base64Decode(raw), fit: BoxFit.contain);
    } catch (_) {
      return Icon(Icons.qr_code_2_rounded, size: 120, color: AppColors.outline);
    }
  }
}
