// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Implementação Web — usa dart:html

String? getSessionStorageValue(String key) {
  return html.window.sessionStorage[key];
}

void removeSessionStorageValue(String key) {
  html.window.sessionStorage.remove(key);
}

void openUrlInNewTab(String url) {
  html.window.open(url, '_blank');
}

void downloadFileWeb(String dataUri, String filename) {
  final anchor = html.AnchorElement(href: dataUri)
    ..setAttribute('download', filename)
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}
