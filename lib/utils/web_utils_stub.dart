/// Stub para plataformas não-web (Android, iOS, Desktop)
/// Todas as funções retornam no-op ou null

// ── sessionStorage ────────────────────────────────────────────────────────────

String? getSessionStorageValue(String key) => null;

void removeSessionStorageValue(String key) {}

void setSessionStorageValue(String key, String value) {}

// ── localStorage (stub — no-op em mobile/desktop) ──────────────────────────

String? getLocalStorageValue(String key) => null;

void setLocalStorageValue(String key, String value) {}

void removeLocalStorageValue(String key) {}

// ── Utilitários de janela ─────────────────────────────────────────────────────

void openUrlInNewTab(String url) {}

void navigateSameTab(String url) {}

/// Stub — mobile nativo usa launchUrl direto, não Blob API
Future<void> downloadApkBlob(String url, String filename) async {}

void downloadFileWeb(String dataUri, String filename) {}

void openHtmlBlobInNewTab(String htmlContent) {}

/// Stub — no-op em mobile/desktop
void notifyFlutterReady() {}

/// Stub — mobile nativo nunca é WebView
bool isNativeApp() => false;

/// Stub — mobile/desktop não tem hash de URL
String getWindowHash() => '';
