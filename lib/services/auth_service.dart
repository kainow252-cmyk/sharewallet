import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;
  String? get error => _error;

  // ── Modo demonstração (sem backend) ───────────────────────────────────────
  // Quando BACKEND_URL não está configurado, usa dados mock locais
  static bool get _isDemoMode {
    const backendUrl = String.fromEnvironment('BACKEND_URL', defaultValue: '');
    return backendUrl.isEmpty;
  }

  static final UserModel _mockUser = UserModel(
    id: 'u001',
    nome: 'João Silva',
    cpf: '123.456.789-00',
    email: 'joao.silva@email.com',
    telefone: '(11) 99999-9999',
    affiliateCode: 'ABC123',
    wooviSubaccountId: 'sub_123abc',
    saldo: 125.50,
    status: 'ativo',
    createdAt: DateTime.now().subtract(const Duration(days: 90)),
  );

  // ── Inicialização ─────────────────────────────────────────────────────────

  Future<void> init() async {
    await ApiService.loadToken();

    if (ApiService.hasToken) {
      if (_isDemoMode) {
        // Modo demo: carrega usuário mock
        _currentUser = _mockUser;
        notifyListeners();
        return;
      }

      // Modo real: valida token com o backend
      final response = await ApiService.get('/auth/me');
      if (response.success && response.data != null) {
        _currentUser = UserModel.fromJson(response.data as Map<String, dynamic>);
        notifyListeners();
      } else {
        // Token inválido/expirado → limpa sessão
        await ApiService.clearToken();
      }
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────────

  Future<bool> login(String email, String senha) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_isDemoMode) {
        // Modo demo — aceita qualquer email + senha >= 6 chars
        await Future.delayed(const Duration(milliseconds: 1200));
        if (email.isNotEmpty && senha.length >= 6) {
          _currentUser = _mockUser.copyWith(email: email);
          await _saveLocalSession();
          _isLoading = false;
          notifyListeners();
          return true;
        }
        _error = 'Email ou senha inválidos';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Modo real — chama o backend
      final response = await ApiService.post('/auth/login', {
        'email': email,
        'senha': senha,
      });

      if (response.success && response.data != null) {
        final token = response.data['token'] as String;
        await ApiService.setToken(token);
        _currentUser = UserModel.fromJson(
          response.data['user'] as Map<String, dynamic>,
        );
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response.errorMessage ?? 'Email ou senha incorretos';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Erro de conexão. Tente novamente.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Cadastro ──────────────────────────────────────────────────────────────

  /// Cria conta do afiliado.
  /// Em modo real: backend cria subconta Woovi automaticamente.
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
      if (_isDemoMode) {
        // Modo demo
        await Future.delayed(const Duration(milliseconds: 2000));
        final novoUsuario = UserModel(
          id: 'u_${DateTime.now().millisecondsSinceEpoch}',
          nome: nome,
          cpf: cpf,
          email: email,
          telefone: telefone,
          affiliateCode: _gerarCodigoAfiliado(),
          sponsorId: sponsorCode,
          wooviSubaccountId: 'sub_demo_${DateTime.now().millisecondsSinceEpoch}',
          saldo: 0.0,
          createdAt: DateTime.now(),
        );
        _currentUser = novoUsuario;
        await _saveLocalSession();
        _isLoading = false;
        notifyListeners();
        return RegisterResult(
          success: true,
          wooviSubaccountCreated: false,
          message: 'Cadastro realizado (modo demonstração)',
        );
      }

      // Modo real — chama o backend
      final response = await ApiService.post('/auth/register', {
        'nome': nome,
        'cpf': cpf,
        'email': email,
        'telefone': telefone,
        'senha': senha,
        'pixKey': pixKey,
        'pixKeyType': pixKeyType,
        if (sponsorCode != null && sponsorCode.isNotEmpty)
          'sponsorCode': sponsorCode,
      });

      if (response.success && response.data != null) {
        final token = response.data['token'] as String;
        await ApiService.setToken(token);
        _currentUser = UserModel.fromJson(
          response.data['user'] as Map<String, dynamic>,
        );
        final wooviCreated = response.data['wooviSubaccountCreated'] as bool? ?? false;
        _isLoading = false;
        notifyListeners();
        return RegisterResult(
          success: true,
          wooviSubaccountCreated: wooviCreated,
          message: wooviCreated
              ? 'Conta e subconta Woovi criadas com sucesso!'
              : 'Conta criada! Subconta PIX será criada em instantes.',
        );
      } else {
        _error = response.errorMessage ?? 'Erro ao criar conta';
        _isLoading = false;
        notifyListeners();
        return RegisterResult(
          success: false,
          message: _error!,
        );
      }
    } catch (e) {
      _error = 'Erro de conexão. Verifique sua internet.';
      _isLoading = false;
      notifyListeners();
      return RegisterResult(success: false, message: _error!);
    }
  }

  // ── Login via Firebase Social (Google / Facebook) ─────────────────────────
  //
  // Fluxo:
  //  1. FirebaseAuthService já autenticou o usuário com Google/Facebook
  //  2. Recebemos uid + email + displayName + idToken do Firebase
  //  3. Enviamos para o backend NestJS → POST /auth/firebase
  //  4. Backend cria/busca afiliado pelo firebaseUid e retorna JWT
  //  5. Em modo demo, cria usuário mock local
  //
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
      if (_isDemoMode) {
        // Modo demo — cria usuário social mock
        await Future.delayed(const Duration(milliseconds: 800));
        final nomePartes = (displayName ?? 'Usuário Social').split(' ');
        _currentUser = _mockUser.copyWith(
          email: email,
          nome: displayName ?? 'Usuário Social',
          affiliateCode: 'SOC${nomePartes.first.toUpperCase().substring(0, 3)}',
        );
        await _saveLocalSession();
        _isLoading = false;
        notifyListeners();
        return true;
      }

      // Modo real — envia Firebase UID + idToken para o backend
      final response = await ApiService.post('/auth/firebase', {
        'firebaseUid': uid,
        'email': email,
        if (displayName != null) 'displayName': displayName,
        if (idToken != null) 'idToken': idToken,
        if (provider != null) 'provider': provider,
        if (sponsorCode != null && sponsorCode.isNotEmpty)
          'sponsorCode': sponsorCode,
      });

      if (response.success && response.data != null) {
        final token = response.data['token'] as String;
        await ApiService.setToken(token);
        _currentUser = UserModel.fromJson(
          response.data['user'] as Map<String, dynamic>,
        );
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response.errorMessage ?? 'Erro ao autenticar com rede social';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Erro de conexão. Verifique sua internet.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    _currentUser = null;
    await ApiService.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    notifyListeners();
  }

  // ── Atualizar saldo local ─────────────────────────────────────────────────

  void updateSaldo(double novoSaldo) {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(saldo: novoSaldo);
      notifyListeners();
    }
  }

  // ── Recarregar perfil do servidor ─────────────────────────────────────────

  Future<void> refreshProfile() async {
    if (_isDemoMode) return;
    final response = await ApiService.get('/auth/me');
    if (response.success && response.data != null) {
      _currentUser = UserModel.fromJson(response.data as Map<String, dynamic>);
      notifyListeners();
    }
  }

  // ── Helpers privados ──────────────────────────────────────────────────────

  Future<void> _saveLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
  }

  String _gerarCodigoAfiliado() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final buffer = StringBuffer();
    for (int i = 0; i < 6; i++) {
      buffer.write(chars[(DateTime.now().microsecond + i * 7) % chars.length]);
    }
    return buffer.toString();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

// ── Resultado do cadastro ─────────────────────────────────────────────────────

class RegisterResult {
  final bool success;
  final bool wooviSubaccountCreated;
  final String message;

  RegisterResult({
    required this.success,
    this.wooviSubaccountCreated = false,
    required this.message,
  });
}
