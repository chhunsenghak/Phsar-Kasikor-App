import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../models/app_state.dart';
import '../widgets/custom_card.dart';
import 'product_detail.dart';
import 'error_screens.dart';

class MarketplaceHomeScreen extends StatelessWidget {
  const MarketplaceHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final filtered = state.filteredProducts;

    final List<String> categories = ['All', 'Vegetables', 'Fruits', 'Grains'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _buildSearchField(state),
          const SizedBox(height: 16),
          _buildCategoryChips(state, categories),
          const SizedBox(height: 16),
          if (state.searchQuery.isEmpty) ...[
            _buildPromoBanner(),
            const SizedBox(height: 20),
          ],
          _buildProductGrid(context, state, filtered),
        ],
      ),
    );
  }

  Widget _buildSearchField(AppState state) {
    return TextField(
      onChanged: (val) => state.setSearchQuery(val),
      decoration: InputDecoration(
        hintText: 'Search fresh crops, farmers...',
        hintStyle: GoogleFonts.inter(color: AppColors.outline),
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.outline),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesign.borderRadiusDefault),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Widget _buildCategoryChips(AppState state, List<String> categories) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = state.selectedCategory == category;
          return ChoiceChip(
            label: Text(
              category,
              style: GoogleFonts.inter(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.onSecondaryContainer : AppColors.onSurfaceVariant,
              ),
            ),
            selected: isSelected,
            selectedColor: AppColors.secondaryContainer,
            backgroundColor: AppColors.surfaceContainerLow,
            onSelected: (selected) {
              if (selected) state.setCategory(category);
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDesign.borderRadiusDefault),
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

  Widget _buildPromoBanner() {
    return CustomCard(
      padding: const EdgeInsets.all(20),
      backgroundColor: AppColors.primaryContainer,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Direct From Farms',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Skip middle-men. Direct pricing & verified farmer negotiations.',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: Icon(Icons.agriculture_rounded, color: AppColors.primary, size: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(BuildContext context, AppState state, List<MarketProduct> filtered) {
    if (filtered.isEmpty) {
      return Expanded(
        child: NoResultsScreen(onReset: () {
          state.setSearchQuery('');
          state.setCategory('All');
        }),
      );
    }

    return Expanded(
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.76,
        ),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final product = filtered[index];
          return _buildProductCard(context, product);
        },
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, MarketProduct product) {
    return CustomCard(
      padding: EdgeInsets.zero,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(product: product),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image Container
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                image: const DecorationImage(
                  image: AssetImage('design/logo.png'), // fallbacks or dummy representation
                  fit: BoxFit.scaleDown,
                  opacity: 0.1,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      product.category == 'Grains'
                          ? Icons.grass_rounded
                          : (product.category == 'Fruits'
                              ? Icons.apple_rounded
                              : Icons.egg_rounded),
                      size: 48,
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  // Location Chip (top left)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        product.location,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Verification indicator
                  if (product.isVerifiedFarmer)
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: Icon(
                        Icons.verified_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    )
                ],
              ),
            ),
          ),
          // Details Area
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'by ${product.farmerName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                // Price
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '\$${product.price.toStringAsFixed(2)}/${product.unit}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      'Qty: ${product.quantity.toInt()}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.outline,
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
