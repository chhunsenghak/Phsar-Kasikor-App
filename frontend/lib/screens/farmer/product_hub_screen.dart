import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/grid_list_toggle.dart';
import '../../widgets/product_collection_view.dart';
import '../buyer/market_price_tracker.dart';
import '../buyer/community_portal.dart';
import '../common/order_contract_history_screen.dart';
import '../../widgets/app_snackbar.dart';
import '../../utils/api_error.dart';
import 'improved_add_new_product.dart';

class FarmerProductHubScreen extends StatefulWidget {
  const FarmerProductHubScreen({super.key});

  @override
  State<FarmerProductHubScreen> createState() => _FarmerProductHubScreenState();
}

class _FarmerProductHubScreenState extends State<FarmerProductHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);

    return Column(
      children: [
        Material(
          color: AppColors.surface,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.outline,
            indicatorColor: AppColors.primary,
            labelStyle: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            tabs: [
              Tab(text: state.translate('products')),
              Tab(text: state.translate('prices')),
              Tab(text: state.translate('community')),
              Tab(text: state.translate('my_orders')),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _MyProductsTab(),
              MarketPriceTrackerScreen(),
              CommunityPortalScreen(),
              OrderContractHistoryScreen(initialTab: 1),
            ],
          ),
        ),
      ],
    );
  }
}

class _MyProductsTab extends StatefulWidget {
  const _MyProductsTab();

  @override
  State<_MyProductsTab> createState() => _MyProductsTabState();
}

class _MyProductsTabState extends State<_MyProductsTab> {
  bool _isGridView = true;

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final myProducts = state.products.where((p) {
      final isMyId =
          (p.sellerId != null &&
          state.userProfile != null &&
          p.sellerId == state.userProfile!['id']);
      final isMyName =
          p.farmerName.toLowerCase().contains('sopheap') ||
          p.farmerName.toLowerCase().contains('sok_farmer') ||
          p.farmerName.toLowerCase().contains('sokha') ||
          p.farmerName.toLowerCase().contains('cooperative') ||
          (state.userProfile != null &&
              p.farmerName == state.userProfile!['username']);
      return isMyId || isMyName;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, state),
          const SizedBox(height: 20),
          _buildCropListings(context, state, myProducts),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.translate('products'),
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
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.error,
                        size: 28,
                      ),
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
                        style: GoogleFonts.inter(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        state.setNavIndex(2);
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
        ),
      ],
    );
  }

  Widget _buildCropListings(
    BuildContext context,
    AppState state,
    List<MarketProduct> myProducts,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              state.translate(
                'my_crop_listings',
                arguments: {'count': myProducts.length.toString()},
              ),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
            GridListToggle(
              isGridView: _isGridView,
              onChanged: (value) => setState(() => _isGridView = value),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ProductCollectionView<MarketProduct>(
          isGridView: _isGridView,
          items: myProducts,
          emptyState: CustomCard(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                state.translate('no_listings_yet'),
                style: GoogleFonts.inter(color: AppColors.outline),
              ),
            ),
          ),
          gridItemBuilder: (context, prod) =>
              _buildProductGridCard(context, state, prod),
          listItemBuilder: (context, prod) =>
              _buildProductListTile(context, state, prod),
        ),
      ],
    );
  }

  Widget _productThumbnail(MarketProduct prod, {required double size}) {
    final icon = prod.category == 'Grains'
        ? Icons.grass_rounded
        : (prod.category == 'Fruits' ? Icons.apple_rounded : Icons.egg_rounded);

    if (prod.imageUrl.isEmpty) {
      return Icon(icon, color: AppColors.primary, size: size * 0.5);
    }

    return Image.network(
      prod.resolvedImageUrl,
      fit: BoxFit.cover,
      width: size,
      height: size,
      errorBuilder: (context, error, stackTrace) =>
          Icon(icon, color: AppColors.primary, size: size * 0.5),
    );
  }

  Widget _productPopupMenu(
    BuildContext context,
    AppState state,
    MarketProduct prod,
  ) {
    return PopupMenuButton<String>(
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
              const Icon(
                Icons.edit_rounded,
                size: 16,
                color: AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(state.translate('edit')),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(
                Icons.delete_outline_rounded,
                size: 16,
                color: AppColors.error,
              ),
              const SizedBox(width: 8),
              Text(
                state.translate('delete'),
                style: const TextStyle(color: AppColors.error),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Mirrors the backend's LOW_STOCK_THRESHOLD (order_service.py) — kept in
  // sync manually since there's no shared config between the two right now.
  static const int _lowStockThreshold = 10;

  Widget? _buildLowStockBadge(AppState state, MarketProduct prod) {
    if (prod.quantity <= 0) {
      return _stockBadge(state.translate('out_of_stock_badge'), AppColors.error);
    }
    if (prod.quantity < _lowStockThreshold) {
      return _stockBadge(state.translate('low_stock_badge'), Colors.amber.shade900);
    }
    return null;
  }

  Widget _stockBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildProductListTile(
    BuildContext context,
    AppState state,
    MarketProduct prod,
  ) {
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
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDesign.borderRadiusSm),
            child: Container(
              width: 48,
              height: 48,
              color: AppColors.surfaceContainerLow,
              child: _productThumbnail(prod, size: 48),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prod.name,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  state.translate(
                    'category_stock_info',
                    arguments: {
                      'category': state.translate(prod.category.toLowerCase()),
                      'qty': prod.quantity.toInt().toString(),
                      'unit': state.translate(
                        'unit_${prod.unit.toLowerCase()}',
                      ),
                    },
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                if (_buildLowStockBadge(state, prod) != null) ...[
                  const SizedBox(height: 4),
                  _buildLowStockBadge(state, prod)!,
                ],
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
              _productPopupMenu(context, state, prod),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductGridCard(
    BuildContext context,
    AppState state,
    MarketProduct prod,
  ) {
    return CustomCard(
      padding: EdgeInsets.zero,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImprovedAddNewProductScreen(product: prod),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppDesign.borderRadiusDefault),
              ),
              child: Container(
                width: double.infinity,
                color: AppColors.surfaceContainerLow,
                child: _productThumbnail(prod, size: 96),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prod.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  state.translate(
                    'category_stock_info',
                    arguments: {
                      'category': state.translate(prod.category.toLowerCase()),
                      'qty': prod.quantity.toInt().toString(),
                      'unit': state.translate(
                        'unit_${prod.unit.toLowerCase()}',
                      ),
                    },
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                if (_buildLowStockBadge(state, prod) != null) ...[
                  const SizedBox(height: 4),
                  _buildLowStockBadge(state, prod)!,
                ],
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${prod.formattedPrice}/${prod.unit}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    _productPopupMenu(context, state, prod),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AppState state,
    MarketProduct prod,
  ) async {
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
              style: GoogleFonts.inter(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
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
        builder: (context) => const Center(child: CircularProgressIndicator()),
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
          AppSnackBar.error(context, translateErrorCode(state, error));
        }
      }
    }
  }

  void _showPremiumStatusDialog(
    BuildContext context,
    AppState state,
    String title,
    String body,
    bool isSuccess,
  ) {
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
                    color: (isSuccess ? AppColors.primary : AppColors.error)
                        .withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isSuccess ? AppColors.primary : AppColors.error)
                          .withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
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
                            ? Icons.check_circle_outline_rounded
                            : Icons.error_outline_rounded,
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
                        backgroundColor: isSuccess
                            ? AppColors.primary
                            : AppColors.error,
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
}
