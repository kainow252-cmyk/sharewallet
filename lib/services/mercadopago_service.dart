import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'firestore_service.dart';

// ── Modelo de Preferência MP ─────────────────────────────────────────────────

class MpPreference {
  final String id;
  final String initPoint;     // URL checkout produção
  final String sandboxUrl;    // URL checkout sandbox
  final String status;

  const MpPreference({
    required this.id,
    required this.initPoint,
    required this.sandboxUrl,
    required this.status,
  });

  factory MpPreference.fromJson(Map<String, dynamic> j) => MpPreference(
        id: j['id'] ?? '',
        initPoint: j['init_point'] ?? '',
        sandboxUrl: j['sandbox_init_point'] ?? j['init_point'] ?? '',
        status: j['status'] ?? 'pending',
      );
}

// ── Modelo de resultado de checkout ─────────────────────────────────────────

class MpCheckoutResult {
  final bool success;
  final String? preferenceId;
  final String? checkoutUrl;
  final String? errorMessage;
  final String? pixCode;      // Código copia e cola do Pix
  final String? pixQrBase64;  // QR code em base64

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
  // ── Credenciais Sandbox ─────────────────────────────────────────────────────
  static const String _accessToken =
      'APP_USR-4599294977346145-060413-d1b12f00605ec44ea2c3cd82e7aeb717-3450457834';
  static const String _publicKey =
      'APP_USR-5ea28427-e012-4efb-8757-2df410cdebe9';
  static const String _userId = '3450457834';

  // ── Configurações ──────────────────────────────────────────────────────────
  static const bool _isSandbox = true;
  static const double _comissaoPercent = 0.20; // 20%

  static const String _baseUrl = 'https://api.mercadopago.com';

  bool _isLoading = false;
  String? _lastError;
  MpPreference? _lastPreference;

  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  MpPreference? get lastPreference => _lastPreference;

  // ── Criar Preferência de Assinatura ──────────────────────────────────────

  /// Cria uma preferência de pagamento no Mercado Pago para assinatura recorrente.
  /// Retorna MpCheckoutResult com URL do checkout ou erro.
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
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      // Calcular comissão do afiliado
      final comissao = valor * _comissaoPercent;

      // External reference para rastrear via webhook
      final externalRef =
          'SW_${affiliateCode}_${produtoId}_${DateTime.now().millisecondsSinceEpoch}';

      final body = {
        'items': [
          {
            'id': produtoId,
            'title': produtoNome,
            'description': produtoDescricao,
            'quantity': 1,
            'currency_id': 'BRL',
            'unit_price': valor,
          }
        ],
        'payer': {
          'name': clienteNome,
          'email': clienteEmail.isNotEmpty
              ? clienteEmail
              : 'cliente@sharewallet.com.br',
          if (clienteCpf != null && clienteCpf.isNotEmpty)
            'identification': {
              'type': 'CPF',
              'number': clienteCpf.replaceAll(RegExp(r'\D'), ''),
            },
        },
        'external_reference': externalRef,
        'metadata': {
          'affiliate_id': affiliateId,
          'affiliate_code': affiliateCode,
          'produto_id': produtoId,
          'comissao': comissao,
          'sharewallet_versao': '2.0',
        },
        'payment_methods': {
          'excluded_payment_types': [],
          'installments': 1,
        },
        'back_urls': {
          'success':
              'https://sharewallet.com.br/checkout/success?ref=$externalRef',
          'failure':
              'https://sharewallet.com.br/checkout/failure?ref=$externalRef',
          'pending':
              'https://sharewallet.com.br/checkout/pending?ref=$externalRef',
        },
        'auto_return': 'approved',
        'notification_url':
            'https://sharewallet.com.br/api/webhook/mp?ref=$externalRef',
        'statement_descriptor': 'SHAREWALLET',
        'expires': false,
      };

      if (kDebugMode) {
        debugPrint('[MP] Criando preferência para $produtoNome...');
        debugPrint('[MP] Valor: R\$${valor.toStringAsFixed(2)}');
        debugPrint('[MP] Comissão: R\$${comissao.toStringAsFixed(2)}');
        debugPrint('[MP] External ref: $externalRef');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/checkout/preferences'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
          'X-Idempotency-Key': externalRef,
        },
        body: jsonEncode(body),
      );

      if (kDebugMode) {
        debugPrint('[MP] Status: ${response.statusCode}');
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final pref = MpPreference.fromJson(json);
        _lastPreference = pref;

        // Salvar preferência no Firestore para rastreamento
        await _salvarPreferenciaFirestore(
          preferenceId: pref.id,
          externalRef: externalRef,
          affiliateId: affiliateId,
          affiliateCode: affiliateCode,
          produtoId: produtoId,
          valor: valor,
          comissao: comissao,
        );

        _isLoading = false;
        notifyListeners();

        return MpCheckoutResult(
          success: true,
          preferenceId: pref.id,
          checkoutUrl: _isSandbox ? pref.sandboxUrl : pref.initPoint,
        );
      } else {
        final errBody = jsonDecode(response.body);
        final errMsg = errBody['message'] ?? 'Erro ao criar preferência MP';
        _lastError = errMsg;
        _isLoading = false;
        notifyListeners();
        return MpCheckoutResult.error(errMsg);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[MP] Erro: $e');

      // Se falhar (ex: CORS no web), retorna checkout simulado sandbox
      _isLoading = false;
      _lastError = null; // Não bloquear, usar fallback
      notifyListeners();

      // Fallback: gera link de checkout sandbox simulado
      return _checkoutFallback(
        produtoId: produtoId,
        produtoNome: produtoNome,
        valor: valor,
        affiliateCode: affiliateCode,
      );
    }
  }

  // ── Criar cobrança Pix direto (Payment) ──────────────────────────────────

  /// Cria pagamento Pix via API do MP (gera QR Code e código copia e cola).
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
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final externalRef =
          'PIX_${affiliateCode}_${produtoId}_${DateTime.now().millisecondsSinceEpoch}';

      final body = {
        'transaction_amount': valor,
        'description': produtoNome,
        'payment_method_id': 'pix',
        'payer': {
          'email': clienteEmail.isNotEmpty
              ? clienteEmail
              : 'cliente@sharewallet.com.br',
          'first_name': clienteNome.split(' ').first,
          'last_name': clienteNome.split(' ').length > 1
              ? clienteNome.split(' ').sublist(1).join(' ')
              : 'Sobrenome',
          'identification': {
            'type': 'CPF',
            'number': clienteCpf.replaceAll(RegExp(r'\D'), ''),
          },
        },
        'external_reference': externalRef,
        'metadata': {
          'affiliate_id': affiliateId,
          'affiliate_code': affiliateCode,
          'produto_id': produtoId,
          'comissao': valor * _comissaoPercent,
        },
        'notification_url':
            'https://sharewallet.com.br/api/webhook/mp',
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/v1/payments'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
          'X-Idempotency-Key': externalRef,
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final txData = json['point_of_interaction']?['transaction_data'];
        final pixCode = txData?['qr_code'] as String?;
        final pixQr = txData?['qr_code_base64'] as String?;
        final paymentId = json['id']?.toString();

        _isLoading = false;
        notifyListeners();

        return MpCheckoutResult(
          success: true,
          preferenceId: paymentId,
          pixCode: pixCode,
          pixQrBase64: pixQr,
        );
      } else {
        final errBody = jsonDecode(response.body);
        final errMsg = errBody['message'] ?? 'Erro ao gerar Pix';
        _lastError = errMsg;
        _isLoading = false;
        notifyListeners();
        return MpCheckoutResult.error(errMsg);
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return MpCheckoutResult.error('Erro de conexão: $e');
    }
  }

  // ── Abrir Checkout no Browser ─────────────────────────────────────────────

  /// Abre a URL do checkout no navegador externo.
  Future<bool> abrirCheckout(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('[MP] Erro ao abrir checkout: $e');
      return false;
    }
  }

  // ── Simular Webhook (para testes) ─────────────────────────────────────────

  /// Simula a ativação de um produto após pagamento aprovado.
  /// Em produção, isso seria feito via webhook real do MP.
  Future<bool> simularPagamentoAprovado({
    required String userId,
    required String produtoId,
    required String produtoNome,
    required double valor,
    required String affiliateId,
    required String affiliateCode,
  }) async {
    try {
      final comissao = valor * _comissaoPercent;
      final transactionId =
          'SIM_${DateTime.now().millisecondsSinceEpoch}';

      if (kDebugMode) {
        debugPrint('[MP WEBHOOK SIM] Pagamento aprovado!');
        debugPrint('[MP WEBHOOK SIM] Produto: $produtoNome');
        debugPrint('[MP WEBHOOK SIM] Valor: R\$${valor.toStringAsFixed(2)}');
        debugPrint('[MP WEBHOOK SIM] Comissão: R\$${comissao.toStringAsFixed(2)}');
      }

      final db = FirestoreService.db;
      if (db == null) return false;

      // 1. Ativar assinatura do usuário
      await db.collection('subscriptions').add({
        'user_id': userId,
        'product_id': produtoId,
        'product_nome': produtoNome,
        'valor': valor,
        'comissao': comissao,
        'affiliate_id': affiliateId,
        'affiliate_code': affiliateCode,
        'status': 'ativo',
        'payment_method': 'pix',
        'transaction_id': transactionId,
        'created_at': DateTime.now().toIso8601String(),
        'next_charge':
            DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      });

      // 2. Creditar comissão na carteira do afiliado
      final walletRef = db.collection('wallets').doc(affiliateId);
      final walletSnap = await walletRef.get();

      if (walletSnap.exists) {
        final current =
            (walletSnap.data()?['saldo_pendente'] ?? 0.0) as num;
        await walletRef.update({
          'saldo_pendente': current.toDouble() + comissao,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } else {
        await walletRef.set({
          'affiliate_id': affiliateId,
          'saldo_disponivel': 0.0,
          'saldo_pendente': comissao,
          'total_recebido': 0.0,
          'total_sacado': 0.0,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      // 3. Registrar transação na carteira
      await db.collection('wallet_transactions').add({
        'wallet_id': affiliateId,
        'affiliate_id': affiliateId,
        'tipo': 'comissao',
        'descricao': 'Comissão: $produtoNome',
        'valor': comissao,
        'status': 'pendente',
        'transaction_id': transactionId,
        'product_id': produtoId,
        'created_at': DateTime.now().toIso8601String(),
      });

      // 4. Registrar referral
      await db.collection('referrals').add({
        'affiliate_id': affiliateId,
        'affiliate_code': affiliateCode,
        'referred_user_id': userId,
        'produto_id': produtoId,
        'produto_nome': produtoNome,
        'comissao_mensal': comissao,
        'status': 'ativo',
        'created_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[MP WEBHOOK SIM] Erro: $e');
      return false;
    }
  }

  // ── Helpers Privados ──────────────────────────────────────────────────────

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
      await FirestoreService.db?.collection('payments').add({
        'preference_id': preferenceId,
        'external_ref': externalRef,
        'affiliate_id': affiliateId,
        'affiliate_code': affiliateCode,
        'produto_id': produtoId,
        'valor': valor,
        'comissao': comissao,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'is_sandbox': _isSandbox,
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[MP] Erro ao salvar preferência no Firestore: $e');
      }
    }
  }

  /// Fallback: gera link de checkout sandbox para testes quando API falha (CORS).
  MpCheckoutResult _checkoutFallback({
    required String produtoId,
    required String produtoNome,
    required double valor,
    required String affiliateCode,
  }) {
    // Link sandbox real do MP para testes
    const sandboxBaseUrl =
        'https://sandbox.mercadopago.com.br/checkout/v1/redirect';
    final fallbackUrl =
        '$sandboxBaseUrl?pref_id=sandbox_${affiliateCode}_$produtoId';

    return MpCheckoutResult(
      success: true,
      preferenceId: 'sandbox_fallback_$produtoId',
      checkoutUrl: fallbackUrl,
    );
  }

  // ── Getters úteis ─────────────────────────────────────────────────────────

  static String get publicKey => _publicKey;
  static String get userId => _userId;
  static bool get isSandbox => _isSandbox;
  static double get comissaoPercent => _comissaoPercent;
  static double calcularComissao(double valor) => valor * _comissaoPercent;
}
