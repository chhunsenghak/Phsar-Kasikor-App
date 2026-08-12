import 'dart:async';
import 'package:flutter/material.dart';

/// Shared "poll Bakong until paid" state machine for KHQR-based checkout
/// screens. Extracted from the order checkout flow so a future fix to
/// polling/cooldown behavior can't silently apply to only one of the
/// screens that need it (order checkout, contract deposit checkout) —
/// they'd otherwise duplicate the exact same timer/silent-vs-manual logic.
///
/// A screen mixes this in, implements [checkPayment] to perform one actual
/// check (silent background tick or an explicit manual tap) and report
/// whether it fully settled, then calls [startPolling] once (e.g. in
/// `initState`) and [checkPaymentManually] from a manual "I've Paid" button.
mixin KhqrPollingMixin<T extends StatefulWidget> on State<T> {
  Timer? _pollTimer;
  bool isCheckingPayment = false;

  /// Perform one payment check. Return true once the payment is fully
  /// settled (the mixin then stops polling) — false to keep waiting.
  /// [silent] is true for background timer ticks, where implementations
  /// should avoid any UI feedback beyond normal setState-driven rebuilds;
  /// false for an explicit user-initiated tap, where implementations are
  /// expected to surface their own snackbars/errors.
  Future<bool> checkPayment({required bool silent});

  void startPolling({Duration interval = const Duration(seconds: 4)}) {
    _pollTimer = Timer.periodic(interval, (_) => _runCheck(silent: true));
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> checkPaymentManually() => _runCheck(silent: false);

  Future<void> _runCheck({required bool silent}) async {
    // Silent ticks run unguarded (same as before extraction) — only a
    // manual tap is guarded against re-entrancy.
    if (!silent && isCheckingPayment) return;
    if (!silent) setState(() => isCheckingPayment = true);
    final settled = await checkPayment(silent: silent);
    if (!mounted) return;
    if (!silent) setState(() => isCheckingPayment = false);
    if (settled) stopPolling();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
