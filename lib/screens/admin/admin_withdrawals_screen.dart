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

  // ── Filtro afiliados ──────────────────────────────────────────────────────
  // 'todos' | 'ativo' | 'suspenso' | 'cancelado'
  String _filtroAfiliado = 'todos';

  static const _filtros = [
    {'key': 'todos',     'label': 'Todos',      'icon': Icons.group_rounded},
    {'key': 'ativo',     'label': 'Ativos',     'icon': Icons.check_circle_rounded},
    {'key': 'suspenso',  'label': 'Suspensos',  'icon': Icons.pause_circle_rounded},
    {'key': 'cancelado', 'label': 'Cancelados', 'icon': Icons.cancel_rounded},
  ];

  @override
  void initState() {
    super.initState();
    // 4 tabs: Pendentes | Aprovados | Recusados | Afiliados
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Hamburguer — filtro de afiliados ──────────────────────────────────────
  void _showFiltroDrawer(BuildContext ctx, AdminService svc) {
    final counts = <String, int>{
      'todos':     svc.affiliates.length,
      'ativo':     svc.affiliates.where((a) => a.status == 'ativo').length,
      'suspenso':  svc.affiliates.where((a) => a.status == 'suspenso').length,
      'cancelado': svc.affiliates
          .where((a) => a.status == 'cancelado' || a.status == 'inativo').length,
    };

    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (bsCtx, bsSetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Filtrar Afiliados',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              const Text('Selecione o status para filtrar a lista',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              // Opções de filtro
              ...(_filtros.map((f) {
                final key     = f['key'] as String;
                final label   = f['label'] as String;
                final icon    = f['icon'] as IconData;
                final count   = counts[key] ?? 0;
                final selected = _filtroAfiliado == key;
                final color   = _statusColor(key);

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() => _filtroAfiliado = key);
                    Navigator.pop(ctx);
                    // Vai para tab Afiliados se não estiver lá
                    if (_tabController.index != 3) {
                      _tabController.animateTo(3);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? color.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? color.withValues(alpha: 0.5)
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(icon,
                            color: selected ? color : AppColors.textHint,
                            size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(label,
                              style: TextStyle(
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selected
                                      ? color
                                      : AppColors.textPrimary,
                                  fontSize: 14)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: selected
                                ? color.withValues(alpha: 0.15)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('$count',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? color
                                      : AppColors.textHint,
                                  fontSize: 12)),
                        ),
                        if (selected) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.check_rounded, color: color, size: 18),
                        ],
                      ],
                    ),
                  ),
                );
              })),
              // Limpar filtro
              if (_filtroAfiliado != 'todos')
                TextButton.icon(
                  onPressed: () {
                    setState(() => _filtroAfiliado = 'todos');
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  label: const Text('Limpar filtro'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ativo':     return AppColors.success;
      case 'suspenso':  return AppColors.warning;
      case 'cancelado':
      case 'inativo':   return AppColors.error;
      default:          return AppColors.primary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'ativo':     return 'Ativo';
      case 'suspenso':  return 'Suspenso';
      case 'cancelado': return 'Cancelado';
      case 'inativo':   return 'Inativo';
      default:          return status;
    }
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

    // ── Filtra afiliados pelo status selecionado ──────────────────────────
    final afiliadosFiltrados = _filtroAfiliado == 'todos'
        ? svc.affiliates
        : svc.affiliates.where((a) {
            if (_filtroAfiliado == 'cancelado') {
              return a.status == 'cancelado' || a.status == 'inativo';
            }
            return a.status == _filtroAfiliado;
          }).toList();

    final totalPendente = pendentes.fold(0.0, (s, w) => s + w.valor);
    final filtroAtivo    = _filtroAfiliado != 'todos';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── TabBar ─────────────────────────────────────────────────────
          Container(
            color: const Color(0xFF071A10),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.gold,
              unselectedLabelColor: Colors.white70,
              indicatorColor: AppColors.gold,
              indicatorSize: TabBarIndicatorSize.label,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              tabs: [
                // Pendentes
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
                // Afiliados com indicador de filtro ativo
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Afiliados'),
                      const SizedBox(width: 4),
                      Builder(builder: (ctx) {
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.menu_rounded, size: 16),
                            if (filtroAtivo)
                              Positioned(
                                right: -3,
                                top: -3,
                                child: Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: AppColors.gold,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Banner pendentes (só quando na tab de saques) ─────────────
          if (pendentes.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
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

          // ── Barra de filtro ativo (tab Afiliados) ─────────────────────
          AnimatedBuilder(
            animation: _tabController,
            builder: (_, __) {
              if (_tabController.index != 3 || !filtroAtivo) {
                return const SizedBox.shrink();
              }
              final cor = _statusColor(_filtroAfiliado);
              return Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.filter_list_rounded, color: cor, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Filtro: ${_statusLabel(_filtroAfiliado)} '
                        '(${afiliadosFiltrados.length} afiliados)',
                        style: TextStyle(
                            color: cor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _filtroAfiliado = 'todos'),
                      child: Icon(Icons.close_rounded, color: cor, size: 16),
                    ),
                  ],
                ),
              );
            },
          ),

          // ── TabBarView ─────────────────────────────────────────────────
          Expanded(
            child: svc.isLoadingData
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
                      // Afiliados (com hamburguer)
                      _AffiliatesList(
                        affiliates: afiliadosFiltrados,
                        filtroAtivo: filtroAtivo,
                        filtroLabel: _statusLabel(_filtroAfiliado),
                        onHamburger: () => _showFiltroDrawer(context, svc),
                        statusColor: _statusColor,
                        statusLabel: _statusLabel,
                        fmt: fmt,
                      ),
                    ],
                  ),
          ),
        ],
      ),

      // ── FAB hamburguer apenas na tab Afiliados ─────────────────────────
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (_, __) {
          if (_tabController.index != 3) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => _showFiltroDrawer(context, svc),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.tune_rounded),
                if (filtroAtivo)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            label: Text(filtroAtivo
                ? _statusLabel(_filtroAfiliado)
                : 'Filtrar'),
            backgroundColor: const Color(0xFF071A10),
            foregroundColor: AppColors.gold,
          );
        },
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
            _ConfirmRow(label: 'Valor', value: fmt.format(w.valor)),
            _ConfirmRow(label: 'Chave PIX', value: w.pixKey),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: AppColors.info),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'O saque será processado via transferência PIX direta.',
                      style: TextStyle(color: AppColors.info, fontSize: 12),
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
            backgroundColor: success ? AppColors.success : AppColors.error,
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
            _ConfirmRow(label: 'Valor', value: fmt.format(w.valor)),
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
            content: Text(
                success ? 'Saque recusado!' : 'Erro ao recusar saque.'),
            backgroundColor:
                success ? AppColors.warning : AppColors.error,
          ),
        );
      }
    }
  }
}

// ── Lista de Afiliados ────────────────────────────────────────────────────────
class _AffiliatesList extends StatelessWidget {
  final List<AdminAffiliate> affiliates;
  final bool filtroAtivo;
  final String filtroLabel;
  final VoidCallback onHamburger;
  final Color Function(String) statusColor;
  final String Function(String) statusLabel;
  final NumberFormat fmt;

  const _AffiliatesList({
    required this.affiliates,
    required this.filtroAtivo,
    required this.filtroLabel,
    required this.onHamburger,
    required this.statusColor,
    required this.statusLabel,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    if (affiliates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline_rounded,
                size: 52, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(
              filtroAtivo
                  ? 'Nenhum afiliado "$filtroLabel"'
                  : 'Nenhum afiliado cadastrado',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 15),
            ),
            if (filtroAtivo) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onHamburger,
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text('Alterar filtro'),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      itemCount: affiliates.length,
      itemBuilder: (ctx, i) => _AffiliateCard(
        affiliate: affiliates[i],
        statusColor: statusColor(affiliates[i].status),
        statusLabel: statusLabel(affiliates[i].status),
        fmt: fmt,
      ),
    );
  }
}

// ── Card de afiliado ──────────────────────────────────────────────────────────
class _AffiliateCard extends StatelessWidget {
  final AdminAffiliate affiliate;
  final Color statusColor;
  final String statusLabel;
  final NumberFormat fmt;

  const _AffiliateCard({
    required this.affiliate,
    required this.statusColor,
    required this.statusLabel,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final a = affiliate;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: statusColor.withValues(alpha: 0.2)),
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
            // ── Cabeçalho ─────────────────────────────────────────────
            Row(
              children: [
                // Avatar
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      a.nome.isNotEmpty ? a.nome[0].toUpperCase() : '?',
                      style: TextStyle(
                          color: statusColor,
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
                      Text(a.nome,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              a.affiliateCode,
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Badge status
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Saldo disponível
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      fmt.format(a.saldoDisponivel),
                      style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w800,
                          fontSize: 16),
                    ),
                    const Text('disponível',
                        style: TextStyle(
                            color: AppColors.textHint, fontSize: 10)),
                  ],
                ),
              ],
            ),

            const Divider(height: 18),

            // ── Métricas ──────────────────────────────────────────────
            Row(
              children: [
                _MetricItem(
                    label: 'Comissões',
                    value: fmt.format(a.totalComissoes),
                    icon: Icons.monetization_on_rounded,
                    color: AppColors.primary),
                _MetricItem(
                    label: 'Sacado',
                    value: fmt.format(a.totalSacado),
                    icon: Icons.account_balance_wallet_rounded,
                    color: AppColors.textSecondary),
                _MetricItem(
                    label: 'Indicados',
                    value: '${a.totalIndicados}',
                    icon: Icons.people_rounded,
                    color: const Color(0xFF7C4DFF)),
                _MetricItem(
                    label: 'Assinaturas',
                    value: '${a.totalAssinaturas}',
                    icon: Icons.repeat_rounded,
                    color: AppColors.info),
              ],
            ),

            // Chave PIX (se tiver)
            if (a.pixKey != null && a.pixKey!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.pix_rounded,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      a.pixKey!,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            // Email
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.email_outlined,
                    size: 13, color: AppColors.textHint),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    a.email,
                    style: const TextStyle(
                        color: AppColors.textHint, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Item de métrica dentro do card ───────────────────────────────────────────
class _MetricItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 12),
              textAlign: TextAlign.center),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textHint, fontSize: 9),
              textAlign: TextAlign.center),
        ],
      ),
    );
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
            Icon(Icons.inbox_rounded,
                size: 48, color: AppColors.textHint),
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
    final fmt   = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final dtFmt = DateFormat('dd/MM/yyyy HH:mm');
    final w     = withdrawal;

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
                              color:
                                  AppColors.primary.withValues(alpha: 0.1),
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
                      icon: const Icon(Icons.check_circle_rounded,
                          size: 16),
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
