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

void downloadFileWeb(String dataUri, String filename) {}

void openHtmlBlobInNewTab(String htmlContent) {}
