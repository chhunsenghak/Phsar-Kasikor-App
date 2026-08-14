import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_input.dart';
import '../../services/api/order_api.dart';
import '../../services/api/review_api.dart';
import '../../services/api/dispute_api.dart';
import '../buyer/khqr_checkout.dart';
import '../buyer/order_tracking.dart';
import '../buyer/contract_builder_screen.dart';
import '../buyer/contract_deposit_checkout_screen.dart';
import 'chat_thread_screen.dart';
import '../../services/pdf_generator_service.dart';
import '../../utils/api_error.dart';
import '../../utils/phnom_penh_time.dart';
import '../../utils/numeric_input.dart' as numeric_input;
import '../../utils/currency_format.dart' as currency_format;
import '../../widgets/app_snackbar.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/ship_order_dialog.dart';

class OrderContractHistoryScreen extends StatefulWidget {
  final int initialTab;
  final bool isPushed;
  // When opened from a specific chat (via its "View Contracts" menu item),
  // the Contracts tab scopes down to just that counterparty's contracts
  // instead of every contract this user has — seeing every other seller's
  // agreements would be a confusing answer to "view contracts [with the
  // person I'm chatting with]". Both null shows everything, as before.
  final String? counterpartyId;
  final String? counterpartyName;
  const OrderContractHistoryScreen({
    super.key,
    this.initialTab = 0,
    this.isPushed = false,
    this.counterpartyId,
    this.counterpartyName,
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

  /// 'ALL' or one of the order_status values — filters the orders tab list
  /// without a separate network call, since [_orders] already holds
  /// everything for this user.
  String _orderStatusFilter = 'ALL';
  DateTimeRange? _orderDateRange;
  double? _orderMinPrice;
  double? _orderMaxPrice;

  static const List<String> _orderStatusFilters = [
    'ALL',
    'PLACED',
    'CONFIRMED',
    'SHIPPED',
    'DELIVERED',
    'CANCELLED',
  ];

  /// Contracts have no dedicated "created" timestamp today (unlike orders) —
  /// their `startDate` is the forward delivery window already shown on every
  /// contract card, so it doubles as the filterable "date" here rather than
  /// adding a new backend field purely for this.
  String _contractStatusFilter = 'ALL';
  DateTimeRange? _contractDateRange;
  double? _contractMinPrice;
  double? _contractMaxPrice;

  static const List<String> _contractStatusFilters = [
    'ALL',
    'pending',
    'pending_deposit',
    'accepted',
    'pending_final_payment',
    'in_fulfillment',
    'completed',
    'rejected',
  ];

  bool get _orderHasExtraFilters =>
      _orderDateRange != null ||
      _orderMinPrice != null ||
      _orderMaxPrice != null;
  bool get _contractHasExtraFilters =>
      _contractDateRange != null ||
      _contractMinPrice != null ||
      _contractMaxPrice != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    // Nothing else reads _tabController.index today — this listener exists
    // solely so the "start a new contract" FAB can show/hide itself as the
    // user switches between the Contracts and Orders tabs.
    _tabController.addListener(() => setState(() {}));
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
      // Admins review every order on the platform, not just ones they
      // happen to be a buyer/seller party to.
      final list = state.currentRole == 'admin'
          ? await OrderApi.fetchAllOrdersAdmin(state.token!)
          : await OrderApi.fetchOrders(state.token!);
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

  Future<void> _updateOrderStatus(
    String orderId,
    String nextStatus, {
    String? contactPhone,
    String? deliveryNotes,
    double? actualDeliveryCost,
  }) async {
    final state = Provider.of<AppState>(context, listen: false);
    if (state.token == null) return;
    try {
      await OrderApi.updateOrder(
        state.token!,
        orderId,
        orderStatus: nextStatus,
        contactPhone: contactPhone,
        deliveryNotes: deliveryNotes,
        actualDeliveryCost: actualDeliveryCost,
      );
      await _loadOrders();
      if (mounted) {
        AppSnackBar.success(
          context,
          state.translate(
            'order_status_success_msg',
            arguments: {'status': nextStatus},
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, friendlyApiError(state, e));
      }
    }
  }

  Future<void> _confirmCancelOrder(
    BuildContext sheetContext,
    AppState state,
    Map<String, dynamic> order,
  ) async {
    // Shows on top of the still-open details sheet — the sheet must not be
    // popped before this, or sheetContext would already be invalid and the
    // dialog would silently fail to appear (this was the original bug: the
    // caller popped the sheet, then tried to open a dialog on the context
    // that pop had just invalidated).
    final confirmed = await showDialog<bool>(
      context: sheetContext,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          state.translate('cancel_order_title'),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          state.translate('cancel_order_confirm'),
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              state.translate('keep_order'),
              style: GoogleFonts.inter(color: AppColors.outline),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              state.translate('cancel_order'),
              style: GoogleFonts.inter(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (sheetContext.mounted) Navigator.pop(sheetContext);

    // From here on, use the screen's own context (via `mounted`/bare
    // `context`) rather than sheetContext, which was just popped above.
    try {
      await OrderApi.cancelOrder(state.token!, order['id'].toString());
      await _loadOrders();
      if (mounted) {
        AppSnackBar.success(
          context,
          state.translate('order_cancelled_success'),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, friendlyApiError(state, e));
      }
    }
  }

  /// Confirms before the buyer withdraws their own contract request —
  /// mirrors [_confirmCancelOrder]'s dialog-over-the-still-open-sheet
  /// pattern for the same reason (the sheet's context must still be valid
  /// when the dialog is shown).
  Future<bool> _confirmWithdrawOffer(
    BuildContext sheetContext,
    AppState state,
  ) async {
    final confirmed = await showDialog<bool>(
      context: sheetContext,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          state.translate('withdraw_offer_title'),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          state.translate('withdraw_offer_confirm'),
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              state.translate('keep_offer'),
              style: GoogleFonts.inter(color: AppColors.outline),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              state.translate('withdraw_offer'),
              style: GoogleFonts.inter(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  String _formatCurrency(num amount, [String currency = 'USD']) => currency_format.formatCurrency(amount, currency);

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

      cartItems.add(
        CartItem(
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
            farmerName:
                known?.farmerName ?? state.translate('registered_seller'),
            location: known?.location ?? '',
            description: known?.description ?? '',
            imageUrl: known?.imageUrl ?? '',
            sellerId: order['seller_id']?.toString(),
          ),
        ),
      );
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
      deliveryFee: (order['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      deliveryMethod: (order['delivery_method'] ?? 'DELIVERY').toString(),
    );
  }

  /// Cambodia local date + time (e.g. "2026-08-04 05:33 PM") for the order
  /// footer — see utils/phnom_penh_time.dart for why this can't just call
  /// `.toLocal()` on the backend's naive-UTC timestamp string.
  String _orderDateTimeText(AppState state, Map<String, dynamic> order) {
    final raw = order['created_at']?.toString();
    if (raw == null) return state.translate('today_label');
    return formatPhnomPenhDateTime(raw);
  }

  String _translateUnit(AppState state, String? rawUnit) {
    if (rawUnit == null || rawUnit.isEmpty) return '';
    final u = rawUnit.toLowerCase().replaceAll('s', '');
    if (state.hasTranslation(u)) {
      return state.translate(u);
    }
    return rawUnit;
  }

  ({Color bg, Color fg, IconData icon, String textKey}) _statusVisual(
    String rawStatus,
  ) {
    final s = rawStatus.toLowerCase();

    if (s == 'accepted' ||
        s == 'paid' ||
        s == 'completed' ||
        s == 'delivered') {
      return (
        bg: AppColors.primary.withValues(alpha: 0.12),
        fg: AppColors.primary,
        icon: Icons.check_circle_rounded,
        textKey: s == 'accepted'
            ? 'status_accepted'
            : (s == 'paid'
                  ? 'status_paid'
                  : (s == 'delivered' ? 'status_delivered' : 'status_completed')),
      );
    } else if (s == 'rejected' || s == 'cancelled') {
      return (
        bg: AppColors.error.withValues(alpha: 0.12),
        fg: AppColors.error,
        icon: Icons.cancel_rounded,
        textKey: s == 'rejected' ? 'status_rejected' : 'status_cancelled',
      );
    } else if (s == 'counter_offered' || s == 'counter') {
      return (
        bg: Colors.blue.withValues(alpha: 0.12),
        fg: Colors.blue.shade700,
        icon: Icons.swap_horizontal_circle_rounded,
        textKey: 'status_countered',
      );
    } else if (s == 'pending_deposit') {
      return (
        bg: Colors.amber.withValues(alpha: 0.15),
        fg: Colors.amber.shade900,
        icon: Icons.qr_code_2_rounded,
        textKey: 'status_pending_deposit',
      );
    } else if (s == 'pending_final_payment') {
      return (
        bg: Colors.deepOrange.withValues(alpha: 0.12),
        fg: Colors.deepOrange.shade700,
        icon: Icons.local_shipping_outlined,
        textKey: 'status_pending_final_payment',
      );
    } else if (s == 'in_fulfillment') {
      return (
        bg: Colors.blue.withValues(alpha: 0.12),
        fg: Colors.blue.shade700,
        icon: Icons.local_shipping_rounded,
        textKey: 'status_in_fulfillment',
      );
    } else if (s == 'confirmed' || s == 'shipped') {
      // Order-only mid-fulfillment states — CONFIRMED (farmer is packaging)
      // and SHIPPED (in transit / ready for pickup) previously fell through
      // to the "else" branch below and rendered as a generic amber
      // "PENDING" badge, so a fully-shipped order looked identical to one
      // that had just been placed.
      return (
        bg: Colors.blue.withValues(alpha: 0.12),
        fg: Colors.blue.shade700,
        icon: s == 'shipped'
            ? Icons.local_shipping_rounded
            : Icons.inventory_2_rounded,
        textKey: s == 'shipped' ? 'status_shipped' : 'status_confirmed',
      );
    } else {
      return (
        bg: Colors.amber.withValues(alpha: 0.15),
        fg: Colors.amber.shade900,
        icon: Icons.schedule_rounded,
        textKey: s == 'placed' ? 'status_placed' : 'status_pending',
      );
    }
  }

  Widget _buildStatusBadge(AppState state, String rawStatus) {
    final visual = _statusVisual(rawStatus);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: visual.bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(visual.icon, size: 12, color: visual.fg),
          const SizedBox(width: 4),
          Text(
            state.translate(visual.textKey),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: visual.fg,
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
      
        toolbarHeight: widget.isPushed ? kToolbarHeight : 20,
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
        title: widget.isPushed
            ? Text(
                widget.counterpartyName ?? state.translate('wholesale_history'),
                style: GoogleFonts.inter(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              )
            : null,
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
      floatingActionButton:
          (state.currentRole == 'buyer' && _tabController.index == 0)
          ? FloatingActionButton.extended(
              onPressed: () => _showSellerPickerSheet(context, state),
              icon: const Icon(Icons.handshake_outlined),
              label: Text(
                state.translate('propose_contract'),
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  /// Lets a buyer start a contract directly with a seller they already know,
  /// without first having to find and open that chat — a second entry point
  /// alongside the chat-first flow, both feeding the same
  /// `ContractBuilderScreen`. Sellers are grouped by id (not name — names
  /// aren't guaranteed unique) from the products already loaded in
  /// [AppState], the same source `farm_map_directory.dart` groups from.
  void _showSellerPickerSheet(BuildContext context, AppState state) {
    final myId = state.userProfile?['id']?.toString();
    final Map<String, ({String name, int productCount})> sellers = {};
    for (final p in state.products) {
      if (p.sellerId == null || p.sellerId == myId) continue;
      final existing = sellers[p.sellerId!];
      sellers[p.sellerId!] = (
        name: existing?.name ?? p.farmerName,
        productCount: (existing?.productCount ?? 0) + 1,
      );
    }
    final sellerIds = sellers.keys.toList()
      ..sort((a, b) => sellers[a]!.name.compareTo(sellers[b]!.name));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
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
            Text(
              state.translate('select_seller_title'),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            if (sellerIds.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  state.translate('no_sellers_available'),
                  style: GoogleFonts.inter(color: AppColors.outline),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: sellerIds.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final sellerId = sellerIds[index];
                    final seller = sellers[sellerId]!;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: UserAvatar(name: seller.name, seed: sellerId),
                      title: Text(
                        seller.name,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        state.translate(
                          'items_count',
                          arguments: {'count': seller.productCount.toString()},
                        ),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ContractBuilderScreen(
                              sellerId: sellerId,
                              sellerName: seller.name,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContractsTab(List<BidOffer> unscopedContracts) {
    final state = Provider.of<AppState>(context, listen: false);
    final allContracts = widget.counterpartyId == null
        ? unscopedContracts
        : unscopedContracts
              .where(
                (c) =>
                    c.buyerId == widget.counterpartyId ||
                    c.sellerId == widget.counterpartyId,
              )
              .toList();
    if (allContracts.isEmpty) {
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

    final contracts = allContracts.where((c) {
      if (_contractStatusFilter != 'ALL' && c.status != _contractStatusFilter) {
        return false;
      }
      if (!_dateInRange(c.startDate, _contractDateRange)) return false;
      if (!_priceInRange(c.totalValue, _contractMinPrice, _contractMaxPrice)) {
        return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        _buildFilterBar(
          Row(
            children: [
              Expanded(
                child: _buildStatusFilterChips(
                  _contractStatusFilters,
                  _contractStatusFilter,
                  (value) => value == 'ALL'
                      ? state.translate('all')
                      : state.translate('status_$value'),
                  (value) => setState(() => _contractStatusFilter = value),
                ),
              ),
              const SizedBox(width: 8),
              _buildMoreFiltersButton(
                active: _contractHasExtraFilters,
                onPressed: () => _showMoreFiltersSheet(
                  context,
                  state,
                  initialRange: _contractDateRange,
                  initialMin: _contractMinPrice,
                  initialMax: _contractMaxPrice,
                  onApply: (range, min, max) => setState(() {
                    _contractDateRange = range;
                    _contractMinPrice = min;
                    _contractMaxPrice = max;
                  }),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: contracts.isEmpty
              ? Center(
                  child: Text(
                    state.translate('no_contracts_match_filter'),
                    style: GoogleFonts.inter(color: AppColors.outline),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: contracts.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final contract = contracts[index];
                    final state = Provider.of<AppState>(context, listen: false);

                    return CustomCard(
                      padding: const EdgeInsets.all(18),
                      elevationLevel: 2,
                      onTap: () =>
                          _showContractDetailsSheet(context, state, contract),
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
                                      color: AppColors.primary.withValues(
                                        alpha: 0.1,
                                      ),
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
                                      contract.items.length > 1
                                          ? '${contract.product.name} +${contract.items.length - 1}'
                                          : contract.product.name,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: AppColors.onSurface,
                                      ),
                                    ),
                                    if (contract.sellerName.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        '${state.translate('seller')}: ${contract.sellerName}',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                    // Admins aren't a party to the contract —
                                    // show the buyer too, since "seller"
                                    // alone doesn't identify the deal.
                                    if (state.currentRole == 'admin' && contract.buyerName.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        '${state.translate('buyer')}: ${contract.buyerName}',
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

                          // Delivery window: what makes this a *contract* rather than a
                          // plain sale — a committed future date range for a crop that's
                          // still growing, not something exchanged today. Absent for
                          // local/offline negotiations that never became a real backend
                          // contract yet.
                          if (contract.startDate != null &&
                              contract.endDate != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryContainer.withValues(
                                  alpha: 0.4,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.event_repeat_rounded,
                                    size: 18,
                                    color: AppColors.onSecondaryContainer,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          state.translate('expected_delivery'),
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            color:
                                                AppColors.onSecondaryContainer,
                                          ),
                                        ),
                                        Text(
                                          state.translate(
                                            'delivery_window',
                                            arguments: {
                                              'start': contract.startDate!
                                                  .toIso8601String()
                                                  .split('T')
                                                  .first,
                                              'end': contract.endDate!
                                                  .toIso8601String()
                                                  .split('T')
                                                  .first,
                                            },
                                          ),
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color:
                                                AppColors.onSecondaryContainer,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              state.translate(
                                                'contract_products',
                                              ),
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: AppColors.outline,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              state.translate(
                                                'items_count',
                                                arguments: {
                                                  'count': contract.items.length
                                                      .toString(),
                                                },
                                              ),
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
                                    color: AppColors.primary.withValues(
                                      alpha: 0.08,
                                    ),
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              state.translate('total_value'),
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _formatCurrency(
                                                contract.totalValue,
                                                contract.product.currency,
                                              ),
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
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Wraps the status-chip row + tune button in its own visually distinct
  /// band, separated from the tab bar above and the list below, so filtering
  /// doesn't read as fused to the tab switcher.
  Widget _buildFilterBar(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: AppColors.outlineVariant, width: 1),
        ),
      ),
      child: child,
    );
  }

  Widget _buildStatusFilterChips(
    List<String> options,
    String selected,
    String Function(String) labelFor,
    ValueChanged<String> onSelected,
  ) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final value = options[index];
          final isSelected = selected == value;
          return ChoiceChip(
            label: Text(
              labelFor(value),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? AppColors.onSecondaryContainer
                    : AppColors.onSurfaceVariant,
              ),
            ),
            selected: isSelected,
            selectedColor: AppColors.secondaryContainer,
            backgroundColor: AppColors.surfaceContainerLow,
            onSelected: (wasSelected) {
              if (wasSelected) onSelected(value);
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                AppDesign.borderRadiusDefault,
              ),
              side: BorderSide(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 1,
              ),
            ),
          );
        },
      ),
    );
  }

  /// Small "more filters" (date range + price range) trigger, shown beside
  /// the status chips row on both tabs — a filled dot marks it when a
  /// non-status filter is active, since those don't have their own visible
  /// chip the way status does.
  Widget _buildMoreFiltersButton({
    required bool active,
    required VoidCallback onPressed,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withValues(alpha: 0.12)
                : AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? AppColors.primary : Colors.transparent,
            ),
          ),
          child: IconButton(
            icon: Icon(
              Icons.tune_rounded,
              color: active ? AppColors.primary : AppColors.onSurfaceVariant,
              size: 20,
            ),
            onPressed: onPressed,
            tooltip: null,
          ),
        ),
        if (active)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  bool _dateInRange(DateTime? day, DateTimeRange? range) {
    if (range == null) return true;
    if (day == null) return false;
    final d = DateTime(day.year, day.month, day.day);
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(range.end.year, range.end.month, range.end.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  bool _priceInRange(double value, double? min, double? max) {
    if (min != null && value < min) return false;
    if (max != null && value > max) return false;
    return true;
  }

  /// Shared bottom sheet for the date-range + price-range filters, used by
  /// both tabs — only the initial values and the apply callback differ.
  void _showMoreFiltersSheet(
    BuildContext context,
    AppState state, {
    required DateTimeRange? initialRange,
    required double? initialMin,
    required double? initialMax,
    required void Function(DateTimeRange? range, double? min, double? max)
    onApply,
  }) {
    DateTimeRange? tempRange = initialRange;
    final minController = TextEditingController(
      text: initialMin == null ? '' : initialMin.toStringAsFixed(0),
    );
    final maxController = TextEditingController(
      text: initialMax == null ? '' : initialMax.toStringAsFixed(0),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        state.translate('more_filters'),
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            tempRange = null;
                            minController.clear();
                            maxController.clear();
                          });
                        },
                        child: Text(
                          state.translate('clear_filters'),
                          style: GoogleFonts.inter(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Text(
                    state.translate('date_range'),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDateRangePicker(
                        context: sheetContext,
                        firstDate: DateTime(now.year - 3),
                        lastDate: DateTime(now.year + 3),
                        initialDateRange: tempRange,
                      );
                      if (picked != null) {
                        setModalState(() => tempRange = picked);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.date_range_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              tempRange == null
                                  ? state.translate('select_date_range')
                                  : '${formatDateOnly(tempRange!.start)}   →   ${formatDateOnly(tempRange!.end)}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    state.translate('price_range'),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: CustomInput(
                          label: state.translate('min_price'),
                          hintText: '0',
                          controller: minController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomInput(
                          label: state.translate('max_price'),
                          hintText: '999999',
                          controller: maxController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        onApply(
                          tempRange,
                          double.tryParse(minController.text),
                          double.tryParse(maxController.text),
                        );
                        Navigator.pop(sheetContext);
                      },
                      child: Text(
                        state.translate('apply_filters'),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
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

    final filteredOrders = _orders.where((o) {
      if (_orderStatusFilter != 'ALL' &&
          (o['order_status'] ?? 'PLACED') != _orderStatusFilter) {
        return false;
      }
      final phnomPenhCreated = backendUtcToPhnomPenh(
        o['created_at']?.toString(),
      );
      if (!_dateInRange(phnomPenhCreated, _orderDateRange)) return false;
      final double total = (o['total_amount'] as num?)?.toDouble() ?? 0.0;
      if (!_priceInRange(total, _orderMinPrice, _orderMaxPrice)) return false;
      return true;
    }).toList();

    return Column(
      children: [
        _buildFilterBar(
          Row(
            children: [
              Expanded(
                child: _buildStatusFilterChips(
                  _orderStatusFilters,
                  _orderStatusFilter,
                  (value) => value == 'ALL'
                      ? state.translate('all')
                      : state.translate('status_${value.toLowerCase()}'),
                  (value) => setState(() => _orderStatusFilter = value),
                ),
              ),
              const SizedBox(width: 8),
              _buildMoreFiltersButton(
                active: _orderHasExtraFilters,
                onPressed: () => _showMoreFiltersSheet(
                  context,
                  state,
                  initialRange: _orderDateRange,
                  initialMin: _orderMinPrice,
                  initialMax: _orderMaxPrice,
                  onApply: (range, min, max) => setState(() {
                    _orderDateRange = range;
                    _orderMinPrice = min;
                    _orderMaxPrice = max;
                  }),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filteredOrders.isEmpty
              ? Center(
                  child: Text(
                    state.translate('no_orders_match_filter'),
                    style: GoogleFonts.inter(color: AppColors.outline),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredOrders.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final order = filteredOrders[index];
                    final double total =
                        (order['total_amount'] as num?)?.toDouble() ?? 0.0;
                    final String status = order['order_status'] ?? 'PENDING';
                    final String pStatus = order['payment_status'] ?? 'UNPAID';
                    final bool isPaid = pStatus == 'PAID';
                    final state = Provider.of<AppState>(context, listen: false);
                    final String currency = resolveOrderCurrency(
                      order,
                      state.products,
                    );
                    final items = order['items'] as List<dynamic>? ?? [];
                    final MarketProduct firstProduct = items.isEmpty
                        ? MarketProduct(
                            id: '',
                            name: state.translate('crop_listing'),
                            category: 'Grains',
                            price: 1.0,
                            unit: 'kg',
                            quantity: 0.0,
                            farmerName: state.translate(
                              'verified_farmer_fallback',
                            ),
                            location: state.translate('cambodia_fallback'),
                            description: '',
                            imageUrl: '',
                          )
                        : state.products.firstWhere(
                            (p) => p.id == items.first['product_id'],
                            orElse: () => MarketProduct(
                              id: '',
                              name: state.translate('crop_listing'),
                              category: 'Grains',
                              price: 1.0,
                              unit: 'kg',
                              quantity: 0.0,
                              farmerName: state.translate(
                                'verified_farmer_fallback',
                              ),
                              location: state.translate('cambodia_fallback'),
                              description: '',
                              imageUrl: '',
                            ),
                          );

                    final bool isFarmerView = state.currentRole == 'farmer';
                    final String buyerDisplayName = order['buyer_name']?.toString().isNotEmpty == true
                        ? order['buyer_name'].toString()
                        : state.translate('registered_buyer');
                    final String sellerDisplayName = order['seller_name']?.toString().isNotEmpty == true
                        ? order['seller_name'].toString()
                        : firstProduct.farmerName;
                    // Admins aren't a party to the order — show both sides
                    // instead of picking one, since neither is "the other
                    // side" from their vantage point.
                    final String counterpartyName = state.currentRole == 'admin'
                        ? '$buyerDisplayName → $sellerDisplayName'
                        : (isFarmerView ? buyerDisplayName : sellerDisplayName);
                    final Widget? footerFlag = _buildOrderFooterFlag(
                      state,
                      order,
                      status,
                      isPaid,
                    );

                    return CustomCard(
                      padding: const EdgeInsets.all(16),
                      elevationLevel: 2,
                      onTap: () =>
                          _showOrderDetailsSheet(context, state, order),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Headline: a colored icon block anchors the card at
                          // a glance, with the product name, status, and
                          // counterparty/date grouped beside it.
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.shopping_bag_rounded,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            items.length > 1
                                                ? '${firstProduct.name} +${items.length - 1}'
                                                : firstProduct.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: AppColors.onSurface,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildStatusBadge(state, status),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    // Who's on the other side, and when — one
                                    // line instead of two icon+label rows.
                                    Row(
                                      children: [
                                        Icon(
                                          isFarmerView
                                              ? Icons.person_outline_rounded
                                              : Icons.storefront_outlined,
                                          size: 13,
                                          color: AppColors.outline,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            counterpartyName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: AppColors.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _orderDateTimeText(state, order),
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: AppColors.outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // Status flag: an "Unpaid" warning or the farmer's
                          // next fulfillment step — only shown when relevant.
                          if (footerFlag != null) ...[
                            const SizedBox(height: 10),
                            footerFlag,
                          ],

                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 10),

                          // Footer row: order reference (support/reprint use
                          // only, so kept small) on the left, total payable —
                          // the number someone actually scans for — on the right.
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                '#${order['id'].toString().substring(0, 8).toUpperCase()}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.outline,
                                ),
                              ),
                              Text(
                                _formatCurrency(total, currency),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 19,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// The one right-hand indicator on an order card: an "Unpaid" warning when
  /// payment is actually overdue (KHQR orders only — COD is unpaid by design
  /// until collection), or the farmer's next fulfillment step when one is
  /// ready. Returns null when neither applies, so the card can skip the row
  /// entirely instead of reserving empty space for it.
  Widget? _buildOrderFooterFlag(
    AppState state,
    Map<String, dynamic> order,
    String status,
    bool isPaid,
  ) {
    final bool isCod = (order['payment_method'] ?? 'KHQR') == 'COD';
    final bool needsPayment = !isPaid && !isCod;

    if (needsPayment) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.schedule_rounded,
              size: 12,
              color: Colors.amber.shade900,
            ),
            const SizedBox(width: 4),
            Text(
              state.translate('status_unpaid'),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.amber.shade900,
              ),
            ),
          ],
        ),
      );
    }

    final String? nextAction = _farmerNextActionLabel(
      state,
      order,
      status,
      isPaid,
    );
    if (nextAction != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          state.translate(
            'next_action_label',
            arguments: {'action': nextAction},
          ),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      );
    }

    return null;
  }

  /// What the farmer still needs to do to move this order forward, or null
  /// if nothing is actionable (wrong role, unpaid, or already at rest).
  String? _farmerNextActionLabel(
    AppState state,
    Map<String, dynamic> order,
    String status,
    bool isPaid,
  ) {
    if (state.currentRole != 'farmer' || !isPaid) return null;
    final bool isPickup = (order['delivery_method'] ?? 'DELIVERY') == 'PICKUP';
    switch (status) {
      case 'PLACED':
        return state.translate('mark_packaging');
      case 'CONFIRMED':
        return isPickup
            ? state.translate('mark_ready_pickup')
            : state.translate('ship_order');
      case 'SHIPPED':
        return isPickup
            ? state.translate('mark_collected')
            : state.translate('mark_delivered');
      default:
        return null;
    }
  }

  void _showContractDetailsSheet(
    BuildContext context,
    AppState state,
    BidOffer contract,
  ) {
    final bool isFarmerParty =
        contract.sellerId != null &&
        contract.sellerId == state.userProfile?['id']?.toString();
    final bool isBuyerParty =
        contract.buyerId != null &&
        contract.buyerId == state.userProfile?['id']?.toString();
    // 'pending' covers the backend's DRAFT status — the stage where
    // accept/decline/counter-offer are meaningful; 'pending_deposit' is the
    // next stage, where the only thing left is the buyer's deposit (or
    // either party backing out). 'accepted' (ACTIVE) is where the seller
    // eventually requests the final payment; 'pending_final_payment' is the
    // buyer's turn to settle it; 'in_fulfillment' hands delivery off to a
    // real order (see ContractStateMixin.requestFinalPayment) — both
    // parties just track it from here. TERMINATED/COMPLETED are resolved.
    final bool isDraft = contract.status == 'pending';
    final bool isPendingDeposit = contract.status == 'pending_deposit';
    final bool isActive = contract.status == 'accepted';
    final bool isPendingFinalPayment = contract.status == 'pending_final_payment';
    final bool isInFulfillment = contract.status == 'in_fulfillment';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        bool isProcessing = false;
        return StatefulBuilder(
          builder: (context, setSheetState) => Container(
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
                  contract.sellerName.isNotEmpty
                      ? contract.sellerName
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
                ...contract.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
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
                                item.product.name,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${item.agreedQuantity.toInt()} ${_translateUnit(state, item.product.unit)} @ ${_formatCurrency(item.agreedPrice, item.product.currency)}/${_translateUnit(state, item.product.unit)}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _formatCurrency(
                            item.agreedPrice * item.agreedQuantity,
                            item.product.currency,
                          ),
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 24),
                _buildCostSummary(
                  state,
                  contract.totalValue,
                  currency: contract.product.currency,
                ),
                const SizedBox(height: 24),

                if (isDraft && isFarmerParty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton.secondary(
                          text: state.translate('decline_agreement'),
                          onPressed: isProcessing
                              ? null
                              : () async {
                                  setSheetState(() => isProcessing = true);
                                  final error = await state.rejectBid(
                                    contract.id,
                                  );
                                  if (error != null) {
                                    setSheetState(() => isProcessing = false);
                                    if (!context.mounted) return;
                                    AppSnackBar.error(
                                      context,
                                      friendlyContractErrorMessage(
                                        state,
                                        error,
                                      ),
                                    );
                                    return;
                                  }
                                  if (!context.mounted) return;
                                  Navigator.pop(context);
                                  AppSnackBar.success(
                                    context,
                                    state.translate('contract_declined_msg'),
                                  );
                                },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomButton(
                          text: state.translate('accept_agreement'),
                          backgroundColor: AppColors.primary,
                          isLoading: isProcessing,
                          onPressed: isProcessing
                              ? null
                              : () => _showAcceptWithDepositDialog(
                                  context,
                                  state,
                                  contract,
                                  setSheetState,
                                  (value) => isProcessing = value,
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: isProcessing
                          ? null
                          : () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ContractBuilderScreen(
                                    sellerId: contract.sellerId ?? '',
                                    sellerName: contract.sellerName,
                                    existingContract: contract,
                                  ),
                                ),
                              );
                            },
                      child: Text(
                        state.translate('counter_offer'),
                        style: GoogleFonts.inter(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ] else if (isDraft && isBuyerParty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer.withValues(
                        alpha: 0.4,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.hourglass_top_rounded,
                          size: 16,
                          color: AppColors.onSecondaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.translate('awaiting_farmer_response'),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton.secondary(
                      text: state.translate('withdraw_offer'),
                      isLoading: isProcessing,
                      onPressed: isProcessing
                          ? null
                          : () async {
                              if (!await _confirmWithdrawOffer(context, state)) {
                                return;
                              }
                              if (!context.mounted) return;
                              setSheetState(() => isProcessing = true);
                              final error = await state.rejectBid(contract.id);
                              if (error != null) {
                                setSheetState(() => isProcessing = false);
                                if (!context.mounted) return;
                                AppSnackBar.error(
                                  context,
                                  friendlyContractErrorMessage(state, error),
                                );
                                return;
                              }
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              AppSnackBar.success(
                                context,
                                state.translate('offer_withdrawn_msg'),
                              );
                            },
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else if (isPendingDeposit && isBuyerParty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.qr_code_2_rounded,
                          size: 16,
                          color: Colors.amber.shade900,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.translate(
                              'deposit_required_msg',
                              arguments: {
                                'amount': _formatCurrency(
                                  contract.depositAmount ?? 0,
                                  contract.depositCurrency ??
                                      contract.product.currency,
                                ),
                              },
                            ),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      text: state.translate('pay_deposit'),
                      backgroundColor: AppColors.primary,
                      icon: Icons.qr_code_2_rounded,
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ContractDepositCheckoutScreen(
                              contractId: contract.id,
                              depositAmount: contract.depositAmount ?? 0,
                              depositCurrency:
                                  contract.depositCurrency ??
                                  contract.product.currency,
                              sellerName: contract.sellerName,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: isProcessing
                          ? null
                          : () async {
                              if (!await _confirmWithdrawOffer(context, state)) {
                                return;
                              }
                              if (!context.mounted) return;
                              setSheetState(() => isProcessing = true);
                              final error = await state.rejectBid(contract.id);
                              if (error != null) {
                                setSheetState(() => isProcessing = false);
                                if (!context.mounted) return;
                                AppSnackBar.error(
                                  context,
                                  friendlyContractErrorMessage(state, error),
                                );
                                return;
                              }
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              AppSnackBar.success(
                                context,
                                state.translate('offer_withdrawn_msg'),
                              );
                            },
                      child: Text(
                        state.translate('withdraw_offer'),
                        style: GoogleFonts.inter(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ] else if (isPendingDeposit && isFarmerParty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer.withValues(
                        alpha: 0.4,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.hourglass_top_rounded,
                          size: 16,
                          color: AppColors.onSecondaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.translate('awaiting_buyer_deposit'),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else if (isActive && isFarmerParty) ...[
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      text: state.translate('request_final_payment'),
                      backgroundColor: AppColors.primary,
                      icon: Icons.local_shipping_outlined,
                      onPressed: isProcessing
                          ? null
                          : () => _showRequestFinalPaymentDialog(
                              context,
                              state,
                              contract,
                              setSheetState,
                              (value) => isProcessing = value,
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else if (isActive && isBuyerParty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.hourglass_top_rounded, size: 16, color: AppColors.onSecondaryContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.translate('awaiting_final_delivery'),
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSecondaryContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else if (isPendingFinalPayment && isBuyerParty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.local_shipping_outlined, size: 16, color: Colors.deepOrange.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.translate('final_balance_due_msg', arguments: {
                              'amount': _formatCurrency(
                                contract.finalAmount ?? 0,
                                contract.depositCurrency ?? contract.product.currency,
                              ),
                            }),
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.deepOrange.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      text: state.translate('pay_final_balance'),
                      backgroundColor: AppColors.primary,
                      icon: Icons.qr_code_2_rounded,
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ContractDepositCheckoutScreen(
                              contractId: contract.id,
                              depositAmount: contract.finalAmount ?? 0,
                              depositCurrency: contract.depositCurrency ?? contract.product.currency,
                              sellerName: contract.sellerName,
                              kind: ContractPaymentKind.finalPayment,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else if (isPendingFinalPayment && isFarmerParty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.hourglass_top_rounded, size: 16, color: AppColors.onSecondaryContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.translate('awaiting_buyer_final_payment'),
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSecondaryContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else if (isInFulfillment && contract.fulfillmentOrderId != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_shipping_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.translate('contract_in_fulfillment_msg'),
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      text: state.translate('track_delivery'),
                      backgroundColor: AppColors.primary,
                      icon: Icons.local_shipping_outlined,
                      onPressed: () {
                        Navigator.pop(context);
                        final double qty = contract.items.first.agreedQuantity;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OrderTrackingScreen(
                              orderId: contract.fulfillmentOrderId!,
                              productName: contract.items.length > 1
                                  ? '${contract.items.first.product.name} +${contract.items.length - 1}'
                                  : contract.items.first.product.name,
                              price: contract.items.first.agreedPrice,
                              quantity: qty,
                              total: contract.totalValue + (contract.deliveryFee ?? 0),
                              currency: contract.depositCurrency ?? contract.product.currency,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                SizedBox(
                  width: double.infinity,
                  child: CustomButton.secondary(
                    text: state.translate('download_agreement'),
                    onPressed: () {
                      Navigator.pop(context);
                      _handleContractDownload(context, state, contract);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Parses a numeric input field defensively (deposit %, delivery fee,
  /// etc.): strips whitespace, treats a comma as a decimal point (some
  /// device locales/keyboards emit one instead of a period), and converts
  /// Khmer numerals (០-៩) to Western digits — a Khmer-script keyboard is a
  /// completely normal choice for this app's users, but `double.tryParse`
  /// only understands Western digits, so without this the field would
  /// silently fail to parse and look "stuck".
  double? _parseNumericInput(String raw) => numeric_input.parseNumericInput(raw);

  void _showAcceptWithDepositDialog(
    BuildContext sheetContext,
    AppState state,
    BidOffer contract,
    StateSetter setSheetState,
    void Function(bool) setProcessing,
  ) {
    final pctController = TextEditingController(text: '20');

    showDialog(
      context: sheetContext,
      builder: (dialogContext) {
        bool isSubmitting = false;
        String? validationError;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              state.translate('accept_agreement'),
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.translate('deposit_percentage_hint'),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                CustomInput(
                  label: state.translate('deposit_percentage_label'),
                  hintText: '20',
                  controller: pctController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  suffixIcon: const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Center(widthFactor: 1, child: Text('%')),
                  ),
                  onChanged: (_) {
                    if (validationError != null) {
                      setDialogState(() => validationError = null);
                    }
                  },
                ),
                if (validationError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    validationError!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ],
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
                        final pct = _parseNumericInput(pctController.text);
                        if (pct == null || pct <= 0 || pct > 100) {
                          setDialogState(() {
                            validationError = state.translate(
                              'deposit_percentage_invalid',
                            );
                          });
                          return;
                        }
                        setDialogState(() {
                          validationError = null;
                          isSubmitting = true;
                        });
                        setSheetState(() => setProcessing(true));
                        final error = await state.acceptBid(contract.id, pct);
                        if (!dialogContext.mounted) return;
                        if (error != null) {
                          setDialogState(() => isSubmitting = false);
                          if (sheetContext.mounted) {
                            setSheetState(() => setProcessing(false));
                          }
                          AppSnackBar.error(
                            dialogContext,
                            friendlyContractErrorMessage(state, error),
                          );
                          return;
                        }
                        Navigator.pop(dialogContext);
                        if (!sheetContext.mounted) return;
                        Navigator.pop(sheetContext);
                        if (mounted) {
                          AppSnackBar.success(
                            context,
                            state.translate('contract_accepted_msg'),
                          );
                        }
                      },
                child: Text(state.translate('accept_agreement')),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The seller sets delivery method (+ a plain entered fee, for Delivery)
  /// once actually ready to hand off the goods — unlike an order's
  /// auto-calculated delivery fee, a wholesale contract's real transport
  /// cost (e.g. hiring a local truck) isn't something the app can estimate,
  /// so the seller enters whatever they were actually quoted. The contract
  /// moves to PENDING_FINAL_PAYMENT, or straight to COMPLETED if the
  /// deposit already covers everything and it's a pickup.
  void _showRequestFinalPaymentDialog(
    BuildContext sheetContext,
    AppState state,
    BidOffer contract,
    StateSetter setSheetState,
    void Function(bool) setProcessing,
  ) {
    String deliveryMethod = 'DELIVERY';
    final feeController = TextEditingController();
    final double remainingBeforeFee = contract.totalValue - (contract.depositAmount ?? 0);
    final double remaining = remainingBeforeFee < 0 ? 0 : remainingBeforeFee;
    final String currency = contract.depositCurrency ?? contract.product.currency;

    showDialog(
      context: sheetContext,
      builder: (dialogContext) {
        bool isSubmitting = false;
        String? validationError;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final double fee = deliveryMethod == 'DELIVERY' ? (_parseNumericInput(feeController.text) ?? 0) : 0;
            final double previewTotal = remaining + fee;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                state.translate('request_final_payment'),
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.translate('request_final_payment_hint'),
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: Text(state.translate('delivery_method_delivery')),
                            selected: deliveryMethod == 'DELIVERY',
                            onSelected: (_) => setDialogState(() => deliveryMethod = 'DELIVERY'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: Text(state.translate('delivery_method_pickup')),
                            selected: deliveryMethod == 'PICKUP',
                            onSelected: (_) => setDialogState(() => deliveryMethod = 'PICKUP'),
                          ),
                        ),
                      ],
                    ),
                    if (deliveryMethod == 'DELIVERY') ...[
                      const SizedBox(height: 12),
                      CustomInput(
                        label: state.translate('delivery_fee_label'),
                        hintText: '0',
                        controller: feeController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setDialogState(() {
                          if (validationError != null) validationError = null;
                        }),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            state.translate('final_amount_preview'),
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                          ),
                          Text(
                            _formatCurrency(previewTotal, currency),
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    if (validationError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        validationError!,
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.error),
                      ),
                    ],
                  ],
                ),
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
                          double? feeValue;
                          if (deliveryMethod == 'DELIVERY') {
                            feeValue = _parseNumericInput(feeController.text);
                            if (feeValue == null || feeValue < 0) {
                              setDialogState(() {
                                validationError = state.translate('delivery_fee_invalid');
                              });
                              return;
                            }
                          }
                          setDialogState(() {
                            validationError = null;
                            isSubmitting = true;
                          });
                          setSheetState(() => setProcessing(true));
                          final error = await state.requestFinalPayment(
                            contract.id,
                            deliveryMethod: deliveryMethod,
                            deliveryFee: feeValue,
                          );
                          if (!dialogContext.mounted) return;
                          if (error != null) {
                            setDialogState(() => isSubmitting = false);
                            if (sheetContext.mounted) setSheetState(() => setProcessing(false));
                            AppSnackBar.error(dialogContext, friendlyContractErrorMessage(state, error));
                            return;
                          }
                          Navigator.pop(dialogContext);
                          if (!sheetContext.mounted) return;
                          Navigator.pop(sheetContext);
                          if (mounted) {
                            AppSnackBar.success(context, state.translate('final_payment_requested_msg'));
                          }
                        },
                  child: Text(state.translate('request_final_payment')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// The order-details sheet's action row(s). At most one of Pay-via-KHQR
  /// and the seller's next fulfillment step ever applies at once — Pay
  /// needs PENDING, fulfillment needs PAID — so there's only ever one
  /// "primary" conditional action to make room for, never three
  /// equal-weight buttons competing for the same row. That one action (if
  /// any) gets its own full-width row above the always-present
  /// Download/Track pair instead of squeezing in beside them.
  Widget _buildOrderSheetActions(
    BuildContext context,
    AppState state,
    Map<String, dynamic> order,
    List<dynamic> items,
    double totalAmount,
    String currency,
    String status,
  ) {
    Widget? primaryAction;

    // Buyer-only: the backend's /payments/khqr endpoint only authorizes the
    // order's actual buyer to generate/pay its QR (it's their money being
    // requested) — a farmer would always get a 403 here, so showing them
    // this button would just be a dead end.
    final bool canPayKhqr =
        state.currentRole == 'buyer' &&
        order['payment_status'] == 'PENDING' &&
        order['order_status'] != 'CANCELLED' &&
        (order['payment_method'] ?? 'KHQR') == 'KHQR';
    if (canPayKhqr) {
      primaryAction = CustomButton(
        text: state.translate('checkout_khqr'),
        backgroundColor: AppColors.primary,
        onPressed: () {
          final navigator = Navigator.of(context);
          navigator.pop(); // Close sheet
          // Settle the order that already exists — creating a new one here
          // would double-order and double-decrement the farmer's stock.
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
      );
    } else if (state.currentRole == 'farmer' &&
        order['payment_status'] == 'PAID') {
      final Map<String, String>? next = switch (status) {
        'PLACED' => {'label': 'mark_packaging', 'next': 'CONFIRMED'},
        'CONFIRMED' => {'label': 'ship_order', 'next': 'SHIPPED'},
        'SHIPPED' => {'label': 'mark_delivered', 'next': 'DELIVERED'},
        _ => null,
      };
      if (next != null) {
        primaryAction = CustomButton(
          text: state.translate(next['label']!),
          backgroundColor: AppColors.primary,
          onPressed: () {
            Navigator.of(context).pop();
            if (next['next'] == 'SHIPPED') {
              if (!mounted) return;
              showShipOrderDialog(
                this.context,
                state,
                onConfirm: ({contactPhone, deliveryNotes, actualDeliveryCost}) => _updateOrderStatus(
                  order['id'],
                  'SHIPPED',
                  contactPhone: contactPhone,
                  deliveryNotes: deliveryNotes,
                  actualDeliveryCost: actualDeliveryCost,
                ),
              );
            } else {
              _updateOrderStatus(order['id'], next['next']!);
            }
          },
        );
      }
    }

    void goToTracking() {
      Navigator.pop(context); // Close sheet
      String pName = state.translate('crop_listing');
      if (items.isNotEmpty) {
        final firstItem = items.first;
        final matchingProd = state.products.firstWhere(
          (p) => p.id == firstItem['product_id'],
          orElse: () => MarketProduct(
            id: '',
            name: state.translate('crop_listing'),
            category: 'Grains',
            price: 1.0,
            unit: 'kg',
            quantity: 0.0,
            farmerName: state.translate('verified_farmer_fallback'),
            location: state.translate('cambodia_fallback'),
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
                    ? ((items.first['quantity'] as num?)?.toDouble() ?? 1)
                    : 1),
            quantity: items.isNotEmpty
                ? ((items.first['quantity'] as num?)?.toDouble() ?? 1)
                : 1,
            total: totalAmount,
            currency: currency,
          ),
        ),
      );
    }

    return Column(
      children: [
        if (primaryAction != null) ...[
          SizedBox(width: double.infinity, child: primaryAction),
          const SizedBox(height: 12),
        ],
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
            const SizedBox(width: 12),
            // Tracking is informational and always safe to view — shown to
            // both roles regardless of payment or even cancellation, unlike
            // the action above.
            Expanded(
              child: CustomButton(
                text: state.translate('track_order'),
                backgroundColor: AppColors.primary,
                onPressed: goToTracking,
              ),
            ),
          ],
        ),
      ],
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
    final double deliveryFee =
        (order['delivery_fee'] as num?)?.toDouble() ?? 0.0;
    final double subtotal = totalAmount - deliveryFee;
    final items = order['items'] as List<dynamic>? ?? [];
    final bool isFarmerView = state.currentRole == 'farmer';
    // Buyer-only, and only offered before the seller has actually confirmed
    // (started packaging) — the backend itself still allows cancelling
    // through CONFIRMED too, but once the seller has committed to
    // fulfilling it, a one-tap cancel isn't the right tool anymore; a
    // dispute is. The seller never gets a cancel button here at all — an
    // incoming order isn't theirs to unilaterally cancel.
    final bool isCancellable =
        state.currentRole == 'buyer' && status == 'PLACED';
    final String buyerDisplayName = order['buyer_name']?.toString().isNotEmpty == true
        ? order['buyer_name'].toString()
        : state.translate('registered_buyer');
    final String sellerDisplayName = order['seller_name']?.toString().isNotEmpty == true
        ? order['seller_name'].toString()
        : state.translate('registered_seller');
    final String counterpartyName = state.currentRole == 'admin'
        ? '$buyerDisplayName → $sellerDisplayName'
        : (isFarmerView ? buyerDisplayName : sellerDisplayName);

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _buildInfoRow(
                      state.translate(isFarmerView ? 'buyer' : 'seller'),
                      counterpartyName,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    tooltip: state.translate('message_button'),
                    onPressed: () {
                      final String? otherUserId =
                          (isFarmerView
                                  ? order['buyer_id']
                                  : order['seller_id'])
                              ?.toString();
                      if (otherUserId == null) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatThreadScreen(
                            otherUserId: otherUserId,
                            otherUserName: counterpartyName,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                state.translate('invoice_date'),
                _orderDateTimeText(state, order),
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
                    name: state.translate('crop_listing'),
                    category: 'Grains',
                    price: 1.0,
                    unit: 'kg',
                    quantity: 0.0,
                    farmerName: state.translate('verified_farmer_fallback'),
                    location: state.translate('cambodia_fallback'),
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
              _buildCostSummary(
                state,
                subtotal,
                currency: currency,
                deliveryFee: deliveryFee,
              ),
              const SizedBox(height: 24),
              _buildOrderSheetActions(
                context,
                state,
                order,
                items,
                totalAmount,
                currency,
                status,
              ),
              if (isCancellable) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    icon: const Icon(
                      Icons.cancel_outlined,
                      size: 18,
                      color: AppColors.error,
                    ),
                    label: Text(
                      state.translate('cancel_order'),
                      style: GoogleFonts.inter(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () => _confirmCancelOrder(context, state, order),
                  ),
                ),
              ],
              // Both Rate and Report are buyer-only — the seller is never the
              // one giving feedback on or disputing their own incoming order.
              // Once the buyer has actually received the goods, a dispute is
              // the wrong tool — feedback belongs in the star rating instead,
              // so the report action is replaced rather than just supplemented.
              if (state.currentRole == 'buyer') ...[
                if (order['order_status'] == 'DELIVERED') ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton.secondary(
                      text: state.translate('rate_this_order'),
                      icon: Icons.star_outline_rounded,
                      onPressed: () =>
                          _showRateOrderDialog(context, state, order),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      icon: const Icon(
                        Icons.report_problem_outlined,
                        size: 18,
                        color: AppColors.error,
                      ),
                      label: Text(
                        state.translate('report_a_problem'),
                        style: GoogleFonts.inter(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () =>
                          _showReportProblemDialog(context, state, order),
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  void _showReportProblemDialog(
    BuildContext sheetContext,
    AppState state,
    Map<String, dynamic> order,
  ) {
    final reasonController = TextEditingController();
    bool isSubmitting = false;

    // Shows on top of the still-open details sheet — see the comment in
    // _confirmCancelOrder for why the sheet must not be popped first.
    showDialog(
      context: sheetContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            state.translate('report_a_problem'),
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: CustomInput(
            label: state.translate('reason_label'),
            hintText: state.translate('dispute_reason_hint'),
            controller: reasonController,
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
                      final reason = reasonController.text.trim();
                      if (reason.isEmpty || state.token == null) return;
                      setDialogState(() => isSubmitting = true);
                      try {
                        await DisputeApi.createDispute(
                          state.token!,
                          order['id'].toString(),
                          reason,
                        );
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                        if (mounted) {
                          AppSnackBar.success(
                            context,
                            state.translate('dispute_submitted_success'),
                          );
                        }
                      } catch (e) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() => isSubmitting = false);
                        AppSnackBar.error(
                          dialogContext,
                          friendlyApiError(state, e),
                        );
                      }
                    },
              child: Text(state.translate('submit_dispute')),
            ),
          ],
        ),
      ),
    );
  }

  void _showRateOrderDialog(
    BuildContext sheetContext,
    AppState state,
    Map<String, dynamic> order,
  ) {
    int rating = 5;
    final commentController = TextEditingController();
    bool isSubmitting = false;

    // Shows on top of the still-open details sheet — see the comment in
    // _confirmCancelOrder for why the sheet must not be popped first.
    showDialog(
      context: sheetContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            state.translate('rate_this_order'),
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.translate('your_rating'),
                style: GoogleFonts.inter(fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final starValue = i + 1;
                  return IconButton(
                    onPressed: () => setDialogState(() => rating = starValue),
                    icon: Icon(
                      starValue <= rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: Colors.amber.shade700,
                      size: 32,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              CustomInput(
                label: '',
                hintText: state.translate('comment_optional'),
                controller: commentController,
              ),
            ],
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
                        await ReviewApi.createReview(
                          state.token!,
                          orderId: order['id'].toString(),
                          rating: rating,
                          comment: commentController.text.trim().isEmpty
                              ? null
                              : commentController.text.trim(),
                        );
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                        if (mounted) {
                          AppSnackBar.success(
                            context,
                            state.translate('review_submitted_success'),
                          );
                        }
                      } catch (e) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() => isSubmitting = false);
                        AppSnackBar.error(
                          dialogContext,
                          friendlyApiError(state, e),
                        );
                      }
                    },
              child: Text(state.translate('submit_review')),
            ),
          ],
        ),
      ),
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
                      backgroundColor: isSuccess
                          ? AppColors.primary
                          : AppColors.error,
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
