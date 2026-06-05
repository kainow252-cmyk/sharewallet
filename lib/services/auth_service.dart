import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'firebase_user_service.dart';
import 'firebase_auth_service.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;
  String? get error => _error;

  // ── Inicialização: restaura sessão Firebase ──────────────────────────────

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Tenta restaurar sessão Firebase (persiste entre aberturas)
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        if (kDebugMode) {
          debugPrint('[AuthService] Sessão Firebase: ${firebaseUser.email}');
        }
        final user = await FirebaseUserService.carregarUsuarioAtual();
        if (user != null) {
          _currentUser = user;
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

      // 2. Fallback: token local (compatibilidade com modo API)
      await ApiService.loadToken();
      if (ApiService.hasToken && !_isFirebaseMode) {
        final response = await ApiService.get('/auth/me');
        if (response.success && response.data != null) {
          _currentUser =
              UserModel.fromJson(response.data as Map<String, dynamic>);
        } else {
          await ApiService.clearToken();
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AuthService] Erro init: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Login ────────────────────────────────────────────────────────────────

  Future<bool> login(String email, String senha) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Modo Firebase (padrão quando Firebase está disponível)
      if (_isFirebaseMode) {
        final result = await FirebaseUserService.login(
          email: email,
          senha: senha,
        );

        if (result.success && result.user != null) {
          _currentUser = result.user;
          await _saveLocalFlag();
          _isLoading = false;
          notifyListeners();
          return true;
        } else {
          _error = result.error ?? 'E-mail ou senha inválidos';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      // Fallback: modo demo local
      await Future.delayed(const Duration(milliseconds: 1000));
      if (email.isNotEmpty && senha.length >= 6) {
        _currentUser = _mockUser.copyWith(email: email);
        await _saveLocalFlag();
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error = 'E-mail ou senha inválidos';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Erro de conexão. Verifique sua internet.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Cadastro ──────────────────────────────────────────────────────────────

  Future<RegisterResult> register({
    required String nome,
    required String cpf,
    required String email,
    required String telefone,
    required String senha,
    required String pixKey,
    required String pixKeyType,
    String? sponsorCode,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_isFirebaseMode) {
        final result = await FirebaseUserService.register(
          nome: nome,
          email: email,
          senha: senha,
          cpf: cpf,
          telefone: telefone,
          sponsorCode: sponsorCode,
          pixKey: pixKey,
          pixKeyType: pixKeyType,
        );

        if (result.success && result.user != null) {
          _currentUser = result.user;
          await _saveLocalFlag();
          _isLoading = false;
          notifyListeners();
          return RegisterResult(
            success: true,
            walletCreated: result.walletCreated,
            message: result.walletCreated
                ? '✅ Conta e carteira criadas com sucesso!'
                : '✅ Conta criada! Carteira será criada em instantes.',
          );
        } else {
          _error = result.error ?? 'Erro ao criar conta';
          _isLoading = false;
          notifyListeners();
          return RegisterResult(success: false, message: _error!);
        }
      }

      // Fallback: modo demo
      await Future.delayed(const Duration(milliseconds: 1500));
      final novoUsuario = UserModel(
        id: 'u_${DateTime.now().millisecondsSinceEpoch}',
        nome: nome,
        cpf: cpf,
        email: email,
        telefone: telefone,
        affiliateCode: _gerarCodigo(nome),
        sponsorId: sponsorCode,
        saldo: 0.0,
        createdAt: DateTime.now(),
      );
      _currentUser = novoUsuario;
      await _saveLocalFlag();
      _isLoading = false;
      notifyListeners();
      return RegisterResult(
        success: true,
        walletCreated: false,
        message: 'Cadastro realizado (modo demonstração)',
      );
    } catch (e) {
      _error = 'Erro inesperado. Tente novamente.';
      _isLoading = false;
      notifyListeners();
      return RegisterResult(success: false, message: _error!);
    }
  }

  // ── Login Social (Google / Facebook) ─────────────────────────────────────

  Future<bool> loginWithFirebase({
    required String uid,
    required String email,
    String? displayName,
    String? idToken,
    String? provider,
    String? sponsorCode,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Busca/cria perfil no Firestore
      final authResult = FirebaseAuthResult(
        success: true,
        uid: uid,
        email: email,
        displayName: displayName,
        idToken: idToken,
      );

      final result = await FirebaseUserService.loginSocial(
        authResult: authResult,
      );

      if (result.success && result.user != null) {
        _currentUser = result.user;
        await _saveLocalFlag();
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error = result.error ?? 'Erro ao autenticar';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Erro de conexão.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    _currentUser = null;
    await ApiService.clearToken();
    await FirebaseUserService.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    notifyListeners();
  }

  // ── Atualizar saldo local ─────────────────────────────────────────────────

  void updateSaldo(double novoSaldo) {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(saldo: novoSaldo);
      // Persistir no Firestore também
      FirebaseUserService.atualizarSaldo(_currentUser!.id, novoSaldo)
          .catchError((_) {});
      notifyListeners();
    }
  }

  // ── Recarregar perfil ─────────────────────────────────────────────────────

  Future<void> refreshProfile() async {
    try {
      final user = await FirebaseUserService.carregarUsuarioAtual();
      if (user != null) {
        _currentUser = user;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AuthService] Erro refreshProfile: $e');
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Helpers privados ──────────────────────────────────────────────────────

  /// Firebase disponível quando o app está configurado com google-services.json.
  static bool get _isFirebaseMode {
    try {
      return FirebaseAuth.instance.app.options.projectId.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveLocalFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
  }

  String _gerarCodigo(String seed) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final clean = seed.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final buffer = StringBuffer();
    for (int i = 0; i < 6; i++) {
      final idx =
          (clean.isEmpty ? i * 13 : clean.codeUnitAt(i % clean.length)) +
              i * 7;
      buffer.write(chars[idx % chars.length]);
    }
    return buffer.toString();
  }

  static final UserModel _mockUser = UserModel(
    id: 'u001',
    nome: 'João Silva',
    cpf: '123.456.789-00',
    email: 'joao.silva@email.com',
    telefone: '(11) 99999-9999',
    affiliateCode: 'ABC123',
    saldo: 125.50,
    status: 'ativo',
    createdAt: DateTime.now().subtract(const Duration(days: 90)),
  );
}

// ── Resultado do cadastro ─────────────────────────────────────────────────────

class RegisterResult {
  final bool success;
  final bool walletCreated;
  final String message;

  RegisterResult({
    required this.success,
    this.walletCreated = false,
    required this.message,
  });
}
