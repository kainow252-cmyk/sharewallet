// ignore_for_file: avoid_web_libraries_in_flutter
// Migrado de dart:js (deprecated) para dart:js_interop + dart:js_interop_unsafe.
// dart:js_interop é a API moderna e estável para interop JS no Flutter Web.
// globalContext.callMethod('eval', ...) substitui window.eval() — não disponível
// no package:web 1.1.1 como método direto.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';

// ── Helper: eval JS seguro ─────────────────────────────────────────────────

/// Executa código JavaScript via globalThis.eval().
/// Substitui web.window.eval() que não existe no package:web 1.1.1.
void _jsEval(String code) {
  try {
    globalContext.callMethod('eval'.toJS, code.toJS);
  } catch (e) {
    if (kDebugMode) debugPrint('[JsBridgeHelper] eval error: $e');
  }
}

/// Define uma propriedade no globalThis (window).
void _setGlobal(String name, JSAny? value) {
  globalContext.setProperty(name.toJS, value);
}

// ── Foto de perfil ────────────────────────────────────────────────────────────

void Function(String dataUrl, String mimeType)? _photoCallback;
JSFunction? _dartPhotoCallbackRef;

/// Registra listener JS 'sw-photo-selected' despachado pelo shell nativo.
/// [onPhoto] é chamado com (dataUrl base64, mimeType) quando a foto chega.
void registerPhotoEventListener(
    void Function(String dataUrl, String mimeType) onPhoto) {
  _photoCallback = onPhoto;

  // Registra a função Dart que será chamada pelo JS
  _dartPhotoCallbackRef = (JSString dataUrl, JSString mime) {
    final du = dataUrl.toDart;
    final m = mime.toDart;
    if (du.isNotEmpty) _photoCallback?.call(du, m);
  }.toJS;

  _setGlobal('_dartPhotoCallback', _dartPhotoCallbackRef);

  // Injeta handler global e event listener
  _jsEval(r'''
    (function() {
      window._swPhotoCallback = function(detail) {
        if (window._dartPhotoCallback) {
          window._dartPhotoCallback(
            detail.dataUrl || '',
            detail.mimeType || 'image/jpeg'
          );
        }
      };
      if (window._swPhotoListenerRegistered) return;
      window._swPhotoListenerRegistered = true;
      window.addEventListener('sw-photo-selected', function(e) {
        if (window._swPhotoCallback && e.detail) {
          window._swPhotoCallback(e.detail);
        }
      });
    })();
  ''');
}

/// Remove o listener JS de foto e limpa o callback.
void unregisterPhotoEventListener() {
  _photoCallback = null;
  _dartPhotoCallbackRef = null;
  _jsEval(r'''
    window._swPhotoListenerRegistered = false;
    delete window._swPhotoCallback;
    delete window._dartPhotoCallback;
  ''');
}

// ── Biometria: login ──────────────────────────────────────────────────────────

void Function(String email, String password)? _bioCallback;
JSFunction? _dartBioCallbackRef;

/// Registra listener JS 'sw-biometric-login' despachado pelo shell nativo.
/// [onLogin] é chamado com (email, password) após biometria bem-sucedida.
void registerBiometricLoginListener(
    void Function(String email, String password) onLogin) {
  _bioCallback = onLogin;

  _dartBioCallbackRef = (JSString email, JSString password) {
    final e = email.toDart;
    final p = password.toDart;
    if (e.isNotEmpty && p.isNotEmpty) _bioCallback?.call(e, p);
  }.toJS;

  _setGlobal('_dartBioCallback', _dartBioCallbackRef);

  _jsEval(r'''
    (function() {
      window._swBiometricLoginCallback = function(detail) {
        if (window._dartBioCallback) {
          window._dartBioCallback(
            detail.email    || '',
            detail.password || ''
          );
        }
      };
      if (window._swBioListenerRegistered) return;
      window._swBioListenerRegistered = true;
      window.addEventListener('sw-biometric-login', function(e) {
        if (window._swBiometricLoginCallback && e.detail) {
          window._swBiometricLoginCallback(e.detail);
        }
      });
    })();
  ''');

  if (kDebugMode) debugPrint('[JsBridgeHelper] sw-biometric-login listener registrado');
}

/// Remove o listener JS de biometria e limpa o callback.
void unregisterBiometricLoginListener() {
  _bioCallback = null;
  _dartBioCallbackRef = null;
  _jsEval(r'''
    window._swBioListenerRegistered = false;
    delete window._swBiometricLoginCallback;
    delete window._dartBioCallback;
  ''');
}

// ── Biometria: erro ────────────────────────────────────────────────────────────

void Function(String msg)? _bioErrorCallback;
JSFunction? _dartBioErrorCallbackRef;

/// Registra listener JS 'sw-biometric-error' para receber erros do shell.
void registerBiometricErrorListener(void Function(String msg) onError) {
  _bioErrorCallback = onError;

  _dartBioErrorCallbackRef = (JSString msg) {
    _bioErrorCallback?.call(msg.toDart);
  }.toJS;

  _setGlobal('_dartBioErrorCallback', _dartBioErrorCallbackRef);

  _jsEval(r'''
    (function() {
      window._swBiometricErrorCallback = function(detail) {
        if (window._dartBioErrorCallback) {
          window._dartBioErrorCallback(detail.msg || '');
        }
      };
      if (window._swBioErrorListenerRegistered) return;
      window._swBioErrorListenerRegistered = true;
      window.addEventListener('sw-biometric-error', function(e) {
        if (window._swBiometricErrorCallback && e.detail) {
          window._swBiometricErrorCallback(e.detail);
        }
      });
    })();
  ''');
}

// ── Picker nativo ─────────────────────────────────────────────────────────────

/// Dispara evento 'sw-request-biometric' para o shell nativo iniciar biometria.
void callNativeBiometric() {
  _jsEval("window.dispatchEvent(new CustomEvent('sw-request-biometric'));");
}

/// Pede ao shell nativo para salvar credenciais no Keystore Android e ativar
/// login biométrico. Disparado quando o usuário clica "Ativar" no dialog.
void callNativeSaveBiometric(String email, String password) {
  // Usa postMessage para passar credenciais ao shell Flutter (evita eval com dados sensíveis)
  _jsEval(
    "if(window.ShareWalletNative){"
    "  window.ShareWalletNative.postMessage("
    "    JSON.stringify({action:'saveBiometric',email:${_jsonString(email)},password:${_jsonString(password)}})"
    "  );"
    "}",
  );
}

/// Serializa string para JSON seguro (evita injeção JS).
String _jsonString(String s) {
  // json.encode retorna aspas duplas ex: "\"foo@bar.com\""
  final escaped = s
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r');
  return '"$escaped"';
}

/// Chama a função JS `openNativeCamera()` injetada pelo shell.
void callNativeCamera() {
  _jsEval('if(window.openNativeCamera) window.openNativeCamera();');
}

/// Chama a função JS `openNativeGallery()` injetada pelo shell.
void callNativeGallery() {
  _jsEval('if(window.openNativeGallery) window.openNativeGallery();');
}
