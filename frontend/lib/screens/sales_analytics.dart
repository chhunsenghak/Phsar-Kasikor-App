import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../widgets/custom_card.dart';

class SalesAnalyticsScreen extends StatelessWidget {
  const SalesAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock monthly revenues
    final List<Map<String, dynamic>> monthlyRevenues = [
      {'month': 'Jan', 'value': 280.0},
      {'month': 'Feb', 'value': 350.0},
      {'month': 'Mar', 'value': 190.0},
      {'month': 'Apr', 'value': 480.0},
      {'month': 'May', 'value': 310.0},
      {'month': 'Jun', 'value': 520.0},
      {'month': 'Jul', 'value': 420.0},
    ];

    // Find max value to calibrate heights
    final maxVal = monthlyRevenues.map((e) => e['value'] as double).reduce((a, b) => a > b ? a : b);

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
          'Sales & Analytics',
          style: GoogleFonts.inter(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Revenue summary block
            CustomCard(
              padding: const EdgeInsets.all(20),
              backgroundColor: AppColors.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yearly Sales Revenue',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$2,550.00',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetricItem('Active Listings', '3 Crops'),
                      _buildMetricItem('Conversion Rate', '4.2%'),
                      _buildMetricItem('Bids Accepted', '14 Offers'),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Bar Chart Container
            Text(
              'Monthly Sales Performance (USD)',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            CustomCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Y-Axis and Bars
                  SizedBox(
                    height: 200,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: monthlyRevenues.map((data) {
                        final double val = data['value'] as double;
                        final String month = data['month'] as String;
                        // Calculate percentage height
                        final double pct = val / maxVal;
                        final double barHeight = (pct * 150).clamp(10.0, 150.0);

                        return Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '\$${val.toInt()}',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            // The Bar
                            Container(
                              width: 24,
                              height: barHeight,
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6),
                                ),
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primaryContainer,
                                    AppColors.primaryContainer.withValues(alpha: 0.7),
                                  ],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              month,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sales breakdown insights
            Text(
              'Product Performance Breakdowns',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            CustomCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildCropBreakdownRow(
                    crop: 'Organic Jasmine Rice',
                    sales: '\$1,560.00',
                    share: '61% Share',
                  ),
                  const Divider(height: 1),
                  _buildCropBreakdownRow(
                    crop: 'Premium Yellow Corn',
                    sales: '\$990.00',
                    share: '39% Share',
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildCropBreakdownRow({required String crop, required String sales, required String share}) {
    return ListTile(
      leading: const Icon(Icons.eco_rounded, color: AppColors.primary),
      title: Text(
        crop,
        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Text(share, style: GoogleFonts.inter(fontSize: 12)),
      trailing: Text(
        sales,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
          fontSize: 14,
        ),
      ),
    );
  }
}
