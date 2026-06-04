import 'api_service.dart';

/// Serviço Flutter para integração Woovi via backend NestJS.
///
/// ⚠️  IMPORTANTE: O app Flutter NUNCA fala diretamente com a Woovi API.
///    Todas as chamadas passam pelo backend NestJS que detém o AppID.
///
/// Fluxo:
///   Flutter → POST /api/sales/charge → NestJS → Woovi API
///   Woovi Webhook → NestJS → atualiza banco → Flutter polling/push
class WooviService {

  // ─── Criar Cobrança PIX ────────────────────────────────────────────────────

  /// Cria uma cobrança PIX com split automático para o afiliado.
  /// Retorna o QR Code para exibir na tela de pagamento.
  static Future<ChargeResult?> createCharge({
    required String affiliateCode,
    required String productId,
    required String customerName,
    required String customerEmail,
    required String customerCpf,
    String? customerPhone,
  }) async {
    final response = await ApiService.post('/sales/charge', {
      'affiliateCode': affiliateCode,
      'productId': productId,
      'customerName': customerName,
      'customerEmail': customerEmail,
      'customerCpf': customerCpf,
      if (customerPhone != null) 'customerPhone': customerPhone,
    });

    if (response.success && response.data != null) {
      return ChargeResult.fromJson(response.data);
    }
    return null;
  }

  // ─── Polling de status do pagamento ───────────────────────────────────────

  /// Consulta o status de uma venda (polling enquanto exibe o QR Code).
  /// Status: PENDING | PAID | EXPIRED
  static Future<String> getSaleStatus(String saleId) async {
    final response = await ApiService.get('/sales/$saleId/status');
    if (response.success) {
      return response.data['status'] as String? ?? 'PENDING';
    }
    return 'PENDING';
  }

  // ─── Solicitar Saque ───────────────────────────────────────────────────────

  /// Solicita o saque integral do saldo disponível.
  /// O backend chama Woovi → PIX enviado para a chave cadastrada.
  static Future<WithdrawResult> requestWithdraw() async {
    final response = await ApiService.post('/withdrawals/request', {});

    if (response.success) {
      return WithdrawResult(
        success: true,
        message: response.data['message'] ?? 'Saque em processamento!',
        value: (response.data['valueInReais'] as num?)?.toDouble() ?? 0,
        pixKey: response.data['pixKey'] as String?,
      );
    }

    return WithdrawResult(
      success: false,
      message: response.errorMessage ?? 'Erro ao solicitar saque',
    );
  }

  // ─── Atualizar Chave PIX ───────────────────────────────────────────────────

  /// Atualiza a chave PIX do afiliado para recebimento de comissões.
  static Future<bool> updatePixKey({
    required String pixKey,
    required String pixKeyType,
  }) async {
    final response = await ApiService.put('/affiliates/pix-key', {
      'pixKey': pixKey,
      'pixKeyType': pixKeyType,
    });
    return response.success;
  }

  // ─── Sincronizar Saldo com Woovi ──────────────────────────────────────────

  /// Consulta o saldo real na Woovi e sincroniza com o banco local.
  static Future<double?> syncBalance() async {
    final response = await ApiService.get('/affiliates/balance/sync');
    if (response.success && response.data['synced'] == true) {
      return (response.data['balanceInReais'] as num?)?.toDouble();
    }
    return null;
  }

  // ─── Dashboard do Afiliado ────────────────────────────────────────────────

  /// Carrega dados do dashboard: saldo, estatísticas, etc.
  static Future<Map<String, dynamic>?> getDashboard() async {
    final response = await ApiService.get('/affiliates/dashboard');
    if (response.success) {
      return response.data as Map<String, dynamic>;
    }
    return null;
  }
}

// ─── Modelos de Resposta ──────────────────────────────────────────────────────

class ChargeResult {
  final String saleId;
  final String brCode;         // Código PIX copia-e-cola
  final String qrCodeImage;    // URL da imagem do QR Code
  final String paymentLinkUrl; // Link de pagamento Woovi
  final String expiresAt;      // Data de expiração ISO 8601
  final int totalValue;        // Valor total em centavos
  final int commissionValue;   // Comissão do afiliado em centavos
  final String productName;

  ChargeResult({
    required this.saleId,
    required this.brCode,
    required this.qrCodeImage,
    required this.paymentLinkUrl,
    required this.expiresAt,
    required this.totalValue,
    required this.commissionValue,
    required this.productName,
  });

  factory ChargeResult.fromJson(Map<String, dynamic> json) {
    return ChargeResult(
      saleId: json['saleId'] as String? ?? '',
      brCode: json['brCode'] as String? ?? '',
      qrCodeImage: json['qrCodeImage'] as String? ?? '',
      paymentLinkUrl: json['paymentLinkUrl'] as String? ?? '',
      expiresAt: json['expiresAt'] as String? ?? '',
      totalValue: json['totalValue'] as int? ?? 0,
      commissionValue: json['commissionValue'] as int? ?? 0,
      productName: json['productName'] as String? ?? '',
    );
  }

  double get totalValueInReais => totalValue / 100;
  double get commissionInReais => commissionValue / 100;

  DateTime get expiresAtDate {
    try {
      return DateTime.parse(expiresAt).toLocal();
    } catch (_) {
      return DateTime.now().add(const Duration(hours: 1));
    }
  }
}

class WithdrawResult {
  final bool success;
  final String message;
  final double value;
  final String? pixKey;

  WithdrawResult({
    required this.success,
    required this.message,
    this.value = 0,
    this.pixKey,
  });
}
