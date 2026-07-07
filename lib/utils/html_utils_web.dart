// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show FileUploadInputElement, FileReader, window;
import 'dart:async';

/// Abre seletor de arquivo e retorna o conteúdo como data URL (base64)
Future<String?> pickFileAsDataUrl({String accept = 'image/*'}) async {
  try {
    final input = html.FileUploadInputElement()..accept = accept;
    input.click();
    await input.onChange.first;
    final files = input.files;
    if (files == null || files.isEmpty) return null;
    final reader = html.FileReader();
    reader.readAsDataUrl(files[0]);
    await reader.onLoad.first;
    return reader.result as String?;
  } catch (_) {
    return null;
  }
}

/// Obtém posição GPS via browser Geolocation API
Future<Map<String, dynamic>?> getCurrentGeoPosition() async {
  try {
    final completer = Completer<Map<String, dynamic>>();
    // ignore: undefined_prefixed_name
    html.window.navigator.geolocation.getCurrentPosition(
      maximumAge: Duration.zero,
      timeout: const Duration(seconds: 15),
      enableHighAccuracy: true,
    ).then((pos) {
      completer.complete({
        'lat': pos.coords!.latitude,
        'lng': pos.coords!.longitude,
        'acc': pos.coords!.accuracy,
        'ts': DateTime.now().toIso8601String(),
      });
    }).catchError((dynamic e) {
      completer.completeError(e);
    });
    return await completer.future;
  } catch (_) {
    return null;
  }
}
