// ===========================================================================
// customer_service.dart - ShareWallet
// ---------------------------------------------------------------------------
// ChangeNotifier que gerencia estado global do cliente logado.
// Análogo ao AuthService (para afiliados), mas para o modo CLIENTE.
// ===========================================================================

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/customer_model.dart';
import 'firebase_customer_service.dart';
import '../utils/web_utils.dart';

class CustomerService extends ChangeNotifier {
  CustomerModel? _currentCustomer;
  List<CustomerProductModel> _produtos = [];
  bool _isLoading = false;
  String? _error;

  // Carteira
  double _saldoDisponivel = 0.0;
  double _saldoPendente   = 0.0;
  double _totalDepositado = 0.0;
  double _totalGasto      = 0.0;

  // Getters
  CustomerModel?               get currentCustomer  => _currentCustomer;
  List<CustomerProductModel>   get produtos          => _produtos;
  List<CustomerProductModel>   get produtosAtivos    =>
      _produtos.where((p) => p.isAtivo).toList();
  bool                         get isLoading         => _isLoading;
  bool                         get isLoggedIn        => _currentCustomer != null;
  String?                      get error             => _error;
  double                       get saldoDisponivel   => _saldoDisponivel;
  double                       get saldoPendente     => _saldoPendente;
  double                       get totalDepositado   => _totalDepositado;
  double                       get totalGasto        => _totalGasto;

  // ── Chaves localStorage para PWA ─────────────────────────────────────────
  static const _kCustUidKey   = 'sw_cust_uid';
  static const _kCustEmailKey = 'sw_cust_email';
  static const _kCustNomeKey  = 'sw_cust_nome';

  // ── Init: restaura sessão cliente ─────────────────────────────────────────

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Cache instantâneo via localStorage (mesmo padrão do AuthService)
      final cachedUid   = kIsWeb ? getLocalStorageValue(_kCustUidKey)   : null;
      final cachedEmail = kIsWeb ? getLocalStorageValue(_kCustEmailKey) : null;
      final cachedNome  = kIsWeb ? getLocalStorageValue(_kCustNomeKey)  : null;

      if (cachedUid != null && cachedUid.isNotEmpty) {
        _currentCustomer = CustomerModel(
          id:    cachedUid,
          nome:  cachedNome ?? cachedEmail?.split('@').first ?? 'Cliente',
          email: cachedEmail ?? '',
          createdAt: DateTime.now(),
        );
        _isLoading = false;
        notifyListeners();
      }

      // Aguarda Firebase hidratar sessão
      final firebaseUser = await FirebaseAuth.instance
          .authStateChanges()
          .first
          .timeout(const Duration(seconds: 2), onTimeout: () => null);

      if (firebaseUser != null) {
        // Salva no localStorage
        if (kIsWeb) {
          setLocalStorageValue(_kCustUidKey, firebaseUser.uid);
          if (firebaseUser.email != null) {
            setLocalStorageValue(_kCustEmailKey, firebaseUser.email!);
          }
        }

        // Carrega perfil completo em background
        FirebaseCustomerService.carregarClienteAtual()
            .timeout(const Duration(seconds: 8), onTimeout: () => null)
            .then((customer) {
          if (customer != null) {
            _currentCustomer = customer;
            notifyListeners();
            // Carrega produtos e carteira em background
            _carregarDados(customer.id);
          }
        }).catchError((_) {});
      } else {
        // Sem sessão Firebase — limpa cache local
        if (kIsWeb && cachedUid != null) {
          removeLocalStorageValue(_kCustUidKey);
          removeLocalStorageValue(_kCustEmailKey);
          removeLocalStorageValue(_kCustNomeKey);
          _currentCustomer = null;
          notifyListeners();
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[CustomerService] init erro: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Login com Google/Facebook/Email ──────────────────────────────────────

  Future<bool> loginWithFirebase({
    required String uid,
    required String email,
    String? displayName,
    String? avatarUrl,
    String? idToken,
    String? provider,
    String? sponsorRef,     // @username ou code vindo do link ?ref=
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await FirebaseCustomerService.buscarOuCriarCliente(
        uid: uid,
        email: email,
        displayName: displayName,
        avatarUrl: avatarUrl,
        sponsorRef: sponsorRef,
        provider: provider,
      );

      if (result.success && result.customer != null) {
        _currentCustomer = result.customer;
        await _salvarLocalFlag();
        _isLoading = false;
        notifyListeners();

        // Carrega dados em background
        _carregarDados(uid);
        return true;
      }

      _error = result.error ?? 'Erro ao entrar como cliente';
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
    _currentCustomer = null;
    _produtos = [];
    _saldoDisponivel = 0;
    _saldoPendente   = 0;
    await FirebaseCustomerService.signOut();
    if (kIsWeb) {
      removeLocalStorageValue(_kCustUidKey);
      removeLocalStorageValue(_kCustEmailKey);
      removeLocalStorageValue(_kCustNomeKey);
    }
    notifyListeners();
  }

  // ── Recarregar dados ──────────────────────────────────────────────────────

  Future<void> refreshProfile() async {
    final uid = _currentCustomer?.id;
    if (uid == null || uid.isEmpty) return;

    try {
      final customer = await FirebaseCustomerService.carregarClienteAtual();
      if (customer != null) {
        _currentCustomer = customer;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[CustomerService] refreshProfile erro: $e');
    }
  }

  Future<void> refreshProdutos() async {
    final uid = _currentCustomer?.id;
    if (uid == null || uid.isEmpty) return;
    await _carregarProdutos(uid);
  }

  Future<void> refreshCarteira() async {
    final uid = _currentCustomer?.id;
    if (uid == null || uid.isEmpty) return;
    await _carregarCarteira(uid);
  }

  // ── Atualizar perfil ──────────────────────────────────────────────────────

  void updateCurrentCustomer({
    String? nome,
    String? telefone,
    String? cpf,
    String? pixKey,
    String? pixKeyType,
  }) {
    if (_currentCustomer == null) return;
    _currentCustomer = _currentCustomer!.copyWith(
      nome: nome,
      telefone: telefone,
      cpf: cpf,
      pixKey: pixKey,
      pixKeyType: pixKeyType,
    );
    notifyListeners();
  }

  // ── Helpers privados ──────────────────────────────────────────────────────

  Future<void> _carregarDados(String uid) async {
    await Future.wait([
      _carregarProdutos(uid),
      _carregarCarteira(uid),
    ]);
  }

  Future<void> _carregarProdutos(String uid) async {
    try {
      _produtos = await FirebaseCustomerService.listarProdutosDoCliente(uid);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _carregarCarteira(String uid) async {
    try {
      final carteira = await FirebaseCustomerService.carregarCarteiraCliente(uid);
      _saldoDisponivel = carteira['saldo_disponivel'] ?? 0;
      _saldoPendente   = carteira['saldo_pendente']   ?? 0;
      _totalDepositado = carteira['total_depositado'] ?? 0;
      _totalGasto      = carteira['total_gasto']      ?? 0;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _salvarLocalFlag() async {
    if (kIsWeb && _currentCustomer != null) {
      setLocalStorageValue(_kCustUidKey,   _currentCustomer!.id);
      setLocalStorageValue(_kCustEmailKey, _currentCustomer!.email);
      if (_currentCustomer!.nome.isNotEmpty) {
        setLocalStorageValue(_kCustNomeKey, _currentCustomer!.nome);
      }
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
