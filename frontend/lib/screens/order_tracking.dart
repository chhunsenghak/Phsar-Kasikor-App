import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../widgets/custom_card.dart';
import '../widgets/custom_button.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String productName;
  final double price;
  final double quantity;
  final double total;

  const OrderTrackingScreen({
    super.key,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.total,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  int _currentStep = 1; // 0: Payment Approved, 1: Packaging, 2: In-Transit, 3: Delivered

  final List<Map<String, String>> _steps = [
    {
      'title': 'Payment Approved',
      'desc': 'Payment settled via Bakong KHQR. Receipt ID: TXN-898231',
      'time': 'July 22, 13:30',
    },
    {
      'title': 'Packaging crops',
      'desc': 'Farmer Chan Sopheap is packaging the crops into fresh containers.',
      'time': 'July 22, 14:00',
    },
    {
      'title': 'In Transit',
      'desc': 'Shipped via Virak Buntham Express. Tracking: VET-902-88',
      'time': 'Pending',
    },
    {
      'title': 'Delivered',
      'desc': 'Courier will hand over to your address in Phnom Penh.',
      'time': 'Pending',
    },
  ];

  void _simulateProgress() {
    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
        if (_currentStep == 2) {
          _steps[2]['time'] = 'July 22, 14:15';
        } else if (_currentStep == 3) {
          _steps[3]['time'] = 'July 22, 14:45';
          _steps[3]['desc'] = 'Package successfully signed and delivered.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Order Tracking',
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
            // Order Receipt Summary Box
            CustomCard(
              padding: const EdgeInsets.all(16),
              backgroundColor: AppColors.surface,
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_shipping_outlined, color: AppColors.onSecondaryContainer),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order Ref: PK-2026-9028',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.quantity.toInt()} units of ${widget.productName}',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '\$${widget.total.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Stepper Header
            Text(
              'Delivery Status',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 16),

            // Custom Vertical Stepper
            Column(
              children: List.generate(_steps.length, (idx) {
                final isCompleted = idx < _currentStep;
                final isActive = idx == _currentStep;
                final isLast = idx == _steps.length - 1;

                Color dotColor = AppColors.outlineVariant;
                Color textColor = AppColors.outline;
                Color subTextColor = AppColors.onSurfaceVariant.withValues(alpha: 0.6);

                if (isCompleted) {
                  dotColor = AppColors.primary;
                  textColor = AppColors.onSurface;
                  subTextColor = AppColors.onSurfaceVariant;
                } else if (isActive) {
                  dotColor = AppColors.secondary;
                  textColor = AppColors.primary;
                  subTextColor = AppColors.onSurface;
                }

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Step Indicator Left Line + Dot
                      Column(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: isCompleted ? dotColor : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: dotColor,
                                width: 2,
                              ),
                            ),
                            child: isCompleted
                                ? const Icon(Icons.check, size: 12, color: Colors.white)
                                : null,
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: isCompleted ? AppColors.primary : AppColors.outlineVariant,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // Text Info Block
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _steps[idx]['title']!,
                                    style: GoogleFonts.inter(
                                      fontWeight: isActive || isCompleted ? FontWeight.bold : FontWeight.w500,
                                      fontSize: 15,
                                      color: textColor,
                                    ),
                                  ),
                                  Text(
                                    _steps[idx]['time']!,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: AppColors.outline,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _steps[idx]['desc']!,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: subTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),

            // Interactivity Sandbox Controller (to show off transitions)
            if (_currentStep < 3) ...[
              CustomCard(
                backgroundColor: AppColors.secondaryContainer.withValues(alpha: 0.3),
                borderSide: const BorderSide(color: AppColors.primary, width: 0.8),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PROTOTYPE INTERACTIVE SIMULATOR',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Advance the delivery status to the next step for testing purposes.',
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurface),
                    ),
                    const SizedBox(height: 12),
                    CustomButton(
                      text: 'Simulate Next Step',
                      icon: Icons.local_shipping_outlined,
                      onPressed: _simulateProgress,
                      height: 44,
                    )
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            CustomButton.secondary(
              text: 'Back to Marketplace',
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
