import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Serviço base de acesso ao Firestore.
///
/// Usa o banco customizado [_databaseId] = 'affiliatewalletwallet'.
/// Como o banco NÃO é o '(default)', precisamos instanciar com
/// [FirebaseFirestore.instanceFor(app:, databaseId:)]
class FirestoreService {
  static const String _databaseId = 'affiliatewalletwallet';

  /// Timeout padrão para todas as queries — evita spinner infinito em 3G/4G fraco
  static const Duration kQueryTimeout = Duration(seconds: 8);

  static FirebaseFirestore? _instance;

  static FirebaseFirestore? get db {
    if (_instance != null) return _instance;

    try {
      if (Firebase.apps.isEmpty) {
        debugPrint('[FirestoreService] Firebase não inicializado — modo demo');
        return null;
      }

      _instance = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: _databaseId,
      );

      // Habilita cache offline — próximas visitas carregam do cache instantaneamente
      _instance!.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      if (kDebugMode) {
        debugPrint('[FirestoreService] Conectado ao banco: $_databaseId (cache offline ON)');
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

  // ── Helpers de query com timeout ──────────────────────────────────────────

  /// Executa um get() com timeout — evita spinner infinito em rede lenta.
  /// Tenta cache primeiro (instantâneo), depois rede.
  static Future<QuerySnapshot<Map<String, dynamic>>?> getWithTimeout(
    Query<Map<String, dynamic>>? query, {
    Duration timeout = kQueryTimeout,
  }) async {
    if (query == null) return null;
    try {
      // 1. Tenta cache local primeiro (instantâneo)
      try {
        final cached = await query
            .get(const GetOptions(source: Source.cache))
            .timeout(const Duration(seconds: 1));
        if (cached.docs.isNotEmpty) return cached;
      } catch (_) {
        // Cache vazio ou expirado — vai para rede
      }
      // 2. Busca na rede com timeout
      return await query.get().timeout(timeout);
    } on Exception catch (e) {
      debugPrint('[FirestoreService] Timeout/erro em query: $e');
      return null;
    }
  }

  /// Executa um docGet() com timeout.
  static Future<DocumentSnapshot<Map<String, dynamic>>?> docGetWithTimeout(
    DocumentReference<Map<String, dynamic>>? ref, {
    Duration timeout = kQueryTimeout,
  }) async {
    if (ref == null) return null;
    try {
      // 1. Cache primeiro
      try {
        final cached = await ref
            .get(const GetOptions(source: Source.cache))
            .timeout(const Duration(seconds: 1));
        if (cached.exists) return cached;
      } catch (_) {}
      // 2. Rede com timeout
      return await ref.get().timeout(timeout);
    } on Exception catch (e) {
      debugPrint('[FirestoreService] Timeout/erro em doc: $e');
      return null;
    }
  }

  // ── Helpers de conversão ──────────────────────────────────────────────────

  static DateTime? toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static DateTime toDateTimeOrNow(dynamic value) {
    return toDateTime(value) ?? DateTime.now();
  }

  static double toDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return fallback;
  }

  static int toInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    return fallback;
  }

  static String toStr(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    return value.toString();
  }
}
