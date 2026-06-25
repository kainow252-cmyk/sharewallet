import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Serviço Flutter para integração Woovi.
///
/// IMPORTANTE: O Flutter NUNCA fala diretamente com a Woovi API.
/// Todas as chamadas passam pelo Cloudflare Worker (api.sharewallet.com.br)
/// que detém o WOOVI_APP_ID em variável de ambiente segura.
///
/// Fluxo Pix Avulso:
///   Flutter → POST /api/charge/woovi → Worker → Woovi API
///   Woovi Webhook → Worker → D1 atualiza venda → Flutter polling
///
/// Fluxo Pix Automático (Assinatura):
///   Flutter → POST /api/subscription/woovi → Worker → Woovi API
///   Woovi Webhook PIX_AUTOMATIC_APPROVED → Worker → D1 atualiza subconta
///   Woovi Webhook PIX_AUTOMATIC_COBR_COMPLETED → Worker → D1 credita comissão

class WooviService {
  static const String _base = 'https://api.sharewallet.com.br';

  // ── Criar Cobrança Pix Avulso ───────────────────────────────────────────

  /// Cria uma cobrança Pix única com split automático para a subconta do afiliado.
  /// Retorna QR Code + brCode para exibir na tela de pagamento.
  static Future<ChargeResult?> createCharge({
    required String correlationID,
    required int valueCents,          // valor total em centavos
    required String userId,           // uid Firebase do afiliado
    required String affiliateCode,
    required String productId,
    required String productNome,
    int commissionCents = 0,          // comissão do afiliado em centavos
    String? affiliatePixKey,          // chave pix da subconta do afiliado
    String? customerName,
    String? customerEmail,
    String? customerCpf,
    String? customerPhone,
    String? comment,
    // Callback para receber a mensagem de erro da Woovi
    void Function(String)? onError,
  }) async {
    try {
      // CPF: limpa máscara antes de enviar
      final cpfClean = customerCpf?.replaceAll(RegExp(r'\D'), '');

      final res = await http.post(
        Uri.parse('$_base/api/charge/woovi'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'correlationID':    correlationID,
          'value':            valueCents,
          'userId':           userId,
          'affiliateCode':    affiliateCode,
          'productId':        productId,
          'productNome':      productNome,
          'comissaoCentavos': commissionCents,
          if (affiliatePixKey != null) 'affiliatePixKey': affiliatePixKey,
          if (customerName  != null && customerName.isNotEmpty)   'customerName':  customerName,
          if (customerEmail != null && customerEmail.isNotEmpty)  'customerEmail': customerEmail,
          if (cpfClean      != null && cpfClean.length == 11)     'customerCpf':   cpfClean,
          if (customerPhone != null && customerPhone.isNotEmpty)  'customerPhone': customerPhone,
          if (comment       != null) 'comment': comment,
        }),
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (kDebugMode) debugPrint('[WooviService] createCharge ${res.statusCode}: $data');

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return ChargeResult.fromJson(data['result'] ?? data);
      }

      // Extrai mensagem de erro real para exibir ao usuário
      final errMsg = _extractError(data);
      if (kDebugMode) debugPrint('[WooviService] Erro charge: $errMsg');
      onError?.call(errMsg);
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[WooviService] createCharge exception: $e');
      onError?.call('Erro de conexão. Verifique sua internet e tente novamente.');
      return null;
    }
  }

  // ── Criar Assinatura Pix Automático ────────────────────────────────────

  /// Cria assinatura recorrente via Woovi Pix Automático (Banco Central).
  /// Retorna QR Code + paymentLinkUrl para o cliente autorizar a recorrência.
  /// Jornada 3: PAYMENT_ON_APPROVAL — cliente paga 1ª parcela + autoriza futuras.
  static Future<SubscriptionResult?> createSubscription({
    required String correlationID,
    required int valueCents,          // valor mensal em centavos
    required String userId,
    required String affiliateCode,
    required String productId,
    required String productNome,
    int commissionCents = 0,
    // dayGenerateCharge é ignorado — Worker usa 25 fixo (regra Woovi PAYMENT_ON_APPROVAL)
    // Dados do cliente (obrigatório para Pix Automático)
    required String customerName,
    required String customerCpf,      // CPF sem formatação
    required String customerEmail,
    String? customerPhone,
    // Endereço do cliente (obrigatório pelo BC)
    required String zipcode,
    required String street,
    required String number,
    required String neighborhood,
    required String city,
    required String state,
    String complement = '',
    String? comment,
    // Callback para receber a mensagem de erro da Woovi
    void Function(String)? onError,
  }) async {
    try {
      final cpfClean = customerCpf.replaceAll(RegExp(r'\D'), '');
      final phoneClean = customerPhone?.replaceAll(RegExp(r'\D'), '');

      final res = await http.post(
        Uri.parse('$_base/api/subscription/woovi'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'correlationID':    correlationID,
          'value':            valueCents,
          'userId':           userId,
          'affiliateCode':    affiliateCode,
          'productId':        productId,
          'productNome':      productNome,
          'comissaoCentavos': commissionCents,
          // dayGenerateCharge: o worker usa 25 fixo (PAYMENT_ON_APPROVAL exige)
          if (comment != null) 'comment': comment,
          'customer': {
            'name':  customerName,
            'taxID': cpfClean,
            'email': customerEmail,
            if (phoneClean != null && phoneClean.isNotEmpty)
              'phone': phoneClean,
            'address': {
              'zipcode':       zipcode.replaceAll(RegExp(r'\D'), ''),
              'street':        street,
              'number':        number,
              'neighborhood':  neighborhood,
              'city':          city,
              'state':         state,
              'complement':    complement,
            },
          },
        }),
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (kDebugMode) debugPrint('[WooviService] createSubscription ${res.statusCode}: $data');

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return SubscriptionResult.fromJson(data['result'] ?? data);
      }

      // Extrai mensagem de erro real para exibir ao usuário
      final errMsg = _extractError(data);
      if (kDebugMode) debugPrint('[WooviService] Erro subscription: $errMsg');
      onError?.call(errMsg);
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[WooviService] createSubscription exception: $e');
      onError?.call('Erro de conexão. Verifique sua internet e tente novamente.');
      return null;
    }
  }

  // ── Helper: extrai mensagem de erro do response do worker ───────────────
  static String _extractError(Map<String, dynamic> data) {
    final raw = data['error'] as String?
             ?? data['message'] as String?
             ?? data['result']?['error'] as String?
             ?? 'Erro desconhecido. Tente novamente.';
    // Remove prefixo "Woovi: " para mensagem mais limpa ao usuário
    return raw.startsWith('Woovi: ') ? raw.substring(7) : raw;
  }

  // ── Polling status da venda ────────────────────────────────────────────

  /// Consulta o status de uma venda enquanto aguarda o pagamento do QR Code.
  /// Status: 'pendente' | 'aprovado' | 'expirado'
  static Future<String> getSaleStatus(String saleId) async {
    try {
      final res = await http.get(
        Uri.parse('$_base/api/sales/$saleId/status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['status'] as String? ?? 'pendente';
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[WooviService] getSaleStatus error: $e');
    }
    return 'pendente';
  }

  // ── Solicitar Saque (delegado ao WalletService) ────────────────────────
  // O saque é iniciado pelo WalletService.solicitarSaque()
  // que chama POST /api/withdrawals/:id/pay no Worker,
  // que por sua vez chama Woovi /api/v1/subaccount/{pixKey}/withdraw.
  // Veja: wallet_service.dart → _enviarPixWoovi()
}

// ── Modelos de Resposta ───────────────────────────────────────────────────────

class ChargeResult {
  final String saleId;
  final String correlationID;
  final String brCode;          // Copia-e-cola Pix
  final String qrCodeImage;     // URL da imagem do QR Code
  final String paymentLinkUrl;  // Link de pagamento Woovi
  final String expiresAt;       // ISO 8601
  final int totalValue;         // centavos
  final int commissionValue;    // centavos (comissão afiliado)
  final String productName;

  const ChargeResult({
    required this.saleId,
    required this.correlationID,
    required this.brCode,
    required this.qrCodeImage,
    required this.paymentLinkUrl,
    required this.expiresAt,
    required this.totalValue,
    required this.commissionValue,
    required this.productName,
  });

  factory ChargeResult.fromJson(Map<String, dynamic> j) => ChargeResult(
    saleId:          j['saleId']         as String? ?? '',
    correlationID:   j['correlationID']  as String? ?? '',
    brCode:          j['brCode']         as String? ?? '',
    qrCodeImage:     j['qrCodeImage']    as String? ?? '',
    paymentLinkUrl:  j['paymentLinkUrl'] as String? ?? '',
    expiresAt:       j['expiresAt']      as String? ?? '',
    totalValue:      j['totalValue']     as int?    ?? 0,
    commissionValue: j['commissionValue']as int?    ?? 0,
    productName:     j['productName']    as String? ?? '',
  );

  double get totalInReais      => totalValue / 100;
  double get commissionInReais => commissionValue / 100;

  DateTime get expiresAtDate {
    try { return DateTime.parse(expiresAt).toLocal(); }
    catch (_) { return DateTime.now().add(const Duration(hours: 1)); }
  }

  bool get hasQrCode => brCode.isNotEmpty || qrCodeImage.isNotEmpty;
}

class SubscriptionResult {
  final String subscriptionId;         // ID local (D1)
  final String wooviSubscriptionId;    // recurrencyId da Woovi
  final String brCode;                 // QR Code EMV (copia e cola)
  final String qrCodeImage;            // URL imagem QR da 1ª parcela
  final String paymentLinkUrl;         // Link de pagamento Woovi
  final String status;                 // CREATED | APPROVED | REJECTED
  final String globalID;

  const SubscriptionResult({
    required this.subscriptionId,
    required this.wooviSubscriptionId,
    required this.brCode,
    required this.qrCodeImage,
    required this.paymentLinkUrl,
    required this.status,
    required this.globalID,
  });

  factory SubscriptionResult.fromJson(Map<String, dynamic> j) => SubscriptionResult(
    subscriptionId:       j['subscriptionId']      as String? ?? '',
    wooviSubscriptionId:  j['wooviSubscriptionId'] as String? ?? '',
    brCode:               j['brCode']              as String? ?? '',
    qrCodeImage:          j['qrCodeImage']         as String? ?? '',
    paymentLinkUrl:       j['paymentLinkUrl']      as String? ?? '',
    status:               j['status']              as String? ?? 'CREATED',
    globalID:             j['globalID']            as String? ?? '',
  );

  bool get hasQrCode => brCode.isNotEmpty || qrCodeImage.isNotEmpty;
  bool get isApproved => status == 'APPROVED';
}

// WithdrawResult continua sendo definido em subscription_service.dart
