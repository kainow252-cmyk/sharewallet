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

/// Navega na MESMA aba para a URL — usado para downloads externos (APK).
/// Diferente de open('_blank') que abre nova guia.
/// O browser trata arquivos .apk como download automático.
void navigateSameTab(String url) {
  html.window.location.href = url;
}

/// Baixa um APK via fetch() + Blob URL — 100% client-side, sem nova guia.
///
/// Fluxo:
///   1. fetch(url) no mesmo domínio → sem nova guia, sem CORS problem
///   2. response.blob() → cria objeto Blob local na memória do browser
///   3. URL.createObjectURL(blob) → cria URL do tipo blob:// (same-origin)
///   4. Cria <a download> e dispara .click() → Chrome inicia download nativo
///   5. URL.revokeObjectURL() após 60s → libera memória
///
/// Funciona mesmo em Chrome Mobile onde window.location.href = url externo
/// causa abertura de nova guia ao invés de download direto.
Future<void> downloadApkBlob(String url, String filename) async {
  try {
    // 1. Busca o APK via fetch (mesmo domínio = sem nova guia)
    final resp = await html.window.fetch(url);
    // ignore: avoid_dynamic_calls
    if ((resp as dynamic).ok != true) {
      // Fallback: navega na mesma aba se fetch falhar
      html.window.location.href = url;
      return;
    }
    // 2. Converte para Blob
    // ignore: avoid_dynamic_calls
    final blob = await (resp as dynamic).blob() as html.Blob;
    // 3. Cria URL blob://
    final blobUrl = html.Url.createObjectUrlFromBlob(blob);
    // 4. Dispara download via <a download>
    final anchor = html.AnchorElement(href: blobUrl)
      ..setAttribute('download', filename)
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    // 5. Revoga após 60s (tempo para o download iniciar)
    Future.delayed(const Duration(seconds: 60),
        () => html.Url.revokeObjectUrl(blobUrl));
  } catch (_) {
    // Fallback final: navega na mesma aba
    html.window.location.href = url;
  }
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
/// Detecta via 4 métodos independentes — qualquer um basta:
///   1. User-Agent 'ShareWalletApp/' injetado pelo WebView shell
///   2. window.ShareWalletNativeApp = true injetado via JS pelo shell
///   3. Classe CSS 'sw-native-app' no documentElement (injetada pelo shell)
///   4. localStorage['sw_native'] == '1' gravado pelo shell no onPageStarted
///      → MAIS CONFIÁVEL: persiste entre recargas, independe de timing
bool isNativeApp() {
  try {
    // 4. localStorage (gravado pelo shell nativo — mais confiável, independe de timing)
    if (html.window.localStorage['sw_native'] == '1') return true;
    // 1. User-Agent
    if (html.window.navigator.userAgent.contains('ShareWalletApp/')) return true;
    // 2. Flag JS injetada pelo shell
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
