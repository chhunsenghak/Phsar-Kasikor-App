import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../models/app_state.dart';
import '../widgets/custom_card.dart';
import '../widgets/custom_button.dart';
import 'order_tracking.dart';

class KHQRCheckoutScreen extends StatelessWidget {
  final String productName;
  final String unit;
  final double price;
  final double quantity;

  const KHQRCheckoutScreen({
    super.key,
    required this.productName,
    required this.unit,
    required this.price,
    required this.quantity,
  });

  @override
  Widget build(BuildContext context) {
    final subtotal = price * quantity;
    final deliveryFee = 2.0; // flat rate USD
    final total = subtotal + deliveryFee;

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
          'KHQR Checkout',
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
          children: [
            // Bill Invoice Details
            CustomCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order Invoice Summary',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  _buildInvoiceRow(
                    label: productName,
                    value: '${quantity.toInt()} $unit × \$${price.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 10),
                  _buildInvoiceRow(
                    label: 'Subtotal',
                    value: '\$${subtotal.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 10),
                  _buildInvoiceRow(
                    label: 'Delivery Fee (Battambang -> Phnom Penh)',
                    value: '\$${deliveryFee.toStringAsFixed(2)}',
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Payable',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '\$${total.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // KHQR Box matching standard Cambodian Bank formats
            CustomCard(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // KHQR Header Logo Banner
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'KHQR',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red[800],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'BAKONG',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Mock QR Code Image area
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppDesign.borderRadiusSm),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Stylized QR code representation using lines/grids
                        Column(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: List.generate(10, (r) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: List.generate(10, (c) {
                                final isDark = (r + c) % 3 == 0 || (r * c) % 4 == 0 || (r == 0 && c < 3) || (c == 0 && r < 3);
                                return Container(
                                  width: 14,
                                  height: 14,
                                  color: isDark ? Colors.black : Colors.white,
                                );
                              }),
                            );
                          }),
                        ),
                        // Inner logo badge
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary, width: 2),
                          ),
                          child: const Icon(
                            Icons.eco_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Merchant Name / Details
                  Text(
                    'PHSAR KASIKOR MERCHANT',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Currency: USD Only',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Confirm Trigger Button
            CustomButton(
              text: 'Simulate Payment Complete',
              icon: Icons.check_circle_outline_rounded,
              onPressed: () {
                // Add order tracking alert
                Provider.of<AppState>(context, listen: false).addNotification(
                  'Payment Successful',
                  'Payment of \$${total.toStringAsFixed(2)} for $productName was approved.',
                );
                // Push order tracking screen
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderTrackingScreen(
                      productName: productName,
                      price: price,
                      quantity: quantity,
                      total: total,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Scanning KHQR triggers standard Bakong Interbank Settlement',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.outline),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceRow({required String label, required String value}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}
