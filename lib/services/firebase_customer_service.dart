// ===========================================================================
// firebase_customer_service.dart - ShareWallet
// ---------------------------------------------------------------------------
// Gerencia clientes no Firestore (coleção `customers/`).
// Clientes são quem COMPRA via link de afiliado — diferente de afiliados
// (que VENDEM e recebem comissão).
//
// Coleções Firestore:
//   customers/{uid}           — perfil do cliente
//   customer_products/{docId} — produtos comprados por clientes
//   customer_wallets/{uid}    — carteira do cliente
// ===========================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer_model.dart';
import 'firebase_auth_service.dart';

class FirebaseCustomerService {
  // ── Banco Firestore (mesmo banco dos afiliados) ──────────────────────────
  static const String _databaseId = 'affiliatewalletwallet';
  static FirebaseFirestore? _dbInstance;

  static FirebaseFirestore? _getDb() {
    if (_dbInstance != null) return _dbInstance;
    try {
      _dbInstance = FirebaseFirestore.instanceFor(
        app: FirebaseFirestore.instance.app,
        databaseId: _databaseId,
      );
      if (kIsWeb) {
        _dbInstance!.settings = const Settings(
          persistenceEnabled: false,
          webExperimentalForceLongPolling: true,
        );
      }
      return _dbInstance;
    } catch (_) {
      try {
        return FirebaseFirestore.instance;
      } catch (_) {
        return null;
      }
    }
  }

  // ── Detectar tipo de conta do usuário logado ─────────────────────────────

  /// Verifica se o uid existe em affiliates/ e/ou customers/.
  /// Retorna o tipo de conta para roteamento pós-login.
  static Future<UserAccountType> detectAccountType(String uid) async {
    final db = _getDb();
    if (db == null) return UserAccountType.unknown;

    try {
      final results = await Future.wait([
        db.collection('affiliates').doc(uid).get(),
        db.collection('customers').doc(uid).get(),
      ]).timeout(const Duration(seconds: 5));

      final isAffiliate = results[0].exists;
      final isCustomer  = results[1].exists;

      if (isAffiliate && isCustomer) return UserAccountType.both;
      if (isAffiliate) return UserAccountType.affiliate;
      if (isCustomer)  return UserAccountType.customer;
      return UserAccountType.unknown;
    } catch (e) {
      if (kDebugMode) debugPrint('[CustomerService] detectAccountType erro: $e');
      // Em caso de timeout, assume afiliado (comportamento seguro)
      return UserAccountType.affiliate;
    }
  }

  // ── Registro / busca do cliente ──────────────────────────────────────────

  /// Cria ou busca perfil do cliente no Firestore.
  /// [sponsorRef] pode ser um @username ou affiliateCode do afiliado indicador.
  static Future<({bool success, CustomerModel? customer, String? error})>
      buscarOuCriarCliente({
    required String uid,
    required String email,
    String? displayName,
    String? avatarUrl,
    String? sponsorRef,       // @username ou affiliateCode do afiliado
    String? provider,         // 'google' | 'facebook' | 'email'
  }) async {
    final db = _getDb();
    if (db == null) {
      return (success: false, customer: null, error: 'Serviço indisponível');
    }

    try {
      final docRef = db.collection('customers').doc(uid);
      final snap   = await docRef.get().timeout(const Duration(seconds: 6));

      if (snap.exists) {
        // Cliente já existe — carrega e retorna
        final data = snap.data()!;
        final customer = CustomerModel.fromJson({...data, 'id': uid});

        // Atualiza last_login e avatar em background
        docRef.set({
          'last_login': FieldValue.serverTimestamp(),
          if (avatarUrl != null && avatarUrl.isNotEmpty) 'avatar_url': avatarUrl,
        }, SetOptions(merge: true)).catchError((_) {});

        return (success: true, customer: customer, error: null);
      }

      // Novo cliente — resolve o afiliado sponsor
      String sponsorAffiliateId   = '';
      String sponsorUsername      = '';
      String sponsorAffiliateCode = '';
      String sponsorNome          = '';

      if (sponsorRef != null && sponsorRef.isNotEmpty) {
        final sponsorInfo = await _resolverSponsor(db, sponsorRef);
        sponsorAffiliateId   = sponsorInfo['id']   ?? '';
        sponsorUsername      = sponsorInfo['username'] ?? '';
        sponsorAffiliateCode = sponsorInfo['affiliate_code'] ?? '';
        sponsorNome          = sponsorInfo['nome']  ?? '';
      }

      final nome = displayName ?? email.split('@').first;
      final now  = FieldValue.serverTimestamp();

      final customerData = {
        'id': uid,
        'firebase_uid': uid,
        'nome': nome,
        'email': email,
        'telefone': '',
        'cpf': '',
        'avatar_url': avatarUrl ?? '',
        'provider': provider ?? 'email',
        'sponsor_affiliate_id':   sponsorAffiliateId,
        'sponsor_username':       sponsorUsername,
        'sponsor_affiliate_code': sponsorAffiliateCode,
        'sponsor_nome':           sponsorNome,
        'saldo_disponivel': 0.0,
        'saldo_pendente':   0.0,
        'total_gasto':      0.0,
        'total_produtos':   0,
        'status': 'ativo',
        'created_at':   now,
        'updated_at':   now,
        'last_login':   now,
        'pix_key':      email,
        'pix_key_type': 'EMAIL',
      };

      // Cria perfil + carteira em paralelo
      await Future.wait([
        docRef.set(customerData),
        _criarCarteiraCliente(db, uid: uid),
      ]);

      if (kDebugMode) {
        debugPrint('[CustomerService] Novo cliente criado: $uid (sponsor: $sponsorAffiliateId)');
      }

      final customer = CustomerModel(
        id: uid,
        nome: nome,
        email: email,
        avatarUrl: avatarUrl ?? '',
        sponsorAffiliateId: sponsorAffiliateId,
        sponsorUsername: sponsorUsername,
        sponsorAffiliateCode: sponsorAffiliateCode,
        sponsorNome: sponsorNome,
        createdAt: DateTime.now(),
      );

      return (success: true, customer: customer, error: null);
    } catch (e) {
      if (kDebugMode) debugPrint('[CustomerService] buscarOuCriar erro: $e');
      return (success: false, customer: null, error: 'Erro ao carregar perfil do cliente.');
    }
  }

  // ── Carregar cliente atual ────────────────────────────────────────────────

  static Future<CustomerModel?> carregarClienteAtual() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) return null;

      final db = _getDb();
      if (db == null) return null;

      final snap = await db
          .collection('customers')
          .doc(firebaseUser.uid)
          .get()
          .timeout(const Duration(seconds: 6));

      if (!snap.exists) return null;
      return CustomerModel.fromJson({...snap.data()!, 'id': firebaseUser.uid});
    } catch (e) {
      if (kDebugMode) debugPrint('[CustomerService] carregarClienteAtual erro: $e');
      return null;
    }
  }

  // ── Produtos do cliente ───────────────────────────────────────────────────

  static Future<List<CustomerProductModel>> listarProdutosDoCliente(
      String customerId) async {
    final db = _getDb();
    if (db == null) return [];

    try {
      final snap = await db
          .collection('customer_products')
          .where('customer_id', isEqualTo: customerId)
          .get()
          .timeout(const Duration(seconds: 8));

      final produtos = snap.docs
          .map((doc) =>
              CustomerProductModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      // Ordena por data (mais recente primeiro) em memória
      produtos.sort((a, b) => b.dataInicio.compareTo(a.dataInicio));
      return produtos;
    } catch (e) {
      if (kDebugMode) debugPrint('[CustomerService] listarProdutos erro: $e');
      return [];
    }
  }

  // ── Carteira do cliente ───────────────────────────────────────────────────

  static Future<Map<String, double>> carregarCarteiraCliente(
      String customerId) async {
    final db = _getDb();
    if (db == null) return {'saldo_disponivel': 0, 'saldo_pendente': 0};

    try {
      final snap = await db
          .collection('customer_wallets')
          .doc(customerId)
          .get()
          .timeout(const Duration(seconds: 5));

      if (!snap.exists) return {'saldo_disponivel': 0, 'saldo_pendente': 0};

      final data = snap.data()!;
      return {
        'saldo_disponivel': _toDouble(data['saldo_disponivel']),
        'saldo_pendente':   _toDouble(data['saldo_pendente']),
        'total_depositado': _toDouble(data['total_depositado']),
        'total_gasto':      _toDouble(data['total_gasto']),
      };
    } catch (e) {
      return {'saldo_disponivel': 0, 'saldo_pendente': 0};
    }
  }

  // ── Atualizar perfil do cliente ───────────────────────────────────────────

  static Future<bool> atualizarPerfilCliente({
    required String uid,
    String? nome,
    String? telefone,
    String? cpf,
    String? pixKey,
    String? pixKeyType,
  }) async {
    final db = _getDb();
    if (db == null) return false;

    try {
      final data = <String, dynamic>{
        'updated_at': FieldValue.serverTimestamp(),
      };
      if (nome != null && nome.isNotEmpty)     data['nome']         = nome;
      if (telefone != null)                    data['telefone']     = telefone;
      if (cpf != null)                         data['cpf']          = cpf;
      if (pixKey != null && pixKey.isNotEmpty) data['pix_key']      = pixKey;
      if (pixKeyType != null)                  data['pix_key_type'] = pixKeyType;

      await db
          .collection('customers')
          .doc(uid)
          .set(data, SetOptions(merge: true));
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[CustomerService] atualizarPerfil erro: $e');
      return false;
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  static Future<void> signOut() => FirebaseAuthService.signOut();

  // ── Helpers privados ─────────────────────────────────────────────────────

  /// Cria documento de carteira zerado para o novo cliente.
  static Future<void> _criarCarteiraCliente(
      FirebaseFirestore db, {required String uid}) async {
    try {
      final ref = db.collection('customer_wallets').doc(uid);
      final existing = await ref.get();
      if (existing.exists) return;

      await ref.set({
        'uid': uid,
        'customer_id': uid,
        'saldo_disponivel': 0.0,
        'saldo_pendente':   0.0,
        'total_depositado': 0.0,
        'total_gasto':      0.0,
        'status': 'ativo',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[CustomerService] criarCarteira erro: $e');
    }
  }

  /// Resolve o afiliado indicador a partir de @username ou affiliateCode.
  static Future<Map<String, String>> _resolverSponsor(
      FirebaseFirestore db, String ref) async {
    try {
      final limpo = ref.replaceFirst('@', '').trim();
      if (limpo.isEmpty) return {};

      // Tenta por username primeiro (mais novo)
      var snap = await db
          .collection('affiliates')
          .where('username', isEqualTo: limpo)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 4));

      if (snap.docs.isEmpty) {
        // Tenta por affiliate_code (legado)
        snap = await db
            .collection('affiliates')
            .where('affiliate_code', isEqualTo: limpo.toUpperCase())
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 4));
      }

      if (snap.docs.isEmpty) return {};

      final data = snap.docs.first.data();
      return {
        'id':             snap.docs.first.id,
        'username':       data['username']?.toString()       ?? '',
        'affiliate_code': data['affiliate_code']?.toString() ?? '',
        'nome':           data['nome']?.toString()           ?? '',
      };
    } catch (_) {
      return {};
    }
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}
