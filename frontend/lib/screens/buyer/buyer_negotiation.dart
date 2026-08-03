import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';
import 'checkout_screen.dart';

class BuyerNegotiationScreen extends StatefulWidget {
  final MarketProduct product;

  const BuyerNegotiationScreen({super.key, required this.product});

  @override
  State<BuyerNegotiationScreen> createState() => _BuyerNegotiationScreenState();
}

class _BuyerNegotiationScreenState extends State<BuyerNegotiationScreen> {
  final _priceController = TextEditingController();
  final _qtyController = TextEditingController();
  bool _isFirstLoad = true;

  @override
  void dispose() {
    _priceController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final product = widget.product;

    // Retrieve active negotiation if it exists
    final activeBid = state.negotiations.firstWhere(
      (n) => n.product.id == product.id && n.buyerName == 'Kosal Pich',
      orElse: () => BidOffer(
        id: '',
        product: product,
        buyerName: 'Kosal Pich',
        offeredPrice: product.price * 0.90, // Default to 10% lower
        quantity: 50.0,
        status: 'none',
        chatMessages: [],
      ),
    );

    if (_isFirstLoad) {
      _priceController.text = activeBid.offeredPrice.toStringAsFixed(2);
      _qtyController.text = activeBid.quantity.toInt().toString();
      _isFirstLoad = false;
    }

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
          'Negotiate: ${product.name}',
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
            // Target Product Summary Card
            _buildProductSummary(context, product),
            const SizedBox(height: 20),

            // Negotiation Timeline / Messages
            _buildNegotiationHistory(activeBid),
            const SizedBox(height: 20),

            // Bid Inputs Card
            _buildOfferDetails(state, product, activeBid),
            const SizedBox(height: 24),

            // Prototype Simulation Box (Helper tool for reviewers)
            if (activeBid.status == 'pending') ...[
              _buildSimulator(state, activeBid),
            ],

            if (activeBid.status == 'accepted') ...[
              _buildCheckoutButton(context, product, activeBid),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildProductSummary(BuildContext context, MarketProduct product) {
    final state = Provider.of<AppState>(context, listen: false);
    return CustomCard(
      padding: const EdgeInsets.all(16),
      elevated: false,
      backgroundColor: AppColors.surfaceContainerLow,
      child: Row(
        children: [
          const Icon(Icons.shopping_bag_outlined, color: AppColors.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '${state.translate('market_price')}: ${product.formattedPrice}/${product.unit}',
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildNegotiationHistory(BidOffer activeBid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Negotiation History',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 180,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDesign.borderRadiusDefault),
            border: Border.all(color: AppColors.outlineVariant, width: 0.5),
          ),
          child: activeBid.status == 'none'
              ? Center(
                  child: Text(
                    'No offers placed yet. Fill fields below to start.',
                    style: GoogleFonts.inter(color: AppColors.outline, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  itemCount: activeBid.chatMessages.length,
                  itemBuilder: (context, idx) {
                    final msg = activeBid.chatMessages[idx];
                    final isFarmer = msg.startsWith('Farmer:');
                    final isSystem = msg.startsWith('System:');

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Align(
                        alignment: isSystem
                            ? Alignment.center
                            : (isFarmer ? Alignment.centerLeft : Alignment.centerRight),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSystem
                                ? Colors.grey[200]
                                : (isFarmer ? AppColors.surfaceContainerLow : AppColors.secondaryContainer),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            msg,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: isSystem ? FontWeight.w500 : FontWeight.bold,
                              color: isSystem
                                  ? AppColors.onSurfaceVariant
                                  : (isFarmer ? AppColors.onSurface : AppColors.onSecondaryContainer),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildOfferDetails(AppState state, MarketProduct product, BidOffer activeBid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Offer details',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        CustomCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: product.currency == 'KHR' ? 'Offered Price (៛)' : 'Offered Price (\$)',
                        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        suffixText: '/${product.unit}',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        suffixText: product.unit,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Bid Status
              if (activeBid.status != 'none') ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Status:',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusBg(activeBid.status),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        activeBid.status.toUpperCase(),
                        style: GoogleFonts.inter(
                          color: _getStatusText(activeBid.status),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // Action Button
              CustomButton(
                text: activeBid.status == 'none' ? 'Submit Offer' : 'Update Bid Offer',
                icon: Icons.send_rounded,
                onPressed: () {
                  final price = double.tryParse(_priceController.text) ?? product.price;
                  final qty = double.tryParse(_qtyController.text) ?? 50.0;
                  state.placeBid(product, price, qty);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSimulator(AppState state, BidOffer activeBid) {
    return CustomCard(
      backgroundColor: AppColors.secondaryContainer.withValues(alpha: 0.3),
      borderSide: const BorderSide(color: AppColors.primary, width: 1),
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
            'Simulate the farmer\'s response to your bid. Choose an action:',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurface),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () {
                    state.acceptBid(activeBid.id);
                  },
                  child: Text(state.translate('accept'), style: const TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.tertiary),
                  onPressed: () {
                    final counterPrice = activeBid.offeredPrice * 1.05; // 5% bump
                    state.counterOffer(activeBid.id, counterPrice);
                    _priceController.text = counterPrice.toStringAsFixed(2);
                  },
                  child: Text(state.translate('counter_offer'), style: const TextStyle(color: Colors.white)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCheckoutButton(BuildContext context, MarketProduct product, BidOffer activeBid) {
    return CustomButton(
      text: 'Proceed to Checkout',
      icon: Icons.shopping_cart_checkout_rounded,
      backgroundColor: AppColors.primary,
      onPressed: () {
        // NOTE: the orders API prices every line from the product's listing
        // price — it has no field for a negotiated rate — so checkout shows and
        // charges the listing price. Honouring activeBid.offeredPrice needs an
        // agreed-price field on the order item first.
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CheckoutScreen(
              items: [
                CartItem(product: product, quantity: activeBid.quantity),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusBg(String status) {
    if (status == 'accepted') return AppColors.secondaryContainer;
    if (status == 'rejected') return AppColors.errorContainer;
    if (status == 'counter_offered') return Colors.amber[100]!;
    return AppColors.surfaceContainerHigh;
  }

  Color _getStatusText(String status) {
    if (status == 'accepted') return AppColors.onSecondaryContainer;
    if (status == 'rejected') return AppColors.error;
    if (status == 'counter_offered') return Colors.amber[900]!;
    return AppColors.onSurfaceVariant;
  }
}
