import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';

class AdminWithdrawalsScreen extends StatefulWidget {
  const AdminWithdrawalsScreen({super.key});

  @override
  State<AdminWithdrawalsScreen> createState() =>
      _AdminWithdrawalsScreenState();
}

class _AdminWithdrawalsScreenState extends State<AdminWithdrawalsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<AdminService>();
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    final pendentes =
        svc.withdrawals.where((w) => w.status == 'pendente').toList();
    final aprovados =
        svc.withdrawals.where((w) => w.status == 'aprovado').toList();
    final recusados = svc.withdrawals
        .where((w) => w.status == 'recusado' || w.status == 'processando')
        .toList();

    final totalPendente =
        pendentes.fold(0.0, (s, w) => s + w.valor);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Saques'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => svc.loadWithdrawals(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.gold,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppColors.gold,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Pendentes'),
                  if (pendentes.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${pendentes.length}',
                          style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
            ),
            Tab(text: 'Aprovados (${aprovados.length})'),
            Tab(text: 'Recusados (${recusados.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Banner de saques pendentes
          if (pendentes.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pending_actions_rounded,
                      color: AppColors.warning, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${pendentes.length} saques pendentes — ${fmt.format(totalPendente)} a processar',
                      style: const TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          const Divider(height: 1),

          // Conteúdo das tabs
          Expanded(
            child: svc.isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Pendentes
                      _WithdrawalList(
                        withdrawals: pendentes,
                        showActions: true,
                        onApprove: (w) => _approve(context, svc, w),
                        onReject: (w) => _reject(context, svc, w),
                      ),
                      // Aprovados
                      _WithdrawalList(withdrawals: aprovados),
                      // Recusados
                      _WithdrawalList(withdrawals: recusados),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _approve(
      BuildContext context, AdminService svc, AdminWithdrawal w) async {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 22),
            SizedBox(width: 8),
            Text('Aprovar Saque'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ConfirmRow(label: 'Afiliado', value: w.affiliateNome),
            _ConfirmRow(label: 'Código', value: w.affiliateCode),
            _ConfirmRow(
                label: 'Valor', value: fmt.format(w.valor)),
            _ConfirmRow(label: 'Chave PIX', value: w.pixKey),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: AppColors.info),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'O saque será processado via Woovi (PIX Subconta).',
                      style: TextStyle(
                          color: AppColors.info, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('Aprovar'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success),
          ),
        ],
      ),
    );

    if (ok == true) {
      final success = await svc.approveWithdrawal(w.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Saque aprovado e enviado via PIX!'
                : 'Erro ao aprovar saque.'),
            backgroundColor:
                success ? AppColors.success : AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _reject(
      BuildContext context, AdminService svc, AdminWithdrawal w) async {
    final motivoCtrl = TextEditingController();
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cancel_rounded, color: AppColors.error, size: 22),
            SizedBox(width: 8),
            Text('Recusar Saque'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ConfirmRow(label: 'Afiliado', value: w.affiliateNome),
            _ConfirmRow(
                label: 'Valor', value: fmt.format(w.valor)),
            const SizedBox(height: 16),
            TextField(
              controller: motivoCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Motivo da recusa *',
                hintText: 'Explique o motivo para o afiliado...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.cancel_rounded, size: 16),
            label: const Text('Recusar'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
          ),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      final motivo = motivoCtrl.text.trim().isNotEmpty
          ? motivoCtrl.text.trim()
          : 'Recusado pelo admin';
      final success = await svc.rejectWithdrawal(w.id, motivo);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Saque recusado!'
                : 'Erro ao recusar saque.'),
            backgroundColor:
                success ? AppColors.warning : AppColors.error,
          ),
        );
      }
    }
  }
}

// ── Lista de saques ───────────────────────────────────────────────────────────
class _WithdrawalList extends StatelessWidget {
  final List<AdminWithdrawal> withdrawals;
  final bool showActions;
  final Function(AdminWithdrawal)? onApprove;
  final Function(AdminWithdrawal)? onReject;

  const _WithdrawalList({
    required this.withdrawals,
    this.showActions = false,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    if (withdrawals.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: AppColors.textHint),
            SizedBox(height: 12),
            Text('Nenhum saque nesta categoria',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: withdrawals.length,
      itemBuilder: (ctx, i) => _WithdrawalCard(
        withdrawal: withdrawals[i],
        showActions: showActions,
        onApprove:
            onApprove != null ? () => onApprove!(withdrawals[i]) : null,
        onReject:
            onReject != null ? () => onReject!(withdrawals[i]) : null,
      ),
    );
  }
}

// ── Card do saque ─────────────────────────────────────────────────────────────
class _WithdrawalCard extends StatelessWidget {
  final AdminWithdrawal withdrawal;
  final bool showActions;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  const _WithdrawalCard({
    required this.withdrawal,
    this.showActions = false,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final dtFmt = DateFormat('dd/MM/yyyy HH:mm');
    final w = withdrawal;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: w.statusColor.withValues(alpha: 0.25)),
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
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: w.statusColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      w.affiliateNome.isNotEmpty
                          ? w.affiliateNome[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                          color: w.statusColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(w.affiliateNome,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.primary
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              w.affiliateCode,
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      fmt.format(w.valor),
                      style: TextStyle(
                          color: w.statusColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 18),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: w.statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        w.statusLabel,
                        style: TextStyle(
                            color: w.statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Info PIX e datas
            Row(
              children: [
                const Icon(Icons.pix_rounded,
                    size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    w.pixKey,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Solicitado: ${dtFmt.format(w.solicitadoEm)}',
              style: const TextStyle(
                  color: AppColors.textHint, fontSize: 11),
            ),
            if (w.processadoEm != null)
              Text(
                'Processado: ${dtFmt.format(w.processadoEm!)}',
                style: const TextStyle(
                    color: AppColors.textHint, fontSize: 11),
              ),
            if (w.txId != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded,
                        size: 13, color: AppColors.success),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'TX: ${w.txId}',
                        style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 11,
                            fontStyle: FontStyle.italic),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            if (w.motivo != null && w.motivo!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 13, color: AppColors.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(w.motivo!,
                          style: const TextStyle(
                              color: AppColors.error, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],

            // Botões de ação (apenas pendentes)
            if (showActions) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.cancel_rounded, size: 16),
                      label: const Text('Recusar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: onApprove,
                      icon:
                          const Icon(Icons.check_circle_rounded, size: 16),
                      label: const Text('Aprovar via PIX'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Linha de confirmação ──────────────────────────────────────────────────────
class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;
  const _ConfirmRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
