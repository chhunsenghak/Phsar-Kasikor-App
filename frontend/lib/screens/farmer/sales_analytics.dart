import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_card.dart';
import '../../services/api/analytics_api.dart';
import '../../utils/currency_format.dart';

class SalesAnalyticsScreen extends StatefulWidget {
  const SalesAnalyticsScreen({super.key});

  @override
  State<SalesAnalyticsScreen> createState() => _SalesAnalyticsScreenState();
}

class _SalesAnalyticsScreenState extends State<SalesAnalyticsScreen> {
  bool _isLoading = true;
  // {currency: total} — a farmer's orders can be placed in either USD or
  // KHR, and there's no exchange rate anywhere in this app to blend them
  // into one number, so each currency gets its own total.
  Map<String, double> _revenueByCurrency = {};
  int _activeListings = 0;
  String _conversionRate = '0.0%';
  int _ordersAccepted = 0;
  // {currency: [{'month': ..., 'value': ...}, ...]}
  Map<String, List<Map<String, dynamic>>> _monthlyRevenuesByCurrency = {};
  String? _selectedCurrency;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    final state = Provider.of<AppState>(context, listen: false);
    if (state.token == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final res = await AnalyticsApi.fetchFarmerSalesAnalytics(state.token!);
      final revenueByCurrency = <String, double>{};
      for (final entry in (res['revenue_by_currency'] as List? ?? [])) {
        revenueByCurrency[entry['currency']?.toString() ?? 'USD'] = (entry['amount'] as num?)?.toDouble() ?? 0.0;
      }

      final monthlyByCurrency = <String, List<Map<String, dynamic>>>{};
      for (final entry in (res['monthly_revenues'] as List? ?? [])) {
        final currency = entry['currency']?.toString() ?? 'USD';
        monthlyByCurrency.putIfAbsent(currency, () => []).add({
          'month': entry['month']?.toString() ?? '',
          'value': (entry['value'] as num?)?.toDouble() ?? 0.0,
        });
      }

      setState(() {
        _revenueByCurrency = revenueByCurrency;
        _activeListings = (res['active_listings'] as num?)?.toInt() ?? 0;
        _conversionRate = res['conversion_rate']?.toString() ?? '0.0%';
        _ordersAccepted = (res['orders_accepted'] as num?)?.toInt() ?? 0;
        _monthlyRevenuesByCurrency = monthlyByCurrency;
        _selectedCurrency = revenueByCurrency.keys.isNotEmpty ? revenueByCurrency.keys.first : null;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final monthlyRevenues = _monthlyRevenuesByCurrency[_selectedCurrency] ?? [];
    final maxVal = monthlyRevenues.map((e) => e['value'] as double).fold(1.0, (a, b) => a > b ? a : b);

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
          state.translate('sales_analytics'),
          style: GoogleFonts.inter(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                          state.translate('yearly_sales_revenue'),
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Both currencies, always, each on its own line —
                        // Cambodia trades in both USD and KHR, so a farmer
                        // with revenue in only one shouldn't look like the
                        // other isn't tracked. Never blended into one
                        // number: there's no exchange rate anywhere in
                        // this app.
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatCurrency(_revenueByCurrency['USD'] ?? 0.0, 'USD'),
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              formatCurrency(_revenueByCurrency['KHR'] ?? 0.0, 'KHR'),
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildMetricItem(state.translate('active_listings'), '$_activeListings'),
                            _buildMetricItem(state.translate('conversion_rate'), _conversionRate),
                            _buildMetricItem(state.translate('bids_accepted'), '$_ordersAccepted'),
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Bar Chart Container
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        state.translate('monthly_performance'),
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                      ),
                      if (_monthlyRevenuesByCurrency.length > 1)
                        DropdownButton<String>(
                          value: _selectedCurrency,
                          underline: const SizedBox.shrink(),
                          items: _monthlyRevenuesByCurrency.keys
                              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (c) => setState(() => _selectedCurrency = c),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CustomCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 200,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: monthlyRevenues.map((data) {
                              final double val = data['value'] as double;
                              final String month = data['month'] as String;
                              final double pct = val / (maxVal == 0 ? 1.0 : maxVal);
                              final double barHeight = (pct * 150).clamp(10.0, 150.0);

                              return Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    _selectedCurrency == 'KHR' ? '${val.round()}៛' : '\$${val.round()}',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    width: 24,
                                    height: barHeight,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryContainer,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(6),
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
}
