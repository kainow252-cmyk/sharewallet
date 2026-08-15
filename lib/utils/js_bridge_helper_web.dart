// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js' as js;

import 'package:flutter/foundation.dart';

// ── Foto de perfil ────────────────────────────────────────────────────────────

void Function(String dataUrl, String mimeType)? _photoCallback;

/// Registra listener JS 'sw-photo-selected' despachado pelo shell nativo.
/// [onPhoto] é chamado com (dataUrl base64, mimeType) quando a foto chega.
void registerPhotoEventListener(void Function(String dataUrl, String mimeType) onPhoto) {
  _photoCallback = onPhoto;

  js.context['_swPhotoCallback'] = js.allowInterop((dynamic detail) {
    try {
      final dataUrl = detail['dataUrl']?.toString() ?? '';
      final mime    = detail['mimeType']?.toString() ?? 'image/jpeg';
      if (dataUrl.isNotEmpty) {
        _photoCallback?.call(dataUrl, mime);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[JsBridgeHelper] photo callback err: $e');
    }
  });

  js.context.callMethod('eval', [
    '''
    (function() {
      if (window._swPhotoListenerRegistered) return;
      window._swPhotoListenerRegistered = true;
      window.addEventListener('sw-photo-selected', function(e) {
        if (window._swPhotoCallback && e.detail) {
          window._swPhotoCallback(e.detail);
        }
      });
    })();
    '''
  ]);
}

/// Remove o listener JS de foto e limpa o callback.
void unregisterPhotoEventListener() {
  _photoCallback = null;
  try {
    js.context.callMethod('eval', [
      '''
      window._swPhotoListenerRegistered = false;
      delete window._swPhotoCallback;
      '''
    ]);
  } catch (_) {}
}

// ── Biometria ─────────────────────────────────────────────────────────────────

void Function(String email, String password)? _bioCallback;

/// Registra listener JS 'sw-biometric-login' despachado pelo shell nativo.
/// [onLogin] é chamado com (email, password) após biometria bem-sucedida.
void registerBiometricLoginListener(void Function(String email, String password) onLogin) {
  _bioCallback = onLogin;

  js.context['_swBiometricLoginCallback'] = js.allowInterop((dynamic detail) {
    try {
      final email    = detail['email']?.toString() ?? '';
      final password = detail['password']?.toString() ?? '';
      if (email.isNotEmpty && password.isNotEmpty) {
        _bioCallback?.call(email, password);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[JsBridgeHelper] bio callback err: $e');
    }
  });

  js.context.callMethod('eval', [
    '''
    (function() {
      if (window._swBioListenerRegistered) return;
      window._swBioListenerRegistered = true;
      window.addEventListener('sw-biometric-login', function(e) {
        if (window._swBiometricLoginCallback && e.detail) {
          window._swBiometricLoginCallback(e.detail);
        }
      });
    })();
    '''
  ]);

  if (kDebugMode) debugPrint('[JsBridgeHelper] sw-biometric-login listener registrado');
}

/// Remove o listener JS de biometria e limpa o callback.
void unregisterBiometricLoginListener() {
  _bioCallback = null;
  try {
    js.context.callMethod('eval', [
      '''
      window._swBioListenerRegistered = false;
      delete window._swBiometricLoginCallback;
      '''
    ]);
  } catch (_) {}
}

// ── Picker nativo ─────────────────────────────────────────────────────────────

/// Chama a função JS `openNativeCamera()` injetada pelo shell.
void callNativeCamera() {
  try {
    js.context.callMethod('openNativeCamera', []);
  } catch (e) {
    if (kDebugMode) debugPrint('[JsBridgeHelper] callNativeCamera err: $e');
  }
}

/// Chama a função JS `openNativeGallery()` injetada pelo shell.
void callNativeGallery() {
  try {
    js.context.callMethod('openNativeGallery', []);
  } catch (e) {
    if (kDebugMode) debugPrint('[JsBridgeHelper] callNativeGallery err: $e');
  }
}
