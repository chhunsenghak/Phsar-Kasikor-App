import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_card.dart';
import '../../services/api/order_api.dart';

class OrderContractHistoryScreen extends StatefulWidget {
  const OrderContractHistoryScreen({super.key});

  @override
  State<OrderContractHistoryScreen> createState() => _OrderContractHistoryScreenState();
}

class _OrderContractHistoryScreenState extends State<OrderContractHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _orders = [];
  bool _isLoadingOrders = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final negotiations = state.negotiations;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Wholesale Transaction History',
          style: GoogleFonts.inter(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.onSurfaceVariant,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Contract Agreements'),
            Tab(text: 'Invoice Orders'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildContractsTab(negotiations),
          _buildOrdersTab(),
        ],
      ),
    );
  }

  Widget _buildContractsTab(List<BidOffer> contracts) {
    if (contracts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.gavel_rounded, size: 48, color: AppColors.outlineVariant),
            const SizedBox(height: 12),
            Text(
              'No active wholesale contracts.',
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
        final isAccepted = contract.status == 'accepted';
        final isRejected = contract.status == 'rejected';

        return CustomCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Agreement #${contract.id.substring(0, 8)}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isAccepted
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : (isRejected ? AppColors.error.withValues(alpha: 0.1) : AppColors.secondary.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      contract.status.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isAccepted ? AppColors.primary : (isRejected ? AppColors.error : AppColors.onSecondaryContainer),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    contract.product.name,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Quantity: ${contract.quantity.toInt()} ${contract.product.unit}s',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                  ),
                  Text(
                    'Rate: \$${contract.offeredPrice.toStringAsFixed(2)}/${contract.product.unit}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
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
    if (_isLoadingOrders) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_rounded, size: 48, color: AppColors.outlineVariant),
            const SizedBox(height: 12),
            Text(
              'No completed orders found.',
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

        return CustomCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order ID: #${order['id'].toString().substring(0, 8)}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: status == 'PAID' || status == 'COMPLETED'
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : AppColors.outlineVariant.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: status == 'PAID' || status == 'COMPLETED' ? AppColors.primary : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Payment Status: ${order['payment_status'] ?? 'UNPAID'}',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                  ),
                  Text(
                    'Total: \$${total.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
