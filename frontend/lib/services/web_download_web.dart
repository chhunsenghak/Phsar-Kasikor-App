// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void downloadFileWeb(List<int> bytes, String filename) {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

void saveWebStorage(String key, String value) {
  html.window.localStorage[key] = value;
}

String? getWebStorage(String key) {
  return html.window.localStorage[key];
}

void removeWebStorage(String key) {
  html.window.localStorage.remove(key);
}
