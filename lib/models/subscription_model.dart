import 'package:flutter/material.dart';
import 'product_model.dart';

// ── Status da assinatura ──────────────────────────────────────────────────────
enum SubscriptionStatus {
  ativa,      // Pix Automático autorizado, pagamentos em dia
  pendente,   // Tentativa de débito falhou (saldo insuficiente, etc.)
  cancelada,  // Usuário cancelou ou plataforma cancelou
  aguardando, // Aguardando autorização do cliente no banco
}

// ── Status do pagamento mensal ────────────────────────────────────────────────
enum PaymentStatus {
  pago,
  pendente,
  falhou,
  processando,
}

// ── Histórico de cobrança mensal ─────────────────────────────────────────────
class SubscriptionPayment {
  final String id;
  final DateTime dataVencimento;
  final DateTime? dataPagamento;
  final double valor;
  final PaymentStatus status;
  final String? motivo; // motivo da falha, se houver

  const SubscriptionPayment({
    required this.id,
    required this.dataVencimento,
    this.dataPagamento,
    required this.valor,
    required this.status,
    this.motivo,
  });

  String get statusLabel {
    switch (status) {
      case PaymentStatus.pago:
        return 'Pago';
      case PaymentStatus.pendente:
        return 'Pendente';
      case PaymentStatus.falhou:
        return 'Recusado';
      case PaymentStatus.processando:
        return 'Processando';
    }
  }

  Color get statusColor {
    switch (status) {
      case PaymentStatus.pago:
        return const Color(0xFF2E7D32);
      case PaymentStatus.pendente:
        return const Color(0xFFF57C00);
      case PaymentStatus.falhou:
        return const Color(0xFFC62828);
      case PaymentStatus.processando:
        return const Color(0xFF1565C0);
    }
  }

  IconData get statusIcon {
    switch (status) {
      case PaymentStatus.pago:
        return Icons.check_circle_rounded;
      case PaymentStatus.pendente:
        return Icons.warning_amber_rounded;
      case PaymentStatus.falhou:
        return Icons.cancel_rounded;
      case PaymentStatus.processando:
        return Icons.sync_rounded;
    }
  }
}

// ── Modelo principal da assinatura ───────────────────────────────────────────
class SubscriptionModel {
  final String id;
  final String productId;
  final String productNome;
  final double valor;
  final double comissao;         // percentual
  final String affiliateCode;    // código do afiliado que indicou
  final String? affiliateNome;
  final SubscriptionStatus status;
  final ChargeType chargeType;
  final DateTime dataInicio;
  final DateTime? dataCancelamento;
  final DateTime proximaCobranca;
  final int diaCobranca;         // dia fixo do mês (ex: 5)
  final String? pixKey;          // chave pix do assinante
  final String? wooviSubscriptionId; // ID da assinatura na Woovi
  final String? motivo;          // motivo de cancelamento ou falha
  final List<SubscriptionPayment> historico;

  const SubscriptionModel({
    required this.id,
    required this.productId,
    required this.productNome,
    required this.valor,
    required this.comissao,
    required this.affiliateCode,
    this.affiliateNome,
    required this.status,
    required this.chargeType,
    required this.dataInicio,
    this.dataCancelamento,
    required this.proximaCobranca,
    this.diaCobranca = 5,
    this.pixKey,
    this.wooviSubscriptionId,
    this.motivo,
    this.historico = const [],
  });

  double get valorComissao => valor * comissao;
  int get comissaoPercent => (comissao * 100).round();
  int get mesesAtivo {
    final now = DateTime.now();
    final diff = now.difference(dataInicio);
    return (diff.inDays / 30).floor();
  }

  double get totalComissoesGeradas => valorComissao * mesesAtivo;

  String get statusLabel {
    switch (status) {
      case SubscriptionStatus.ativa:
        return 'Ativo';
      case SubscriptionStatus.pendente:
        return 'Pendente';
      case SubscriptionStatus.cancelada:
        return 'Cancelado';
      case SubscriptionStatus.aguardando:
        return 'Aguardando';
    }
  }

  Color get statusColor {
    switch (status) {
      case SubscriptionStatus.ativa:
        return const Color(0xFF2E7D32);
      case SubscriptionStatus.pendente:
        return const Color(0xFFF57C00);
      case SubscriptionStatus.cancelada:
        return const Color(0xFFC62828);
      case SubscriptionStatus.aguardando:
        return const Color(0xFF1565C0);
    }
  }

  IconData get statusIcon {
    switch (status) {
      case SubscriptionStatus.ativa:
        return Icons.check_circle_rounded;
      case SubscriptionStatus.pendente:
        return Icons.warning_amber_rounded;
      case SubscriptionStatus.cancelada:
        return Icons.cancel_rounded;
      case SubscriptionStatus.aguardando:
        return Icons.hourglass_top_rounded;
    }
  }

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    SubscriptionStatus st = SubscriptionStatus.ativa;
    if (json['status'] == 'pendente') st = SubscriptionStatus.pendente;
    if (json['status'] == 'cancelada') st = SubscriptionStatus.cancelada;
    if (json['status'] == 'aguardando') st = SubscriptionStatus.aguardando;

    ChargeType ct = ChargeType.pixAutomatico;
    if (json['chargeType'] == 'pixAvulso') ct = ChargeType.pixAvulso;

    return SubscriptionModel(
      id: json['id']?.toString() ?? '',
      productId: json['productId']?.toString() ?? '',
      productNome: json['productNome'] ?? '',
      valor: (json['valor'] ?? 0).toDouble(),
      comissao: (json['comissao'] ?? 0).toDouble(),
      affiliateCode: json['affiliateCode'] ?? '',
      affiliateNome: json['affiliateNome'],
      status: st,
      chargeType: ct,
      dataInicio: DateTime.tryParse(json['dataInicio'] ?? '') ?? DateTime.now(),
      dataCancelamento: json['dataCancelamento'] != null
          ? DateTime.tryParse(json['dataCancelamento'])
          : null,
      proximaCobranca:
          DateTime.tryParse(json['proximaCobranca'] ?? '') ?? DateTime.now(),
      diaCobranca: json['diaCobranca'] ?? 5,
      pixKey: json['pixKey'],
      wooviSubscriptionId: json['wooviSubscriptionId'],
      motivo: json['motivo'],
    );
  }

  // ── Mock para demonstração ────────────────────────────────────────────────
  static List<SubscriptionModel> get mockSubscriptions => [
        SubscriptionModel(
          id: 'sub_001',
          productId: '1',
          productNome: 'Seguro Motoboy',
          valor: 10.00,
          comissao: 0.20,
          affiliateCode: 'ABC123',
          affiliateNome: 'João Silva',
          status: SubscriptionStatus.ativa,
          chargeType: ChargeType.pixAutomatico,
          dataInicio: DateTime.now().subtract(const Duration(days: 95)),
          proximaCobranca: DateTime(
              DateTime.now().year, DateTime.now().month + 1, 5),
          diaCobranca: 5,
          pixKey: 'carlos.motoboy@gmail.com',
          historico: [
            SubscriptionPayment(
              id: 'pay_003',
              dataVencimento: DateTime(
                  DateTime.now().year, DateTime.now().month, 5),
              dataPagamento: DateTime(
                  DateTime.now().year, DateTime.now().month, 5),
              valor: 10.00,
              status: PaymentStatus.pago,
            ),
            SubscriptionPayment(
              id: 'pay_002',
              dataVencimento: DateTime(
                  DateTime.now().year, DateTime.now().month - 1, 5),
              dataPagamento: DateTime(
                  DateTime.now().year, DateTime.now().month - 1, 5),
              valor: 10.00,
              status: PaymentStatus.pago,
            ),
            SubscriptionPayment(
              id: 'pay_001',
              dataVencimento: DateTime(
                  DateTime.now().year, DateTime.now().month - 2, 5),
              dataPagamento: DateTime(
                  DateTime.now().year, DateTime.now().month - 2, 5),
              valor: 10.00,
              status: PaymentStatus.pago,
            ),
          ],
        ),
        SubscriptionModel(
          id: 'sub_002',
          productId: '3',
          productNome: 'Clube de Benefícios',
          valor: 19.90,
          comissao: 0.30,
          affiliateCode: 'ABC123',
          affiliateNome: 'Maria Souza',
          status: SubscriptionStatus.pendente,
          chargeType: ChargeType.pixAutomatico,
          dataInicio: DateTime.now().subtract(const Duration(days: 40)),
          proximaCobranca: DateTime(
              DateTime.now().year, DateTime.now().month + 1, 5),
          diaCobranca: 5,
          pixKey: 'maria.souza@email.com',
          motivo: 'Saldo insuficiente',
          historico: [
            SubscriptionPayment(
              id: 'pay_005',
              dataVencimento: DateTime(
                  DateTime.now().year, DateTime.now().month, 5),
              valor: 19.90,
              status: PaymentStatus.falhou,
              motivo: 'Pix Automático recusado — Saldo insuficiente',
            ),
            SubscriptionPayment(
              id: 'pay_004',
              dataVencimento: DateTime(
                  DateTime.now().year, DateTime.now().month - 1, 5),
              dataPagamento: DateTime(
                  DateTime.now().year, DateTime.now().month - 1, 5),
              valor: 19.90,
              status: PaymentStatus.pago,
            ),
          ],
        ),
      ];
}
