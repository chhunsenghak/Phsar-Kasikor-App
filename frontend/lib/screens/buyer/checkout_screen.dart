import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/app_snackbar.dart';
import '../../services/api/order_api.dart';
import '../common/order_contract_history_screen.dart';
import 'khqr_checkout.dart';
import 'order_tracking.dart';

/// The single checkout surface for any number of crops.
///
/// Fulfillment and payment are chosen once here rather than per crop, because
/// they belong to the order, not the product. Items are split into one order
/// per seller+currency, which is what the backend accepts.
class CheckoutScreen extends StatefulWidget {
  final List<CartItem> items;

  /// True when the items came from the live cart, so the successfully ordered
  /// lines should be removed from it afterwards.
  final bool fromCart;

  const CheckoutScreen({
    super.key,
    required this.items,
    this.fromCart = false,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _deliveryMethod = 'DELIVERY';
  String _paymentMethod = 'KHQR';
  bool _isPlacingOrders = false;

  /// Snapshot taken at construction: the cart can be mutated while this screen
  /// is open, and checkout must charge exactly what was reviewed.
  late final List<CartItem> _items = widget.items
      .map((item) => CartItem(product: item.product, quantity: item.quantity))
      .toList();

  late final List<CartGroup> _groups = groupCartItems(_items);

  String _friendlyError(AppState state, Object error) {
    final msg = error.toString().replaceAll('Exception: ', '').trim();
    switch (msg) {
      case 'INSUFFICIENT_STOCK':
        return state.translate('exceeds_stock');
      case 'PRODUCT_NOT_FOUND':
        return state.translate('product_unavailable');
      case 'CANNOT_ORDER_OWN_PRODUCT':
        return state.translate('cannot_order_own_product');
      default:
        return msg;
    }
  }

  Future<void> _placeOrders(AppState state) async {
    if (_isPlacingOrders) return;

    if (_items.isEmpty) {
      _showMessage(state.translate('nothing_to_checkout'));
      return;
    }
    if (state.token == null) {
      _showMessage(state.translate('login_to_checkout'));
      return;
    }

    setState(() => _isPlacingOrders = true);

    final List<PlacedOrder> placed = [];
    final List<String> failures = [];

    for (final group in _groups) {
      try {
        final res = await OrderApi.createOrder(
          state.token!,
          items: group.toOrderItems(),
          paymentMethod: _paymentMethod,
          deliveryMethod: _deliveryMethod,
        );
        final orderId = res['id']?.toString();
        if (orderId == null || orderId.isEmpty) {
          failures.add('${group.sellerName}: ${state.translate('transaction_failed')}');
          continue;
        }
        placed.add(PlacedOrder(
          orderId: orderId,
          group: group,
          deliveryMethod: _deliveryMethod,
        ));
      } catch (e) {
        failures.add('${group.sellerName}: ${_friendlyError(state, e)}');
      }
    }

    if (!mounted) return;
    setState(() => _isPlacingOrders = false);

    // Drop only the lines that actually became orders, so a partial failure
    // leaves the rest of the cart intact for a retry.
    if (widget.fromCart && placed.isNotEmpty) {
      state.removeCartItems(
        placed.expand((order) => order.group.items).map((item) => item.product.id),
      );
    }

    // Stock changed server-side; refresh so other screens show real numbers.
    if (placed.isNotEmpty) {
      state.refreshProducts();
    }

    if (placed.isEmpty) {
      _showFailureDialog(state, failures);
      return;
    }

    if (failures.isNotEmpty) {
      _showMessage(state.translate('partial_order_failure', arguments: {
        'success': placed.length.toString(),
        'total': _groups.length.toString(),
      }));
    }

    if (_paymentMethod == 'KHQR') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => KHQRCheckoutScreen(orders: placed),
        ),
      );
      return;
    }

    // Cash on delivery — the orders are already placed.
    state.addNotification(
      state.translate('order_placed_successfully'),
      state.translate('orders_placed_msg', arguments: {
        'count': placed.length.toString(),
      }),
    );
    _goToPostOrderScreen(placed);
  }

  /// A single crop from a single farm goes straight to its tracking timeline;
  /// anything larger goes to the order list, which can show them all.
  void _goToPostOrderScreen(List<PlacedOrder> placed) {
    if (placed.length == 1 && placed.first.group.items.length == 1) {
      final order = placed.first;
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

  void _showMessage(String message) {
    if (!mounted) return;
    AppSnackBar.warning(context, message);
  }

  void _showFailureDialog(AppState state, List<String> failures) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          state.translate('transaction_failed'),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: failures
              .map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      f,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(state.translate('try_again')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final int lineCount = _items.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.onSurface),
          onPressed: _isPlacingOrders ? null : () => Navigator.pop(context),
        ),
        title: Text(
          state.translate('review_order'),
          style: GoogleFonts.inter(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_groups.length > 1) ...[
            _buildSplitNotice(state),
            const SizedBox(height: 16),
          ],
          ..._groups.map((group) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildGroupCard(state, group),
              )),
          const SizedBox(height: 6),
          _buildOptionSection(
            label: state.translate('delivery_method'),
            children: [
              _buildChoice(
                icon: Icons.local_shipping_outlined,
                label: state.translate('express_delivery'),
                selected: _deliveryMethod == 'DELIVERY',
                onTap: () => setState(() => _deliveryMethod = 'DELIVERY'),
              ),
              const SizedBox(width: 12),
              _buildChoice(
                icon: Icons.storefront_rounded,
                label: state.translate('self_pickup'),
                selected: _deliveryMethod == 'PICKUP',
                onTap: () => setState(() => _deliveryMethod = 'PICKUP'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildOptionSection(
            label: state.translate('payment_method'),
            children: [
              _buildChoice(
                icon: Icons.qr_code_scanner_rounded,
                label: state.translate('khqr_pay'),
                selected: _paymentMethod == 'KHQR',
                onTap: () => setState(() => _paymentMethod = 'KHQR'),
              ),
              const SizedBox(width: 12),
              _buildChoice(
                icon: Icons.payments_outlined,
                label: state.translate('cod_cash'),
                selected: _paymentMethod == 'COD',
                onTap: () => setState(() => _paymentMethod = 'COD'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildTotalsCard(state),
          const SizedBox(height: 24),
          CustomButton(
            text: _paymentMethod == 'KHQR'
                ? state.translate('proceed_checkout')
                : state.translate('place_order'),
            icon: _paymentMethod == 'KHQR'
                ? Icons.qr_code_scanner_rounded
                : Icons.check_circle_outline_rounded,
            isLoading: _isPlacingOrders,
            onPressed: lineCount == 0 ? null : () => _placeOrders(state),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSplitNotice(AppState state) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppDesign.borderRadiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: AppColors.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              state.translate('order_split_notice', arguments: {
                'count': _groups.length.toString(),
              }),
              style: GoogleFonts.inter(
                fontSize: 12.5,
                height: 1.4,
                color: AppColors.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(AppState state, CartGroup group) {
    return CustomCard(
      padding: const EdgeInsets.all(16),
      borderSide: const BorderSide(color: AppColors.outlineVariant, width: 0.8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.agriculture_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.translate('sold_by', arguments: {'name': group.sellerName}),
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          ...group.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.product.name,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${_qtyLabel(item.quantity)} ${item.product.unit} × ${item.product.formattedPrice}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      item.formattedItemTotal,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )),
          const Divider(height: 18),
          _buildAmountRow(
            state.translate('subtotal'),
            formatCurrencyAmount(group.subtotal, group.currency),
          ),
          const SizedBox(height: 4),
          _buildAmountRow(
            state.translate('delivery_fee'),
            _deliveryMethod == 'PICKUP'
                ? state.translate('free')
                : formatCurrencyAmount(group.deliveryFee(_deliveryMethod), group.currency),
          ),
          const SizedBox(height: 8),
          _buildAmountRow(
            state.translate('total_payable'),
            formatCurrencyAmount(group.total(_deliveryMethod), group.currency),
            emphasize: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsCard(AppState state) {
    // One grand total per currency — a KHR total and a USD total cannot be added.
    final Map<String, double> totals = {};
    for (final group in _groups) {
      totals[group.currency] =
          (totals[group.currency] ?? 0.0) + group.total(_deliveryMethod);
    }

    return CustomCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                state.translate('order_invoice_summary'),
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Text(
                state.translate('items_count',
                    arguments: {'count': _items.length.toString()}),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          ...totals.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${state.translate('total_amount')} (${entry.key})',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      formatCurrencyAmount(entry.value, entry.key),
                      style: GoogleFonts.inter(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
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

  Widget _buildAmountRow(String label, String value, {bool emphasize = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: emphasize ? 14 : 13,
            fontWeight: emphasize ? FontWeight.bold : FontWeight.normal,
            color: emphasize ? AppColors.onSurface : AppColors.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: emphasize ? 15 : 13,
            fontWeight: emphasize ? FontWeight.bold : FontWeight.w600,
            color: emphasize ? AppColors.primary : AppColors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildOptionSection({
    required String label,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Row(children: children),
      ],
    );
  }

  Widget _buildChoice({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: OutlinedButton.icon(
        icon: Icon(icon, size: 18),
        label: Text(label, textAlign: TextAlign.center),
        style: OutlinedButton.styleFrom(
          foregroundColor: selected ? AppColors.primary : AppColors.onSurfaceVariant,
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.outlineVariant,
            width: selected ? 2 : 1,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: _isPlacingOrders ? null : onTap,
      ),
    );
  }
}

/// Shows whole numbers without a trailing `.0` but keeps fractional weights.
String _qtyLabel(double qty) =>
    qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toString();
