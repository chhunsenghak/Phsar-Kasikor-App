import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/trust_badge.dart';
import '../../widgets/app_snackbar.dart';
import '../common/chat_thread_screen.dart';
import 'checkout_screen.dart';
import 'farm_profile.dart';
import 'cart_screen.dart';

class ProductDetailScreen extends StatelessWidget {
  final MarketProduct product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
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
          product.name,
          style: GoogleFonts.inter(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.shopping_cart_outlined, color: AppColors.onSurface),
                if (state.cartItemCount > 0)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${state.cartItemCount}',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: state.translate('shopping_cart'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CartScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroImage(state),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleAndPrice(state),
                  const SizedBox(height: 20),
                  _buildStockIndicator(state),
                  const SizedBox(height: 24),
                  Text(
                    state.translate('product_description'),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.description,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: AppColors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildProducerCard(context, state),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActionBar(context, state),
    );
  }

  Widget _buildHeroImage(AppState state) {
    return Container(
      height: 250,
      width: double.infinity,
      color: AppColors.surfaceContainerLow,
      child: Stack(
        alignment: Alignment.center,
        children: [
          product.imageUrl.isNotEmpty
              ? Image.network(
                  product.resolvedImageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      product.category == 'Grains'
                          ? Icons.grass_rounded
                          : (product.category == 'Fruits' ? Icons.apple_rounded : Icons.egg_rounded),
                      size: 120,
                      color: AppColors.primary.withValues(alpha: 0.15),
                    );
                  },
                )
              : Icon(
                  product.category == 'Grains'
                      ? Icons.grass_rounded
                      : (product.category == 'Fruits' ? Icons.apple_rounded : Icons.egg_rounded),
                  size: 120,
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
          Positioned(
            bottom: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                state.translate(product.category.toLowerCase()),
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTitleAndPrice(AppState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              TrustBadge(certType: state.getFarmerCertType(product.farmerName)),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: AppColors.outline),
                  const SizedBox(width: 4),
                  Text(
                    state.translateLocation(product.location),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              product.formattedPrice,
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            Text(
              state.translate('unit_${product.unit}'),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.outline,
              ),
            )
          ],
        )
      ],
    );
  }

  Widget _buildStockIndicator(AppState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppDesign.borderRadiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.onSecondaryContainer),
          const SizedBox(width: 6),
          Text(
            state.translate('available_stock', arguments: {
              'count': product.quantity.toInt().toString(),
              'unit': state.translate(product.unit.toLowerCase()),
            }),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProducerCard(BuildContext context, AppState state) {
    final hasCert = state.getFarmerCertType(product.farmerName) != 'none';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.translate('producer_info'),
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        CustomCard(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FarmProfileScreen(
                  farmerName: product.farmerName,
                  isVerifiedFarmer: hasCert,
                  location: product.location,
                  sellerId: product.sellerId,
                ),
              ),
            );
          },
          padding: const EdgeInsets.all(16),
          borderSide: const BorderSide(color: AppColors.outlineVariant, width: 0.8),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  product.farmerName[0],
                  style: GoogleFonts.inter(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          product.farmerName,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 6),
                        TrustBadge(
                          certType: state.getFarmerCertType(product.farmerName),
                          isMini: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasCert
                          ? state.translate('certified_producer', arguments: {'certType': state.getFarmerCertType(product.farmerName).toUpperCase()})
                          : state.translate('registered_seller'),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.outline)
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionBar(BuildContext context, AppState state) {
    final bool inStock = product.quantity > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppDesign.level2Shadow,
        border: const Border(
          top: BorderSide(color: AppColors.outlineVariant, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Chat with the seller first — a contract can be proposed from
            // inside the conversation once the buyer is actually interested,
            // rather than this icon skipping straight to a price proposal.
            SizedBox(
              width: 56,
              height: 56,
              child: OutlinedButton(
                onPressed: product.sellerId == null
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatThreadScreen(
                              otherUserId: product.sellerId!,
                              otherUserName: product.farmerName,
                            ),
                          ),
                        );
                      },
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomButton.secondary(
                text: state.translate('add_to_cart'),
                icon: Icons.add_shopping_cart_rounded,
                onPressed: inStock
                    ? () => _showQuantitySelectorSheet(context, buyNow: false)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomButton(
                text: inStock
                    ? state.translate('buy_now')
                    : state.translate('out_of_stock'),
                icon: inStock ? Icons.bolt_rounded : null,
                onPressed: inStock
                    ? () => _showQuantitySelectorSheet(context, buyNow: true)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Quantity is the only thing chosen here. Fulfillment and payment belong to
  /// the order as a whole, so they are chosen once on the checkout screen —
  /// otherwise a multi-item order would carry conflicting choices per crop.
  void _showQuantitySelectorSheet(BuildContext context, {required bool buyNow}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => _QuantitySelectorSheet(
        product: product,
        buyNowIsPrimary: buyNow,
      ),
    );
  }
}

class _QuantitySelectorSheet extends StatefulWidget {
  final MarketProduct product;

  /// Which of the two actions is styled as the primary button. Both are always
  /// offered so the buyer can change their mind without reopening the sheet.
  final bool buyNowIsPrimary;

  const _QuantitySelectorSheet({
    required this.product,
    required this.buyNowIsPrimary,
  });

  @override
  State<_QuantitySelectorSheet> createState() => _QuantitySelectorSheetState();
}

class _QuantitySelectorSheetState extends State<_QuantitySelectorSheet> {
  late final TextEditingController _quantityController;
  late double _qty;
  String? _error;

  double get _maxStock => widget.product.quantity;

  @override
  void initState() {
    super.initState();
    // Default to 10 but never propose more than the farmer actually has.
    _qty = _maxStock < 10 ? _maxStock : 10.0;
    if (_qty < 1) _qty = 1;
    _quantityController = TextEditingController(text: _formatQty(_qty));
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  String _formatQty(double qty) =>
      qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toString();

  void _setQty(double next) {
    final double clamped = next < 1
        ? 1
        : (next > _maxStock ? _maxStock : next);
    setState(() {
      _qty = clamped;
      _error = null;
      _quantityController.text = _formatQty(clamped);
      _quantityController.selection = TextSelection.fromPosition(
        TextPosition(offset: _quantityController.text.length),
      );
    });
  }

  /// Validates the typed value, since the field accepts free text.
  double? _resolveQty(AppState state) {
    final double? parsed = double.tryParse(_quantityController.text.trim());
    if (parsed == null || parsed < 1 || parsed > _maxStock) {
      setState(() {
        _error = state.translate('invalid_quantity', arguments: {
          'max': _formatQty(_maxStock),
        });
      });
      return null;
    }
    return parsed;
  }

  void _addToCart(AppState state) {
    final qty = _resolveQty(state);
    if (qty == null) return;

    // Resolve these before popping — the sheet's own context is defunct after.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final result = state.addToCart(widget.product, qty);
    navigator.pop();

    final message = result.cappedToStock
        ? state.translate('stock_limit_notice', arguments: {
            'count': _formatQty(_maxStock),
            'unit': widget.product.unit,
          })
        : state.translate('added_to_cart_msg', arguments: {
            'qty': _formatQty(qty),
            'unit': widget.product.unit,
            'name': widget.product.name,
          });
    void onViewCart() => navigator.push(
          MaterialPageRoute(builder: (context) => const CartScreen()),
        );

    AppSnackBar.showOnMessenger(
      messenger,
      message,
      type: result.cappedToStock ? AppSnackBarType.info : AppSnackBarType.success,
      actionLabel: state.translate('view_cart'),
      onAction: onViewCart,
    );
  }

  void _buyNow(AppState state) {
    final qty = _resolveQty(state);
    if (qty == null) return;

    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          items: [CartItem(product: widget.product, quantity: qty)],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final product = widget.product;
    final double alreadyInCart = state.quantityInCart(product.id);
    final double lineTotal = product.price * _qty;

    return Padding(
      padding: EdgeInsets.only(
        left: 24.0,
        right: 24.0,
        top: 16.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
      ),
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
            state.translate('select_quantity'),
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            state.translate('available_stock', arguments: {
              'count': _formatQty(_maxStock),
              'unit': product.unit,
            }),
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant),
          ),
          if (alreadyInCart > 0) ...[
            const SizedBox(height: 6),
            Text(
              state.translate('already_in_cart', arguments: {
                'count': _formatQty(alreadyInCart),
                'unit': product.unit,
              }),
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                state.translate('quantity'),
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded,
                        size: 28, color: AppColors.primary),
                    onPressed: _qty > 1 ? () => _setQty(_qty - 1) : null,
                  ),
                  SizedBox(
                    width: 84,
                    child: TextField(
                      controller: _quantityController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderSide: const BorderSide(color: AppColors.outlineVariant),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: AppColors.primary),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (val) {
                        final double? parsed = double.tryParse(val.trim());
                        // Keep the running total live, but let the buyer finish
                        // typing before complaining about an invalid value.
                        setState(() {
                          _error = null;
                          if (parsed != null && parsed >= 1 && parsed <= _maxStock) {
                            _qty = parsed;
                          }
                        });
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded,
                        size: 28, color: AppColors.primary),
                    onPressed: _qty < _maxStock ? () => _setQty(_qty + 1) : null,
                  ),
                ],
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(
              _error!,
              style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.error),
            ),
          ],
          const Divider(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                state.translate('subtotal'),
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              Text(
                formatCurrencyAmount(lineTotal, product.currency),
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (widget.buyNowIsPrimary) ...[
            CustomButton(
              text: state.translate('buy_now'),
              icon: Icons.bolt_rounded,
              onPressed: () => _buyNow(state),
            ),
            const SizedBox(height: 10),
            CustomButton.secondary(
              text: state.translate('add_to_cart'),
              icon: Icons.add_shopping_cart_rounded,
              onPressed: () => _addToCart(state),
            ),
          ] else ...[
            CustomButton(
              text: state.translate('add_to_cart'),
              icon: Icons.add_shopping_cart_rounded,
              onPressed: () => _addToCart(state),
            ),
            const SizedBox(height: 10),
            CustomButton.secondary(
              text: state.translate('buy_now'),
              icon: Icons.bolt_rounded,
              onPressed: () => _buyNow(state),
            ),
          ],
        ],
      ),
    );
  }
}
