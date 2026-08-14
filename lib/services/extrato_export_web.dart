// ignore_for_file: avoid_web_libraries_in_flutter
// ─────────────────────────────────────────────────────────────────────────────
// extrato_export_web.dart — implementação WEB (dart:html)
// Usado apenas na plataforma web via importação condicional.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'dart:html' as html;

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

/// Stub não usado na web — existe para satisfazer a assinatura
/// compartilhada entre web e stub.
Future<void> shareFileNative({
  required List<int> content,
  required String fileName,
  required String mimeType,
  required String subject,
}) async {
  // No web, usa downloadFileWeb ou openHtmlBlob diretamente.
  // Esta função nunca é chamada na plataforma web.
}
