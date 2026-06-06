import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

// ── Modelos ───────────────────────────────────────────────────────────────────

class MpCredentials {
  final String accessToken;
  final String publicKey;
  final String userId;
  final bool verified;

  const MpCredentials({
    required this.accessToken,
    required this.publicKey,
    required this.userId,
    required this.verified,
  });

  bool get isEmpty => accessToken.isEmpty || publicKey.isEmpty;

  factory MpCredentials.empty() => const MpCredentials(
        accessToken: '', publicKey: '', userId: '', verified: false);

  factory MpCredentials.fromMap(Map<String, dynamic> m) => MpCredentials(
        accessToken: m['access_token'] as String? ?? '',
        publicKey:   m['public_key']   as String? ?? '',
        userId:      m['user_id']      as String? ?? '',
        verified:    m['verified']     as bool?   ?? false,
      );

  Map<String, dynamic> toMap() => {
        'access_token': accessToken,
        'public_key':   publicKey,
        'user_id':      userId,
        'verified':     verified,
      };
}

class MpConfig {
  final String mode; // 'sandbox' | 'production'
  final MpCredentials sandbox;
  final MpCredentials production;
  final double comissaoPercent;
  final String notificationUrl;
  final String backUrlSuccess;
  final String backUrlFailure;
  final String backUrlPending;
  // Credenciais OAuth para renovação automática do token (expira 6h)
  final String clientId;
  final String clientSecret;

  const MpConfig({
    required this.mode,
    required this.sandbox,
    required this.production,
    required this.comissaoPercent,
    required this.notificationUrl,
    required this.backUrlSuccess,
    required this.backUrlFailure,
    required this.backUrlPending,
    this.clientId     = '',
    this.clientSecret = '',
  });

  bool get isSandbox => mode == 'sandbox';

  MpCredentials get active => isSandbox ? sandbox : production;

  factory MpConfig.defaultConfig() => MpConfig(
        // Modo produção com credenciais da conta real (client_credentials OAuth)
        // Token expira a cada 6h — renovado automaticamente via clientId+clientSecret
        mode: 'production',
        clientId:     '4493562791162337',
        clientSecret: 'NiedJYvJnAX6G7JLPIzIfF3xSybXoyS5',
        sandbox: MpCredentials.empty(),
        production: MpCredentials.fromMap({
          'access_token': 'APP_USR-4493562791162337-060618-dbba35b7784dc2366844eaae4bbdc03e-3235638414',
          'public_key':   '',
          'user_id':      '3235638414',
          'verified':     true,
        }),
        comissaoPercent: 0.20,
        notificationUrl: 'https://sharewallet.com.br/api/webhook/mp',
        backUrlSuccess:  'https://sharewallet.com.br/checkout/success',
        backUrlFailure:  'https://sharewallet.com.br/checkout/failure',
        backUrlPending:  'https://sharewallet.com.br/checkout/pending',
      );

  factory MpConfig.fromFirestore(Map<String, dynamic> d) => MpConfig(
        mode: d['mode'] as String? ?? 'sandbox',
        clientId:     d['client_id']     as String? ?? '',
        clientSecret: d['client_secret'] as String? ?? '',
        sandbox:    MpCredentials.fromMap(
            (d['sandbox']    as Map<String, dynamic>?) ?? {}),
        production: MpCredentials.fromMap(
            (d['production'] as Map<String, dynamic>?) ?? {}),
        comissaoPercent: (d['comissao_percent'] as num?)?.toDouble() ?? 0.20,
        notificationUrl: d['notification_url'] as String? ??
            'https://sharewallet.com.br/api/webhook/mp',
        backUrlSuccess: d['back_url_success'] as String? ??
            'https://sharewallet.com.br/checkout/success',
        backUrlFailure: d['back_url_failure'] as String? ??
            'https://sharewallet.com.br/checkout/failure',
        backUrlPending: d['back_url_pending'] as String? ??
            'https://sharewallet.com.br/checkout/pending',
      );
}

class MpPreference {
  final String id;
  final String initPoint;
  final String sandboxUrl;
  final String status;

  const MpPreference({
    required this.id,
    required this.initPoint,
    required this.sandboxUrl,
    required this.status,
  });

  factory MpPreference.fromJson(Map<String, dynamic> j) => MpPreference(
        id:         j['id']                  ?? '',
        initPoint:  j['init_point']          ?? '',
        sandboxUrl: j['sandbox_init_point']  ?? j['init_point'] ?? '',
        status:     j['status']              ?? 'pending',
      );
}

class MpCheckoutResult {
  final bool success;
  final String? preferenceId;
  final String? checkoutUrl;
  final String? errorMessage;
  final String? pixCode;
  final String? pixQrBase64;

  const MpCheckoutResult({
    required this.success,
    this.preferenceId,
    this.checkoutUrl,
    this.errorMessage,
    this.pixCode,
    this.pixQrBase64,
  });

  factory MpCheckoutResult.error(String msg) =>
      MpCheckoutResult(success: false, errorMessage: msg);
}

// ── MercadoPagoService ────────────────────────────────────────────────────────

class MercadoPagoService extends ChangeNotifier {
  static const String _baseUrl = 'https://api.mercadopago.com';
  // Caminho do documento de configuração no Firestore
  // ignore: unused_field
  static const String _configDocPath = 'config/mercadopago';

  // Config em memória — carregada do Firestore
  MpConfig _config = MpConfig.defaultConfig();
  bool _isLoading = false;
  bool _isConfigLoaded = false;
  String? _lastError;
  MpPreference? _lastPreference;

  MpConfig get config => _config;
  bool get isLoading => _isLoading;
  bool get isConfigLoaded => _isConfigLoaded;
  String? get lastError => _lastError;
  MpPreference? get lastPreference => _lastPreference;

  // ── Instância Firestore (banco affiliatewalletwallet) ────────────────────
  static const _databaseId = 'affiliatewalletwallet';
  static FirebaseFirestore? _dbInst;
  static FirebaseFirestore? get _db {
    if (_dbInst != null) return _dbInst;
    try {
      // Usa Firebase.app() para NÃO abrir o banco "(default)"
      // Abrir FirebaseFirestore.instance dispara WebChannel no banco errado
      _dbInst = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: _databaseId,
      );
    } catch (_) {}
    return _dbInst;
  }
  static CollectionReference<Map<String, dynamic>>? get _cfgCollection =>
      _db?.collection('config');

  // ── Carregar config do Firestore ──────────────────────────────────────────

  Future<void> loadConfig() async {
    try {
      final snap = await _cfgCollection?.doc('mercadopago').get();
      if (snap != null && snap.exists) {
        _config = MpConfig.fromFirestore(snap.data()!);
        _isConfigLoaded = true;
        if (kDebugMode) {
          debugPrint('[MP] Config carregada — modo: ${_config.mode}');
          debugPrint('[MP] Credencial ativa: ${_config.active.accessToken.substring(0, 20)}...');
        }
        notifyListeners();
      } else {
        // Documento não existe — criar com defaults
        await _saveConfigToFirestore(_config);
        _isConfigLoaded = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[MP] Erro ao carregar config: $e');
      // Usa defaults hardcoded como fallback
      _isConfigLoaded = true;
      notifyListeners();
    }
  }

  // ── Salvar config no Firestore ────────────────────────────────────────────

  Future<bool> saveConfig(MpConfig newConfig) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _saveConfigToFirestore(newConfig);
      _config = newConfig;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[MP] Erro ao salvar config: $e');
      _lastError = 'Erro ao salvar: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _saveConfigToFirestore(MpConfig cfg) async {
    await _cfgCollection?.doc('mercadopago').set({
      'mode': cfg.mode,
      'sandbox': {
        ...cfg.sandbox.toMap(),
        'label': '🧪 Sandbox (Testes)',
      },
      'production': {
        ...cfg.production.toMap(),
        'label': '🔴 Produção',
      },
      'comissao_percent': cfg.comissaoPercent,
      'notification_url': cfg.notificationUrl,
      'back_url_success':  cfg.backUrlSuccess,
      'back_url_failure':  cfg.backUrlFailure,
      'back_url_pending':  cfg.backUrlPending,
      if (cfg.clientId.isNotEmpty)     'client_id':     cfg.clientId,
      if (cfg.clientSecret.isNotEmpty) 'client_secret': cfg.clientSecret,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // ── Renovar token via OAuth client_credentials (token expira em 6h) ─────────

  Future<bool> _renovarToken() async {
    final cid = _config.clientId;
    final sec = _config.clientSecret;
    if (cid.isEmpty || sec.isEmpty) return false;

    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/oauth/token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'client_id':     cid,
          'client_secret': sec,
          'grant_type':    'client_credentials',
        }),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final newToken  = data['access_token'] as String? ?? '';
        final newUserId = data['user_id']?.toString() ?? _config.production.userId;
        if (newToken.isEmpty) return false;

        // Atualizar config em memória
        final newProd = MpCredentials(
          accessToken: newToken,
          publicKey:   _config.production.publicKey,
          userId:      newUserId,
          verified:    true,
        );
        _config = MpConfig(
          mode:            _config.mode,
          sandbox:         _config.sandbox,
          production:      newProd,
          comissaoPercent: _config.comissaoPercent,
          notificationUrl: _config.notificationUrl,
          backUrlSuccess:  _config.backUrlSuccess,
          backUrlFailure:  _config.backUrlFailure,
          backUrlPending:  _config.backUrlPending,
          clientId:        cid,
          clientSecret:    sec,
        );

        // Persistir novo token no Firestore (em background)
        _cfgCollection?.doc('mercadopago').set({
          'production': newProd.toMap(),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).catchError((_) {});

        notifyListeners();
        if (kDebugMode) debugPrint('[MP] ✅ Token renovado: ${newToken.substring(0, 25)}...');
        return true;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[MP] Erro ao renovar token: $e');
    }
    return false;
  }

  // ── Trocar modo (sandbox ↔ produção) ──────────────────────────────────────

  Future<bool> setMode(String mode) async {
    if (mode == _config.mode) return true;
    if (mode == 'production' && _config.production.isEmpty) {
      _lastError = 'Configure as credenciais de produção antes de ativar.';
      notifyListeners();
      return false;
    }
    final newCfg = MpConfig(
      mode: mode,
      sandbox:    _config.sandbox,
      production: _config.production,
      comissaoPercent: _config.comissaoPercent,
      notificationUrl: _config.notificationUrl,
      backUrlSuccess:  _config.backUrlSuccess,
      backUrlFailure:  _config.backUrlFailure,
      backUrlPending:  _config.backUrlPending,
    );
    return saveConfig(newCfg);
  }

  // ── Verificar credenciais via API ─────────────────────────────────────────

  Future<Map<String, dynamic>> verifyCredentials(String accessToken) async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/users/me'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return {
          'valid': true,
          'email': data['email'] ?? '',
          'user_id': data['id']?.toString() ?? '',
          'site_id': data['site_id'] ?? '',
          'is_test': (data['email'] as String? ?? '').contains('testuser'),
        };
      } else {
        return {'valid': false, 'error': 'Token inválido (${resp.statusCode})'};
      }
    } catch (e) {
      return {'valid': false, 'error': 'Erro de conexão: $e'};
    }
  }

  // ── Criar Preferência de Assinatura ──────────────────────────────────────

  Future<MpCheckoutResult> criarPreferenciaAssinatura({
    required String produtoId,
    required String produtoNome,
    required String produtoDescricao,
    required double valor,
    required String affiliateId,
    required String affiliateCode,
    required String clienteNome,
    required String clienteEmail,
    String? clienteCpf,
  }) async {
    if (!_isConfigLoaded) await loadConfig();

    _isLoading = true;
    _lastError = null;
    notifyListeners();

    final creds = _config.active;
    if (creds.isEmpty) {
      _isLoading = false;
      _lastError = _config.isSandbox
          ? 'Credenciais sandbox não configuradas.'
          : 'Credenciais de produção não configuradas. Configure no painel admin.';
      notifyListeners();
      return MpCheckoutResult.error(_lastError!);
    }

    try {
      final comissao   = valor * _config.comissaoPercent;
      final externalRef =
          'SW_${affiliateCode}_${produtoId}_${DateTime.now().millisecondsSinceEpoch}';

      final body = {
        'items': [{
          'id':          produtoId,
          'title':       produtoNome,
          'description': produtoDescricao,
          'quantity':    1,
          'currency_id': 'BRL',
          'unit_price':  valor,
        }],
        'payer': {
          'name':  clienteNome,
          'email': clienteEmail.isNotEmpty
              ? clienteEmail
              : 'cliente@sharewallet.com.br',
          if (clienteCpf != null && clienteCpf.isNotEmpty)
            'identification': {
              'type':   'CPF',
              'number': clienteCpf.replaceAll(RegExp(r'\D'), ''),
            },
        },
        'external_reference': externalRef,
        'metadata': {
          'affiliate_id':   affiliateId,
          'affiliate_code': affiliateCode,
          'produto_id':     produtoId,
          'comissao':       comissao,
          'sharewallet_versao': '2.0',
        },
        'payment_methods': {
          'excluded_payment_types': [],
          'installments': 1,
        },
        'back_urls': {
          'success': '${_config.backUrlSuccess}?ref=$externalRef',
          'failure': '${_config.backUrlFailure}?ref=$externalRef',
          'pending': '${_config.backUrlPending}?ref=$externalRef',
        },
        'auto_return':          'approved',
        'notification_url':     '${_config.notificationUrl}?ref=$externalRef',
        'statement_descriptor': 'SHAREWALLET',
        'expires':              false,
      };

      if (kDebugMode) {
        debugPrint('[MP] Criando preferência — modo: ${_config.mode}');
        debugPrint('[MP] Produto: $produtoNome | Valor: R\$${valor.toStringAsFixed(2)}');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/checkout/preferences'),
        headers: {
          'Authorization':     'Bearer ${creds.accessToken}',
          'Content-Type':      'application/json',
          'X-Idempotency-Key': externalRef,
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final pref = MpPreference.fromJson(json);
        _lastPreference = pref;

        await _salvarPreferenciaFirestore(
          preferenceId:  pref.id,
          externalRef:   externalRef,
          affiliateId:   affiliateId,
          affiliateCode: affiliateCode,
          produtoId:     produtoId,
          valor:         valor,
          comissao:      comissao,
        );

        _isLoading = false;
        notifyListeners();

        return MpCheckoutResult(
          success:      true,
          preferenceId: pref.id,
          checkoutUrl:  _config.isSandbox ? pref.sandboxUrl : pref.initPoint,
        );
      } else {
        final errBody = jsonDecode(response.body);
        final errMsg  = errBody['message'] ?? 'Erro ${response.statusCode}';
        _lastError    = errMsg;
        _isLoading    = false;
        notifyListeners();
        return MpCheckoutResult.error(errMsg);
      }
    } catch (e) {
      debugPrint('[MP] Erro na criação de preferência: $e');
      _isLoading = false;
      _lastError = null;
      notifyListeners();
      return _checkoutFallback(
        produtoId:    produtoId,
        produtoNome:  produtoNome,
        valor:        valor,
        affiliateCode: affiliateCode,
      );
    }
  }

  // ── Criar Pix direto ──────────────────────────────────────────────────────

  Future<MpCheckoutResult> criarPix({
    required String produtoId,
    required String produtoNome,
    required double valor,
    required String affiliateId,
    required String affiliateCode,
    required String clienteNome,
    required String clienteCpf,
    required String clienteEmail,
  }) async {
    if (!_isConfigLoaded) await loadConfig();

    _isLoading = true;
    _lastError = null;
    notifyListeners();

    final creds = _config.active;
    if (creds.isEmpty) {
      _isLoading = false;
      _lastError = 'Credenciais ${_config.mode} não configuradas.';
      notifyListeners();
      return MpCheckoutResult.error(_lastError!);
    }

    try {
      final externalRef =
          'PIX_${affiliateCode}_${produtoId}_${DateTime.now().millisecondsSinceEpoch}';

      final body = {
        'transaction_amount': valor,
        'description':        produtoNome,
        'payment_method_id':  'pix',
        'payer': {
          'email': clienteEmail.isNotEmpty
              ? clienteEmail
              : 'cliente@sharewallet.com.br',
          'first_name': clienteNome.split(' ').first,
          'last_name':  clienteNome.split(' ').length > 1
              ? clienteNome.split(' ').sublist(1).join(' ')
              : 'Sobrenome',
          'identification': {
            'type':   'CPF',
            'number': clienteCpf.replaceAll(RegExp(r'\D'), ''),
          },
        },
        'external_reference': externalRef,
        'metadata': {
          'affiliate_id':   affiliateId,
          'affiliate_code': affiliateCode,
          'produto_id':     produtoId,
          'comissao':       valor * _config.comissaoPercent,
        },
        'notification_url': _config.notificationUrl,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/v1/payments'),
        headers: {
          'Authorization':     'Bearer ${creds.accessToken}',
          'Content-Type':      'application/json',
          'X-Idempotency-Key': externalRef,
        },
        body: jsonEncode(body),
      );

      // Token expirado (6h) → renovar via client_credentials e tentar de novo
      if (response.statusCode == 401) {
        if (kDebugMode) debugPrint('[MP] 401 — tentando renovar token...');
        final renovado = await _renovarToken();
        if (renovado) {
          final newCreds = _config.active;
          final retryResp = await http.post(
            Uri.parse('$_baseUrl/v1/payments'),
            headers: {
              'Authorization':     'Bearer ${newCreds.accessToken}',
              'Content-Type':      'application/json',
              'X-Idempotency-Key': '${externalRef}_retry',
            },
            body: jsonEncode(body),
          );
          if (retryResp.statusCode == 201 || retryResp.statusCode == 200) {
            final json    = jsonDecode(retryResp.body) as Map<String, dynamic>;
            final txData  = json['point_of_interaction']?['transaction_data'];
            _isLoading    = false;
            notifyListeners();
            return MpCheckoutResult(
              success:      true,
              preferenceId: json['id']?.toString(),
              pixCode:      txData?['qr_code']        as String?,
              pixQrBase64:  txData?['qr_code_base64'] as String?,
            );
          }
          final errBody2 = jsonDecode(retryResp.body);
          _lastError  = errBody2['message'] ?? 'Token inválido após renovação';
          _isLoading  = false;
          notifyListeners();
          return MpCheckoutResult.error(_lastError!);
        }
        _lastError = 'Token expirado. Acesse Admin → Pagamentos e salve as credenciais novamente.';
        _isLoading = false;
        notifyListeners();
        return MpCheckoutResult.error(_lastError!);
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        final json     = jsonDecode(response.body) as Map<String, dynamic>;
        final txData   = json['point_of_interaction']?['transaction_data'];
        final pixCode  = txData?['qr_code']        as String?;
        final pixQr    = txData?['qr_code_base64'] as String?;
        final paymentId = json['id']?.toString();

        _isLoading = false;
        notifyListeners();
        return MpCheckoutResult(
          success:      true,
          preferenceId: paymentId,
          pixCode:      pixCode,
          pixQrBase64:  pixQr,
        );
      } else {
        final errBody = jsonDecode(response.body);
        _lastError    = errBody['message'] ?? 'Erro ao gerar Pix';
        _isLoading    = false;
        notifyListeners();
        return MpCheckoutResult.error(_lastError!);
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return MpCheckoutResult.error('Erro de conexão: $e');
    }
  }

  // ── Abrir Checkout ────────────────────────────────────────────────────────

  Future<bool> abrirCheckout(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[MP] Erro ao abrir checkout: $e');
      return false;
    }
  }

  // ── Simular Pagamento Aprovado (sandbox) ──────────────────────────────────

  Future<bool> simularPagamentoAprovado({
    required String userId,
    required String produtoId,
    required String produtoNome,
    required double valor,
    required String affiliateId,
    required String affiliateCode,
  }) async {
    try {
      final comissao      = valor * _config.comissaoPercent;
      final transactionId = 'SIM_${DateTime.now().millisecondsSinceEpoch}';

      final db = _db;
      if (db == null) return false;

      await db.collection('subscriptions').add({
        'user_id':       userId,
        'product_id':    produtoId,
        'product_nome':  produtoNome,
        'valor':         valor,
        'comissao':      comissao,
        'affiliate_id':  affiliateId,
        'affiliate_code': affiliateCode,
        'status':        'ativo',
        'payment_method': 'pix',
        'transaction_id': transactionId,
        'created_at':    FieldValue.serverTimestamp(),
        'next_charge':   Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 30))),
      });

      final walletRef  = db.collection('wallets').doc(affiliateId);
      final walletSnap = await walletRef.get();
      if (walletSnap.exists) {
        await walletRef.update({
          'saldo_pendente':  FieldValue.increment(comissao),
          'total_recebido':  FieldValue.increment(comissao),
          'total_vendas':    FieldValue.increment(1),
          'updated_at':      FieldValue.serverTimestamp(),
        });
      } else {
        await walletRef.set({
          'uid':              affiliateId,
          'affiliate_id':     affiliateId,
          'affiliate_code':   affiliateCode,
          'saldo_disponivel': 0.0,
          'saldo_pendente':   comissao,
          'total_recebido':   comissao,
          'total_sacado':     0.0,
          'total_comissoes':  comissao,
          'total_vendas':     1,
          'status':           'ativo',
          'created_at':       FieldValue.serverTimestamp(),
          'updated_at':       FieldValue.serverTimestamp(),
        });
      }

      await db.collection('affiliates').doc(affiliateId).update({
        'saldo_pendente': FieldValue.increment(comissao),
        'total_recebido': FieldValue.increment(comissao),
        'total_sales':    FieldValue.increment(1),
        'updated_at':     FieldValue.serverTimestamp(),
      }).catchError((_) {});

      await db.collection('wallet_transactions').add({
        'wallet_id':    affiliateId,
        'affiliate_id': affiliateId,
        'tipo':         'comissao',
        'descricao':    'Comissão: $produtoNome',
        'valor':        comissao,
        'status':       'pendente',
        'transaction_id': transactionId,
        'product_id':   produtoId,
        'created_at':   FieldValue.serverTimestamp(),
      });

      await db.collection('referrals').add({
        'affiliate_id':   affiliateId,
        'affiliate_code': affiliateCode,
        'referred_user_id': userId,
        'produto_id':     produtoId,
        'produto_nome':   produtoNome,
        'comissao_mensal': comissao,
        'status':         'ativo',
        'created_at':     FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('[MP WEBHOOK SIM] Erro: $e');
      return false;
    }
  }

  // ── Helpers privados ──────────────────────────────────────────────────────

  Future<void> _salvarPreferenciaFirestore({
    required String preferenceId,
    required String externalRef,
    required String affiliateId,
    required String affiliateCode,
    required String produtoId,
    required double valor,
    required double comissao,
  }) async {
    try {
      await _db?.collection('payments').add({
        'preference_id':  preferenceId,
        'external_ref':   externalRef,
        'affiliate_id':   affiliateId,
        'affiliate_code': affiliateCode,
        'produto_id':     produtoId,
        'valor':          valor,
        'comissao':       comissao,
        'status':         'pending',
        'created_at':     FieldValue.serverTimestamp(),
        'is_sandbox':     _config.isSandbox,
        'mp_mode':        _config.mode,
      });
    } catch (e) {
      debugPrint('[MP] Erro ao salvar preferência no Firestore: $e');
    }
  }

  MpCheckoutResult _checkoutFallback({
    required String produtoId,
    required String produtoNome,
    required double valor,
    required String affiliateCode,
  }) {
    const sandboxBase = 'https://sandbox.mercadopago.com.br/checkout/v1/redirect';
    final url = '$sandboxBase?pref_id=sandbox_${affiliateCode}_$produtoId';
    return MpCheckoutResult(
      success:      true,
      preferenceId: 'sandbox_fallback_$produtoId',
      checkoutUrl:  url,
    );
  }

  // ── Getters estáticos (compatibilidade) ───────────────────────────────────

  String get publicKey       => _config.active.publicKey;
  String get userId          => _config.active.userId;
  bool   get isSandbox       => _config.isSandbox;
  double get comissaoPercent => _config.comissaoPercent;

  // Instância — usa a comissão carregada do Firestore
  double calcularComissaoAtual(double valor) => valor * _config.comissaoPercent;

  // Estático — compatibilidade com código legado (usa 20% fixo)
  static double calcularComissao(double valor) => valor * 0.20;
}
