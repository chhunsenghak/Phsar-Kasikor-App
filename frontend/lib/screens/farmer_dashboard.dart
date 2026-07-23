import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../models/app_state.dart';
import '../widgets/custom_card.dart';
import '../widgets/custom_button.dart';
import 'sales_analytics.dart';
import 'improved_add_new_product.dart';

class FarmerDashboardScreen extends StatelessWidget {
  const FarmerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final myProducts = state.products.where((p) => p.farmerName == 'Chan Sopheap').toList();
    final activeBids = state.negotiations.where((n) => n.product.farmerName == 'Chan Sopheap').toList();

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
            _buildIncomingBids(state, activeBids),
            const SizedBox(height: 24),
            _buildCropListings(myProducts),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Farmer Dashboard',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage crops, view sales & respond to bids',
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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ImprovedAddNewProductScreen(),
              ),
            );
          },
        )
      ],
    );
  }

  Widget _buildPerformanceStats(BuildContext context, List<BidOffer> activeBids) {
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
                  'Total Revenue ↗',
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
                  'Active Negotiations',
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
          'Incoming Buyer Bids (${activeBids.length})',
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
                    'No active buyer bids on your listings.',
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
                          'Product: ${bid.product.name}',
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Offer details: \$${bid.offeredPrice.toStringAsFixed(2)}/kg for ${bid.quantity.toInt()} kgs',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        if (isPending) ...[
                          const Divider(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: CustomButton(
                                  text: 'Accept',
                                  height: 38,
                                  onPressed: () {
                                    state.acceptBid(bid.id);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: CustomButton.secondary(
                                  text: 'Reject',
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

  Widget _buildCropListings(List<MarketProduct> myProducts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My Crop Listings (${myProducts.length})',
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
                    'You have not listed any products yet.',
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
                          child: Icon(
                            prod.category == 'Grains' ? Icons.grass_rounded : Icons.egg_rounded,
                            color: AppColors.primary,
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
                                'Category: ${prod.category} | Stock: ${prod.quantity.toInt()} ${prod.unit}s',
                                style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '\$${prod.price.toStringAsFixed(2)}/${prod.unit}',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ],
    );
  }
}
