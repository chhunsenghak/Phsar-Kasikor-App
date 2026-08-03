import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_card.dart';
import '../../services/api/analytics_api.dart';

class SalesAnalyticsScreen extends StatefulWidget {
  const SalesAnalyticsScreen({super.key});

  @override
  State<SalesAnalyticsScreen> createState() => _SalesAnalyticsScreenState();
}

class _SalesAnalyticsScreenState extends State<SalesAnalyticsScreen> {
  bool _isLoading = true;
  double _totalYearlySales = 2550.0;
  int _activeListings = 3;
  String _conversionRate = '4.2%';
  int _ordersAccepted = 14;
  List<Map<String, dynamic>> _monthlyRevenues = [
    {'month': 'Jan', 'value': 280.0},
    {'month': 'Feb', 'value': 350.0},
    {'month': 'Mar', 'value': 190.0},
    {'month': 'Apr', 'value': 480.0},
    {'month': 'May', 'value': 310.0},
    {'month': 'Jun', 'value': 520.0},
    {'month': 'Jul', 'value': 420.0},
  ];

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
      setState(() {
        _totalYearlySales = (res['total_yearly_sales'] as num?)?.toDouble() ?? 0.0;
        _activeListings = (res['active_listings'] as num?)?.toInt() ?? 0;
        _conversionRate = res['conversion_rate']?.toString() ?? '0.0%';
        _ordersAccepted = (res['orders_accepted'] as num?)?.toInt() ?? 0;

        if (res['monthly_revenues'] is List && (res['monthly_revenues'] as List).isNotEmpty) {
          _monthlyRevenues = (res['monthly_revenues'] as List).map((e) {
            return {
              'month': e['month']?.toString() ?? '',
              'value': (e['value'] as num?)?.toDouble() ?? 0.0,
            };
          }).toList();
        }
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final maxVal = _monthlyRevenues.map((e) => e['value'] as double).fold(1.0, (a, b) => a > b ? a : b);

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
                        Text(
                          '\$${_totalYearlySales.toStringAsFixed(2)}',
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
                  Text(
                    state.translate('monthly_performance'),
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
                        SizedBox(
                          height: 200,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: _monthlyRevenues.map((data) {
                              final double val = data['value'] as double;
                              final String month = data['month'] as String;
                              final double pct = val / (maxVal == 0 ? 1.0 : maxVal);
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
