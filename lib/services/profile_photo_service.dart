import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Serviço de foto de perfil — upload para Firebase Storage + atualiza Firestore.
///
/// Fluxo:
///   1. Usuário escolhe: câmera ou galeria
///   2. Faz upload para storage/avatars/{uid}.jpg
///   3. Pega download URL
///   4. Salva photo_url no Firestore (affiliates/{uid})
///   5. Retorna a URL para o app atualizar o estado local
class ProfilePhotoService {
  static final _picker = ImagePicker();

  /// Abre câmera ou galeria e retorna a URL final após upload.
  /// Retorna null se cancelado ou em caso de erro.
  static Future<String?> pickAndUpload({
    required String uid,
    required ImageSource source,
    void Function(String msg)? onError,
  }) async {
    try {
      // 1. Selecionar imagem
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked == null) return null; // usuário cancelou

      // 2. Upload para Firebase Storage
      final ref = FirebaseStorage.instance
          .ref()
          .child('avatars')
          .child('$uid.jpg');

      UploadTask task;
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        task = ref.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        task = ref.putFile(
          File(picked.path),
          SettableMetadata(contentType: 'image/jpeg'),
        );
      }

      final snapshot = await task;
      final url = await snapshot.ref.getDownloadURL();

      // 3. Salvar URL no Firestore
      try {
        final db = _getFirestore();
        if (db != null) {
          await db.collection('affiliates').doc(uid).set(
            {'photo_url': url, 'updated_at': FieldValue.serverTimestamp()},
            SetOptions(merge: true),
          );
        }
      } catch (e) {
        // Não bloqueia — a URL já foi salva no Storage
        if (kDebugMode) debugPrint('[ProfilePhotoService] Firestore update error: $e');
      }

      return url;
    } catch (e) {
      if (kDebugMode) debugPrint('[ProfilePhotoService] error: $e');
      onError?.call('Erro ao enviar foto. Tente novamente.');
      return null;
    }
  }

  /// Remove a foto do perfil (define photo_url como null no Firestore).
  static Future<void> removePhoto(String uid) async {
    try {
      final db = _getFirestore();
      if (db != null) {
        await db.collection('affiliates').doc(uid).update({'photo_url': null});
      }
      // Tenta apagar do Storage também (não é crítico se falhar)
      try {
        await FirebaseStorage.instance
            .ref()
            .child('avatars/$uid.jpg')
            .delete();
      } catch (_) {}
    } catch (e) {
      if (kDebugMode) debugPrint('[ProfilePhotoService] removePhoto error: $e');
    }
  }

  static FirebaseFirestore? _getFirestore() {
    try {
      return FirebaseFirestore.instanceFor(
        app: Firebase.app('affiliatewalletwallet'),
      );
    } catch (_) {
      try {
        return FirebaseFirestore.instance;
      } catch (_) {
        return null;
      }
    }
  }
}
