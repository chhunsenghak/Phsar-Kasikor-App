import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/app_snackbar.dart';
import 'checkout_screen.dart';

/// Lists and edits the cart. Fulfillment, payment and order placement all live
/// on [CheckoutScreen] so they are chosen once for the whole basket.
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  String _formatQty(double qty) =>
      qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toString();

  void _notifyStockCap(BuildContext context, AppState state, CartItem item) {
    AppSnackBar.info(
      context,
      state.translate('stock_limit_notice', arguments: {
        'count': _formatQty(item.product.quantity),
        'unit': item.product.unit,
      }),
    );
  }

  Future<void> _confirmClearCart(BuildContext context, AppState state) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          state.translate('clear_cart'),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: Text(
          state.translate('cart_empty_subtitle'),
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(state.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              state.translate('clear_cart'),
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      state.clearCart();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final cartItems = state.cartItems;
    final groups = state.cartGroups;

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
          state.translate('shopping_cart'),
          style: GoogleFonts.inter(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          if (cartItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.error),
              tooltip: state.translate('clear_cart'),
              onPressed: () => _confirmClearCart(context, state),
            ),
        ],
      ),
      body: cartItems.isEmpty
          ? _buildEmptyState(context, state)
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final group in groups) ...[
                        _buildSellerHeader(state, group),
                        const SizedBox(height: 8),
                        for (final item in group.items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildCartLine(context, state, item),
                          ),
                        const SizedBox(height: 6),
                      ],
                    ],
                  ),
                ),
                _buildSummaryFooter(context, state, groups),
              ],
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              state.translate('cart_empty'),
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.translate('cart_empty_subtitle'),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            CustomButton(
              text: state.translate('browse_crops'),
              icon: Icons.storefront_rounded,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Items are shown per farm because each farm becomes its own order.
  Widget _buildSellerHeader(AppState state, CartGroup group) {
    return Row(
      children: [
        const Icon(Icons.agriculture_rounded, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            state.translate('sold_by', arguments: {'name': group.sellerName}),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          formatCurrencyAmount(group.subtotal, group.currency),
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildCartLine(BuildContext context, AppState state, CartItem item) {
    final prod = item.product;
    final bool atStockLimit = item.quantity >= prod.quantity;

    return CustomCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: prod.imageUrl.isEmpty
                ? const Icon(Icons.eco_rounded, color: AppColors.primary, size: 32)
                : Image.network(
                    prod.resolvedImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.eco_rounded,
                      color: AppColors.primary,
                      size: 32,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prod.name,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${prod.formattedPrice} / ${prod.unit}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.remove_circle_outline_rounded,
                            size: 24,
                            color: AppColors.primary,
                          ),
                          // Stepping below 1 removes the line entirely.
                          onPressed: () => state.updateCartQuantity(
                            prod.id,
                            item.quantity - 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '${_formatQty(item.quantity)} ${prod.unit}',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            Icons.add_circle_outline_rounded,
                            size: 24,
                            color: atStockLimit
                                ? AppColors.outlineVariant
                                : AppColors.primary,
                          ),
                          onPressed: atStockLimit
                              ? () => _notifyStockCap(context, state, item)
                              : () => state.updateCartQuantity(
                                    prod.id,
                                    item.quantity + 1,
                                  ),
                        ),
                      ],
                    ),
                    Text(
                      item.formattedItemTotal,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.outline),
            tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
            onPressed: () => state.removeFromCart(prod.id),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryFooter(
    BuildContext context,
    AppState state,
    List<CartGroup> groups,
  ) {
    final subtotals = state.cartSubtotalsByCurrency;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppDesign.level2Shadow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (groups.length > 1) ...[
              Text(
                state.translate('order_split_notice', arguments: {
                  'count': groups.length.toString(),
                }),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Delivery fees depend on the fulfillment choice made at checkout,
            // so only goods subtotals are shown here.
            for (final entry in subtotals.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${state.translate('subtotal')} (${entry.key})',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      formatCurrencyAmount(entry.value, entry.key),
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            CustomButton(
              text:
                  '${state.translate('checkout')} · ${state.translate('items_count', arguments: {
                        'count': state.cartItemCount.toString(),
                      })}',
              icon: Icons.shopping_bag_outlined,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CheckoutScreen(
                      items: state.cartItems,
                      fromCart: true,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
