import'package:flutter/foundation.dart';
import'package:firebase_storage/firebase_storage.dart';
import'package:cloud_firestore/cloud_firestore.dart';

class PhotoService {
 static final _storage = FirebaseStorage.instance;
 static final _firestore = FirebaseFirestore.instance;

 /// Faz upload da foto de perfil para o Firebase Storage
 /// Retorna a URL pública da foto ou null em caso de erro
 static Future<String?> uploadProfilePhoto({
 required String uid,
 required Uint8List imageBytes,
 String extension ='jpg',
 }) async {
 try {
 final ref = _storage
 .ref()
 .child('profile_photos')
 .child('$uid.$extension');

 final metadata = SettableMetadata(
 contentType:'image/$extension',
 customMetadata: {'uid': uid},
 );

 final uploadTask = await ref.putData(imageBytes, metadata);
 final downloadUrl = await uploadTask.ref.getDownloadURL();

 // Salva a URL no Firestore
 await _firestore.collection('users').doc(uid).set(
 {'photo_url': downloadUrl},
 SetOptions(merge: true),
 );

 if (kDebugMode) debugPrint('[PhotoService] Upload OK: $downloadUrl');
 return downloadUrl;
 } catch (e) {
 if (kDebugMode) debugPrint('[PhotoService] Erro upload: $e');
 return null;
 }
 }

 /// Remove a foto de perfil do Storage e limpa no Firestore
 static Future<bool> removeProfilePhoto(String uid) async {
 try {
 // Remove do Storage (tenta jpg e png)
 for (final ext in ['jpg','png','jpeg']) {
 try {
 await _storage
 .ref()
 .child('profile_photos')
 .child('$uid.$ext')
 .delete();
 } catch (_) {}
 }

 // Limpa no Firestore
 await _firestore.collection('users').doc(uid).set(
 {'photo_url':''},
 SetOptions(merge: true),
 );
 return true;
 } catch (e) {
 if (kDebugMode) debugPrint('[PhotoService] Erro remover foto: $e');
 return false;
 }
 }
}
