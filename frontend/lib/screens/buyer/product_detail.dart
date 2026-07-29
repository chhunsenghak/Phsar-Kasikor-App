import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/trust_badge.dart';
import 'buyer_negotiation.dart';
import 'khqr_checkout.dart';
import 'farm_profile.dart';

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
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroImage(),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleAndPrice(state),
                  const SizedBox(height: 20),
                  _buildStockIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    'Product Description',
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
      bottomNavigationBar: _buildBottomActionBar(context),
    );
  }

  Widget _buildHeroImage() {
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
                product.category,
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
              'per ${product.unit}',
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

  Widget _buildStockIndicator() {
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
            'Available Stock: ${product.quantity.toInt()} ${product.unit}s',
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
          'Producer Information',
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
                          ? '${state.getFarmerCertType(product.farmerName).toUpperCase()} Certified Producer'
                          : 'Registered Seller',
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

  Widget _buildBottomActionBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppDesign.level2Shadow,
        border: const Border(
          top: BorderSide(color: AppColors.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: CustomButton.secondary(
              text: 'Negotiate',
              icon: Icons.chat_bubble_outline_rounded,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BuyerNegotiationScreen(product: product),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: CustomButton(
              text: 'Buy Now',
              icon: Icons.shopping_cart_outlined,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => KHQRCheckoutScreen(
                      productName: product.name,
                      unit: product.unit,
                      price: product.price,
                      quantity: 10, // Mock checkout quantity
                      currency: product.currency,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
