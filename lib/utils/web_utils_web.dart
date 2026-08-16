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

/// Retorna true se o Flutter Web está rodando dentro do APK WebView.
/// Detecta via:
///   1. User-Agent 'ShareWalletApp/1.0' injetado pelo WebView shell (mais confiável)
///   2. window.ShareWalletNativeApp = true injetado via JS após onPageFinished
///   3. Classe CSS 'sw-native-app' no documentElement (também injetada pelo shell)
bool isNativeApp() {
  try {
    // 1. User-Agent (mais confiável — definido antes da navegação)
    if (html.window.navigator.userAgent.contains('ShareWalletApp/')) return true;
    // 2. Flag JS injetada pelo shell após onPageFinished
    // Lê via JS eval: window.ShareWalletNativeApp
    final nativeFlag = (html.window as dynamic).ShareWalletNativeApp;
    if (nativeFlag == true) return true;
    // 3. Classe CSS no documentElement
    if (html.document.documentElement?.className.contains('sw-native-app') == true) return true;
    return false;
  } catch (_) {
    return false;
  }
}

/// Retorna o hash atual da URL (sem o '#').
/// Ex: URL = /app/#/produto/p_123?ref=ABC → retorna '/produto/p_123?ref=ABC'
/// Usado como fallback quando o sessionStorage está vazio.
String getWindowHash() {
  try {
    final hash = html.window.location.hash;
    if (hash.length > 1) return hash.substring(1); // remove '#'
    return '';
  } catch (_) {
    return '';
  }
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
