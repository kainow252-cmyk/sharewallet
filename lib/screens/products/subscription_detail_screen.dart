import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/subscription_model.dart';
import '../../models/product_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

/// Tela de Detalhes da Assinatura com histórico completo de cobranças.
class SubscriptionDetailScreen extends StatefulWidget {
  final SubscriptionModel subscription;

  const SubscriptionDetailScreen({
    super.key,
    required this.subscription,
  });

  @override
  State<SubscriptionDetailScreen> createState() =>
      _SubscriptionDetailScreenState();
}

class _SubscriptionDetailScreenState extends State<SubscriptionDetailScreen> {
  List<_ChargeRecord> _charges = [];
  bool _isLoading = true;

  final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCharges());
  }

  Future<void> _loadCharges() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final db = FirestoreService.db;
      if (db != null) {
        final snap = await db
            .collection('subscription_charges')
            .where('subscription_id', isEqualTo: widget.subscription.id)
            .get();

        final list = snap.docs.map((doc) {
          final d = doc.data();
          return _ChargeRecord(
            id: doc.id,
            valor: FirestoreService.toDouble(d['valor']),
            dataVencimento: FirestoreService.toDateTimeOrNow(d['data_vencimento']),
            dataPagamento: FirestoreService.toDateTime(d['data_pagamento']),
            status: FirestoreService.toStr(d['status'], fallback: 'pendente'),
            metodo: FirestoreService.toStr(d['metodo'], fallback: 'pix'),
            txId: d['tx_id'] as String?,
          );
        }).toList();

        // Ordenar do mais recente ao mais antigo
        list.sort((a, b) => b.dataVencimento.compareTo(a.dataVencimento));

        setState(() {
          _charges = list;
          _isLoading = false;
        });
      } else {
        // Demo: gerar histórico simulado
        setState(() {
          _charges = _generateDemoCharges();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _charges = _generateDemoCharges();
        _isLoading = false;
      });
    }
  }

  List<_ChargeRecord> _generateDemoCharges() {
    final sub = widget.subscription;
    final now = DateTime.now();
    return List.generate(6, (i) {
      final venc = DateTime(now.year, now.month - i, sub.diaCobranca);
      final isPago = i > 0; // O mais recente pode estar pendente
      return _ChargeRecord(
        id: 'charge_$i',
        valor: sub.valor,
        dataVencimento: venc,
        dataPagamento: isPago ? venc.add(const Duration(hours: 2)) : null,
        status: isPago ? 'pago' : 'pendente',
        metodo: 'pix_automatico',
        txId: isPago ? 'TXN${1000000 + i}' : null,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.subscription;
    final totalPago = _charges
        .where((c) => c.status == 'pago')
        .fold(0.0, (s, c) => s + c.valor);
    final totalComissao = totalPago * widget.subscription.comissao;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── AppBar flexível com gradiente ──────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF083D29), Color(0xFF0D5C3D)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: sub.statusColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: sub.statusColor.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(sub.statusIcon,
                                  color: sub.statusColor, size: 12),
                              const SizedBox(width: 5),
                              Text(
                                sub.statusLabel,
                                style: TextStyle(
                                    color: sub.statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          sub.productNome,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.person_rounded,
                                color: Colors.white60, size: 13),
                            const SizedBox(width: 5),
                            Text(
                              sub.affiliateNome ?? 'Cliente',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.pix_rounded,
                                color: Color(0xFF32BCAD), size: 13),
                            const SizedBox(width: 5),
                            Text(
                              _currency.format(sub.valor),
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Cards de resumo ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Métricas em grid 2x2
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          label: 'Cobranças pagas',
                          value:
                              '${_charges.where((c) => c.status == 'pago').length}',
                          icon: Icons.check_circle_outline_rounded,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricCard(
                          label: 'Total recebido',
                          value: _currency.format(totalPago),
                          icon: Icons.attach_money_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          label: 'Próx. cobrança',
                          value: DateFormat('dd/MM/yyyy', 'pt_BR').format(sub.proximaCobranca),
                          icon: Icons.event_rounded,
                          color: AppColors.info,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricCard(
                          label: 'Sua comissão total',
                          value: _currency.format(totalComissao),
                          icon: Icons.monetization_on_rounded,
                          color: AppColors.gold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Detalhes da assinatura
                  _SubscriptionInfoCard(sub: sub, dateFormat: _dateFormat),

                  const SizedBox(height: 20),

                  // Cabeçalho histórico
                  Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded,
                          color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Histórico de Cobranças',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_charges.length} registros',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textHint),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // ── Lista histórico de cobranças ─────────────────────────────
          if (_isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary)),
              ),
            )
          else if (_charges.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.receipt_outlined,
                          size: 48, color: AppColors.textHint),
                      SizedBox(height: 12),
                      Text(
                        'Nenhum histórico disponível',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _ChargeItem(
                    charge: _charges[i],
                    valor: _charges[i].valor,
                    currency: _currency,
                    dateFormat: _dateFormat,
                    isFirst: i == 0,
                    isLast: i == _charges.length - 1,
                  ),
                  childCount: _charges.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Modelo interno de cobrança ────────────────────────────────────────────────

class _ChargeRecord {
  final String id;
  final double valor;
  final DateTime dataVencimento;
  final DateTime? dataPagamento;
  final String status; // pago, pendente, falhou, processando
  final String metodo;
  final String? txId;

  const _ChargeRecord({
    required this.id,
    required this.valor,
    required this.dataVencimento,
    this.dataPagamento,
    required this.status,
    required this.metodo,
    this.txId,
  });

  Color get statusColor {
    switch (status) {
      case 'pago':
        return AppColors.success;
      case 'pendente':
        return AppColors.warning;
      case 'falhou':
        return AppColors.error;
      case 'processando':
        return AppColors.info;
      default:
        return AppColors.textHint;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case 'pago':
        return Icons.check_circle_rounded;
      case 'pendente':
        return Icons.schedule_rounded;
      case 'falhou':
        return Icons.cancel_rounded;
      case 'processando':
        return Icons.sync_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'pago':
        return 'Pago';
      case 'pendente':
        return 'Pendente';
      case 'falhou':
        return 'Recusado';
      case 'processando':
        return 'Processando';
      default:
        return status;
    }
  }
}

// ── Widget: Card de métrica ───────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}

// ── Widget: Informações da assinatura ────────────────────────────────────────

class _SubscriptionInfoCard extends StatelessWidget {
  final SubscriptionModel sub;
  final DateFormat dateFormat;

  const _SubscriptionInfoCard(
      {required this.sub, required this.dateFormat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: AppColors.primary, size: 16),
              SizedBox(width: 8),
              Text(
                'Detalhes da Assinatura',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary),
              ),
            ],
          ),
          const Divider(height: 20),
          _InfoRow(
            icon: Icons.calendar_today_rounded,
            label: 'Iniciada em',
            value: dateFormat.format(sub.dataInicio),
          ),
          _InfoRow(
            icon: Icons.pix_rounded,
            label: 'Método',
            value: sub.chargeType == ChargeType.pixRecorrente
                ? 'Pix Recorrente'
                : 'Pix Único',
            valueColor: const Color(0xFF32BCAD),
          ),
          _InfoRow(
            icon: Icons.tag_rounded,
            label: 'Código afiliado',
            value: sub.affiliateCode,
          ),
          if (sub.pixKey != null && sub.pixKey!.isNotEmpty)
            _InfoRow(
              icon: Icons.key_rounded,
              label: 'Chave PIX',
              value: sub.pixKey!,
            ),
          _InfoRow(
            icon: Icons.percent_rounded,
            label: 'Comissão',
            value: '${sub.comissaoPercent}% — R\$ ${sub.valorComissao.toStringAsFixed(2)}/mês',
            valueColor: AppColors.gold,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textHint, size: 15),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widget: Item de cobrança no histórico ─────────────────────────────────────

class _ChargeItem extends StatelessWidget {
  final _ChargeRecord charge;
  final double valor;
  final NumberFormat currency;
  final DateFormat dateFormat;
  final bool isFirst;
  final bool isLast;

  const _ChargeItem({
    required this.charge,
    required this.valor,
    required this.currency,
    required this.dateFormat,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final comissao = valor * 0.20;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Timeline linha vertical ──────────────────────────────────
        SizedBox(
          width: 32,
          child: Column(
            children: [
              // Ponto do timeline
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: charge.statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: charge.statusColor.withValues(alpha: 0.4),
                      width: 1.5),
                ),
                child: Icon(charge.statusIcon,
                    color: charge.statusColor, size: 14),
              ),
              // Linha conectora (exceto último)
              if (!isLast)
                Container(
                  width: 2,
                  height: 60,
                  color: AppColors.cardBorder,
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // ── Conteúdo da cobrança ─────────────────────────────────────
        Expanded(
          child: Container(
            margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isFirst
                    ? charge.statusColor.withValues(alpha: 0.3)
                    : AppColors.cardBorder,
                width: isFirst ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Mês/Ano
                    Expanded(
                      child: Text(
                        DateFormat('MMMM yyyy', 'pt_BR')
                            .format(charge.dataVencimento)
                            .toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: charge.statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        charge.statusLabel,
                        style: TextStyle(
                          color: charge.statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Valor principal
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Valor',
                            style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textHint)),
                        Text(
                          currency.format(valor),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    // Sua comissão
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sua comissão',
                            style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textHint)),
                        Text(
                          currency.format(comissao),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Datas
                Row(
                  children: [
                    _DateChip(
                      label: 'Vencimento',
                      date: dateFormat.format(charge.dataVencimento),
                      icon: Icons.event_rounded,
                    ),
                    if (charge.dataPagamento != null) ...[
                      const SizedBox(width: 8),
                      _DateChip(
                        label: 'Pago em',
                        date: dateFormat.format(charge.dataPagamento!),
                        icon: Icons.check_rounded,
                        color: AppColors.success,
                      ),
                    ],
                  ],
                ),
                // TxID se disponível
                if (charge.txId != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.tag_rounded,
                          size: 12, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text(
                        'TX: ${charge.txId}',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textHint),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final String date;
  final IconData icon;
  final Color? color;

  const _DateChip({
    required this.label,
    required this.date,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textHint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: c),
          const SizedBox(width: 4),
          Text(
            '$label: $date',
            style: TextStyle(
                fontSize: 10, color: c, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
