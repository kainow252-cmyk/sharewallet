import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/subscription_model.dart';
import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';

// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Tela de Relatórios Admin — exporta CSV / JSON das tabelas D1
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _exporting = false;

  // Filtros de data
  DateTime? _de;
  DateTime? _ate;

  final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ── Helpers de data ────────────────────────────────────────────────────────

  bool _inRange(DateTime d) {
    if (_de != null && d.isBefore(_de!)) return false;
    if (_ate != null && d.isAfter(_ate!.add(const Duration(days: 1)))) {
      return false;
    }
    return true;
  }

  Future<void> _pickDe() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _de ?? DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _de = picked);
  }

  Future<void> _pickAte() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _ate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _ate = picked);
  }

  // ── Download no browser via JS ─────────────────────────────────────────────

  void _downloadCsv(String filename, String csv) {
    try {
      final encoded = base64Encode(utf8.encode(csv));
      final anchor  = html.AnchorElement(
        href: 'data:text/csv;charset=utf-8;base64,$encoded',
      )
        ..setAttribute('download', filename)
        ..click();
      html.document.body?.append(anchor);
      anchor.remove();
    } catch (e) {
      debugPrint('[Reports] Erro download CSV: $e');
    }
  }

  void _downloadJson(String filename, String jsonData) {
    try {
      final encoded = base64Encode(utf8.encode(jsonData));
      final anchor  = html.AnchorElement(
        href: 'data:application/json;charset=utf-8;base64,$encoded',
      )
        ..setAttribute('download', filename)
        ..click();
      html.document.body?.append(anchor);
      anchor.remove();
    } catch (e) {
      debugPrint('[Reports] Erro download JSON: $e');
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dados copiados para área de transferência!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  // ── Gerador CSV — Afiliados ────────────────────────────────────────────────

  String _csvAfiliados(List<AdminAffiliate> rows) {
    final buf = StringBuffer();
    buf.writeln(
        'ID,Nome,Email,CPF,Telefone,Código,Patrocinador,Status,'
        'Saldo Disponível,Total Comissões,Total Sacado,'
        'Total Indicados,Total Assinaturas,Data Cadastro,Chave PIX');
    for (final a in rows) {
      buf.writeln([
        _esc(a.id), _esc(a.nome), _esc(a.email), _esc(a.cpf),
        _esc(a.telefone), _esc(a.affiliateCode),
        _esc(a.sponsorCode ?? ''),
        _esc(a.status),
        a.saldoDisponivel.toStringAsFixed(2),
        a.totalComissoes.toStringAsFixed(2),
        a.totalSacado.toStringAsFixed(2),
        a.totalIndicados.toString(),
        a.totalAssinaturas.toString(),
        _dateFmt.format(a.createdAt),
        _esc(a.pixKey ?? ''),
      ].join(','));
    }
    return buf.toString();
  }

  // ── Gerador CSV — Saques ──────────────────────────────────────────────────

  String _csvSaques(List<AdminWithdrawal> rows) {
    final buf = StringBuffer();
    buf.writeln(
        'ID,Afiliado,Código,Valor,Chave PIX,Status,'
        'Solicitado Em,Processado Em,Tx ID,Motivo');
    for (final w in rows) {
      buf.writeln([
        _esc(w.id), _esc(w.affiliateNome), _esc(w.affiliateCode),
        w.valor.toStringAsFixed(2),
        _esc(w.pixKey), _esc(w.status),
        _dateFmt.format(w.solicitadoEm),
        w.processadoEm != null ? _dateFmt.format(w.processadoEm!) : '',
        _esc(w.txId ?? ''),
        _esc(w.motivo ?? ''),
      ].join(','));
    }
    return buf.toString();
  }

  // ── Gerador CSV — Assinaturas ─────────────────────────────────────────────

  String _csvAssinaturas(List<SubscriptionModel> rows) {
    final buf = StringBuffer();
    buf.writeln(
        'ID,Produto,Afiliado,Código,Valor,Comissão,Status,'
        'Tipo,Data Início,Próxima Cobrança,Chave PIX,Motivo');
    for (final s in rows) {
      buf.writeln([
        _esc(s.id), _esc(s.productNome),
        _esc(s.affiliateNome ?? ''), _esc(s.affiliateCode),
        s.valor.toStringAsFixed(2),
        s.comissao.toStringAsFixed(2),
        _esc(s.status.name),
        _esc(s.chargeType.name),
        _dateFmt.format(s.dataInicio),
        _dateFmt.format(s.proximaCobranca),
        _esc(s.pixKey ?? ''),
        _esc(s.motivo ?? ''),
      ].join(','));
    }
    return buf.toString();
  }

  static String _esc(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<AdminService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Filtro de datas ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.filter_alt_rounded,
                        color: AppColors.primary, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Filtrar por período',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _DateChip(
                        label: _de == null
                            ? 'Data início'
                            : _dateFmt.format(_de!),
                        icon: Icons.calendar_today_rounded,
                        isSet: _de != null,
                        onTap: _pickDe,
                        onClear: _de != null
                            ? () => setState(() => _de = null)
                            : null,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('→',
                          style:
                              TextStyle(color: AppColors.textHint, fontSize: 18)),
                    ),
                    Expanded(
                      child: _DateChip(
                        label: _ate == null
                            ? 'Data fim'
                            : _dateFmt.format(_ate!),
                        icon: Icons.calendar_month_rounded,
                        isSet: _ate != null,
                        onTap: _pickAte,
                        onClear: _ate != null
                            ? () => setState(() => _ate = null)
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Tabs ──────────────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.only(top: 12),
            color: const Color(0xFF071A10),
            child: TabBar(
              controller: _tab,
              labelColor: AppColors.gold,
              unselectedLabelColor: Colors.white54,
              indicatorColor: AppColors.gold,
              tabs: [
                Tab(
                  icon: const Icon(Icons.people_rounded, size: 18),
                  text: 'Afiliados',
                ),
                Tab(
                  icon: const Icon(
                      Icons.account_balance_wallet_rounded, size: 18),
                  text: 'Saques',
                ),
                Tab(
                  icon: const Icon(Icons.repeat_rounded, size: 18),
                  text: 'Assinaturas',
                ),
              ],
            ),
          ),

          Expanded(
            child: svc.isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tab,
                    children: [
                      // ── Afiliados ──────────────────────────────────────────
                      _ReportTab<AdminAffiliate>(
                        items: svc.affiliates,
                        dateOf: (a) => a.createdAt,
                        filter: _inRange,
                        csvBuilder: _csvAfiliados,
                        jsonBuilder: (rows) => jsonEncode(rows
                            .map((a) => {
                                  'id': a.id,
                                  'nome': a.nome,
                                  'email': a.email,
                                  'cpf': a.cpf,
                                  'telefone': a.telefone,
                                  'affiliate_code': a.affiliateCode,
                                  'sponsor_code': a.sponsorCode,
                                  'status': a.status,
                                  'saldo_disponivel': a.saldoDisponivel,
                                  'total_comissoes': a.totalComissoes,
                                  'total_sacado': a.totalSacado,
                                  'total_indicados': a.totalIndicados,
                                  'total_assinaturas': a.totalAssinaturas,
                                  'created_at': a.createdAt.toIso8601String(),
                                  'pix_key': a.pixKey,
                                })
                            .toList()),
                        filenameBase: 'afiliados',
                        summaryWidgets: (rows) => [
                          _SummaryKpi(
                            label: 'Total',
                            value: rows.length.toString(),
                            icon: Icons.people_rounded,
                            color: AppColors.primary,
                          ),
                          _SummaryKpi(
                            label: 'Ativos',
                            value: rows
                                .where((a) => a.status == 'ativo')
                                .length
                                .toString(),
                            icon: Icons.check_circle_rounded,
                            color: AppColors.success,
                          ),
                          _SummaryKpi(
                            label: 'Comissões',
                            value: _fmt.format(rows.fold(
                                0.0, (s, a) => s + a.totalComissoes)),
                            icon: Icons.handshake_rounded,
                            color: AppColors.gold,
                          ),
                          _SummaryKpi(
                            label: 'Saques',
                            value: _fmt.format(
                                rows.fold(0.0, (s, a) => s + a.totalSacado)),
                            icon: Icons.pix_rounded,
                            color: AppColors.info,
                          ),
                        ],
                        rowBuilder: (a) => _AffiliateRow(a: a, fmt: _fmt),
                        onDownloadCsv: _downloadCsv,
                        onDownloadJson: _downloadJson,
                        onCopy: _copyToClipboard,
                        exporting: _exporting,
                        onExportingChange: (v) =>
                            setState(() => _exporting = v),
                      ),

                      // ── Saques ─────────────────────────────────────────────
                      _ReportTab<AdminWithdrawal>(
                        items: svc.withdrawals,
                        dateOf: (w) => w.solicitadoEm,
                        filter: _inRange,
                        csvBuilder: _csvSaques,
                        jsonBuilder: (rows) => jsonEncode(rows
                            .map((w) => {
                                  'id': w.id,
                                  'affiliate_nome': w.affiliateNome,
                                  'affiliate_code': w.affiliateCode,
                                  'valor': w.valor,
                                  'pix_key': w.pixKey,
                                  'status': w.status,
                                  'solicitado_em':
                                      w.solicitadoEm.toIso8601String(),
                                  'processado_em':
                                      w.processadoEm?.toIso8601String(),
                                  'tx_id': w.txId ?? '',
                                  'motivo': w.motivo ?? '',
                                })
                            .toList()),
                        filenameBase: 'saques',
                        summaryWidgets: (rows) {
                          final pendentes = rows
                              .where((w) => w.status == 'pendente')
                              .toList();
                          final aprovados = rows
                              .where((w) => w.status == 'aprovado')
                              .toList();
                          return [
                            _SummaryKpi(
                              label: 'Total',
                              value: rows.length.toString(),
                              icon: Icons.list_rounded,
                              color: AppColors.primary,
                            ),
                            _SummaryKpi(
                              label: 'Pendentes',
                              value: pendentes.length.toString(),
                              icon: Icons.hourglass_empty_rounded,
                              color: AppColors.warning,
                            ),
                            _SummaryKpi(
                              label: 'Aprovados',
                              value: aprovados.length.toString(),
                              icon: Icons.check_circle_rounded,
                              color: AppColors.success,
                            ),
                            _SummaryKpi(
                              label: 'Volume',
                              value: _fmt.format(
                                  rows.fold(0.0, (s, w) => s + w.valor)),
                              icon: Icons.attach_money_rounded,
                              color: AppColors.gold,
                            ),
                          ];
                        },
                        rowBuilder: (w) =>
                            _WithdrawalRow(w: w, fmt: _fmt),
                        onDownloadCsv: _downloadCsv,
                        onDownloadJson: _downloadJson,
                        onCopy: _copyToClipboard,
                        exporting: _exporting,
                        onExportingChange: (v) =>
                            setState(() => _exporting = v),
                      ),

                      // ── Assinaturas ────────────────────────────────────────
                      _ReportTab<SubscriptionModel>(
                        items: svc.subscriptions,
                        dateOf: (s) => s.dataInicio,
                        filter: _inRange,
                        csvBuilder: _csvAssinaturas,
                        jsonBuilder: (rows) => jsonEncode(rows
                            .map((s) => {
                                  'id': s.id,
                                  'product_nome': s.productNome,
                                  'affiliate_nome': s.affiliateNome,
                                  'affiliate_code': s.affiliateCode,
                                  'valor': s.valor,
                                  'comissao': s.comissao,
                                  'status': s.status.name,
                                  'charge_type': s.chargeType.name,
                                  'data_inicio':
                                      s.dataInicio.toIso8601String(),
                                  'proxima_cobranca':
                                      s.proximaCobranca.toIso8601String(),
                                  'pix_key': s.pixKey ?? '',
                                  'motivo': s.motivo ?? '',
                                })
                            .toList()),
                        filenameBase: 'assinaturas',
                        summaryWidgets: (rows) {
                          final ativas = rows
                              .where((s) =>
                                  s.status == SubscriptionStatus.ativa)
                              .toList();
                          return [
                            _SummaryKpi(
                              label: 'Total',
                              value: rows.length.toString(),
                              icon: Icons.repeat_rounded,
                              color: AppColors.primary,
                            ),
                            _SummaryKpi(
                              label: 'Ativas',
                              value: ativas.length.toString(),
                              icon: Icons.check_circle_rounded,
                              color: AppColors.success,
                            ),
                            _SummaryKpi(
                              label: 'MRR',
                              value: _fmt.format(ativas.fold(
                                  0.0, (s, a) => s + a.valor)),
                              icon: Icons.trending_up_rounded,
                              color: AppColors.gold,
                            ),
                            _SummaryKpi(
                              label: 'Comissões',
                              value: _fmt.format(ativas.fold(
                                  0.0, (s, a) => s + a.comissao)),
                              icon: Icons.handshake_rounded,
                              color: AppColors.info,
                            ),
                          ];
                        },
                        rowBuilder: (s) =>
                            _SubscriptionRow(s: s, fmt: _fmt),
                        onDownloadCsv: _downloadCsv,
                        onDownloadJson: _downloadJson,
                        onCopy: _copyToClipboard,
                        exporting: _exporting,
                        onExportingChange: (v) =>
                            setState(() => _exporting = v),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ── _DateChip ────────────────────────────────────────────────────────────────
class _DateChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSet;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateChip({
    required this.label,
    required this.icon,
    required this.isSet,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSet
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isSet ? AppColors.primary : AppColors.cardBorder,
              width: isSet ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSet ? AppColors.primary : AppColors.textHint,
                size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: isSet
                          ? AppColors.textPrimary
                          : AppColors.textHint,
                      fontWeight: isSet ? FontWeight.w600 : FontWeight.normal),
                  overflow: TextOverflow.ellipsis),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close_rounded,
                    color: AppColors.textHint, size: 14),
              ),
          ],
        ),
      ),
    );
  }
}

// ── _SummaryKpi ───────────────────────────────────────────────────────────────
class _SummaryKpi extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryKpi({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 6),
            FittedBox(
              child: Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.textPrimary)),
            ),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ── Tab genérica de relatório ─────────────────────────────────────────────────
class _ReportTab<T> extends StatelessWidget {
  final List<T> items;
  final DateTime Function(T) dateOf;
  final bool Function(DateTime) filter;
  final String Function(List<T>) csvBuilder;
  final String Function(List<T>) jsonBuilder;
  final String filenameBase;
  final List<Widget> Function(List<T>) summaryWidgets;
  final Widget Function(T) rowBuilder;
  final void Function(String, String) onDownloadCsv;
  final void Function(String, String) onDownloadJson;
  final void Function(String) onCopy;
  final bool exporting;
  final void Function(bool) onExportingChange;

  const _ReportTab({
    required this.items,
    required this.dateOf,
    required this.filter,
    required this.csvBuilder,
    required this.jsonBuilder,
    required this.filenameBase,
    required this.summaryWidgets,
    required this.rowBuilder,
    required this.onDownloadCsv,
    required this.onDownloadJson,
    required this.onCopy,
    required this.exporting,
    required this.onExportingChange,
  });

  List<T> get _filtered => items.where((i) => filter(dateOf(i))).toList();

  String get _timestamp =>
      DateFormat('yyyyMMdd_HHmm').format(DateTime.now());

  void _doExport(BuildContext ctx, String format) async {
    onExportingChange(true);
    await Future.delayed(const Duration(milliseconds: 100));
    final rows = _filtered;
    final ts = _timestamp;

    try {
      if (format == 'csv') {
        final csv = csvBuilder(rows);
        onDownloadCsv('${filenameBase}_$ts.csv', csv);
        if (ctx.mounted) _showSnack(ctx, '\u2705 CSV exportado! (${rows.length} registros)');
      } else if (format == 'json') {
        final json = jsonBuilder(rows);
        onDownloadJson('${filenameBase}_$ts.json', json);
        if (ctx.mounted) _showSnack(ctx, '\u2705 JSON exportado! (${rows.length} registros)');
      } else if (format == 'clipboard') {
        final csv = csvBuilder(rows);
        onCopy(csv);
      }
    } catch (e) {
      if (ctx.mounted) _showSnack(ctx, 'Erro ao exportar: $e', isError: true);
    }
    onExportingChange(false);
  }

  void _showSnack(BuildContext ctx, String msg,
      {bool isError = false}) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isError ? AppColors.error : AppColors.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    return Column(
      children: [
        // ── KPIs de resumo ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              ...summaryWidgets(rows)
                  .map((w) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: w,
                      )),
            ],
          ),
        ),

        // ── Barra de ações de exportação ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.download_rounded,
                        color: AppColors.primary, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Exportar — ${rows.length} registros',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // CSV
                    Expanded(
                      child: _ExportButton(
                        label: 'CSV',
                        icon: Icons.table_chart_rounded,
                        color: AppColors.success,
                        loading: exporting,
                        onTap: () => _doExport(context, 'csv'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // JSON
                    Expanded(
                      child: _ExportButton(
                        label: 'JSON',
                        icon: Icons.data_object_rounded,
                        color: AppColors.info,
                        loading: exporting,
                        onTap: () => _doExport(context, 'json'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Copiar
                    Expanded(
                      child: _ExportButton(
                        label: 'Copiar',
                        icon: Icons.copy_rounded,
                        color: AppColors.textSecondary,
                        loading: exporting,
                        onTap: () => _doExport(context, 'clipboard'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── Tabela / Lista ────────────────────────────────────────────────
        Expanded(
          child: rows.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off_rounded,
                          color: AppColors.textHint, size: 48),
                      const SizedBox(height: 12),
                      const Text('Nenhum registro no período',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => rowBuilder(rows[i]),
                ),
        ),
      ],
    );
  }
}

// ── Botão de exportação ───────────────────────────────────────────────────────
class _ExportButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  const _ExportButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: color),
                  )
                : Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ── Row: Afiliado ─────────────────────────────────────────────────────────────
class _AffiliateRow extends StatelessWidget {
  final AdminAffiliate a;
  final NumberFormat fmt;
  const _AffiliateRow({required this.a, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final statusColor = a.status == 'ativo' ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                a.nome.isNotEmpty ? a.nome[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(a.nome,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(a.status,
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                Text(a.email,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _Mini(label: 'Código', value: a.affiliateCode),
                    const SizedBox(width: 12),
                    _Mini(
                        label: 'Comissões',
                        value: fmt.format(a.totalComissoes),
                        color: AppColors.gold),
                    const SizedBox(width: 12),
                    _Mini(
                        label: 'Saldo',
                        value: fmt.format(a.saldoDisponivel),
                        color: AppColors.success),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Row: Saque ────────────────────────────────────────────────────────────────
class _WithdrawalRow extends StatelessWidget {
  final AdminWithdrawal w;
  final NumberFormat fmt;
  const _WithdrawalRow({required this.w, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy HH:mm');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: w.statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: w.statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.pix_rounded, color: w.statusColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(w.affiliateNome,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      fmt.format(w.valor),
                      style: TextStyle(
                          color: w.statusColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 14),
                    ),
                  ],
                ),
                Text(w.pixKey,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _Mini(
                        label: 'Status',
                        value: w.statusLabel,
                        color: w.statusColor),
                    const SizedBox(width: 12),
                    _Mini(
                        label: 'Solicitado',
                        value: df.format(w.solicitadoEm)),
                    if (w.txId != null && w.txId!.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      _Mini(label: 'Tx ID', value: w.txId!),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Row: Assinatura ───────────────────────────────────────────────────────────
class _SubscriptionRow extends StatelessWidget {
  final SubscriptionModel s;
  final NumberFormat fmt;
  const _SubscriptionRow({required this.s, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: s.statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: s.statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.repeat_rounded, color: s.statusColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(s.productNome,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      fmt.format(s.valor),
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 14),
                    ),
                  ],
                ),
                Text(s.affiliateNome ?? s.affiliateCode,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _Mini(
                        label: 'Status',
                        value: s.statusLabel,
                        color: s.statusColor),
                    const SizedBox(width: 12),
                    _Mini(
                        label: 'Comissão',
                        value: fmt.format(s.comissao),
                        color: AppColors.gold),
                    const SizedBox(width: 12),
                    _Mini(
                        label: 'Início',
                        value: df.format(s.dataInicio)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Micro texto label+valor ───────────────────────────────────────────────────
class _Mini extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Mini({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 9, color: AppColors.textHint)),
        Text(value,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color ?? AppColors.textSecondary)),
      ],
    );
  }
}
