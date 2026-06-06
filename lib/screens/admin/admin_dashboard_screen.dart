import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<AdminService>();
    final m = svc.metrics;
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final pendingWithdrawals =
        svc.withdrawals.where((w) => w.status == 'pendente').toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: svc.isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : m == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bar_chart_rounded,
                          size: 48, color: AppColors.textHint),
                      const SizedBox(height: 12),
                      const Text('Nenhuma métrica disponível',
                          style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: svc.loadAll,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: svc.loadAll,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      // ── Header com botão refresh ───────────────────────────
                      _DashboardHeader(onRefresh: svc.loadAll),
                      const SizedBox(height: 20),

                      // ── Receita ────────────────────────────────────────────
                      _SectionTitle(title: 'Receita'),
                      const SizedBox(height: 10),
                      _TwoColumnGrid(children: [
                        _MetricCard(
                          label: 'MRR',
                          value: fmt.format(m.mrr),
                          icon: Icons.trending_up_rounded,
                          color: AppColors.success,
                          subtitle: 'Receita recorrente',
                        ),
                        _MetricCard(
                          label: 'Receita do Mês',
                          value: fmt.format(m.receitaMes),
                          icon: Icons.calendar_month_rounded,
                          color: AppColors.primary,
                          subtitle: 'Mês atual',
                        ),
                        _MetricCard(
                          label: 'Receita Total',
                          value: fmt.format(m.receitaTotal),
                          icon: Icons.attach_money_rounded,
                          color: AppColors.gold,
                          subtitle: 'Desde o início',
                        ),
                        _MetricCard(
                          label: 'Comissões do Mês',
                          value: fmt.format(m.comissoesMes),
                          icon: Icons.handshake_rounded,
                          color: AppColors.info,
                          subtitle: 'Pagas a afiliados',
                        ),
                      ]),
                      const SizedBox(height: 24),

                      // ── Afiliados ──────────────────────────────────────────
                      _SectionTitle(title: 'Afiliados'),
                      const SizedBox(height: 10),
                      _TwoColumnGrid(children: [
                        _MetricCard(
                          label: 'Total de Afiliados',
                          value: m.totalAfiliados.toString(),
                          icon: Icons.people_rounded,
                          color: AppColors.primary,
                          isNumber: true,
                        ),
                        _MetricCard(
                          label: 'Afiliados Ativos',
                          value: m.afiliadosAtivos.toString(),
                          icon: Icons.check_circle_rounded,
                          color: AppColors.success,
                          isNumber: true,
                          subtitle: m.totalAfiliados > 0
                              ? '${((m.afiliadosAtivos / m.totalAfiliados) * 100).round()}% do total'
                              : null,
                        ),
                      ]),
                      const SizedBox(height: 24),

                      // ── Assinaturas ────────────────────────────────────────
                      _SectionTitle(title: 'Assinaturas'),
                      const SizedBox(height: 10),
                      _TwoColumnGrid(children: [
                        _MetricCard(
                          label: 'Total',
                          value: m.totalAssinaturas.toString(),
                          icon: Icons.repeat_rounded,
                          color: AppColors.primary,
                          isNumber: true,
                        ),
                        _MetricCard(
                          label: 'Ativas',
                          value: m.assinaturasAtivas.toString(),
                          icon: Icons.check_circle_rounded,
                          color: AppColors.success,
                          isNumber: true,
                        ),
                        _MetricCard(
                          label: 'Pendentes',
                          value: m.assinaturasPendentes.toString(),
                          icon: Icons.hourglass_empty_rounded,
                          color: AppColors.warning,
                          isNumber: true,
                        ),
                      ]),
                      const SizedBox(height: 24),

                      // ── Saques pendentes ───────────────────────────────────
                      if (pendingWithdrawals.isNotEmpty) ...[
                        _SectionTitle(
                          title: 'Saques Pendentes',
                          trailing: _BadgeCount(
                              count: pendingWithdrawals.length),
                        ),
                        const SizedBox(height: 10),
                        ...pendingWithdrawals.take(3).map(
                              (w) => _PendingWithdrawalTile(
                                withdrawal: w,
                                onTap: () {},
                              ),
                            ),
                        if (pendingWithdrawals.length > 3)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              'e mais ${pendingWithdrawals.length - 3} saques pendentes…',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13),
                            ),
                          ),
                        const SizedBox(height: 24),
                      ],

                      // ── Resumo financeiro ──────────────────────────────────
                      _SummaryCard(metrics: m),
                    ],
                  ),
                ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _DashboardHeader extends StatelessWidget {
  final VoidCallback onRefresh;
  const _DashboardHeader({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: AppColors.greenGradient,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.dashboard_rounded,
              color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Visão geral do negócio',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Atualizar',
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.cardBorder),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Título de seção ───────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionTitle({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ── Badge contador ────────────────────────────────────────────────────────────
class _BadgeCount extends StatelessWidget {
  final int count;
  const _BadgeCount({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Grid de 2 colunas ─────────────────────────────────────────────────────────
class _TwoColumnGrid extends StatelessWidget {
  final List<Widget> children;
  const _TwoColumnGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    // Divide em pares de 2 para montar rows
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      final left = children[i];
      final right = i + 1 < children.length ? children[i + 1] : const SizedBox();
      rows.add(
        Row(
          children: [
            Expanded(child: left),
            const SizedBox(width: 10),
            Expanded(child: right),
          ],
        ),
      );
      if (i + 2 < children.length) {
        rows.add(const SizedBox(height: 10));
      }
    }
    return Column(children: rows);
  }
}

// ── Card de métrica ───────────────────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final bool isNumber;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.isNumber = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ícone
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(height: 10),
          // Valor principal
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: isNumber ? 28 : 17,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Label
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          // Subtitle opcional
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: TextStyle(
                color: color.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Tile de saque pendente ────────────────────────────────────────────────────
class _PendingWithdrawalTile extends StatelessWidget {
  final AdminWithdrawal withdrawal;
  final VoidCallback onTap;
  const _PendingWithdrawalTile(
      {required this.withdrawal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final ago = DateTime.now().difference(withdrawal.solicitadoEm);
    final agoStr =
        ago.inHours < 24 ? 'há ${ago.inHours}h' : 'há ${ago.inDays}d';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.account_balance_wallet_rounded,
              color: AppColors.warning, size: 20),
        ),
        title: Text(
          withdrawal.affiliateNome,
          style:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          withdrawal.pixKey,
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              fmt.format(withdrawal.valor),
              style: const TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w700,
                  fontSize: 14),
            ),
            Text(agoStr,
                style: const TextStyle(
                    color: AppColors.textHint, fontSize: 11)),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

// ── Card resumo financeiro ────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final AdminMetrics metrics;
  const _SummaryCard({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.darkGreenGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart_rounded,
                  color: AppColors.gold, size: 20),
              SizedBox(width: 8),
              Text(
                'Resumo Financeiro',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SummaryRow(
              label: 'Receita Total',
              value: fmt.format(metrics.receitaTotal)),
          _SummaryRow(
              label: 'Comissões Pagas',
              value: fmt.format(metrics.comissoesTotal)),
          _SummaryRow(
              label: 'Saques Pendentes',
              value: fmt.format(metrics.valorSaquesPendentes),
              highlight: metrics.valorSaquesPendentes > 0),
          const Divider(color: Colors.white24, height: 20),
          _SummaryRow(
            label: 'Lucro Líquido',
            value: fmt.format(
                metrics.receitaTotal - metrics.comissoesTotal),
            isBold: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final bool highlight;
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight:
                    isBold ? FontWeight.w700 : FontWeight.normal),
          ),
          Text(
            value,
            style: TextStyle(
              color: highlight
                  ? AppColors.warning
                  : isBold
                      ? AppColors.gold
                      : Colors.white,
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
