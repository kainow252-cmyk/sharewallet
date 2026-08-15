/// Helper de interoperabilidade JS para bridge APK WebView.
/// Usa implementação web real na plataforma web, stub vazio no mobile/desktop.
export 'js_bridge_helper_stub.dart'
    if (dart.library.html) 'js_bridge_helper_web.dart';
