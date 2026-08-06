import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/app_snackbar.dart';
import '../../services/api/order_api.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  final String productName;
  final double price;
  final double quantity;
  final double total;
  final String currency;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.total,
    this.currency = 'USD',
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  String _orderStatus = 'PLACED';
  String _paymentMethod = 'KHQR';
  String _deliveryMethod = 'DELIVERY';
  bool _isLoading = false;
  Timer? _pollingTimer;

  final List<Map<String, String>> _steps = [
    {
      'title': 'step_payment_approved',
      'desc': 'step_payment_approved_desc',
      'time': 'just_now',
    },
    {
      'title': 'step_packaging',
      'desc': 'step_packaging_desc',
      'time': 'pending_time_label',
    },
    {
      'title': 'step_in_transit',
      'desc': 'step_in_transit_desc',
      'time': 'pending_time_label',
    },
    {
      'title': 'step_delivered',
      'desc': 'step_delivered_desc',
      'time': 'pending_time_label',
    },
  ];

  int get _currentStep {
    switch (_orderStatus) {
      case 'PLACED':
        return 0;
      case 'CONFIRMED':
        return 1;
      case 'SHIPPED':
        return 2;
      case 'DELIVERED':
        return 3;
      case 'CANCELLED':
        return -1;
      default:
        return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchOrderStatus();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) => _fetchOrderStatus(silent: true));
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchOrderStatus({bool silent = false}) async {
    final state = Provider.of<AppState>(context, listen: false);
    if (state.token == null) return;
    if (!silent) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final res = await OrderApi.fetchOrderDetails(state.token!, widget.orderId);
      if (mounted) {
        setState(() {
          _orderStatus = res['order_status'] ?? 'PLACED';
          _paymentMethod = res['payment_method'] ?? 'KHQR';
          _deliveryMethod = res['delivery_method'] ?? 'DELIVERY';

          if (_paymentMethod == 'COD') {
            _steps[0]['title'] = 'step_order_confirmed';
            _steps[0]['desc'] = 'step_order_confirmed_desc';
          } else {
            _steps[0]['title'] = 'step_payment_approved';
            _steps[0]['desc'] = 'step_payment_approved_desc';
          }

          if (_deliveryMethod == 'PICKUP') {
            _steps[2]['title'] = 'step_ready_pickup';
            _steps[2]['desc'] = 'step_ready_pickup_desc';
            _steps[3]['title'] = 'step_collected';
            _steps[3]['desc'] = 'step_collected_desc';
          } else {
            _steps[2]['title'] = 'step_in_transit';
            _steps[2]['desc'] = 'step_in_transit_desc';
            _steps[3]['title'] = 'step_delivered';
            _steps[3]['desc'] = 'step_delivered_desc';
          }

          if (_currentStep >= 1) {
            _steps[1]['time'] = 'updated_label';
          }
          if (_currentStep >= 2) {
            _steps[2]['time'] = 'step_in_transit';
          }
          if (_currentStep >= 3) {
            _steps[3]['time'] = 'arrived_label';
            _steps[3]['desc'] = 'step_delivered_success_desc';
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted && !silent) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final ref = widget.orderId.length > 8 ? widget.orderId.substring(0, 8).toUpperCase() : widget.orderId;

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
          state.translate('order_tracking'),
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
                          '${state.translate('order_id')}: PK-$ref',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          state.translate('units_of', arguments: {
                            'count': widget.quantity.toInt().toString(),
                            'name': widget.productName,
                          }),
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatCurrencyAmount(widget.total, widget.currency),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            CustomCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              backgroundColor: AppColors.surface,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        state.translate('payment_method'),
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant),
                      ),
                      Text(
                        _paymentMethod == 'COD' ? state.translate('cod_cash') : state.translate('khqr_pay'),
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        state.translate('delivery_method'),
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant),
                      ),
                      Text(
                        _deliveryMethod == 'PICKUP' ? state.translate('self_pickup') : state.translate('express_delivery'),
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_orderStatus == 'CANCELLED') ...[
              CustomCard(
                backgroundColor: AppColors.error.withValues(alpha: 0.1),
                borderSide: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.cancel_rounded, color: AppColors.error),
                    const SizedBox(width: 12),
                    Text(
                      state.translate('order_cancelled'),
                      style: GoogleFonts.inter(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  state.translate('delivery_status'),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                else
                  TextButton.icon(
                    onPressed: () => _fetchOrderStatus(silent: false),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(state.translate('refresh')),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            Column(
              children: List.generate(_steps.length, (idx) {
                final isCompleted = _orderStatus != 'CANCELLED' && idx < _currentStep;
                final isActive = _orderStatus != 'CANCELLED' && idx == _currentStep;

                final circleColor = isCompleted
                    ? AppColors.primary
                    : isActive
                        ? AppColors.secondary
                        : AppColors.outlineVariant;
                final textColor = isCompleted || isActive ? AppColors.onSurface : AppColors.onSurfaceVariant;
                final subTextColor = isCompleted || isActive ? AppColors.onSurfaceVariant : AppColors.outline;

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: circleColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isCompleted ? Icons.check_rounded : Icons.lens_rounded,
                              size: isCompleted ? 14 : 10,
                              color: isCompleted || isActive ? Colors.white : AppColors.outline,
                            ),
                          ),
                          if (idx < _steps.length - 1)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: isCompleted ? AppColors.primary : AppColors.outlineVariant,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
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
                                    state.translate(_steps[idx]['title']!),
                                    style: GoogleFonts.inter(
                                      fontWeight: isActive || isCompleted ? FontWeight.bold : FontWeight.w500,
                                      fontSize: 15,
                                      color: textColor,
                                    ),
                                  ),
                                  Text(
                                    state.translate(_steps[idx]['time']!),
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: AppColors.outline,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                state.translate(_steps[idx]['desc']!),
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

            if (state.currentRole == 'farmer') ...[
              if (_isUpdating)
                const Center(child: CircularProgressIndicator(color: AppColors.primary))
              else ...[
                if (_orderStatus == 'PLACED')
                  CustomButton(
                    text: state.translate('mark_packaging'),
                    backgroundColor: AppColors.primary,
                    onPressed: () => _updateStatus(state, 'CONFIRMED'),
                  )
                else if (_orderStatus == 'CONFIRMED')
                  CustomButton(
                    text: _deliveryMethod == 'PICKUP' ? state.translate('mark_ready_pickup') : state.translate('ship_order'),
                    backgroundColor: AppColors.primary,
                    onPressed: () => _updateStatus(state, 'SHIPPED'),
                  )
                else if (_orderStatus == 'SHIPPED')
                  CustomButton(
                    text: _deliveryMethod == 'PICKUP' ? state.translate('mark_collected') : state.translate('mark_delivered'),
                    backgroundColor: AppColors.primary,
                    onPressed: () => _updateStatus(state, 'DELIVERED'),
                  ),
              ],
              const SizedBox(height: 12),
            ],

            CustomButton.secondary(
              text: state.translate('back_home'),
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

  bool _isUpdating = false;

  Future<void> _updateStatus(AppState state, String nextStatus) async {
    if (state.token == null) return;
    setState(() {
      _isUpdating = true;
    });
    try {
      await OrderApi.updateOrder(
        state.token!,
        widget.orderId,
        orderStatus: nextStatus,
      );
      state.addNotification(
        state.translate('order_status_updated'),
        state.translate('order_status_updated_msg', arguments: {
          'id': widget.orderId.substring(0, 8).toUpperCase(),
          'status': nextStatus,
        }),
      );
      await _fetchOrderStatus(silent: false);
      if (mounted) {
        AppSnackBar.success(context, state.translate('order_updated_success', arguments: {'status': nextStatus}));
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, state.translate('failed_update_status', arguments: {'error': e.toString()}));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }
}
