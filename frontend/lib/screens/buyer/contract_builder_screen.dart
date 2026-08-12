import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_input.dart';
import '../../widgets/app_snackbar.dart';
import '../../utils/phnom_penh_time.dart';

class _DraftLine {
  final MarketProduct product;
  final TextEditingController priceController;
  final TextEditingController quantityController;

  _DraftLine(this.product, {double? price, double? quantity})
      : priceController = TextEditingController(text: (price ?? product.price).toStringAsFixed(2)),
        quantityController = TextEditingController(text: (quantity ?? 10).toStringAsFixed(0));

  void dispose() {
    priceController.dispose();
    quantityController.dispose();
  }
}

/// Proposes (or, when [existingContract] is set, counter-offers on) a
/// contract bundling one or more of [sellerName]'s products — the backend
/// has always supported multiple line items per contract; this is the
/// screen that finally lets a buyer actually build one.
class ContractBuilderScreen extends StatefulWidget {
  final String sellerId;
  final String sellerName;
  final BidOffer? existingContract;

  const ContractBuilderScreen({
    super.key,
    required this.sellerId,
    required this.sellerName,
    this.existingContract,
  });

  @override
  State<ContractBuilderScreen> createState() => _ContractBuilderScreenState();
}

class _ContractBuilderScreenState extends State<ContractBuilderScreen> {
  final List<_DraftLine> _lines = [];
  bool _isSubmitting = false;

  // Delivery window is now something the buyer sets to match what was
  // actually agreed in chat, rather than a silent +1/+30 day default the
  // seller never got a say in. Falls back to that same default when there's
  // nothing to seed from yet (a fresh proposal, or an old contract that
  // predates dates being tracked at all).
  late DateTime _startDate;
  late DateTime _endDate;

  bool get _isEditing => widget.existingContract != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingContract;
    if (existing != null) {
      for (final item in existing.items) {
        _lines.add(_DraftLine(item.product, price: item.agreedPrice, quantity: item.agreedQuantity));
      }
    }
    _startDate = existing?.startDate ?? DateTime.now().add(const Duration(days: 1));
    _endDate = existing?.endDate ?? DateTime.now().add(const Duration(days: 30));
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  List<MarketProduct> _sellerProductsNotAdded(AppState state) {
    final addedIds = _lines.map((l) => l.product.id).toSet();
    return state.products.where((p) => p.sellerId == widget.sellerId && !addedIds.contains(p.id)).toList();
  }

  Future<void> _pickProduct(AppState state) async {
    final available = _sellerProductsNotAdded(state);
    final picked = await showModalBottomSheet<MarketProduct>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.translate('add_product_to_contract'),
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (available.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  state.translate('no_more_products_to_add'),
                  style: GoogleFonts.inter(color: AppColors.outline),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: available.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final p = available[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(p.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${p.formattedPrice}/${p.unit}',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                      ),
                      onTap: () => Navigator.pop(context, p),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() => _lines.add(_DraftLine(picked)));
    }
  }

  double get _totalValue {
    double total = 0;
    for (final line in _lines) {
      final price = double.tryParse(line.priceController.text) ?? 0;
      final qty = double.tryParse(line.quantityController.text) ?? 0;
      total += price * qty;
    }
    return total;
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final earliestStart = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final firstDate = isStart ? earliestStart : _startDate.add(const Duration(days: 1));
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstDate) ? firstDate : initial,
      firstDate: firstDate,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (!_endDate.isAfter(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 1));
        }
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _submit(AppState state) async {
    if (_lines.isEmpty) {
      AppSnackBar.warning(context, state.translate('error_no_items_in_contract'));
      return;
    }
    if (!_startDate.isAfter(DateTime.now())) {
      AppSnackBar.warning(context, state.translate('start_date_future_error'));
      return;
    }
    if (!_endDate.isAfter(_startDate)) {
      AppSnackBar.warning(context, state.translate('end_date_after_start_error'));
      return;
    }

    final items = <ContractLineItem>[];
    for (final line in _lines) {
      final price = double.tryParse(line.priceController.text);
      final qty = double.tryParse(line.quantityController.text);
      if (price == null || price <= 0 || qty == null || qty <= 0) {
        AppSnackBar.warning(context, state.translate('enter_valid_price_quantity'));
        return;
      }
      items.add(ContractLineItem(product: line.product, agreedPrice: price, agreedQuantity: qty));
    }

    setState(() => _isSubmitting = true);
    final error = _isEditing
        ? await state.counterOffer(
            widget.existingContract!.id,
            items,
            startDate: _startDate,
            endDate: _endDate,
          )
        : await state.placeBid(
            widget.sellerId,
            items,
            startDate: _startDate,
            endDate: _endDate,
          );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (error != null) {
      AppSnackBar.error(context, friendlyContractErrorMessage(state, error));
      return;
    }
    Navigator.pop(context, true);
    AppSnackBar.success(
      context,
      state.translate(_isEditing ? 'counter_offer_sent' : 'contract_proposed_success'),
    );
  }

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
          _isEditing ? state.translate('counter_offer') : state.translate('propose_contract'),
          style: GoogleFonts.inter(color: AppColors.onSurface, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomCard(
              padding: const EdgeInsets.all(16),
              backgroundColor: AppColors.surfaceContainerLow,
              elevated: false,
              child: Row(
                children: [
                  const Icon(Icons.storefront_outlined, color: AppColors.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      state.translate('contract_with_seller', arguments: {'name': widget.sellerName}),
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              state.translate('delivery_window_label'),
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              state.translate('delivery_window_hint'),
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildDateField(
                    label: state.translate('start_date'),
                    date: _startDate,
                    onTap: () => _pickDate(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateField(
                    label: state.translate('end_date'),
                    date: _endDate,
                    onTap: () => _pickDate(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  state.translate('contract_products'),
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextButton.icon(
                  onPressed: () => _pickProduct(state),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(state.translate('add_product')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_lines.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    state.translate('no_products_added_yet'),
                    style: GoogleFonts.inter(color: AppColors.outline),
                  ),
                ),
              )
            else
              ..._lines.asMap().entries.map((entry) => _buildLineCard(state, entry.key, entry.value)),
            if (_lines.isNotEmpty) ...[
              const SizedBox(height: 16),
              CustomCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(state.translate('total_value'), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    Text(
                      formatCurrencyAmount(_totalValue, _lines.first.product.currency),
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            CustomButton(
              text: _isEditing ? state.translate('submit_counter_offer') : state.translate('submit_offer'),
              icon: Icons.send_rounded,
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : () => _submit(state),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField({required String label, required DateTime date, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    formatDateOnly(date),
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineCard(AppState state, int index, _DraftLine line) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: CustomCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(line.product.name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.error),
                  onPressed: () => setState(() {
                    line.dispose();
                    _lines.removeAt(index);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CustomInput(
                    label: line.product.currency == 'KHR'
                        ? state.translate('offered_price_khr')
                        : state.translate('offered_price_usd'),
                    hintText: '0.00',
                    controller: line.priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomInput(
                    label: state.translate('quantity'),
                    hintText: '0',
                    controller: line.quantityController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
