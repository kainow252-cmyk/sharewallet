// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Implementação Web — usa dart:html

// ── sessionStorage ────────────────────────────────────────────────────────────

String? getSessionStorageValue(String key) {
  return html.window.sessionStorage[key];
}

void removeSessionStorageValue(String key) {
  html.window.sessionStorage.remove(key);
}

/// Grava um valor no sessionStorage.
void setSessionStorageValue(String key, String value) {
  html.window.sessionStorage[key] = value;
}

// ── localStorage (persiste entre sessões / PWA relaunches) ───────────────────

/// Lê um valor do localStorage. Retorna null se não existir ou em caso de erro.
String? getLocalStorageValue(String key) {
  try {
    return html.window.localStorage[key];
  } catch (_) {
    return null;
  }
}

/// Grava um valor no localStorage.
void setLocalStorageValue(String key, String value) {
  try {
    html.window.localStorage[key] = value;
  } catch (_) {
    // Ignora erros de storage cheio ou modo privado sem localStorage
  }
}

/// Remove uma chave do localStorage.
void removeLocalStorageValue(String key) {
  try {
    html.window.localStorage.remove(key);
  } catch (_) {}
}

// ── Utilitários de janela ─────────────────────────────────────────────────────

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

/// Dispara o evento 'flutter-first-frame' no window para remover o splash nativo.
/// Deve ser chamado quando o primeiro frame do app estiver visível.
void notifyFlutterReady() {
  try {
    html.window.dispatchEvent(html.Event('flutter-first-frame'));
  } catch (_) {}
}

/// Abre HTML como Blob URL em nova aba (não usa data: URI — evita bloqueio do Chrome).
/// Usa window.open com Blob URL que o browser aceita mesmo em contexto async.
void openHtmlBlobInNewTab(String htmlContent) {
  // ignore: avoid_web_libraries_in_flutter, deprecated_member_use
  final blob = html.Blob([htmlContent], 'text/html;charset=utf-8');
  final url  = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
  // Revoga após 2 minutos (tempo suficiente para a aba carregar e imprimir)
  Future.delayed(const Duration(minutes: 2), () => html.Url.revokeObjectUrl(url));
}
