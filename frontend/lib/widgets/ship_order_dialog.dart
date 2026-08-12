import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../models/app_state.dart';
import '../utils/numeric_input.dart';
import 'custom_input.dart';

/// Shown right before a farmer marks an order (or a contract's linked
/// fulfillment order) SHIPPED — lets them optionally record a delivery
/// contact phone and handoff notes for the buyer, plus a private note of
/// what the delivery actually cost them. All three fields are optional;
/// confirming with everything blank behaves exactly like the old one-tap
/// "Ship Order" did. [actualDeliveryCost] is never shown to or charged to
/// the buyer — it's separate from the order/contract's own delivery fee,
/// which was already fixed earlier in the flow.
Future<void> showShipOrderDialog(
  BuildContext context,
  AppState state, {
  required Future<void> Function({
    String? contactPhone,
    String? deliveryNotes,
    double? actualDeliveryCost,
  }) onConfirm,
}) {
  final phoneController = TextEditingController();
  final notesController = TextEditingController();
  final costController = TextEditingController();

  return showDialog(
    context: context,
    builder: (dialogContext) {
      bool isSubmitting = false;
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            state.translate('ship_order_dialog_title'),
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.translate('ship_order_dialog_hint'),
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                CustomInput(
                  label: state.translate('delivery_contact_phone_label'),
                  hintText: '012 345 678',
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                CustomInput(
                  label: state.translate('delivery_notes_label'),
                  hintText: state.translate('delivery_notes_hint'),
                  controller: notesController,
                ),
                const SizedBox(height: 12),
                CustomInput(
                  label: state.translate('actual_delivery_cost_label'),
                  hintText: '0',
                  controller: costController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 4),
                Text(
                  state.translate('actual_delivery_cost_hint'),
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
              child: Text(state.translate('cancel')),
            ),
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() => isSubmitting = true);
                      await onConfirm(
                        contactPhone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                        deliveryNotes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                        actualDeliveryCost: parseNumericInput(costController.text),
                      );
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
              child: Text(state.translate('ship_order')),
            ),
          ],
        ),
      );
    },
  );
}
