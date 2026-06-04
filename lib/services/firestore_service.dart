import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Serviço base de acesso ao Firestore.
///
/// Usa o banco customizado [_databaseId] = 'affiliatewalletwallet'.
/// Como o banco NÃO é o '(default)', precisamos instanciar com
/// [FirebaseFirestore.instanceFor(app:, databaseId:)].
class FirestoreService {
  static const String _databaseId = 'affiliatewalletwallet';

  static FirebaseFirestore? _instance;

  /// Retorna a instância do Firestore apontando para o banco correto.
  /// Retorna null se o Firebase não estiver inicializado (modo demo).
  static FirebaseFirestore? get db {
    if (_instance != null) return _instance;

    try {
      // Verifica se o Firebase já foi inicializado
      if (Firebase.apps.isEmpty) {
        debugPrint('[FirestoreService] Firebase não inicializado — modo demo');
        return null;
      }

      _instance = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: _databaseId,
      );

      if (kDebugMode) {
        debugPrint('[FirestoreService] Conectado ao banco: $_databaseId');
      }

      return _instance;
    } catch (e) {
      debugPrint('[FirestoreService] Erro ao inicializar: $e');
      return null;
    }
  }

  /// Verifica se o Firestore está disponível (Firebase inicializado).
  static bool get isAvailable => Firebase.apps.isNotEmpty;

  // ── Coleções ──────────────────────────────────────────────────────────────

  static CollectionReference<Map<String, dynamic>>? collection(String name) {
    return db?.collection(name);
  }

  static CollectionReference<Map<String, dynamic>>? get products =>
      collection('products');

  static CollectionReference<Map<String, dynamic>>? get affiliates =>
      collection('affiliates');

  static CollectionReference<Map<String, dynamic>>? get subscriptions =>
      collection('subscriptions');

  static CollectionReference<Map<String, dynamic>>? get withdrawals =>
      collection('withdrawals');

  static CollectionReference<Map<String, dynamic>>? get metrics =>
      collection('metrics');

  static CollectionReference<Map<String, dynamic>>? get config =>
      collection('config');

  // ── Helpers de conversão de timestamps ────────────────────────────────────

  /// Converte um campo do Firestore (Timestamp ou String) para DateTime.
  static DateTime? toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Converte um campo do Firestore para DateTime, usando [fallback] se nulo.
  static DateTime toDateTimeOrNow(dynamic value) {
    return toDateTime(value) ?? DateTime.now();
  }

  /// Converte um valor numérico do Firestore para double.
  static double toDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return fallback;
  }

  /// Converte um valor numérico do Firestore para int.
  static int toInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    return fallback;
  }

  /// Converte um valor para String segura.
  static String toStr(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    return value.toString();
  }
}
