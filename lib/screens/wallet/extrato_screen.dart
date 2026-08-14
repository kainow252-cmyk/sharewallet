import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/wallet_service.dart';
import '../../services/extrato_export_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';

class ExtratoScreen extends StatefulWidget {
  const ExtratoScreen({super.key});

  @override
  State<ExtratoScreen> createState() => _ExtratoScreenState();
}

class _ExtratoScreenState extends State<ExtratoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      context.read<WalletService>().loadData(userId: uid);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletService>();
    final extrato = wallet.extratoCompleto;
    final totalSaques =
        wallet.withdraws.fold(0.0, (s, w) => s + w.valor);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Extrato'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Exportar',
            onPressed: extrato.isEmpty
                ? null
                : () => _showExportSheet(
                      context,
                      extrato: extrato,
                      totalComissoes: wallet.totalComissoes,
                      totalSaques: totalSaques,
                    ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.gold,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppColors.gold,
          tabs: const [
            Tab(text: 'Todos'),
            Tab(text: 'Comissões'),
            Tab(text: 'Saques'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Resumo
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Row(
              children: [
                _SummaryItem(
                  label: 'Total Comissões',
                  value:
                      'R\$ ${wallet.totalComissoes.toStringAsFixed(2).replaceAll('.',',')}',
                  color: AppColors.gold,
                ),
                Container(
                    height: 40,
                    width: 1,
                    color: Colors.white.withValues(alpha: 0.2)),
                _SummaryItem(
                  label: 'Total Saques',
                  value: 'R\$ ${totalSaques.toStringAsFixed(2).replaceAll('.',',')}',
                  color: Colors.white,
                ),
                Container(
                    height: 40,
                    width: 1,
                    color: Colors.white.withValues(alpha: 0.2)),
                _SummaryItem(
                  label: 'Transações',
                  value: extrato.length.toString(),
                  color: Colors.white,
                ),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildList(extrato),
                _buildList(
                    extrato.where((e) => e['tipo'] == 'comissao').toList()),
                _buildList(
                    extrato.where((e) => e['tipo'] == 'saque').toList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                color: AppColors.textHint, size: 64),
            SizedBox(height: 16),
            Text('Nenhuma transação',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16)),
          ],
        ),
      );
    }

    // Agrupa por mês
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final date = item['data'] as DateTime;
      final key = DateFormat('MMMM yyyy', 'pt_BR').format(date);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(item);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: grouped.length,
      itemBuilder: (ctx, groupIndex) {
        final month = grouped.keys.elementAt(groupIndex);
        final monthItems = grouped[month]!;
        final monthTotal = monthItems
            .where((i) => i['positivo'] == true)
            .fold(0.0, (s, i) => s + (i['valor'] as double));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Text(
                    month.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHint,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '+R\$ ${monthTotal.toStringAsFixed(2).replaceAll('.',',')}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
            ...monthItems.map((item) => _ExtratoItem(item: item)),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  // ── Bottom sheet de exportação ──────────────────────────────────────────────
  void _showExportSheet(
    BuildContext context, {
    required List<Map<String, dynamic>> extrato,
    required double totalComissoes,
    required double totalSaques,
  }) {
    final user = FirebaseAuth.instance.currentUser;
    final nomeAfiliado = user?.displayName ?? user?.email ?? 'Afiliado';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ExportSheet(
        extrato: extrato,
        totalComissoes: totalComissoes,
        totalSaques: totalSaques,
        nomeAfiliado: nomeAfiliado,
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w800),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ExportSheet — bottom sheet com opções de exportação
// ─────────────────────────────────────────────────────────────────────────────
class _ExportSheet extends StatefulWidget {
  final List<Map<String, dynamic>> extrato;
  final double totalComissoes;
  final double totalSaques;
  final String nomeAfiliado;

  const _ExportSheet({
    required this.extrato,
    required this.totalComissoes,
    required this.totalSaques,
    required this.nomeAfiliado,
  });

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  bool _loadingCsv = false;
  bool _loadingPdf = false;

  Future<void> _downloadCsv() async {
    if (_loadingCsv) return;
    setState(() => _loadingCsv = true);
    try {
      await ExtratoExportService.downloadCsv(
        extrato: widget.extrato,
        nomeAfiliado: widget.nomeAfiliado,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar CSV: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingCsv = false);
    }
  }

  Future<void> _openPdf() async {
    if (_loadingPdf) return;
    setState(() => _loadingPdf = true);
    try {
      await ExtratoExportService.openPdf(
        extrato: widget.extrato,
        totalComissoes: widget.totalComissoes,
        totalSaques: widget.totalSaques,
        nomeAfiliado: widget.nomeAfiliado,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar PDF: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.extrato.length;
    final fmtMoney = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Título
            const Row(
              children: [
                Icon(Icons.download_rounded, color: AppColors.gold, size: 22),
                SizedBox(width: 10),
                Text(
                  'Exportar Extrato',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Info resumo
            Text(
              '$count transações  •  Comissões: ${fmtMoney.format(widget.totalComissoes)}  •  Saques: ${fmtMoney.format(widget.totalSaques)}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 20),

            // Opção CSV
            _ExportOption(
              icon: Icons.table_chart_rounded,
              iconColor: const Color(0xFF1B8A4A),
              title: 'Baixar CSV',
              subtitle: 'Planilha compatível com Excel, Google Sheets e outros',
              loading: _loadingCsv,
              onTap: _downloadCsv,
            ),
            const SizedBox(height: 12),

            // Opção PDF
            _ExportOption(
              icon: Icons.picture_as_pdf_rounded,
              iconColor: const Color(0xFFC0392B),
              title: 'Visualizar / Salvar PDF',
              subtitle: 'Abre em nova aba — use Ctrl+P para salvar como PDF',
              loading: _loadingPdf,
              onTap: _openPdf,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ExportOption — card clicável de cada formato
// ─────────────────────────────────────────────────────────────────────────────
class _ExportOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback onTap;

  const _ExportOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: loading
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: iconColor,
                      ),
                    )
                  : Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: loading ? AppColors.cardBorder : AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtratoItem extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ExtratoItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final isPositivo = item['positivo'] as bool;
    final valor = item['valor'] as double;
    final date = item['data'] as DateTime;
    final tipo = item['tipo'] as String;

    final icon = tipo == 'comissao'
        ? Icons.trending_up_rounded
        : Icons.arrow_upward_rounded;
    final color = isPositivo ? AppColors.success : AppColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['descricao'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(date),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textHint),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isPositivo ?'+':'-'}R\$ ${valor.toStringAsFixed(2).replaceAll('.',',')}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              StatusBadge(status: item['status'] as String),
            ],
          ),
        ],
      ),
    );
  }
}
