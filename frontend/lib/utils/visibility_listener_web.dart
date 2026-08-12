// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

typedef VisibilityCancel = void Function();

/// Belt-and-suspenders alongside AppLifecycleState.resumed: Flutter's own
/// web lifecycle mapping to document.visibilitychange has a history of
/// rough edges across browser/engine versions, so this listens to the DOM
/// event directly instead of trusting only the engine's relay of it.
/// Returns a cancel function to remove the listener.
VisibilityCancel onPageVisible(void Function() callback) {
  void handler(html.Event event) {
    if (html.document.visibilityState == 'visible') {
      callback();
    }
  }

  html.document.addEventListener('visibilitychange', handler);
  return () => html.document.removeEventListener('visibilitychange', handler);
}
