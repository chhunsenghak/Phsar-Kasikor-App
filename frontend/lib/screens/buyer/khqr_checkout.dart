import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/app_snackbar.dart';
import '../../services/api/payment_api.dart';
import '../common/order_contract_history_screen.dart';
import 'order_tracking.dart';

/// Bakong KHQR settlement for orders that have already been created as PENDING
/// by [CheckoutScreen]. A cart spanning several farms produces several orders;
/// they are all settled by this one payment.
class KHQRCheckoutScreen extends StatefulWidget {
  final List<PlacedOrder> orders;

  const KHQRCheckoutScreen({
    super.key,
    required this.orders,
  });

  @override
  State<KHQRCheckoutScreen> createState() => _KHQRCheckoutScreenState();
}

class _KHQRCheckoutScreenState extends State<KHQRCheckoutScreen> {
  bool _isSettlingPayment = false;

  /// Orders still awaiting settlement — a retry only re-sends these.
  late List<PlacedOrder> _unsettled = List<PlacedOrder>.from(widget.orders);

  /// One real KHQR per currency (a QR encodes exactly one amount in one
  /// currency, so a cart spanning USD and KHR orders needs two separate
  /// codes). Keyed by currency; value holds qr_image_base64/md5/qr_string,
  /// or null while still generating.
  final Map<String, Map<String, dynamic>?> _qrByCurrency = {};
  final Set<String> _qrErrors = {};
  bool _isGeneratingQr = true;

  @override
  void initState() {
    super.initState();
    _generateQrCodes();
  }

  Future<void> _generateQrCodes() async {
    final state = Provider.of<AppState>(context, listen: false);
    if (state.token == null) return;

    setState(() {
      _isGeneratingQr = true;
      _qrErrors.clear();
    });

    final Map<String, List<String>> orderIdsByCurrency = {};
    for (final order in widget.orders) {
      orderIdsByCurrency.putIfAbsent(order.currency, () => []).add(order.orderId);
    }

    for (final entry in orderIdsByCurrency.entries) {
      try {
        final result = await PaymentApi.generateKhqr(state.token!, entry.value);
        if (!mounted) return;
        setState(() => _qrByCurrency[entry.key] = result);
      } catch (e) {
        if (!mounted) return;
        setState(() => _qrErrors.add(entry.key));
      }
    }

    if (!mounted) return;
    setState(() => _isGeneratingQr = false);
  }

  List<CartItem> get _allItems =>
      widget.orders.expand((order) => order.group.items).toList();

  /// Grand total per currency; a KHR and a USD amount cannot be summed.
  Map<String, double> get _totalsByCurrency {
    final Map<String, double> totals = {};
    for (final order in widget.orders) {
      totals[order.currency] = (totals[order.currency] ?? 0.0) + order.total;
    }
    return totals;
  }

  /// Re-checks each currency's KHQR against Bakong and settles whichever
  /// orders it actually confirms as paid. There is deliberately no path here
  /// that marks an order PAID just because the buyer tapped this button —
  /// only a verified Bakong result (or, separately, the seller's own
  /// confirm-payment action) does that.
  Future<void> _settlePayment(AppState state) async {
    if (_isSettlingPayment || state.token == null) return;

    setState(() => _isSettlingPayment = true);

    final Map<String, List<PlacedOrder>> unsettledByCurrency = {};
    for (final order in _unsettled) {
      unsettledByCurrency.putIfAbsent(order.currency, () => []).add(order);
    }

    final Set<String> confirmedIds = {};
    bool anyVerificationUnavailable = false;

    for (final currency in unsettledByCurrency.keys) {
      final md5 = _qrByCurrency[currency]?['md5']?.toString();
      if (md5 == null) continue;
      try {
        final res = await PaymentApi.confirmKhqrPayment(state.token!, md5);
        final status = res['status']?.toString();
        if (status == 'paid') {
          final ids = res['confirmed_order_ids'] as List<dynamic>? ?? [];
          confirmedIds.addAll(ids.map((e) => e.toString()));
        } else if (status == 'unavailable') {
          anyVerificationUnavailable = true;
        }
      } catch (_) {
        // Treated as not-yet-confirmed below; the user can just retry.
      }
    }

    if (!mounted) return;
    final int settled = confirmedIds.length;
    setState(() {
      _isSettlingPayment = false;
      _unsettled = _unsettled.where((o) => !confirmedIds.contains(o.orderId)).toList();
    });

    if (settled == 0) {
      AppSnackBar.warning(
        context,
        anyVerificationUnavailable
            ? state.translate('payment_check_unavailable')
            : state.translate('payment_not_confirmed_yet'),
      );
      return;
    }

    final summary = _totalsByCurrency.entries
        .map((e) => formatCurrencyAmount(e.value, e.key))
        .join(' + ');
    state.addNotification(
      state.translate('payment_successful'),
      state.translate('payment_approved_msg', arguments: {
        'summary': summary,
        'count': widget.orders.length.toString(),
      }),
    );

    if (_unsettled.isNotEmpty) {
      AppSnackBar.warning(context, state.translate('partial_order_failure', arguments: {
        'success': settled.toString(),
        'total': widget.orders.length.toString(),
      }));
      return;
    }

    _goToPostPaymentScreen();
  }

  void _goToPostPaymentScreen() {
    if (widget.orders.length == 1 && widget.orders.first.group.items.length == 1) {
      final order = widget.orders.first;
      final item = order.group.items.first;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OrderTrackingScreen(
            orderId: order.orderId,
            productName: item.product.name,
            price: item.product.price,
            quantity: item.quantity,
            total: order.total,
            currency: order.currency,
          ),
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const OrderContractHistoryScreen(
          initialTab: 1,
          isPushed: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final totals = _totalsByCurrency;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.onSurface),
          onPressed: _isSettlingPayment ? null : () => Navigator.pop(context),
        ),
        title: Text(
          state.translate('khqr_checkout'),
          style: GoogleFonts.inter(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildInvoiceCard(state, totals),
            const SizedBox(height: 24),
            ...totals.entries.expand((entry) => [
                  _buildQrCard(state, entry.key, entry.value),
                  const SizedBox(height: 16),
                ]),
            const SizedBox(height: 16),
            CustomButton(
              text: _isSettlingPayment
                  ? state.translate('settling_payment')
                  : state.translate('confirm_payment_done'),
              icon: Icons.check_circle_outline_rounded,
              isLoading: _isSettlingPayment,
              onPressed: (_isSettlingPayment || _isGeneratingQr)
                  ? null
                  : () => _settlePayment(state),
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

  Widget _buildInvoiceCard(AppState state, Map<String, double> totals) {
    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                state.translate('order_invoice_summary'),
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                state.translate('items_count',
                    arguments: {'count': _allItems.length.toString()}),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...widget.orders.map((order) => _buildOrderBlock(state, order)),
          const Divider(height: 24),
          ...totals.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${state.translate('total_payable')} (${entry.key})',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      formatCurrencyAmount(entry.value, entry.key),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildOrderBlock(AppState state, PlacedOrder order) {
    final bool isPaid = !_unsettled.contains(order);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  state.translate('sold_by',
                      arguments: {'name': order.group.sellerName}),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              if (isPaid)
                const Icon(Icons.check_circle_rounded,
                    size: 16, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 8),
          ...order.group.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _buildInvoiceRow(
                  label: item.product.name,
                  value:
                      '${_qtyLabel(item.quantity)} ${item.product.unit} × ${item.product.formattedPrice}',
                ),
              )),
          _buildInvoiceRow(
            label: state.translate('subtotal'),
            value: formatCurrencyAmount(order.subtotal, order.currency),
          ),
          if (order.hasDeliveryFee) ...[
            const SizedBox(height: 6),
            _buildInvoiceRow(
              label: state.translate('delivery_fee'),
              value: order.deliveryFee == 0
                  ? state.translate('free')
                  : formatCurrencyAmount(order.deliveryFee, order.currency),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQrCard(AppState state, String currency, double amount) {
    final String amountLabel = formatCurrencyAmount(amount, currency);
    final ordersForCurrency =
        widget.orders.where((o) => o.currency == currency).toList();

    return CustomCard(
      backgroundColor: AppColors.primary,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'KHQR',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red[800],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'BAKONG',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppDesign.borderRadiusSm),
            ),
            padding: const EdgeInsets.all(12),
            child: _buildQrContent(state, currency),
          ),
          const SizedBox(height: 20),
          Text(
            'PHSAR KASIKOR MERCHANT',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amountLabel,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ordersForCurrency.length == 1
                ? state.translate('order_id_prefix', arguments: {'id': ordersForCurrency.first.orderId})
                : state.translate('items_count', arguments: {
                    'count': ordersForCurrency.length.toString(),
                  }),
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrContent(AppState state, String currency) {
    if (_qrErrors.contains(currency)) {
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
          TextButton(
            onPressed: _generateQrCodes,
            child: Text(state.translate('retry')),
          ),
        ],
      );
    }

    final qrData = _qrByCurrency[currency];
    if (qrData == null) {
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
      // The KHQR library's base64 output has been observed both as a raw
      // base64 string and as a data: URI — strip the prefix if present.
      String raw = qrData['qr_image_base64'] as String;
      final commaIndex = raw.indexOf(',');
      if (raw.startsWith('data:') && commaIndex != -1) {
        raw = raw.substring(commaIndex + 1);
      }
      return Image.memory(base64Decode(raw), fit: BoxFit.contain);
    } catch (_) {
      return Icon(Icons.qr_code_2_rounded, size: 120, color: AppColors.outline);
    }
  }

  Widget _buildInvoiceRow({required String label, required String value}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}

String _qtyLabel(double qty) =>
    qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toString();
