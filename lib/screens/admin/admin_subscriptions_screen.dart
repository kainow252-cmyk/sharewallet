import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/admin_service.dart';
import '../../models/subscription_model.dart';
import '../../models/product_model.dart';
import '../../theme/app_theme.dart';

class AdminSubscriptionsScreen extends StatefulWidget {
  const AdminSubscriptionsScreen({super.key});

  @override
  State<AdminSubscriptionsScreen> createState() =>
      _AdminSubscriptionsScreenState();
}

class _AdminSubscriptionsScreenState extends State<AdminSubscriptionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<SubscriptionModel> _filtered(
      List<SubscriptionModel> all, SubscriptionStatus? status) {
    return all.where((s) {
      final matchStatus = status == null || s.status == status;
      final matchSearch = _search.isEmpty ||
          (s.affiliateNome?.toLowerCase().contains(_search.toLowerCase()) ?? false) ||
          s.productNome.toLowerCase().contains(_search.toLowerCase()) ||
          s.affiliateCode.toLowerCase().contains(_search.toLowerCase());
      return matchStatus && matchSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<AdminService>();
    final all = svc.subscriptions;

    final ativas = _filtered(all, SubscriptionStatus.ativa);
    final pendentes = _filtered(all, SubscriptionStatus.pendente);
    final canceladas = _filtered(all, SubscriptionStatus.cancelada);
    final todas = _filtered(all, null);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // TabBar integrada ao body
          Container(
            color: const Color(0xFF071A10),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.gold,
              unselectedLabelColor: Colors.white70,
              indicatorColor: AppColors.gold,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700),
              tabs: [
                Tab(text: 'Todas (${todas.length})'),
                Tab(text: 'Ativas (${ativas.length})'),
                Tab(text: 'Pendentes (${pendentes.length})'),
                Tab(text: 'Canceladas (${canceladas.length})'),
              ],
            ),
          ),
          // Busca
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Buscar por afiliado, produto ou código...',
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textHint),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => setState(() => _search = ''),
                      )
                    : null,
                isDense: true,
              ),
            ),
          ),
          const Divider(height: 1),

          // Tabs
          Expanded(
            child: svc.isLoadingData
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _SubList(subs: todas, onCancel: _cancelSub),
                      _SubList(subs: ativas, onCancel: _cancelSub),
                      _SubList(subs: pendentes, onCancel: _cancelSub),
                      _SubList(subs: canceladas, onCancel: null),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelSub(
      BuildContext context, SubscriptionModel sub) async {
    final motivoCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancelar Assinatura'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Cancelar assinatura de ${sub.affiliateNome} para "${sub.productNome}"?'),
            const SizedBox(height: 16),
            TextField(
              controller: motivoCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Motivo do cancelamento',
                hintText: 'Descreva o motivo...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      final svc = context.read<AdminService>();
      final motivo =
          motivoCtrl.text.trim().isNotEmpty ? motivoCtrl.text.trim() : 'Cancelado pelo admin';
      await svc.cancelSubscription(sub.id, motivo);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assinatura cancelada!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }
}

// ── Lista de assinaturas ──────────────────────────────────────────────────────
class _SubList extends StatelessWidget {
  final List<SubscriptionModel> subs;
  final Future<void> Function(BuildContext, SubscriptionModel)? onCancel;
  const _SubList({required this.subs, this.onCancel});

  @override
  Widget build(BuildContext context) {
    if (subs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: AppColors.textHint),
            SizedBox(height: 12),
            Text('Nenhuma assinatura nesta categoria',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: subs.length,
      itemBuilder: (ctx, i) => _SubCard(
        sub: subs[i],
        onCancel: onCancel != null
            ? () => onCancel!(ctx, subs[i])
            : null,
      ),
    );
  }
}

// ── Card da assinatura ────────────────────────────────────────────────────────
class _SubCard extends StatelessWidget {
  final SubscriptionModel sub;
  final VoidCallback? onCancel;
  const _SubCard({required this.sub, this.onCancel});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final dtFmt = DateFormat('dd/MM/yyyy');
    final statusColor = _statusColor(sub.status);
    final statusLabel = _statusLabel(sub.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: statusColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Ícone tipo de cobrança
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _chargeColor(sub.chargeType)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    sub.chargeType == ChargeType.pixRecorrente
                        ? Icons.autorenew_rounded
                        : sub.chargeType == ChargeType.pixAvulso
                            ? Icons.pix_rounded
                            : Icons.shopping_bag_rounded,
                    color: _chargeColor(sub.chargeType),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sub.productNome,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      Row(
                        children: [
                          const Icon(Icons.person_rounded,
                              size: 12,
                              color: AppColors.textSecondary),
                          const SizedBox(width: 3),
                          Text(
                            (sub.affiliateNome != null && sub.affiliateNome!.isNotEmpty)
                                ? sub.affiliateNome!
                                : sub.affiliateCode,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.primary
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              sub.affiliateCode,
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Valores e datas
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                // ── Tipo de cobrança bem visível ────────────────────────────
                _InfoPill(
                    icon: sub.chargeType == ChargeType.pixRecorrente
                        ? Icons.autorenew_rounded
                        : Icons.pix_rounded,
                    label: sub.chargeType == ChargeType.pixRecorrente
                        ? 'Mensal'
                        : 'Valor Único',
                    color: sub.chargeType == ChargeType.pixRecorrente
                        ? const Color(0xFF0D7A5A)
                        : AppColors.info),
                _InfoPill(
                    icon: Icons.attach_money_rounded,
                    label: fmt.format(sub.valor),
                    color: AppColors.primary),
                _InfoPill(
                    icon: Icons.handshake_rounded,
                    label: fmt.format(sub.valorComissao),
                    color: AppColors.success),
                _InfoPill(
                    icon: Icons.calendar_today_rounded,
                    label: 'Início: ${dtFmt.format(sub.dataInicio)}',
                    color: AppColors.textSecondary),
                if (sub.chargeType == ChargeType.pixRecorrente)
                  _InfoPill(
                        icon: Icons.event_repeat_rounded,
                        label: 'Dia ${sub.diaCobranca}',
                        color: AppColors.info),
              ],
            ),

            if (sub.motivo != null && sub.motivo!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 13, color: AppColors.warning),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(sub.motivo!,
                          style: const TextStyle(
                              color: AppColors.warning,
                              fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],

            if (onCancel != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel_rounded, size: 14),
                  label: const Text('Cancelar', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(SubscriptionStatus s) {
    switch (s) {
      case SubscriptionStatus.ativa:
        return AppColors.success;
      case SubscriptionStatus.pendente:
        return AppColors.warning;
      case SubscriptionStatus.cancelada:
        return AppColors.error;
      case SubscriptionStatus.aguardando:
        return AppColors.info;
    }
  }

  String _statusLabel(SubscriptionStatus s) {
    switch (s) {
      case SubscriptionStatus.ativa:
        return 'Ativa';
      case SubscriptionStatus.pendente:
        return 'Pendente';
      case SubscriptionStatus.cancelada:
        return 'Cancelada';
      case SubscriptionStatus.aguardando:
        return 'Aguardando';
    }
  }

  Color _chargeColor(ChargeType ct) {
    switch (ct) {
      case ChargeType.pixRecorrente:
        return const Color(0xFF0D7A5A);
      case ChargeType.pixAvulso:
        return AppColors.info;
    }
  }
}

// ── Pill de info ──────────────────────────────────────────────────────────────
class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoPill(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
