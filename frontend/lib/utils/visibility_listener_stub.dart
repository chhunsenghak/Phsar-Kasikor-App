typedef VisibilityCancel = void Function();

/// No-op on mobile/desktop — those platforms get their "became visible again"
/// signal from AppLifecycleState.resumed instead (see WidgetsBindingObserver
/// usage in chat_thread_screen.dart / chat_inbox_screen.dart).
VisibilityCancel onPageVisible(void Function() callback) => () {};
