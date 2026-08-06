import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_card.dart';

class MarketPriceTrackerScreen extends StatelessWidget {
  const MarketPriceTrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final prices = state.marketPrices;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          // Heading Section
          Text(
            state.translate('market_price_tracker_title'),
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            state.translate('market_price_subtitle'),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),

          // Price Index Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(AppDesign.borderRadiusDefault),
            ),
            child: Row(
              children: [
                const Icon(Icons.analytics_outlined, size: 28, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.translate('agri_price_index'),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        state.translate('updated_today', arguments: {'date': 'July 22, 2026'}),
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '+1.4%',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Search benchmark field
          TextField(
            decoration: InputDecoration(
              hintText: state.translate('search_commodities_hint'),
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
          ),
          const SizedBox(height: 16),

          // Price List
          Expanded(
            child: ListView.separated(
              itemCount: prices.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final price = prices[index];
                final bool isUp = price.changePercentage > 0;
                final bool isDown = price.changePercentage < 0;

                IconData trendIcon = Icons.trending_flat_rounded;
                if (isUp) {
                  trendIcon = Icons.trending_up_rounded;
                } else if (isDown) {
                  trendIcon = Icons.trending_down_rounded;
                }

                return CustomCard(
                  padding: const EdgeInsets.all(16),
                  elevated: true,
                  child: Row(
                    children: [
                      // Commodity icon/representation
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(AppDesign.borderRadiusSm),
                        ),
                        child: const Icon(
                          Icons.grass_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Commodity details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              price.name,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              state.translate('wholesale_benchmark'),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Prices and trends
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${price.currentPrice.toStringAsFixed(2)}/kg',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Price change chip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isUp
                                  ? AppColors.secondaryContainer
                                  : (isDown ? AppColors.errorContainer : AppColors.surfaceContainer),
                              borderRadius: BorderRadius.circular(AppDesign.borderRadiusSm),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  trendIcon,
                                  size: 14,
                                  color: isUp
                                      ? AppColors.onSecondaryContainer
                                      : (isDown ? AppColors.onErrorContainer : AppColors.outline),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${isUp ? "+" : ""}${price.changePercentage.toStringAsFixed(1)}%',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isUp
                                        ? AppColors.onSecondaryContainer
                                        : (isDown ? AppColors.onErrorContainer : AppColors.onSurfaceVariant),
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      )
                    ],
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
