/// Stub para plataformas não-web (Android, iOS, desktop).
/// Todas as funções são no-ops — o bridge JS não existe fora do WebView web.

/// Registra listener JS 'sw-photo-selected' → chama [onPhoto] com (dataUrl, mimeType).
void registerPhotoEventListener(void Function(String dataUrl, String mimeType) onPhoto) {
  // No-op em Android/iOS (a foto chega via image_picker nativo, não via JS event)
}

/// Remove o listener JS de foto (limpeza no dispose).
void unregisterPhotoEventListener() {}

/// Registra listener JS 'sw-biometric-login' → chama [onLogin] com (email, password).
void registerBiometricLoginListener(void Function(String email, String password) onLogin) {
  // No-op em Android/iOS (biometria é tratada pelo shell nativo diretamente)
}

/// Remove o listener JS de biometria.
void unregisterBiometricLoginListener() {}

/// Chama openNativeCamera() no contexto JS do WebView shell.
void callNativeCamera() {}

/// Chama openNativeGallery() no contexto JS do WebView shell.
void callNativeGallery() {}
