// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../utils/web_utils.dart';

/// Serviço de foto de perfil — upload via Worker proxy (sem CORS).
///
/// O Firebase Storage bloqueia uploads diretos do browser por CORS quando o
/// bucket usa o formato novo `firebasestorage.app`. A solução é enviar os
/// bytes em base64 para o Worker Cloudflare, que faz o upload server-side
/// usando as credenciais Admin SDK (sem restrição de CORS) e retorna a URL.
class ProfilePhotoService {
  static const String _base = 'https://api.sharewallet.com.br';
  static const Duration _timeout = Duration(seconds: 30); // upload pode demorar

  // ── Selecionar e fazer upload ─────────────────────────────────────────────

  /// Abre picker (câmera ou galeria) e faz upload via worker.
  /// No APK WebView (isNativeApp): dispara o bridge nativo via JS.
  /// No browser/web normal: usa image_picker diretamente.
  /// Retorna a URL pública da foto ou null em caso de erro.
  static Future<String?> pickAndUpload({
    required String uid,
    required ImageSource source,
    void Function(String msg)? onError,
  }) async {
    // No APK WebView: o image_picker não funciona direto no contexto web.
    // Pedimos ao shell nativo via openNativeCamera/openNativeGallery (JS bridge).
    // A resposta chega via evento 'sw-photo-selected' que o profile_screen escuta.
    if (kIsWeb && isNativeApp()) {
      // Sinaliza ao WebView shell para abrir a câmera/galeria nativa
      // O resultado volta via CustomEvent 'sw-photo-selected' direto para o widget
      // que chamou — o profile_screen.dart cuida de receber e fazer upload.
      // Aqui só disparamos a solicitação; o upload acontece lá.
      return null; // retorno null pois o fluxo é assíncrono via evento
    }

    try {
      // 1. Selecionar imagem
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked == null) return null; // usuário cancelou

      // 2. Ler bytes da imagem
      final Uint8List bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        onError?.call('Não foi possível ler a imagem selecionada.');
        return null;
      }

      // 3. Determinar content type
      final String fileName = picked.name.toLowerCase();
      String contentType = 'image/jpeg';
      if (fileName.endsWith('.png')) contentType = 'image/png';
      else if (fileName.endsWith('.webp')) contentType = 'image/webp';

      // 4. Codificar em base64
      final String base64Image = base64Encode(bytes);

      // 5. Enviar para worker proxy
      final uri = Uri.parse('$_base/api/profile/upload-photo');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'uid': uid,
              'imageBase64': base64Image,
              'contentType': contentType,
            }),
          )
          .timeout(_timeout);

      final Map<String, dynamic> body = jsonDecode(response.body);

      if (body['success'] == true) {
        final result = body['result'];
        final url = result?['url'] as String?;
        if (url != null && url.isNotEmpty) {
          if (kDebugMode) debugPrint('[PhotoService] Upload OK: $url');
          return url;
        }
      }

      final errMsg = body['error'] as String? ?? 'Erro desconhecido no upload';
      if (kDebugMode) debugPrint('[PhotoService] Upload erro: $errMsg');
      onError?.call('Falha ao enviar foto: $errMsg');
      return null;
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('[PhotoService] Exceção: $e');
      onError?.call('Erro ao processar imagem: ${e.toString()}');
      return null;
    }
  }

  // ── Upload via bridge (APK WebView) ──────────────────────────────────────

  /// Recebe o dataUrl em base64 vindo do evento 'sw-photo-selected' (ponte JS/nativa)
  /// e faz upload direto ao worker proxy — mesmo fluxo do pickAndUpload normal.
  /// Retorna a URL pública da foto ou null em caso de erro.
  static Future<String?> uploadBytes({
    required String uid,
    required String base64DataUrl, // 'data:image/jpeg;base64,/9j/...'
    required String mimeType,      // 'image/jpeg' | 'image/png' | 'image/webp'
    void Function(String msg)? onError,
  }) async {
    if (uid.isEmpty || base64DataUrl.isEmpty) {
      onError?.call('UID ou imagem inválidos.');
      return null;
    }
    try {
      // Remove o prefixo 'data:image/xxx;base64,' — worker espera só o base64 puro
      final commaIdx = base64DataUrl.indexOf(',');
      final pureBase64 = commaIdx >= 0
          ? base64DataUrl.substring(commaIdx + 1)
          : base64DataUrl;

      final String contentType = mimeType.isNotEmpty ? mimeType : 'image/jpeg';

      final uri = Uri.parse('$_base/api/profile/upload-photo');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'uid': uid,
              'imageBase64': pureBase64,
              'contentType': contentType,
            }),
          )
          .timeout(_timeout);

      final Map<String, dynamic> body = jsonDecode(response.body);

      if (body['success'] == true) {
        final result = body['result'];
        final url = result?['url'] as String?;
        if (url != null && url.isNotEmpty) {
          if (kDebugMode) debugPrint('[PhotoService] uploadBytes OK: $url');
          return url;
        }
      }

      final errMsg = body['error'] as String? ?? 'Erro desconhecido no upload';
      if (kDebugMode) debugPrint('[PhotoService] uploadBytes erro: $errMsg');
      onError?.call('Falha ao enviar foto: $errMsg');
      return null;
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('[PhotoService] uploadBytes exceção: $e');
      onError?.call('Erro ao processar imagem: ${e.toString()}');
      return null;
    }
  }

  // ── Remover foto ─────────────────────────────────────────────────────────

  /// Remove a photo_url do perfil no Firestore (via Firestore REST API do worker).
  /// Para simplicidade, usa o endpoint PATCH /api/affiliates/:id que já existe.
  static Future<void> removePhoto(String uid) async {
    try {
      final uri = Uri.parse('$_base/api/affiliates/$uid');
      await http
          .patch(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'photo_url': ''}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      if (kDebugMode) debugPrint('[PhotoService] removePhoto error: $e');
    }
  }
}
