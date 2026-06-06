// ═══════════════════════════════════════════════════════════════════════════
// firebase_user_service.dart — ShareWallet
// ───────────────────────────────────────────────────────────────────────────
// Gerencia registro, login e perfil de usuários com Firebase Auth + Firestore.
//
// Fluxo de REGISTRO:
//   1. Cria conta no Firebase Auth (email + senha)
//   2. Cria documento em affiliates/{uid}    ← perfil no Firestore
//   3. Cria documento em wallets/{uid}       ← carteira zerada automática
//   4. Cria registro no D1 (Worker)          ← visível no painel Admin
//
// Fluxo de LOGIN:
//   1. Autentica no Firebase Auth
//   2. Busca/atualiza perfil em affiliates/{uid}
//   3. Retorna UserModel com saldo real da carteira
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'firebase_auth_service.dart';
import 'cf_api_service.dart';

// ── Resultado de operações do serviço ────────────────────────────────────────

class UserServiceResult {
  final bool success;
  final UserModel? user;
  final String? error;
  final bool walletCreated;

  const UserServiceResult({
    required this.success,
    this.user,
    this.error,
    this.walletCreated = false,
  });

  factory UserServiceResult.failure(String msg) =>
      UserServiceResult(success: false, error: msg);
}

// ── Serviço principal ────────────────────────────────────────────────────────

class FirebaseUserService {
  // ── Registrar novo afiliado ─────────────────────────────────────────────

  /// Cria conta Firebase + perfil Firestore + carteira zerada.
  static Future<UserServiceResult> register({
    required String nome,
    required String email,
    required String senha,
    required String cpf,
    required String telefone,
    String? sponsorCode,
    String pixKey = '',
    String pixKeyType = 'EMAIL',
  }) async {
    try {
      // 1. Criar conta no Firebase Auth
      final authResult = await FirebaseAuthService.createUserWithEmail(
        email: email,
        password: senha,
        displayName: nome,
      );

      if (!authResult.success || authResult.uid == null) {
        return UserServiceResult.failure(
            authResult.error ?? 'Erro ao criar conta');
      }

      final uid = authResult.uid!;
      final affiliateCode = _gerarCodigo(nome);
      final pixFinal = pixKey.isNotEmpty ? pixKey : email;
      final now = DateTime.now();

    final db = _getDb();
    if (db == null) {
        // Firebase não disponível — retorna usuário local sem Firestore
        return UserServiceResult(
          success: true,
          walletCreated: false,
          user: UserModel(
            id: uid,
            nome: nome,
            cpf: cpf,
            email: email,
            telefone: telefone,
            affiliateCode: affiliateCode,
            sponsorId: sponsorCode,
            saldo: 0.0,
            createdAt: now,
          ),
        );
      }

      // 2. Resolver sponsorId a partir do sponsorCode
      String? sponsorId;
      if (sponsorCode != null && sponsorCode.isNotEmpty) {
        sponsorId = await _buscarSponsorId(db, sponsorCode);
      }

      // 3. Criar perfil do afiliado em affiliates/{uid}
      final affiliateData = {
        'uid': uid,
        'firebase_uid': uid,
        'nome': nome,
        'email': email,
        'cpf': cpf,
        'telefone': telefone,
        'affiliate_code': affiliateCode,
        'sponsor_id': sponsorId,
        'sponsor_code': sponsorCode,
        'pix_key': pixFinal,
        'pix_key_type': pixKeyType,
        'saldo': 0.0,
        'saldo_disponivel': 0.0,
        'saldo_pendente': 0.0,
        'total_recebido': 0.0,
        'total_sacado': 0.0,
        'total_referrals': 0,
        'total_sales': 0,
        'status': 'ativo',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      await db.collection('affiliates').doc(uid).set(affiliateData);

      // 4. Criar carteira em wallets/{uid} — zerada, pronta para receber
      await _criarCarteira(db, uid: uid, affiliateCode: affiliateCode);

      // 5. Incrementar contador no afiliado sponsor (se houver)
      if (sponsorId != null) {
        await _incrementarReferral(db, sponsorId);
      }

      // 6. Sincronizar no D1 (Cloudflare Worker) — necessário para o painel Admin
      await _sincronizarD1(
        uid: uid,
        nome: nome,
        email: email,
        cpf: cpf,
        telefone: telefone,
        affiliateCode: affiliateCode,
        sponsorCode: sponsorCode,
        pixKey: pixFinal,
        pixKeyType: pixKeyType,
      );

      if (kDebugMode) {
        debugPrint('[FirebaseUserService] ✅ Registro completo:');
        debugPrint('  uid: $uid');
        debugPrint('  code: $affiliateCode');
        debugPrint('  sponsor: $sponsorId');
      }

      return UserServiceResult(
        success: true,
        walletCreated: true,
        user: UserModel(
          id: uid,
          nome: nome,
          cpf: cpf,
          email: email,
          telefone: telefone,
          affiliateCode: affiliateCode,
          sponsorId: sponsorId,
          saldo: 0.0,
          createdAt: now,
        ),
      );
    } on FirebaseAuthException catch (e) {
      return UserServiceResult.failure(_traduzirErro(e.code));
    } catch (e) {
      if (kDebugMode) debugPrint('[FirebaseUserService] Erro registro: $e');
      return UserServiceResult.failure('Erro inesperado. Tente novamente.');
    }
  }

  // ── Login de afiliado existente ─────────────────────────────────────────

  /// Autentica no Firebase Auth e busca perfil + saldo no Firestore.
  static Future<UserServiceResult> login({
    required String email,
    required String senha,
  }) async {
    try {
      // 1. Autenticar no Firebase
      final authResult = await FirebaseAuthService.signInWithEmail(
        email: email,
        password: senha,
      );

      if (!authResult.success || authResult.uid == null) {
        return UserServiceResult.failure(
            authResult.error ?? 'E-mail ou senha inválidos');
      }

      final uid = authResult.uid!;

      // 2. Buscar perfil no Firestore
      final user = await _buscarOuCriarPerfil(
        uid: uid,
        email: email,
        displayName: authResult.displayName,
      );

      return UserServiceResult(success: true, user: user);
    } on FirebaseAuthException catch (e) {
      return UserServiceResult.failure(_traduzirErro(e.code));
    } catch (e) {
      if (kDebugMode) debugPrint('[FirebaseUserService] Erro login: $e');
      return UserServiceResult.failure('Erro de conexão. Verifique sua internet.');
    }
  }

  // ── Login via Google / Facebook (social) ───────────────────────────────

  /// Processa login social — cria perfil se for primeiro acesso.
  static Future<UserServiceResult> loginSocial({
    required FirebaseAuthResult authResult,
  }) async {
    if (!authResult.success || authResult.uid == null) {
      return UserServiceResult.failure(
          authResult.error ?? 'Erro na autenticação social');
    }

    final uid = authResult.uid!;

    try {
      final user = await _buscarOuCriarPerfil(
        uid: uid,
        email: authResult.email ?? '',
        displayName: authResult.displayName,
        isNewUser: false,
      );

      return UserServiceResult(success: true, user: user);
    } catch (e) {
      if (kDebugMode) debugPrint('[FirebaseUserService] Erro loginSocial: $e');
      return UserServiceResult.failure('Erro ao carregar perfil.');
    }
  }

  // ── Buscar perfil do usuário atual ─────────────────────────────────────

  /// Verifica Firebase Auth atual e carrega dados do Firestore.
  static Future<UserModel?> carregarUsuarioAtual() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) return null;

      return await _buscarOuCriarPerfil(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FirebaseUserService] Erro ao carregar usuário: $e');
      }
      return null;
    }
  }

  // ── Atualizar saldo local no Firestore ─────────────────────────────────

  /// Atualiza dados do perfil do afiliado no Firestore.
  static Future<void> atualizarPerfil({
    required String uid,
    required String nome,
    required String telefone,
    required String cpf,
    required String pixKey,
  }) async {
    try {
      final db = _getDb();
      if (db == null) return;

      await db.collection('affiliates').doc(uid).update({
        'nome': nome,
        'telefone': telefone,
        'cpf': cpf,
        'pix_key': pixKey,
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) debugPrint('[FirebaseUserService] ✅ Perfil atualizado: $uid');
    } catch (e) {
      if (kDebugMode) debugPrint('[FirebaseUserService] Erro atualizarPerfil: $e');
      rethrow;
    }
  }

  /// Atualiza saldo disponível na carteira do usuário.
  static Future<void> atualizarSaldo(String uid, double novoSaldo) async {
    try {
      final db = _getDb();
      if (db == null) return;

      await Future.wait([
        db.collection('wallets').doc(uid).update({
          'saldo_disponivel': novoSaldo,
          'updated_at': FieldValue.serverTimestamp(),
        }),
        db.collection('affiliates').doc(uid).update({
          'saldo': novoSaldo,
          'updated_at': FieldValue.serverTimestamp(),
        }),
      ]);
    } catch (e) {
      if (kDebugMode) debugPrint('[FirebaseUserService] Erro atualizarSaldo: $e');
    }
  }

  // ── Logout ──────────────────────────────────────────────────────────────

  static Future<void> signOut() => FirebaseAuthService.signOut();

  // ── Helpers privados ────────────────────────────────────────────────────

  /// Busca perfil no Firestore. Se não existir, cria automaticamente.
  static Future<UserModel> _buscarOuCriarPerfil({
    required String uid,
    required String email,
    String? displayName,
    bool isNewUser = false,
  }) async {
    final db = _getDb();
    final fallback = UserModel(
      id: uid,
      nome: displayName ?? email.split('@').first,
      cpf: '',
      email: email,
      telefone: '',
      affiliateCode: _gerarCodigo(displayName ?? uid),
      saldo: 0.0,
      createdAt: DateTime.now(),
    );

    if (db == null) return fallback;

    try {
      // Buscar perfil do afiliado
      final affiliateDoc = await db.collection('affiliates').doc(uid).get();
      final walletDoc = await db.collection('wallets').doc(uid).get();

      // Se perfil não existe, criar automaticamente (primeiro login social)
      if (!affiliateDoc.exists) {
        final code = _gerarCodigo(displayName ?? uid);
        final now = FieldValue.serverTimestamp();

        await db.collection('affiliates').doc(uid).set({
          'uid': uid,
          'firebase_uid': uid,
          'nome': displayName ?? email.split('@').first,
          'email': email,
          'cpf': '',
          'telefone': '',
          'affiliate_code': code,
          'pix_key': email,
          'pix_key_type': 'EMAIL',
          'saldo': 0.0,
          'total_referrals': 0,
          'total_sales': 0,
          'status': 'ativo',
          'created_at': now,
          'updated_at': now,
        });

        await _criarCarteira(db, uid: uid, affiliateCode: code);

        return UserModel(
          id: uid,
          nome: displayName ?? email.split('@').first,
          cpf: '',
          email: email,
          telefone: '',
          affiliateCode: code,
          saldo: 0.0,
          createdAt: DateTime.now(),
        );
      }

      // Perfil existe — montar UserModel com dados reais
      final aData = affiliateDoc.data()!;
      final saldoDisponivel = walletDoc.exists
          ? _toDouble(walletDoc.data()?['saldo_disponivel'])
          : _toDouble(aData['saldo']);

      // Atualizar last_login
      db.collection('affiliates').doc(uid).update({
        'last_login': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }).catchError((_) {});

      final affiliateCode = _toStr(aData['affiliate_code'], fallback: _gerarCodigo(uid));

      // Sincronizar com D1 em background (sem bloquear o login)
      // Garante que afiliados antigos também apareçam no Admin
      _sincronizarD1(
        uid: uid,
        nome: _toStr(aData['nome'], fallback: displayName ?? email.split('@').first),
        email: email,
        cpf: _toStr(aData['cpf']),
        telefone: _toStr(aData['telefone']),
        affiliateCode: affiliateCode,
        sponsorCode: aData['sponsor_code']?.toString(),
        pixKey: _toStr(aData['pix_key'], fallback: email),
        pixKeyType: _toStr(aData['pix_key_type'], fallback: 'EMAIL'),
      ).catchError((_) {});

      return UserModel(
        id: uid,
        nome: _toStr(aData['nome'],
            fallback: displayName ?? email.split('@').first),
        cpf: _toStr(aData['cpf']),
        email: email,
        telefone: _toStr(aData['telefone']),
        affiliateCode: affiliateCode,
        sponsorId: aData['sponsor_id']?.toString(),
        saldo: saldoDisponivel,
        status: _toStr(aData['status'], fallback: 'ativo'),
        createdAt: _toDateTimeOrNow(aData['created_at']),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FirebaseUserService] Erro ao buscar perfil: $e');
      }
      return fallback;
    }
  }

  /// Cria o documento de carteira zerado em wallets/{uid}.
  static Future<void> _criarCarteira(
    FirebaseFirestore db, {
    required String uid,
    required String affiliateCode,
  }) async {
    try {
      final walletRef = db.collection('wallets').doc(uid);
      final existing = await walletRef.get();
      if (existing.exists) return; // já existe, não sobrescrever

      await walletRef.set({
        'uid': uid,
        'affiliate_id': uid,
        'affiliate_code': affiliateCode,
        'saldo_disponivel': 0.0,
        'saldo_pendente': 0.0,
        'total_recebido': 0.0,
        'total_sacado': 0.0,
        'total_comissoes': 0.0,
        'total_vendas': 0,
        'pix_key': '',
        'pix_key_type': 'EMAIL',
        'status': 'ativo',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        debugPrint('[FirebaseUserService] ✅ Carteira criada: wallets/$uid');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FirebaseUserService] Erro ao criar carteira: $e');
      }
    }
  }

  /// Busca o UID do afiliado sponsor pelo código de indicação.
  static Future<String?> _buscarSponsorId(
      FirebaseFirestore db, String code) async {
    try {
      final snap = await db
          .collection('affiliates')
          .where('affiliate_code', isEqualTo: code.toUpperCase())
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) return snap.docs.first.id;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Incrementa total_referrals do afiliado sponsor.
  static Future<void> _incrementarReferral(
      FirebaseFirestore db, String sponsorId) async {
    try {
      await db.collection('affiliates').doc(sponsorId).update({
        'total_referrals': FieldValue.increment(1),
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Sincroniza o afiliado no banco D1 do Cloudflare Worker.
  /// Isso torna o usuário visível no painel Admin (que lê do D1).
  static Future<void> _sincronizarD1({
    required String uid,
    required String nome,
    required String email,
    required String cpf,
    required String telefone,
    required String affiliateCode,
    String? sponsorCode,
    String pixKey = '',
    String pixKeyType = 'EMAIL',
  }) async {
    try {
      // Verifica se já existe no D1 pelo email
      final existing = await CfApiService.getAffiliateByEmail(email);
      if (existing != null) {
        if (kDebugMode) debugPrint('[FirebaseUserService] D1: afiliado já existe ($email)');
        return;
      }

      // Cria no D1
      final result = await CfApiService.createAffiliate({
        'id': uid,
        'nome': nome,
        'email': email,
        'cpf': cpf,
        'telefone': telefone,
        'affiliate_code': affiliateCode,
        'sponsor_code': sponsorCode,
        'pix_key': pixKey.isNotEmpty ? pixKey : email,
        'pix_key_type': pixKeyType,
        'status': 'ativo',
        'saldo_disponivel': 0.0,
        'saldo_pendente': 0.0,
        'total_comissoes': 0.0,
        'total_sacado': 0.0,
        'total_indicados': 0,
        'total_assinaturas': 0,
      });

      if (kDebugMode) {
        if (result != null) {
          debugPrint('[FirebaseUserService] ✅ D1 sincronizado: $affiliateCode');
        } else {
          debugPrint('[FirebaseUserService] ⚠️ D1 falhou (será reprocessado no login)');
        }
      }
    } catch (e) {
      // Não bloqueia o cadastro se o D1 falhar
      if (kDebugMode) debugPrint('[FirebaseUserService] Erro D1: $e');
    }
  }

  /// Gera código de 6 caracteres baseado no nome/uid.
  static String _gerarCodigo(String seed) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final clean = seed.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final buffer = StringBuffer();
    for (int i = 0; i < 6; i++) {
      final idx = (clean.isEmpty ? i * 13 : clean.codeUnitAt(i % clean.length))
          + i * 7;
      buffer.write(chars[idx % chars.length]);
    }
    return buffer.toString();
  }

  // ── Helpers inline (substitui FirestoreService helpers) ────────────────

  static const String _databaseId = 'affiliatewalletwallet';
  static FirebaseFirestore? _dbInstance;

  static FirebaseFirestore? _getDb() {
    if (_dbInstance != null) return _dbInstance;
    try {
      _dbInstance = FirebaseFirestore.instanceFor(
        app: FirebaseFirestore.instance.app,
        databaseId: _databaseId,
      );
      _dbInstance!.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      return _dbInstance;
    } catch (_) {
      try {
        return FirebaseFirestore.instance;
      } catch (_) {
        return null;
      }
    }
  }

  static double _toDouble(dynamic v) =>
      (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;

  static String _toStr(dynamic v, {String fallback = ''}) =>
      v?.toString().isNotEmpty == true ? v.toString() : fallback;

  static DateTime _toDateTimeOrNow(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is Timestamp) return v.toDate();
    return DateTime.tryParse(v.toString()) ?? DateTime.now();
  }

  /// Traduz erros Firebase para português.
  static String _traduzirErro(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Nenhuma conta encontrada com este e-mail.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha inválidos.';
      case 'email-already-in-use':
        return 'Este e-mail já está cadastrado. Faça login.';
      case 'weak-password':
        return 'Senha muito fraca. Use pelo menos 6 caracteres.';
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde alguns minutos.';
      case 'network-request-failed':
        return 'Sem conexão. Verifique sua internet.';
      default:
        return 'Erro de autenticação ($code).';
    }
  }
}
