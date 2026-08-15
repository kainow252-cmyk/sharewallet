import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _searchCtrl = TextEditingController();
  String _search = '';
  DateTimeRange? _dateRange;
  final _dtShort = DateFormat('dd/MM/yy');
  final _dtFull  = DateFormat('dd/MM/yyyy HH:mm');

  List<AdminWithdrawal> _filtered(List<AdminWithdrawal> list) {
    return list.where((w) {
      // busca texto
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        if (!w.affiliateNome.toLowerCase().contains(q) &&
            !w.affiliateCode.toLowerCase().contains(q) &&
            !w.pixKey.toLowerCase().contains(q)) { return false; }
      }
      // filtro data
      if (_dateRange != null) {
        final d = w.solicitadoEm;
        if (d.isBefore(_dateRange!.start)) { return false; }
        final end = _dateRange!.end.add(const Duration(days: 1));
        if (d.isAfter(end)) { return false; }
      }
      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    // 4 tabs: Pendentes | Processando | Aprovados | Recusados
    _tabController = TabController(length: 4, vsync: this);
    _searchCtrl.addListener(() => setState(() => _search = _searchCtrl.text.trim()));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<AdminService>();
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    final pendentes    = _filtered(svc.withdrawals.where((w) => w.status == 'pendente').toList());
    final processando  = _filtered(svc.withdrawals.where((w) => w.status == 'processando').toList());
    final aprovados    = _filtered(svc.withdrawals.where((w) => w.status == 'aprovado').toList());
    final recusados    = _filtered(svc.withdrawals.where((w) => w.status == 'recusado').toList());
    final todos        = _filtered(svc.withdrawals);

    final totalPendente = pendentes.fold(0.0, (s, w) => s + w.valor);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // -- TabBar -----------------------------------------------------
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
                // Processando
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Processando'),
                      if (processando.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.info,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('${processando.length}',
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

          // -- Banner pendentes (só quando na tab de saques) -------------
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
                      '${pendentes.length} saques pendentes  -  ${fmt.format(totalPendente)} a processar',
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

          // -- Busca + data + exportar ------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por afiliado, código ou chave PIX...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textHint),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); },
                      )
                    : null,
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final now = DateTime.now();
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2024),
                        lastDate: now,
                        initialDateRange: _dateRange,
                        helpText: 'Selecione o período',
                        cancelText: 'Cancelar',
                        confirmText: 'Confirmar',
                        builder: (ctx, child) => Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: ColorScheme.dark(
                              primary: AppColors.primary,
                              onPrimary: Colors.white,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (range != null) setState(() => _dateRange = range);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: _dateRange != null
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _dateRange != null ? AppColors.primary : Colors.white12,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 14,
                              color: _dateRange != null ? AppColors.primary : AppColors.textHint),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _dateRange != null
                                  ? '${_dtShort.format(_dateRange!.start)} – ${_dtShort.format(_dateRange!.end)}'
                                  : 'Data inicial – final',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: _dateRange != null ? Colors.white : AppColors.textHint),
                            ),
                          ),
                          if (_dateRange != null)
                            GestureDetector(
                              onTap: () => setState(() => _dateRange = null),
                              child: const Icon(Icons.close_rounded,
                                  size: 14, color: AppColors.textHint),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showExport(todos),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.download_rounded, size: 14, color: AppColors.gold),
                        SizedBox(width: 5),
                        Text('Relatório', style: TextStyle(
                            color: AppColors.gold, fontSize: 12,
                            fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // -- TabBarView -------------------------------------------------
          Expanded(
            child: svc.isLoadingData
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _WithdrawalList(
                        withdrawals: pendentes,
                        showActions: true,
                        onApprove: (w) => _approve(context, svc, w),
                        onReject: (w) => _reject(context, svc, w),
                      ),
                      _WithdrawalList(
                        withdrawals: processando,
                        showMarkApproved: true,
                        onMarkApproved: (w) => _markApproved(context, svc, w),
                      ),
                      _WithdrawalList(withdrawals: aprovados),
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

  Future<void> _markApproved(
      BuildContext context, AdminService svc, AdminWithdrawal w) async {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
          SizedBox(width: 8),
          Text('Confirmar Aprovação'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ConfirmRow(label: 'Afiliado', value: w.affiliateNome),
            _ConfirmRow(label: 'Valor', value: fmt.format(w.valor)),
            _ConfirmRow(label: 'Chave PIX', value: w.pixKey),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline_rounded, size: 14, color: AppColors.info),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Marcar como aprovado manualmente.\nUse quando a Woovi confirmou o pagamento mas o webhook não chegou.',
                    style: TextStyle(color: AppColors.info, fontSize: 12),
                  ),
                ),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await svc.approveWithdrawal(w.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saque ${fmt.format(w.valor)} marcado como aprovado!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showExport(List<AdminWithdrawal> list) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    // CSV
    String toCsv() {
      final buf = StringBuffer();
      buf.writeln('ID,Data,Afiliado,Código,Chave PIX,Valor,Status');
      for (final w in list) {
        final cells = [
          w.id,
          _dtFull.format(w.solicitadoEm),
          w.affiliateNome,
          w.affiliateCode,
          w.pixKey,
          w.valor.toStringAsFixed(2),
          w.status,
        ].map((c) => '"${c.toString().replaceAll('"', '""')}"').join(',');
        buf.writeln(cells);
      }
      return buf.toString();
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D2B1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.download_rounded, color: AppColors.gold, size: 22),
          const SizedBox(width: 8),
          Text('Exportar ${list.length} saques',
              style: const TextStyle(color: Colors.white, fontSize: 15)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ExportBtn(
              icon: Icons.table_chart_rounded,
              label: 'Copiar CSV',
              color: const Color(0xFF1B5E20),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: toCsv()));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('CSV copiado!'),
                      backgroundColor: AppColors.primary,
                      duration: Duration(seconds: 2)),
                );
              },
            ),
            const SizedBox(height: 8),
            _ExportBtn(
              icon: Icons.list_alt_rounded,
              label: 'Copiar lista simples',
              color: const Color(0xFF4A148C),
              onTap: () {
                Navigator.pop(ctx);
                final lines = list.map((w) =>
                    '${_dtShort.format(w.solicitadoEm)} | ${w.affiliateNome} | '
                    '${fmt.format(w.valor)} | ${w.pixKey} | ${w.status}').join('\n');
                Clipboard.setData(ClipboardData(text: lines));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lista copiada!'),
                      backgroundColor: AppColors.primary,
                      duration: Duration(seconds: 2)),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }
}

// -- Widget botão de exportação ------------------------------------------------
class _ExportBtn extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final VoidCallback onTap;
  const _ExportBtn({required this.icon, required this.label,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// -- Lista de saques -----------------------------------------------------------
class _WithdrawalList extends StatelessWidget {
  final List<AdminWithdrawal> withdrawals;
  final bool showActions;
  final bool showMarkApproved;
  final Function(AdminWithdrawal)? onApprove;
  final Function(AdminWithdrawal)? onReject;
  final Function(AdminWithdrawal)? onMarkApproved;

  const _WithdrawalList({
    required this.withdrawals,
    this.showActions = false,
    this.showMarkApproved = false,
    this.onApprove,
    this.onReject,
    this.onMarkApproved,
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
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 20),
      itemCount: withdrawals.length,
      itemBuilder: (ctx, i) => _WithdrawalCard(
        withdrawal: withdrawals[i],
        showActions: showActions,
        showMarkApproved: showMarkApproved,
        onApprove:
            onApprove != null ? () => onApprove!(withdrawals[i]) : null,
        onReject:
            onReject != null ? () => onReject!(withdrawals[i]) : null,
        onMarkApproved:
            onMarkApproved != null ? () => onMarkApproved!(withdrawals[i]) : null,
      ),
    );
  }
}

// -- Card compacto do saque (ExpansionTile) ------------------------------------
class _WithdrawalCard extends StatelessWidget {
  final AdminWithdrawal withdrawal;
  final bool showActions;
  final bool showMarkApproved;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onMarkApproved;

  const _WithdrawalCard({
    required this.withdrawal,
    this.showActions = false,
    this.showMarkApproved = false,
    this.onApprove,
    this.onReject,
    this.onMarkApproved,
  });

  @override
  Widget build(BuildContext context) {
    final fmt   = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final dtFmt = DateFormat('dd/MM/yyyy HH:mm');
    final w     = withdrawal;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: w.statusColor.withValues(alpha: 0.25)),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          // ── Linha resumo ─────────────────────────────────────────────────
          leading: Container(
            width: 32,
            height: 32,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  w.affiliateNome,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              // Código
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  w.affiliateCode,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 9,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 6),
              // Valor
              Text(
                fmt.format(w.valor),
                style: TextStyle(
                    color: w.statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
              ),
              const SizedBox(width: 5),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: w.statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  w.statusLabel,
                  style: TextStyle(
                      color: w.statusColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          // ── Conteúdo expandido ────────────────────────────────────────────
          children: [
            const Divider(color: AppColors.cardBorder, height: 1),
            const SizedBox(height: 8),

            // Chave PIX
            Row(
              children: [
                const Icon(Icons.pix_rounded,
                    size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 5),
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

            // Datas
            Text(
              'Solicitado: ${dtFmt.format(w.solicitadoEm)}',
              style: const TextStyle(color: AppColors.textHint, fontSize: 11),
            ),
            if (w.processadoEm != null)
              Text(
                'Processado: ${dtFmt.format(w.processadoEm!)}',
                style:
                    const TextStyle(color: AppColors.textHint, fontSize: 11),
              ),

            // TX ID
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

            // Motivo recusa
            if (w.motivo != null && w.motivo!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

            // Botões ação (apenas pendentes)
            if (showActions) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.cancel_rounded, size: 15),
                      label: const Text('Recusar',
                          style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check_circle_rounded, size: 15),
                      label: const Text('Aprovar via PIX',
                          style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Botão ação (saques processando — aprovação manual)
            if (showMarkApproved) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onMarkApproved,
                  icon: const Icon(Icons.check_circle_rounded, size: 15),
                  label: const Text('Marcar como Aprovado',
                      style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.info,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// -- Linha de confirmação ------------------------------------------------------
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
