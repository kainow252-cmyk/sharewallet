// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:async';

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
  // window.open(url, '_self') força mesma aba mesmo com redirect 302 cross-origin.
  // location.href falha quando o redirect vai para domínio externo (GitHub) —
  // Chrome Android abre nova guia. '_self' explicito resolve isso.
  html.window.open(url, '_self');
}

/// Baixa APK via fetch() + Blob URL — SEM abrir nova guia, SEM navegar.
///
/// Fluxo:
///   1. fetch(url) no mesmo domínio (Worker) → sem nova guia, sem CORS
///   2. response.blob() → Blob local na memória do browser
///   3. URL.createObjectURL(blob) → URL tipo blob:// (same-origin)
///   4. <a download> + .click() → Chrome inicia download nativo imediato
///   5. URL.revokeObjectURL() após 60s → libera memória
///
/// Por que funciona:
///   • fetch same-origin → browser não abre nova guia
///   • blob:// é same-origin → <a download> é respeitado pelo Chrome Android
///   • window.location.href/redirect cross-origin → Chrome abre nova guia ❌
/// Download APK via XMLHttpRequest blob — Chrome Android mostra barra de
/// progresso nativa e notificação "ABRIR" ao terminar. Sem nova guia.
///
/// XHR responseType='blob' é diferente de fetch+blob:
///   • Chrome Android trata XHR blob como download nativo — barra de progresso ✅
///   • fetch+blob carrega silencioso na memória — sem notificação visível ❌
Future<void> downloadApkBlob(String url, String filename) async {
  try {
    final completer = Completer<void>();
    final xhr = html.HttpRequest();
    xhr.open('GET', url);
    xhr.responseType = 'blob';
    xhr.onLoad.listen((_) {
      try {
        final blob = xhr.response as html.Blob;
        final blobUrl = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: blobUrl)
          ..setAttribute('download', filename)
          ..style.display = 'none';
        html.document.body?.append(anchor);
        anchor.click();
        anchor.remove();
        Future.delayed(const Duration(seconds: 60),
            () => html.Url.revokeObjectUrl(blobUrl));
      } catch (_) {
        html.window.location.href = url;
      }
      completer.complete();
    });
    xhr.onError.listen((_) {
      html.window.location.href = url;
      completer.complete();
    });
    xhr.send();
    await completer.future;
  } catch (_) {
    html.window.location.href = url;
  }
}

/// Abre o gerenciador de downloads do Android via intent:// URI.
/// Isso leva o usuário direto para a pasta de Downloads onde o APK foi salvo,
/// permitindo tocar no arquivo para iniciar a instalação.
void openAndroidDownloads() {
  try {
    // intent:// abre o app Arquivos/Downloads nativo do Android
    // Funciona no Chrome Mobile — redireciona para o gerenciador de arquivos
    html.window.location.href =
        'intent://com.android.documentsui#Intent;'
        'action=android.intent.action.MAIN;'
        'category=android.intent.category.LAUNCHER;'
        'package=com.android.documentsui;'
        'end';
  } catch (_) {
    // Fallback: abre a pasta de downloads via content://
    try {
      html.window.location.href =
          'intent://downloads#Intent;'
          'action=android.intent.action.VIEW;'
          'type=*/*;'
          'end';
    } catch (_) {
      // Último fallback: abre a página de download direto
      html.window.location.href = _apkDirectDownloadUrl;
    }
  }
}

const _apkDirectDownloadUrl = 'https://payment.sharewallet.com.br/app/download';

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
