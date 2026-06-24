/// Stub para plataformas não-web (Android, iOS, Desktop)
/// Todas as funções retornam no-op ou null

String? getSessionStorageValue(String key) => null;

void removeSessionStorageValue(String key) {}

void openUrlInNewTab(String url) {}

void downloadFileWeb(String dataUri, String filename) {}
