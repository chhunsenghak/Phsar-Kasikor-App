import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';
import '../../services/api/order_api.dart';
import '../buyer/khqr_checkout.dart';
import '../buyer/order_tracking.dart';
import '../../services/pdf_generator_service.dart';

class OrderContractHistoryScreen extends StatefulWidget {
  final int initialTab;
  final bool isPushed;
  const OrderContractHistoryScreen({
    super.key,
    this.initialTab = 0,
    this.isPushed = false,
  });

  @override
  State<OrderContractHistoryScreen> createState() =>
      _OrderContractHistoryScreenState();
}

class _OrderContractHistoryScreenState extends State<OrderContractHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _orders = [];
  bool _isLoadingOrders = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    final state = Provider.of<AppState>(context, listen: false);
    if (state.token == null) return;
    setState(() {
      _isLoadingOrders = true;
    });
    try {
      final list = await OrderApi.fetchOrders(state.token!);
      setState(() {
        _orders = list;
      });
    } catch (_) {
      // Fallback or ignore
    } finally {
      setState(() {
        _isLoadingOrders = false;
      });
    }
  }

  Future<void> _updateOrderStatus(String orderId, String nextStatus) async {
    final state = Provider.of<AppState>(context, listen: false);
    if (state.token == null) return;
    try {
      await OrderApi.updateOrder(
        state.token!,
        orderId,
        orderStatus: nextStatus,
      );
      await _loadOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order status successfully updated to $nextStatus'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
      }
    }
  }

  String _formatCurrency(num amount, [String currency = 'USD']) {
    if (currency == 'KHR') {
      final String val = amount.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
      return '$val ៛';
    }
    final parts = amount.toStringAsFixed(2).split('.');
    final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String mathFunc(Match match) => '${match[1]},';
    final formattedInt = parts[0].replaceAllMapped(reg, mathFunc);
    return '\$$formattedInt.${parts[1]}';
  }

  /// Rebuilds the checkout view-model for an order that already exists, so the
  /// KHQR screen can settle it instead of placing a second one.
  ///
  /// Line items are matched back to the catalogue where possible; when a listing
  /// has since been removed, a stand-in carrying the recorded quantity and rate
  /// is used so the invoice still adds up.
  PlacedOrder _placedOrderFromRecord(
    AppState state,
    Map<String, dynamic> order,
    List<dynamic> items,
    double totalAmount,
  ) {
    // The order record is authoritative for currency — falls back to the first
    // item's product only for orders placed before that field existed.
    final String orderCurrency = resolveOrderCurrency(order, state.products);
    final List<CartItem> cartItems = [];

    for (final item in items) {
      final double qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
      final double subtotal =
          (item['subtotal'] as num?)?.toDouble() ?? totalAmount;
      final double rate = qty > 0 ? subtotal / qty : subtotal;

      MarketProduct? known;
      for (final p in state.products) {
        if (p.id == item['product_id']) {
          known = p;
          break;
        }
      }

      cartItems.add(CartItem(
        quantity: qty,
        // Price the line at the rate actually recorded on the order, not the
        // listing's current price, which may have changed since.
        product: MarketProduct(
          id: known?.id ?? (item['product_id']?.toString() ?? ''),
          name: known?.name ?? state.translate('crop_listing'),
          category: known?.category ?? 'Grains',
          price: rate,
          unit: known?.unit ?? 'kg',
          currency: orderCurrency,
          quantity: qty,
          farmerName: known?.farmerName ?? state.translate('registered_seller'),
          location: known?.location ?? '',
          description: known?.description ?? '',
          imageUrl: known?.imageUrl ?? '',
          sellerId: order['seller_id']?.toString(),
        ),
      ));
    }

    // One stored order is one group, whatever its line items look like.
    final group = CartGroup(
      groupKey: order['id']?.toString() ?? '',
      sellerKey: order['seller_id']?.toString() ?? '',
      sellerName: cartItems.isNotEmpty
          ? cartItems.first.product.farmerName
          : state.translate('registered_seller'),
      currency: orderCurrency,
      items: cartItems,
    );

    return PlacedOrder.existing(
      orderId: order['id']?.toString() ?? '',
      group: group,
      totalAmount: totalAmount,
      deliveryMethod: (order['delivery_method'] ?? 'DELIVERY').toString(),
    );
  }

  String _translateUnit(AppState state, String? rawUnit) {
    if (rawUnit == null || rawUnit.isEmpty) return '';
    final u = rawUnit.toLowerCase().replaceAll('s', '');
    if (state.hasTranslation(u)) {
      return state.translate(u);
    }
    return rawUnit;
  }

  Widget _buildStatusBadge(AppState state, String rawStatus) {
    final s = rawStatus.toLowerCase();
    Color bg;
    Color fg;
    IconData icon;
    String textKey;

    if (s == 'accepted' || s == 'paid' || s == 'completed') {
      bg = AppColors.primary.withValues(alpha: 0.12);
      fg = AppColors.primary;
      icon = Icons.check_circle_rounded;
      textKey = s == 'accepted'
          ? 'status_accepted'
          : (s == 'paid' ? 'status_paid' : 'status_completed');
    } else if (s == 'rejected' || s == 'cancelled') {
      bg = AppColors.error.withValues(alpha: 0.12);
      fg = AppColors.error;
      icon = Icons.cancel_rounded;
      textKey = s == 'rejected' ? 'status_rejected' : 'status_cancelled';
    } else if (s == 'counter_offered' || s == 'counter') {
      bg = Colors.blue.withValues(alpha: 0.12);
      fg = Colors.blue.shade700;
      icon = Icons.swap_horizontal_circle_rounded;
      textKey = 'status_countered';
    } else {
      bg = Colors.amber.withValues(alpha: 0.15);
      fg = Colors.amber.shade900;
      icon = Icons.schedule_rounded;
      textKey = s == 'placed' ? 'status_placed' : 'status_pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            state.translate(textKey),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final negotiations = state.negotiations;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        automaticallyImplyLeading: widget.isPushed,
        leading: widget.isPushed
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.onSurface,
                ),
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
              )
            : null,
        title: Text(
          state.translate('wholesale_history'),
          style: GoogleFonts.inter(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.onSurfaceVariant,
              labelStyle: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              unselectedLabelStyle: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: state.translate('contract_agreements')),
                Tab(text: state.translate('invoice_orders')),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildContractsTab(negotiations), _buildOrdersTab()],
      ),
    );
  }

  Widget _buildContractsTab(List<BidOffer> contracts) {
    final state = Provider.of<AppState>(context, listen: false);
    if (contracts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.gavel_rounded,
              size: 48,
              color: AppColors.outlineVariant,
            ),
            const SizedBox(height: 12),
            Text(
              state.translate('no_active_contracts'),
              style: GoogleFonts.inter(color: AppColors.outline),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: contracts.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final contract = contracts[index];
        final state = Provider.of<AppState>(context, listen: false);

        return CustomCard(
          padding: const EdgeInsets.all(18),
          onTap: () => _showContractDetailsSheet(context, state, contract),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Agreement ID & Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.assignment_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${state.translate('agreement')} #${contract.id.substring(0, 8).toUpperCase()}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                  _buildStatusBadge(state, contract.status),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Crop Info
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.eco_rounded,
                      size: 22,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contract.product.name,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.onSurface,
                          ),
                        ),
                        if (contract.product.farmerName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${state.translate('seller')}: ${contract.product.farmerName}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Metrics Row: Quantity & Rate Chips
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 18,
                            color: AppColors.outline,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  state.translate('quantity'),
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.outline,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${contract.quantity.toInt()} ${_translateUnit(state, contract.product.unit)}',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.payments_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  state.translate('rate'),
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_formatCurrency(contract.offeredPrice, contract.product.currency)}/${_translateUnit(state, contract.product.unit)}',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Tap hint
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    state.translate('tap_view_details'),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrdersTab() {
    final state = Provider.of<AppState>(context, listen: false);
    if (_isLoadingOrders) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.receipt_long_rounded,
              size: 48,
              color: AppColors.outlineVariant,
            ),
            const SizedBox(height: 12),
            Text(
              state.translate('no_orders_found'),
              style: GoogleFonts.inter(color: AppColors.outline),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = _orders[index];
        final double total = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
        final String status = order['order_status'] ?? 'PENDING';
        final String pStatus = order['payment_status'] ?? 'UNPAID';
        final state = Provider.of<AppState>(context, listen: false);
        final String currency = resolveOrderCurrency(order, state.products);

        return CustomCard(
          padding: const EdgeInsets.all(18),
          onTap: () => _showOrderDetailsSheet(context, state, order),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Order ID & Order Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${state.translate('order_id')} #${order['id'].toString().substring(0, 8).toUpperCase()}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                  _buildStatusBadge(state, status),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Metrics Row: Payment Status & Total
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.translate('payment_status_label'),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.outline,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            state.translate('status_${pStatus.toLowerCase()}'),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: pStatus == 'PAID'
                                  ? AppColors.primary
                                  : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.translate('total_payable'),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatCurrency(total, currency),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Tap hint
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    state.translate('tap_view_details'),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showContractDetailsSheet(
    BuildContext context,
    AppState state,
    BidOffer contract,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    state.translate('contract_details'),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${state.translate('agreement')} #${contract.id.substring(0, 8).toUpperCase()}',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontSize: 14,
                    ),
                  ),
                  _buildStatusBadge(state, contract.status),
                ],
              ),
              const Divider(height: 24),
              _buildInfoRow(state.translate('buyer'), contract.buyerName),
              const SizedBox(height: 8),
              _buildInfoRow(
                state.translate('seller'),
                contract.product.farmerName.isNotEmpty
                    ? contract.product.farmerName
                    : state.translate('registered_seller'),
              ),
              const Divider(height: 24),
              Text(
                state.translate('invoice_items'),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.shopping_bag_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contract.product.name,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${contract.quantity.toInt()} ${_translateUnit(state, contract.product.unit)} @ ${_formatCurrency(contract.offeredPrice, contract.product.currency)}/${_translateUnit(state, contract.product.unit)}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatCurrency(contract.offeredPrice * contract.quantity, contract.product.currency),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              _buildCostSummary(
                state,
                contract.offeredPrice * contract.quantity,
                currency: contract.product.currency,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: state.translate('download_agreement'),
                  backgroundColor: AppColors.primary,
                  onPressed: () {
                    Navigator.pop(context);
                    _handleContractDownload(context, state, contract);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showOrderDetailsSheet(
    BuildContext context,
    AppState state,
    Map<String, dynamic> order,
  ) {
    final String status = order['order_status'] ?? 'PENDING';
    final double totalAmount =
        (order['total_amount'] as num?)?.toDouble() ?? 0.0;
    final String currency = resolveOrderCurrency(order, state.products);
    final isPickup = (order['delivery_method'] ?? 'DELIVERY') == 'PICKUP';
    // No delivery-fee column exists on the order yet, so the split shown here
    // is reconstructed from today's flat-fee schedule — it may not match what
    // was actually charged on an older order — but must still sum back to the
    // backend's real total_amount rather than inflate it.
    final double deliveryFee = isPickup ? 0.0 : deliveryFeeFor(currency);
    final double subtotal = totalAmount - deliveryFee;
    final items = order['items'] as List<dynamic>? ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    state.translate('invoice_details'),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${state.translate('order_id')} #${order['id'].toString().substring(0, 8).toUpperCase()}',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontSize: 14,
                    ),
                  ),
                  _buildStatusBadge(state, status),
                ],
              ),
              const Divider(height: 24),
              _buildInfoRow(
                state.translate('invoice_date'),
                order['created_at'] != null
                    ? order['created_at'].toString().split('T').first
                    : 'Today',
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                state.translate('payment_method'),
                (order['payment_method'] ?? 'KHQR') == 'COD'
                    ? state.translate('cod_cash')
                    : state.translate('khqr_pay'),
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                state.translate('delivery_method'),
                (order['delivery_method'] ?? 'DELIVERY') == 'PICKUP'
                    ? state.translate('self_pickup')
                    : state.translate('express_delivery'),
              ),
              const Divider(height: 24),
              Text(
                state.translate('invoice_items'),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              ...items.map((item) {
                final matchingProd = state.products.firstWhere(
                  (p) => p.id == item['product_id'],
                  orElse: () => MarketProduct(
                    id: '',
                    name: 'Crop Listing',
                    category: 'Grains',
                    price: 1.0,
                    unit: 'kg',
                    quantity: 0.0,
                    farmerName: 'Verified Farmer',
                    location: 'Cambodia',
                    description: '',
                    imageUrl: '',
                  ),
                );
                final double itemQty =
                    (item['quantity'] as num?)?.toDouble() ?? 1.0;
                final double itemSubtotal =
                    (item['subtotal'] as num?)?.toDouble() ?? totalAmount;
                final double itemRate = itemSubtotal / itemQty;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              matchingProd.name,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${itemQty.toInt()} ${_translateUnit(state, matchingProd.unit)} @ ${_formatCurrency(itemRate, currency)}/${_translateUnit(state, matchingProd.unit)}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatCurrency(itemSubtotal, currency),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 24),
              _buildCostSummary(state, subtotal, currency: currency, deliveryFee: deliveryFee),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: CustomButton.secondary(
                      text: state.translate('download_invoice'),
                      onPressed: () {
                        Navigator.pop(context);
                        _handleInvoiceDownload(context, state, order);
                      },
                    ),
                  ),
                  if (order['payment_status'] == 'PENDING' &&
                      (order['payment_method'] ?? 'KHQR') == 'KHQR') ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomButton(
                        text: state.translate('checkout_khqr'),
                        backgroundColor: AppColors.primary,
                        onPressed: () {
                          final navigator = Navigator.of(context);
                          navigator.pop(); // Close sheet
                          // Settle the order that already exists — creating a
                          // new one here would double-order and double-decrement
                          // the farmer's stock.
                          navigator.push(
                            MaterialPageRoute(
                              builder: (context) => KHQRCheckoutScreen(
                                orders: [
                                  _placedOrderFromRecord(state, order, items, totalAmount),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  if (state.currentRole == 'farmer' &&
                      order['payment_status'] == 'PAID') ...[
                    if (status == 'PLACED') ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomButton(
                          text: 'Mark Packaging',
                          backgroundColor: AppColors.primary,
                          onPressed: () {
                            Navigator.pop(context);
                            _updateOrderStatus(order['id'], 'CONFIRMED');
                          },
                        ),
                      ),
                    ] else if (status == 'CONFIRMED') ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomButton(
                          text: 'Ship Order',
                          backgroundColor: AppColors.primary,
                          onPressed: () {
                            Navigator.pop(context);
                            _updateOrderStatus(order['id'], 'SHIPPED');
                          },
                        ),
                      ),
                    ] else if (status == 'SHIPPED') ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomButton(
                          text: 'Mark Delivered',
                          backgroundColor: AppColors.primary,
                          onPressed: () {
                            Navigator.pop(context);
                            _updateOrderStatus(order['id'], 'DELIVERED');
                          },
                        ),
                      ),
                    ],
                  ],
                  if ((state.currentRole == 'buyer' ||
                          state.currentRole == 'farmer') &&
                      (order['payment_status'] == 'PAID' ||
                          (order['payment_method'] ?? 'KHQR') == 'COD')) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomButton(
                        text: 'Track Order',
                        backgroundColor: AppColors.primary,
                        onPressed: () {
                          Navigator.pop(context); // Close sheet
                          String pName = 'Crop Listing';
                          if (items.isNotEmpty) {
                            final firstItem = items.first;
                            final matchingProd = state.products.firstWhere(
                              (p) => p.id == firstItem['product_id'],
                              orElse: () => MarketProduct(
                                id: '',
                                name: 'Crop Listing',
                                category: 'Grains',
                                price: 1.0,
                                unit: 'kg',
                                quantity: 0.0,
                                farmerName: 'Verified Farmer',
                                location: 'Cambodia',
                                description: '',
                                imageUrl: '',
                              ),
                            );
                            pName = matchingProd.name;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OrderTrackingScreen(
                                orderId: order['id'],
                                productName: pName,
                                price:
                                    totalAmount /
                                    (items.isNotEmpty
                                        ? ((items.first['quantity'] as num?)
                                                  ?.toDouble() ??
                                              1)
                                        : 1),
                                quantity: items.isNotEmpty
                                    ? ((items.first['quantity'] as num?)
                                              ?.toDouble() ??
                                          1)
                                    : 1,
                                total: totalAmount,
                                currency: currency,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.outline),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildCostSummary(
    AppState state,
    double subtotal, {
    String currency = 'USD',
    double deliveryFee = 0.0,
  }) {
    final double total = subtotal + deliveryFee;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              state.translate('subtotal'),
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.outline),
            ),
            Text(
              _formatCurrency(subtotal, currency),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              state.translate('delivery_fee'),
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.outline),
            ),
            Text(
              _formatCurrency(deliveryFee, currency),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const Divider(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              state.translate('total_payable'),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
            Text(
              _formatCurrency(total, currency),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleInvoiceDownload(
    BuildContext context,
    AppState state,
    Map<String, dynamic> order,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  state.translate('downloading_sim'),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final success = await PdfGeneratorService.downloadOrPrintInvoice(
      order: order,
      state: state,
    );

    if (!context.mounted) return;
    Navigator.pop(context); // Close loading dialog

    if (success) {
      _showDownloadResultDialog(
        context: context,
        state: state,
        isSuccess: true,
        title: state.translate('success'),
        message: state.translate('download_success_sim'),
        onRetry: null,
      );
    } else {
      _showDownloadResultDialog(
        context: context,
        state: state,
        isSuccess: false,
        title: state.translate('download_failed'),
        message: state.translate('download_failed'),
        onRetry: () => _handleInvoiceDownload(context, state, order),
      );
    }
  }

  Future<void> _handleContractDownload(
    BuildContext context,
    AppState state,
    BidOffer contract,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  state.translate('downloading_sim'),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final success = await PdfGeneratorService.downloadOrPrintContract(
      contract: contract,
      state: state,
    );

    if (!context.mounted) return;
    Navigator.pop(context); // Close loading dialog

    if (success) {
      _showDownloadResultDialog(
        context: context,
        state: state,
        isSuccess: true,
        title: state.translate('success'),
        message: state.translate('download_success_sim'),
        onRetry: null,
      );
    } else {
      _showDownloadResultDialog(
        context: context,
        state: state,
        isSuccess: false,
        title: state.translate('download_failed'),
        message: state.translate('download_failed'),
        onRetry: () => _handleContractDownload(context, state, contract),
      );
    }
  }

  void _showDownloadResultDialog({
    required BuildContext context,
    required AppState state,
    required bool isSuccess,
    required String title,
    required String message,
    VoidCallback? onRetry,
  }) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isSuccess ? AppColors.primary : AppColors.error)
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSuccess
                    ? Icons.check_circle_rounded
                    : Icons.error_outline_rounded,
                color: isSuccess ? AppColors.primary : AppColors.error,
                size: 44,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (!isSuccess && onRetry != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(dialogCtx);
                        onRetry();
                      },
                      child: Text(
                        state.translate('retry'),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSuccess ? AppColors.primary : AppColors.error,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: Text(
                      state.translate('close'),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
