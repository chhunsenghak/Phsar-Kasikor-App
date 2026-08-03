import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';
import 'sales_analytics.dart';
import 'improved_add_new_product.dart';
import 'crop_advisor_screen.dart';
import '../common/order_contract_history_screen.dart';

class FarmerDashboardScreen extends StatelessWidget {
  const FarmerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    
    final myProducts = state.products.where((p) {
      final isMyId = (p.sellerId != null && state.userProfile != null && p.sellerId == state.userProfile!['id']);
      final isMyName = p.farmerName.toLowerCase().contains('sopheap') || 
                       p.farmerName.toLowerCase().contains('sok_farmer') || 
                       p.farmerName.toLowerCase().contains('sokha') ||
                       p.farmerName.toLowerCase().contains('cooperative') ||
                       (state.userProfile != null && p.farmerName == state.userProfile!['username']);
      return isMyId || isMyName;
    }).toList();

    final activeBids = state.negotiations.where((n) {
      final p = n.product;
      final isMyId = (p.sellerId != null && state.userProfile != null && p.sellerId == state.userProfile!['id']);
      final isMyName = p.farmerName.toLowerCase().contains('sopheap') || 
                       p.farmerName.toLowerCase().contains('sok_farmer') || 
                       p.farmerName.toLowerCase().contains('sokha') ||
                       p.farmerName.toLowerCase().contains('cooperative') ||
                       (state.userProfile != null && p.farmerName == state.userProfile!['username']);
      return isMyId || isMyName;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 20),
            _buildPerformanceStats(context, activeBids),
            const SizedBox(height: 24),
            _buildOrdersShortcut(context, state),
            const SizedBox(height: 16),
            _buildAdvisorShortcut(context, state),
            const SizedBox(height: 24),
            _buildIncomingBids(state, activeBids),
            const SizedBox(height: 24),
            _buildCropListings(context, myProducts),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final state = Provider.of<AppState>(context, listen: false);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.translate('farmer_dashboard'),
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              state.translate('manage_crops_subtitle'),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        IconButton.filled(
          style: IconButton.styleFrom(backgroundColor: AppColors.primary),
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          onPressed: () {
            if (!state.isLocationComplete) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        state.translate('location_required'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  content: Text(
                    state.translate('location_required_desc'),
                    style: GoogleFonts.inter(fontSize: 14),
                  ),
                  actions: [
                    TextButton(
                      child: Text(
                        state.translate('cancel'),
                        style: GoogleFonts.inter(color: AppColors.outline),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    TextButton(
                      child: Text(
                        state.translate('go_to_profile'),
                        style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        state.setNavIndex(3);
                      },
                    ),
                  ],
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ImprovedAddNewProductScreen(),
                ),
              );
            }
          },
        )
      ],
    );
  }

  Widget _buildPerformanceStats(BuildContext context, List<BidOffer> activeBids) {
    final state = Provider.of<AppState>(context, listen: false);
    return Row(
      children: [
        Expanded(
          child: CustomCard(
            padding: const EdgeInsets.all(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SalesAnalyticsScreen(),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.monetization_on_outlined, color: AppColors.primary, size: 24),
                const SizedBox(height: 8),
                Text(
                  '\$1,420.00',
                  style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                const SizedBox(height: 2),
                Text(
                  state.translate('total_revenue_trend'),
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CustomCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.gavel_outlined, color: AppColors.secondary, size: 24),
                const SizedBox(height: 8),
                Text(
                  '${activeBids.length}',
                  style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.secondary),
                ),
                const SizedBox(height: 2),
                Text(
                  state.translate('active_negotiations'),
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIncomingBids(AppState state, List<BidOffer> activeBids) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.translate('incoming_buyer_bids', arguments: {'count': activeBids.length.toString()}),
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        activeBids.isEmpty
            ? CustomCard(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    state.translate('no_active_bids'),
                    style: GoogleFonts.inter(color: AppColors.outline),
                  ),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activeBids.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final bid = activeBids[index];
                  final isPending = bid.status == 'pending';

                  return CustomCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              bid.buyerName,
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isPending ? Colors.amber[100] : AppColors.secondaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                bid.status.toUpperCase(),
                                style: GoogleFonts.inter(
                                  color: isPending ? Colors.amber[900] : AppColors.onSecondaryContainer,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.translate('product_prefix', arguments: {'name': bid.product.name}),
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          state.translate('offer_details', arguments: {
                            'price': bid.offeredPrice.toStringAsFixed(2),
                            'qty': bid.quantity.toInt().toString(),
                          }),
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        if (isPending) ...[
                          const Divider(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: CustomButton(
                                  text: state.translate('accept'),
                                  height: 38,
                                  onPressed: () {
                                    state.acceptBid(bid.id);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: CustomButton.secondary(
                                  text: state.translate('reject'),
                                  height: 38,
                                  backgroundColor: AppColors.errorContainer,
                                  textColor: AppColors.onErrorContainer,
                                  onPressed: () {
                                    state.rejectBid(bid.id);
                                  },
                                ),
                              ),
                            ],
                          )
                        ]
                      ],
                    ),
                  );
                },
              ),
      ],
    );
  }

  Widget _buildCropListings(BuildContext context, List<MarketProduct> myProducts) {
    final state = Provider.of<AppState>(context, listen: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.translate('my_crop_listings', arguments: {'count': myProducts.length.toString()}),
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        myProducts.isEmpty
            ? CustomCard(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    state.translate('no_listings_yet'),
                    style: GoogleFonts.inter(color: AppColors.outline),
                  ),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: myProducts.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final prod = myProducts[index];

                  return CustomCard(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ImprovedAddNewProductScreen(product: prod),
                        ),
                      );
                    },
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(AppDesign.borderRadiusSm),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppDesign.borderRadiusSm),
                            child: prod.imageUrl.isNotEmpty
                                ? Image.network(
                                    prod.resolvedImageUrl,
                                    fit: BoxFit.cover,
                                    width: 48,
                                    height: 48,
                                    errorBuilder: (context, error, stackTrace) => Icon(
                                      prod.category == 'Grains'
                                          ? Icons.grass_rounded
                                          : (prod.category == 'Fruits' ? Icons.apple_rounded : Icons.egg_rounded),
                                      color: AppColors.primary,
                                    ),
                                  )
                                : Icon(
                                    prod.category == 'Grains'
                                        ? Icons.grass_rounded
                                        : (prod.category == 'Fruits' ? Icons.apple_rounded : Icons.egg_rounded),
                                    color: AppColors.primary,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                prod.name,
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                state.translate('category_stock_info', arguments: {
                                  'category': state.translate(prod.category.toLowerCase()),
                                  'qty': prod.quantity.toInt().toString(),
                                  'unit': state.translate('unit_${prod.unit.toLowerCase()}'),
                                }),
                                style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${prod.formattedPrice}/${prod.unit}',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                fontSize: 14,
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.more_horiz_rounded,
                                color: AppColors.outline,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 100),
                              onSelected: (val) {
                                if (val == 'edit') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ImprovedAddNewProductScreen(product: prod),
                                    ),
                                  );
                                } else if (val == 'delete') {
                                  _confirmDelete(context, state, prod);
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.edit_rounded, size: 16, color: AppColors.onSurfaceVariant),
                                      const SizedBox(width: 8),
                                      Text(state.translate('edit')),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                                      const SizedBox(width: 8),
                                      Text(
                                        state.translate('delete'),
                                        style: const TextStyle(color: AppColors.error),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, AppState state, MarketProduct prod) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          state.translate('delete_product_title'),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          state.translate('delete_product_confirm'),
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            child: Text(
              state.translate('cancel'),
              style: GoogleFonts.inter(color: AppColors.outline),
            ),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: Text(
              state.translate('delete'),
              style: GoogleFonts.inter(color: AppColors.error, fontWeight: FontWeight.bold),
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final error = await state.deleteProduct(prod.id);
      
      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading
        
        if (error == null) {
          _showPremiumStatusDialog(
            context,
            state,
            state.translate('success'),
            state.translate('delete_success'),
            true,
          );
        } else {
          final bool hasRelated = error.contains('PRODUCT_HAS_RELATED_INFO');
          final displayMsg = hasRelated
              ? state.translate('product_has_related_info')
              : error;
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              content: Text(
                displayMsg,
                style: GoogleFonts.inter(color: Colors.white),
              ),
            ),
          );
        }
      }
    }
  }

  void _showPremiumStatusDialog(BuildContext context, AppState state, String title, String body, bool isSuccess) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Status Dialog',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curve,
          child: Align(
            alignment: Alignment.center,
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (isSuccess ? AppColors.primary : AppColors.error).withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isSuccess ? AppColors.primary : AppColors.error).withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: (isSuccess ? AppColors.primary : AppColors.error).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSuccess ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                        color: isSuccess ? AppColors.primary : AppColors.error,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      body,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.onSurfaceVariant,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: CustomButton(
                        text: state.translate('ok'),
                        backgroundColor: isSuccess ? AppColors.primary : AppColors.error,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrdersShortcut(BuildContext context, AppState state) {
    return CustomCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      backgroundColor: AppColors.surface,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const OrderContractHistoryScreen(initialTab: 1, isPushed: true),
          ),
        );
      },
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.assignment_rounded, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.translate('customer_orders'),
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  state.translate('customer_orders_desc'),
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.outline),
        ],
      ),
    );
  }

  Widget _buildAdvisorShortcut(BuildContext context, AppState state) {
    return CustomCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      backgroundColor: AppColors.surface,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CropAdvisorScreen(),
          ),
        );
      },
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.psychology_rounded, color: AppColors.secondary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.translate('crop_diagnostics'),
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  'Diagnose crop diseases & get organic recommendations',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.outline),
        ],
      ),
    );
  }
}
