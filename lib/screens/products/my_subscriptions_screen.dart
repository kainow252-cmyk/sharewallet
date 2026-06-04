import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/subscription_model.dart';
import '../../models/product_model.dart';
import '../../services/subscription_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
// ignore: unused_import
import '../../widgets/app_widgets.dart';
import 'subscription_detail_screen.dart';

class MySubscriptionsScreen extends StatefulWidget {
  const MySubscriptionsScreen({super.key});

  @override
  State<MySubscriptionsScreen> createState() => _MySubscriptionsScreenState();
}

class _MySubscriptionsScreenState extends State<MySubscriptionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthService>();
      context
          .read<SubscriptionService>()
          .loadSubscriptions(auth.currentUser?.affiliateCode ?? '');
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<SubscriptionService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Minhas Assinaturas'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.gold,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(
                text:
                    'Ativas (${svc.totalAtivas})'),
            Tab(
                text:
                    'Pendentes (${svc.totalPendentes})'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Resumo de comissões ────────────────────────────────────────────
          _CommissionSummary(svc: svc),

          // ── Tabs ──────────────────────────────────────────────────────────
          Expanded(
            child: svc.isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary))
                : TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _SubscriptionList(
                          subscriptions: svc.ativas,
                          emptyMessage: 'Nenhuma assinatura ativa',
                          emptyIcon: Icons.subscriptions_outlined),
                      _SubscriptionList(
                          subscriptions: svc.pendentes,
                          emptyMessage: 'Nenhuma assinatura pendente',
                          emptyIcon: Icons.check_circle_outline_rounded),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Resumo de comissões ───────────────────────────────────────────────────────

class _CommissionSummary extends StatelessWidget {
  final SubscriptionService svc;
  const _CommissionSummary({required this.svc});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.darkGreenGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Comissões Recorrentes',
              style: TextStyle(
                  color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            fmt.format(svc.comissoesMensaisRecorrentes),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900),
          ),
          const Text('por mês (estimado)',
              style: TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatChip(
                  icon: Icons.subscriptions_rounded,
                  label: '${svc.totalAtivas}',
                  sub: 'assinaturas ativas'),
              const SizedBox(width: 8),
              _StatChip(
                  icon: Icons.account_balance_wallet_rounded,
                  label: fmt.format(svc.saldoDisponivel),
                  sub: 'disponível para saque'),
              const SizedBox(width: 8),
              _StatChip(
                  icon: Icons.warning_amber_rounded,
                  label: '${svc.totalPendentes}',
                  sub: 'pendentes',
                  color: svc.totalPendentes > 0
                      ? AppColors.warning
                      : Colors.white70),
            ],
          ),
          // Barra de progresso para saque mínimo
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Meta para saque',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 11)),
                        Text(
                          'R\$ ${SubscriptionService.saqueMinimo.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (svc.saldoDisponivel /
                                SubscriptionService.saqueMinimo)
                            .clamp(0.0, 1.0),
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation(
                          svc.podeSacar ? AppColors.gold : Colors.white70,
                        ),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      svc.podeSacar
                          ? '✅ Saldo suficiente — você pode sacar agora!'
                          : 'Faltam R\$ ${(SubscriptionService.saqueMinimo - svc.saldoDisponivel).toStringAsFixed(2).replaceAll('.', ',')} para o saque mínimo',
                      style: TextStyle(
                          color: svc.podeSacar
                              ? AppColors.gold
                              : Colors.white60,
                          fontSize: 11,
                          fontWeight: svc.podeSacar
                              ? FontWeight.w700
                              : FontWeight.normal),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color? color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.sub,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color ?? Colors.white70, size: 14),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    color: color ?? Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
            Text(sub,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white60, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

// ── Lista de assinaturas ──────────────────────────────────────────────────────

class _SubscriptionList extends StatelessWidget {
  final List<SubscriptionModel> subscriptions;
  final String emptyMessage;
  final IconData emptyIcon;

  const _SubscriptionList({
    required this.subscriptions,
    required this.emptyMessage,
    required this.emptyIcon,
  });

  @override
  Widget build(BuildContext context) {
    if (subscriptions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, color: AppColors.textHint, size: 56),
            const SizedBox(height: 12),
            Text(emptyMessage,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
            const SizedBox(height: 6),
            const Text(
              'Compartilhe seus produtos para atrair assinantes',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textHint, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: subscriptions.length,
      itemBuilder: (ctx, i) =>
          _SubscriptionCard(subscription: subscriptions[i]),
    );
  }
}

// ── Card de assinatura ────────────────────────────────────────────────────────

class _SubscriptionCard extends StatefulWidget {
  final SubscriptionModel subscription;
  const _SubscriptionCard({required this.subscription});

  @override
  State<_SubscriptionCard> createState() => _SubscriptionCardState();
}

class _SubscriptionCardState extends State<_SubscriptionCard> {
  bool _showHistory = false;

  @override
  Widget build(BuildContext context) {
    final sub = widget.subscription;
    final months = ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];
    final proxima =
        '${sub.proximaCobranca.day.toString().padLeft(2,'0')}/${months[sub.proximaCobranca.month - 1]}/${sub.proximaCobranca.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: sub.status == SubscriptionStatus.pendente
              ? AppColors.warning.withValues(alpha: 0.5)
              : AppColors.cardBorder,
          width: sub.status == SubscriptionStatus.pendente ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar inicial
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: sub.statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      sub.affiliateNome?.substring(0, 1).toUpperCase() ?? 'C',
                      style: TextStyle(
                          color: sub.statusColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sub.affiliateNome ?? 'Cliente',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.textPrimary),
                      ),
                      Text(
                        sub.productNome,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary),
                      ),
                      if (sub.pixKey != null)
                        Text(
                          sub.pixKey!,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textHint),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // Badge status
                _StatusBadge(sub: sub),
              ],
            ),
          ),

          // ── Info da assinatura ───────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                // Aviso de pendência
                if (sub.status == SubscriptionStatus.pendente &&
                    sub.motivo != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color:
                              AppColors.warning.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: AppColors.warning, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            sub.motivo!,
                            style: const TextStyle(
                                color: AppColors.warning,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),

                Row(
                  children: [
                    Expanded(
                      child: _InfoRow(
                        label: 'Valor',
                        value:
                            'R\$ ${sub.valor.toStringAsFixed(2).replaceAll('.', ',')}',
                        valueColor: AppColors.textPrimary,
                      ),
                    ),
                    Expanded(
                      child: _InfoRow(
                        label: 'Sua comissão',
                        value: sub.valorComissao
                            .toStringAsFixed(2)
                            .replaceAll('.', ','),
                        prefix: 'R\$ ',
                        valueColor: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _InfoRow(
                        label: 'Próxima cobrança',
                        value: proxima,
                      ),
                    ),
                    Expanded(
                      child: _InfoRow(
                        label: 'Forma',
                        value: sub.chargeType == ChargeType.pixAutomatico
                            ? 'Pix Automático'
                            : 'Pix Avulso',
                        valueColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Histórico de pagamentos ──────────────────────────────────────────
          if (sub.historico.isNotEmpty) ...[
            GestureDetector(
              onTap: () => setState(() => _showHistory = !_showHistory),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded,
                        color: AppColors.primary, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Histórico (${sub.historico.length} cobranças)',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Icon(
                      _showHistory
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: AppColors.primary,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
            if (_showHistory)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                child: Column(
                  children: sub.historico
                      .map((pay) => _PaymentRow(payment: pay))
                      .toList(),
                ),
              ),
          ],

          // ── Botão Ver Detalhes Completos ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SubscriptionDetailScreen(subscription: sub),
                    ),
                  );
                },
                icon: const Icon(Icons.receipt_long_rounded, size: 16),
                label: const Text('Ver Histórico de Cobranças',
                    style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final SubscriptionModel sub;
  const _StatusBadge({required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: sub.statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: sub.statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(sub.statusIcon, color: sub.statusColor, size: 12),
          const SizedBox(width: 4),
          Text(
            sub.statusLabel,
            style: TextStyle(
                color: sub.statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final String? prefix;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.prefix,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: AppColors.textHint)),
        const SizedBox(height: 2),
        Text(
          '${prefix ?? ''}$value',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary),
        ),
      ],
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final SubscriptionPayment payment;
  const _PaymentRow({required this.payment});

  @override
  Widget build(BuildContext context) {
    final months = ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];
    final data =
        '${payment.dataVencimento.day.toString().padLeft(2,'0')}/${months[payment.dataVencimento.month - 1]}/${payment.dataVencimento.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(payment.statusIcon, color: payment.statusColor, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600)),
                if (payment.motivo != null)
                  Text(payment.motivo!,
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.error)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'R\$ ${payment.valor.toStringAsFixed(2).replaceAll('.', ',')}',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: payment.statusColor),
              ),
              Text(
                payment.statusLabel,
                style: TextStyle(
                    fontSize: 10, color: payment.statusColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
