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
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Atualizar',
            onPressed: () => svc.loadAll(),
          ),
        ],
      ),
      body: svc.isLoading
          ? const Center(child: CircularProgressIndicator())
          : m == null
              ? const Center(child: Text('Nenhuma métrica disponível'))
              : RefreshIndicator(
                  onRefresh: svc.loadAll,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // ── Receita ─────────────────────────────────────────
                      _SectionTitle(title: 'Receita'),
                      const SizedBox(height: 8),
                      _MetricsGrid(children: [
                        _MetricCard(
                          label: 'MRR',
                          value: fmt.format(m.mrr),
                          icon: Icons.trending_up_rounded,
                          color: AppColors.success,
                          subtitle: 'Receita recorrente mensal',
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
                      const SizedBox(height: 20),

                      // ── Afiliados ────────────────────────────────────────
                      _SectionTitle(title: 'Afiliados'),
                      const SizedBox(height: 8),
                      _MetricsGrid(children: [
                        _MetricCard(
                          label: 'Total de Afiliados',
                          value: m.totalAfiliados.toString(),
                          icon: Icons.people_rounded,
                          color: AppColors.primary,
                          isNumber: true,
                        ),
                        _MetricCard(
                          label: 'Ativos',
                          value: m.afiliadosAtivos.toString(),
                          icon: Icons.check_circle_rounded,
                          color: AppColors.success,
                          isNumber: true,
                          subtitle:
                              '${m.totalAfiliados > 0 ? ((m.afiliadosAtivos / m.totalAfiliados) * 100).round() : 0}% do total',
                        ),
                      ]),
                      const SizedBox(height: 20),

                      // ── Assinaturas ──────────────────────────────────────
                      _SectionTitle(title: 'Assinaturas'),
                      const SizedBox(height: 8),
                      _MetricsGrid(children: [
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
                      const SizedBox(height: 20),

                      // ── Saques pendentes ─────────────────────────────────
                      if (pendingWithdrawals.isNotEmpty) ...[
                        _SectionTitle(
                          title: 'Saques Pendentes',
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${pendingWithdrawals.length}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...pendingWithdrawals.take(3).map((w) => _PendingWithdrawalTile(
                              withdrawal: w,
                              onTap: () {
                                // Navega para aba de saques
                              },
                            )),
                        if (pendingWithdrawals.length > 3)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              'e mais ${pendingWithdrawals.length - 3} saques pendentes…',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ),
                        const SizedBox(height: 20),
                      ],

                      // ── Resumo comissões ─────────────────────────────────
                      _SummaryCard(metrics: m),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }
}

// ── Seção com título ──────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionTitle({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ── Grid de métricas ──────────────────────────────────────────────────────────
class _MetricsGrid extends StatelessWidget {
  final List<Widget> children;
  const _MetricsGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final crossCount = constraints.maxWidth > 500 ? 4 : 2;
      return GridView.count(
        crossAxisCount: crossCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: constraints.maxWidth > 500 ? 1.4 : 1.5,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: children,
      );
    });
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: isNumber ? 26 : 16,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: TextStyle(
                  color: color.withValues(alpha: 0.8),
                  fontSize: 10),
            ),
        ],
      ),
    );
  }
}

// ── Saque pendente tile ───────────────────────────────────────────────────────
class _PendingWithdrawalTile extends StatelessWidget {
  final AdminWithdrawal withdrawal;
  final VoidCallback onTap;
  const _PendingWithdrawalTile(
      {required this.withdrawal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final ago = DateTime.now().difference(withdrawal.solicitadoEm);
    final agoStr = ago.inHours < 24
        ? 'há ${ago.inHours}h'
        : 'há ${ago.inDays}d';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: ListTile(
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
        title: Text(withdrawal.affiliateNome,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(withdrawal.pixKey,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12)),
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

// ── Card de resumo total ──────────────────────────────────────────────────────
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
              Icon(Icons.bar_chart_rounded, color: AppColors.gold, size: 20),
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
  const _SummaryRow(
      {required this.label,
      required this.value,
      this.isBold = false,
      this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight:
                      isBold ? FontWeight.w700 : FontWeight.normal)),
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
