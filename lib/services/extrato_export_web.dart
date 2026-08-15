// ignore_for_file: avoid_web_libraries_in_flutter
// ─────────────────────────────────────────────────────────────────────────────
// extrato_export_web.dart — implementação WEB (dart:html)
// Usado apenas na plataforma web via importação condicional.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;

/// Faz download de um arquivo de texto diretamente no browser.
/// Cria um Blob → ObjectURL → ancora com `download` → clica automaticamente.
void downloadFileWeb({
  required String content,
  required String fileName,
  required String mimeType,
}) {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  // ignore: unsafe_html
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

/// Abre um blob HTML em nova aba do browser.
/// O usuário pode usar Ctrl+P (ou o botão no HTML) para salvar como PDF.
void openHtmlBlob({required String html_, required String fileName}) {
  final bytes = utf8.encode(html_);
  final blob = html.Blob([bytes], 'text/html;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
  // Revoga após 60 s para liberar memória (a aba já carregou)
  Future.delayed(const Duration(seconds: 60), () {
    html.Url.revokeObjectUrl(url);
  });
}

/// No APK WebView (kIsWeb=true mas isNativeApp()=true):
/// usa a Web Share API do Android se disponível, ou faz download via blob.
/// No browser desktop: fallback para download direto.
Future<void> shareFileNative({
  required List<int> content,
  required String fileName,
  required String mimeType,
  required String subject,
}) async {
  try {
    // Tenta Web Share API (suportada no Android Chrome/WebView)
    final blob = html.Blob([content], mimeType);
    final file = js.JsObject(js.context['File'], [
      js.JsArray.from([blob]),
      fileName,
      js.JsObject.jsify({'type': mimeType}),
    ]);
    final navigator = js.context['navigator'];
    if (navigator.hasProperty('share') && navigator.hasProperty('canShare')) {
      final shareData = js.JsObject.jsify({
        'files': [file],
        'title': subject,
      });
      if (navigator.callMethod('canShare', [shareData]) == true) {
        navigator.callMethod('share', [shareData]);
        return;
      }
    }
  } catch (_) {}
  // Fallback: download via blob URL
  final blob = html.Blob([content], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  Future.delayed(const Duration(seconds: 5), () => html.Url.revokeObjectUrl(url));
}
