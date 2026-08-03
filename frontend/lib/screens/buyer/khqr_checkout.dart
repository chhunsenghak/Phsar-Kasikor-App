import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';
import '../../services/api/order_api.dart';
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

  Future<void> _settlePayment(AppState state) async {
    if (_isSettlingPayment || state.token == null) return;

    setState(() => _isSettlingPayment = true);

    final List<PlacedOrder> stillUnsettled = [];
    int settled = 0;

    for (final order in _unsettled) {
      try {
        await OrderApi.updateOrder(
          state.token!,
          order.orderId,
          paymentStatus: 'PAID',
          orderStatus: 'CONFIRMED',
        );
        settled++;
      } catch (_) {
        stillUnsettled.add(order);
      }
    }

    if (!mounted) return;
    setState(() {
      _isSettlingPayment = false;
      _unsettled = stillUnsettled;
    });

    if (settled == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.translate('payment_settlement_failed'))),
      );
      return;
    }

    final summary = _totalsByCurrency.entries
        .map((e) => formatCurrencyAmount(e.value, e.key))
        .join(' + ');
    state.addNotification(
      'Payment Successful',
      'Payment of $summary was approved for ${widget.orders.length} order(s).',
    );

    if (stillUnsettled.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.translate('partial_order_failure', arguments: {
            'success': settled.toString(),
            'total': widget.orders.length.toString(),
          })),
        ),
      );
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
            _buildQrCard(state, totals),
            const SizedBox(height: 32),
            CustomButton(
              text: _isSettlingPayment
                  ? state.translate('settling_payment')
                  : state.translate('simulate_payment_complete'),
              icon: Icons.check_circle_outline_rounded,
              isLoading: _isSettlingPayment,
              onPressed: _isSettlingPayment ? null : () => _settlePayment(state),
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

  Widget _buildQrCard(AppState state, Map<String, double> totals) {
    final String amountLabel = totals.entries
        .map((e) => formatCurrencyAmount(e.value, e.key))
        .join('  +  ');

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
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Stylized QR representation — this is a simulated payment.
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(10, (r) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(10, (c) {
                        final isDark = (r + c) % 3 == 0 ||
                            (r * c) % 4 == 0 ||
                            (r == 0 && c < 3) ||
                            (c == 0 && r < 3);
                        return Container(
                          width: 14,
                          height: 14,
                          color: isDark ? Colors.black : Colors.white,
                        );
                      }),
                    );
                  }),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: const Icon(
                    Icons.eco_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
              ],
            ),
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
            widget.orders.length == 1
                ? 'Order ID: ${widget.orders.first.orderId}'
                : state.translate('items_count', arguments: {
                    'count': widget.orders.length.toString(),
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
