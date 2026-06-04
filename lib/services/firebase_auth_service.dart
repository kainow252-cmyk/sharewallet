// ═══════════════════════════════════════════════════════════════════════════════
// firebase_auth_service.dart — Affiliate Wallet
// ─────────────────────────────────────────────────────────────────────────────
// Gerencia autenticação Firebase com três provedores:
//   1. Email + Senha  (Firebase Auth nativo)
//   2. Google Sign-In (OAuth via Firebase)
//   3. Facebook Login (OAuth via Firebase — requer configuração no Meta)
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter/foundation.dart';

// ── Resultado padrão de autenticação ─────────────────────────────────────────

class FirebaseAuthResult {
  final bool success;
  final String? uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? idToken;   // Token Firebase para enviar ao backend NestJS
  final String? error;
  final FirebaseAuthProvider provider;

  const FirebaseAuthResult({
    required this.success,
    this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.idToken,
    this.error,
    this.provider = FirebaseAuthProvider.email,
  });

  factory FirebaseAuthResult.failure(String message,
      {FirebaseAuthProvider provider = FirebaseAuthProvider.email}) {
    return FirebaseAuthResult(
      success: false,
      error: message,
      provider: provider,
    );
  }
}

enum FirebaseAuthProvider { email, google, facebook }

// ── Serviço principal ─────────────────────────────────────────────────────────

class FirebaseAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // clientId necessário para Google Sign-In funcionar na Web
  // Tipo 3 = Web client do google-services.json
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '470218127330-d1tr5j60i6db3ui56jgdqhar039dilvh.apps.googleusercontent.com'
        : null,
    scopes: ['email', 'profile'],
  );

  // Usuário Firebase atual (pode ser null se não logado)
  static User? get currentUser => _auth.currentUser;

  // Stream de mudanças de autenticação (útil para ouvir login/logout em tempo real)
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Buscar ID Token do Firebase (para enviar ao backend NestJS) ──────────────

  static Future<String?> getIdToken({bool forceRefresh = false}) async {
    try {
      return await _auth.currentUser?.getIdToken(forceRefresh);
    } catch (e) {
      if (kDebugMode) debugPrint('[FirebaseAuth] Erro ao buscar ID Token: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 1. EMAIL + SENHA — Cadastro
  // ══════════════════════════════════════════════════════════════════════════════

  static Future<FirebaseAuthResult> createUserWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Atualiza o nome de exibição se fornecido
      if (displayName != null && displayName.isNotEmpty) {
        await credential.user?.updateDisplayName(displayName);
        await credential.user?.reload();
      }

      final idToken = await credential.user?.getIdToken();

      return FirebaseAuthResult(
        success: true,
        uid: credential.user?.uid,
        email: credential.user?.email,
        displayName: credential.user?.displayName ?? displayName,
        photoUrl: credential.user?.photoURL,
        idToken: idToken,
        provider: FirebaseAuthProvider.email,
      );
    } on FirebaseAuthException catch (e) {
      return FirebaseAuthResult.failure(
        _translateFirebaseError(e.code),
        provider: FirebaseAuthProvider.email,
      );
    } catch (e) {
      return FirebaseAuthResult.failure(
        'Erro inesperado ao criar conta. Tente novamente.',
        provider: FirebaseAuthProvider.email,
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 2. EMAIL + SENHA — Login
  // ══════════════════════════════════════════════════════════════════════════════

  static Future<FirebaseAuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final idToken = await credential.user?.getIdToken();

      return FirebaseAuthResult(
        success: true,
        uid: credential.user?.uid,
        email: credential.user?.email,
        displayName: credential.user?.displayName,
        photoUrl: credential.user?.photoURL,
        idToken: idToken,
        provider: FirebaseAuthProvider.email,
      );
    } on FirebaseAuthException catch (e) {
      return FirebaseAuthResult.failure(
        _translateFirebaseError(e.code),
        provider: FirebaseAuthProvider.email,
      );
    } catch (e) {
      return FirebaseAuthResult.failure(
        'Erro de conexão. Verifique sua internet.',
        provider: FirebaseAuthProvider.email,
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 3. GOOGLE SIGN-IN
  // ══════════════════════════════════════════════════════════════════════════════

  static Future<FirebaseAuthResult> signInWithGoogle() async {
    // Fluxo Web usa signInWithPopup; Mobile usa Google Sign-In nativo
    if (kIsWeb) {
      return await _signInWithGoogleWeb();
    } else {
      return await _signInWithGoogleMobile();
    }
  }

  static Future<FirebaseAuthResult> _signInWithGoogleMobile() async {
    // Abre o seletor de conta Google nativo
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

    if (googleUser == null) {
      // Usuário cancelou o fluxo
      return FirebaseAuthResult.failure(
        'Login com Google cancelado.',
        provider: FirebaseAuthProvider.google,
      );
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final idToken = await userCredential.user?.getIdToken();

    return FirebaseAuthResult(
      success: true,
      uid: userCredential.user?.uid,
      email: userCredential.user?.email,
      displayName: userCredential.user?.displayName,
      photoUrl: userCredential.user?.photoURL,
      idToken: idToken,
      provider: FirebaseAuthProvider.google,
    );
  }

  static Future<FirebaseAuthResult> _signInWithGoogleWeb() async {
    final GoogleAuthProvider googleProvider = GoogleAuthProvider();
    googleProvider.addScope('email');
    googleProvider.addScope('profile');

    try {
      final userCredential = await _auth.signInWithPopup(googleProvider);
      final idToken = await userCredential.user?.getIdToken();
      return FirebaseAuthResult(
        success: true,
        uid: userCredential.user?.uid,
        email: userCredential.user?.email,
        displayName: userCredential.user?.displayName,
        photoUrl: userCredential.user?.photoURL,
        idToken: idToken,
        provider: FirebaseAuthProvider.google,
      );
    } on FirebaseAuthException catch (e) {
      final code = e.code;
      final msg  = e.message?.toLowerCase() ?? '';

      if (code == 'popup-closed-by-user' || code == 'cancelled-popup-request') {
        return FirebaseAuthResult.failure(
          'Login com Google cancelado.',
          provider: FirebaseAuthProvider.google,
        );
      }

      if (code == 'unauthorized-domain' ||
          code == 'popup-blocked' ||
          msg.contains('domain') ||
          msg.contains('not authorized') ||
          msg.contains('origin')) {
        return FirebaseAuthResult.failure(
          'UNAUTHORIZED_DOMAIN',
          provider: FirebaseAuthProvider.google,
        );
      }

      return FirebaseAuthResult.failure(
        'FIREBASE_ERR:$code|${e.message ?? ''}',
        provider: FirebaseAuthProvider.google,
      );
    } catch (e) {
      final s = e.toString().toLowerCase();
      if (s.contains('domain') ||
          s.contains('unauthorized') ||
          s.contains('origin') ||
          s.contains('not authorized')) {
        return FirebaseAuthResult.failure(
          'UNAUTHORIZED_DOMAIN',
          provider: FirebaseAuthProvider.google,
        );
      }
      return FirebaseAuthResult.failure(
        'ERR:${e.toString()}',
        provider: FirebaseAuthProvider.google,
      );
    }
  }

  /// Verifica se há resultado pendente de redirect (chamar no initState da tela de login)
  static Future<FirebaseAuthResult?> getRedirectResult() async {
    try {
      final result = await _auth.getRedirectResult();
      if (result.user == null) return null;
      final idToken = await result.user?.getIdToken();
      return FirebaseAuthResult(
        success: true,
        uid: result.user?.uid,
        email: result.user?.email,
        displayName: result.user?.displayName,
        photoUrl: result.user?.photoURL,
        idToken: idToken,
        provider: FirebaseAuthProvider.google,
      );
    } catch (_) {
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 4. FACEBOOK / META LOGIN
  // ══════════════════════════════════════════════════════════════════════════════
  //
  // REQUISITO: Configurar no Meta for Developers:
  //   1. Acesse https://developers.facebook.com/
  //   2. Crie um app ou use existente
  //   3. Adicione o produto "Login do Facebook"
  //   4. Configure redirect URIs: https://SEU_PROJECT.firebaseapp.com/__/auth/handler
  //   5. Ative no Firebase Console → Authentication → Sign-in method → Facebook
  //   6. Insira App ID e App Secret do Meta
  // ════════════════════════════════════════════════════════════════════════════

  static Future<FirebaseAuthResult> signInWithFacebook() async {
    try {
      if (kIsWeb) {
        return await _signInWithFacebookWeb();
      } else {
        return await _signInWithFacebookMobile();
      }
    } catch (e) {
      return FirebaseAuthResult.failure(
        'Erro ao entrar com Facebook. Tente novamente.',
        provider: FirebaseAuthProvider.facebook,
      );
    }
  }

  static Future<FirebaseAuthResult> _signInWithFacebookMobile() async {
    // Abre o diálogo de login do Facebook nativo
    final LoginResult loginResult = await FacebookAuth.instance.login(
      permissions: ['email', 'public_profile'],
    );

    if (loginResult.status == LoginStatus.cancelled) {
      return FirebaseAuthResult.failure(
        'Login com Facebook cancelado.',
        provider: FirebaseAuthProvider.facebook,
      );
    }

    if (loginResult.status != LoginStatus.success ||
        loginResult.accessToken == null) {
      return FirebaseAuthResult.failure(
        loginResult.message ?? 'Erro ao autenticar com Facebook.',
        provider: FirebaseAuthProvider.facebook,
      );
    }

    // Troca o token do Facebook por credencial Firebase
    final OAuthCredential credential =
        FacebookAuthProvider.credential(loginResult.accessToken!.tokenString);

    final userCredential = await _auth.signInWithCredential(credential);
    final idToken = await userCredential.user?.getIdToken();

    return FirebaseAuthResult(
      success: true,
      uid: userCredential.user?.uid,
      email: userCredential.user?.email,
      displayName: userCredential.user?.displayName,
      photoUrl: userCredential.user?.photoURL,
      idToken: idToken,
      provider: FirebaseAuthProvider.facebook,
    );
  }

  static Future<FirebaseAuthResult> _signInWithFacebookWeb() async {
    // Usa signInWithPopup SEM nenhum scope adicional.
    // O Firebase Auth web chama o endpoint OAuth do Facebook diretamente
    // sem depender do FB JS SDK (que exige "Login com SDK do JavaScript" ativo).
    // O Facebook entrega public_profile por padrão; email chega quando
    // o app estiver em modo Live no Meta.
    final provider = FacebookAuthProvider();
    // NÃO adicionar nenhum scope — evita error_code=100 e independe do JS SDK

    try {
      final userCredential = await _auth.signInWithPopup(provider);
      final idToken = await userCredential.user?.getIdToken();

      return FirebaseAuthResult(
        success: true,
        uid: userCredential.user?.uid,
        email: userCredential.user?.email,
        displayName: userCredential.user?.displayName,
        photoUrl: userCredential.user?.photoURL,
        idToken: idToken,
        provider: FirebaseAuthProvider.facebook,
      );
    } on FirebaseAuthException catch (e) {
      final code = e.code;
      if (code == 'popup-closed-by-user' || code == 'cancelled-popup-request') {
        return FirebaseAuthResult.failure(
          'Login com Facebook cancelado.',
          provider: FirebaseAuthProvider.facebook,
        );
      }
      if (code == 'operation-not-allowed' ||
          (e.message?.toLowerCase().contains('not enabled') == true)) {
        return FirebaseAuthResult.failure(
          'FACEBOOK_NOT_CONFIGURED',
          provider: FirebaseAuthProvider.facebook,
        );
      }
      if (code == 'unauthorized-domain' ||
          (e.message?.toLowerCase().contains('domain') == true)) {
        return FirebaseAuthResult.failure(
          'FACEBOOK_DOMAIN_ERROR',
          provider: FirebaseAuthProvider.facebook,
        );
      }
      return FirebaseAuthResult.failure(
        'FACEBOOK_ERR:$code|${e.message ?? ''}',
        provider: FirebaseAuthProvider.facebook,
      );
    } catch (e) {
      final s = e.toString().toLowerCase();
      if (s.contains('popup') && s.contains('close')) {
        return FirebaseAuthResult.failure(
          'Login com Facebook cancelado.',
          provider: FirebaseAuthProvider.facebook,
        );
      }
      return FirebaseAuthResult.failure(
        'FACEBOOK_ERR:${e.toString()}',
        provider: FirebaseAuthProvider.facebook,
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 5. REDEFINIR SENHA
  // ══════════════════════════════════════════════════════════════════════════════

  static Future<FirebaseAuthResult> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return const FirebaseAuthResult(
        success: true,
        provider: FirebaseAuthProvider.email,
      );
    } on FirebaseAuthException catch (e) {
      return FirebaseAuthResult.failure(_translateFirebaseError(e.code));
    } catch (e) {
      return FirebaseAuthResult.failure('Erro ao enviar e-mail de redefinição.');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 6. LOGOUT (todos os provedores)
  // ══════════════════════════════════════════════════════════════════════════════

  static Future<void> signOut() async {
    try {
      // Faz logout do Google se estava logado
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
      // Faz logout do Facebook
      await FacebookAuth.instance.logOut();
      // Faz logout do Firebase
      await _auth.signOut();
    } catch (e) {
      if (kDebugMode) debugPrint('[FirebaseAuth] Erro no logout: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TRADUTOR DE ERROS FIREBASE → Português
  // ═══════════════════════════════════════════════════════════════════════════

  static String _translateFirebaseError(String code) {
    switch (code) {
      // Erros de login
      case 'user-not-found':
        return 'Nenhuma conta encontrada com este e-mail.';
      case 'wrong-password':
        return 'Senha incorreta. Tente novamente.';
      case 'invalid-credential':
        return 'E-mail ou senha inválidos.';
      case 'user-disabled':
        return 'Esta conta foi desativada. Entre em contato com o suporte.';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente em alguns minutos.';

      // Erros de cadastro
      case 'email-already-in-use':
        return 'Este e-mail já está cadastrado. Faça login ou use outro e-mail.';
      case 'invalid-email':
        return 'E-mail inválido. Verifique o formato.';
      case 'weak-password':
        return 'Senha muito fraca. Use pelo menos 6 caracteres.';
      case 'operation-not-allowed':
        return 'Este método de login não está habilitado. Contate o suporte.';

      // Erros de rede
      case 'network-request-failed':
        return 'Sem conexão com a internet. Verifique sua rede.';

      // Erros de conta social
      case 'account-exists-with-different-credential':
        return 'Já existe uma conta com este e-mail usando outro provedor.';
      case 'popup-closed-by-user':
        return 'Login cancelado. Tente novamente.';
      case 'cancelled-popup-request':
        return 'Login cancelado.';

      default:
        return 'Erro de autenticação ($code). Tente novamente.';
    }
  }
}
