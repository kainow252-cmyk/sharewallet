import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/admin_service.dart';
import '../../services/cf_api_service.dart';
import '../../theme/app_theme.dart';

// ──────────────────────────────────────────────────────────────────────────────
// AdminSalesScreen — tela de Vendas no painel admin
// Funcionalidades:
//   • Tabs: Todas / Aprovadas / Pendentes / Canceladas
//   • Busca: cliente nome, email, produto, código afiliado, payment_id
//   • Filtro: Todos / Mensal (pixRecorrente) / Único (pixAvulso)
//   • Range de datas (dateFrom / dateTo)
//   • Export: CSV / JSON / Clipboard
//   • KPIs: total vendas, volume R$, comissões R$, aprovadas
// ──────────────────────────────────────────────────────────────────────────────

class AdminSalesScreen extends StatefulWidget {
  const AdminSalesScreen({super.key});

  @override
  State<AdminSalesScreen> createState() => _AdminSalesScreenState();
}

class _AdminSalesScreenState extends State<AdminSalesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final TextEditingController _searchCtrl = TextEditingController();

  String _searchQuery = '';
  String? _tipoFiltro; // null=todos, 'pixRecorrente', 'pixAvulso'
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Filtros ─────────────────────────────────────────────────────────────────

  List<AdminSale> _filter(List<AdminSale> all, String? statusFilter) {
    return all.where((s) {
      // filtro por aba (status)
      if (statusFilter != null && s.status != statusFilter) return false;

      // filtro tipo
      if (_tipoFiltro != null && s.chargeType != _tipoFiltro) return false;

      // filtro data
      if (_dateRange != null) {
        final d = s.createdAt;
        if (d.isBefore(_dateRange!.start)) return false;
        final end = _dateRange!.end.add(const Duration(days: 1));
        if (d.isAfter(end)) return false;
      }

      // busca de texto
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery;
        if (s.clienteNome.toLowerCase().contains(q)) return true;
        if (s.clienteEmail.toLowerCase().contains(q)) return true;
        if (s.productNome.toLowerCase().contains(q)) return true;
        if (s.affiliateCode.toLowerCase().contains(q)) return true;
        if (s.affiliateNome.toLowerCase().contains(q)) return true;
        if (s.paymentId.toLowerCase().contains(q)) return true;
        return false;
      }

      return true;
    }).toList();
  }

  // ── Export ──────────────────────────────────────────────────────────────────

  String _toCsv(List<AdminSale> list) {
    final buf = StringBuffer();
    buf.writeln(
        'ID,Data,Cliente Nome,Cliente Email,Produto,Valor,Comissão,Afiliado Código,Afiliado Nome,Status,Tipo,Payment ID');
    for (final s in list) {
      buf.writeln([
        _csvCell(s.id),
        _csvCell(_fmtDate(s.createdAt)),
        _csvCell(s.clienteNome.isNotEmpty ? s.clienteNome : 'N/A'),
        _csvCell(s.clienteEmail.isNotEmpty ? s.clienteEmail : 'N/A'),
        _csvCell(s.productNome),
        s.valor.toStringAsFixed(2),
        s.comissao.toStringAsFixed(2),
        _csvCell(s.affiliateCode),
        _csvCell(s.affiliateNome.isNotEmpty ? s.affiliateNome : 'N/A'),
        _csvCell(s.statusLabel),
        _csvCell(s.chargeTypeLabel),
        _csvCell(s.paymentId.isNotEmpty ? s.paymentId : 'N/A'),
      ].join(','));
    }
    return buf.toString();
  }

  String _csvCell(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  String _toJson(List<AdminSale> list) {
    final arr = list
        .map((s) => {
              'id': s.id,
              'data': s.createdAt.toIso8601String(),
              'cliente_nome': s.clienteNome,
              'cliente_email': s.clienteEmail,
              'produto': s.productNome,
              'valor': s.valor,
              'comissao': s.comissao,
              'affiliate_code': s.affiliateCode,
              'affiliate_nome': s.affiliateNome,
              'status': s.status,
              'tipo': s.chargeType,
              'payment_id': s.paymentId,
            })
        .toList();
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(arr);
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copiado para a área de transferência'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showExportDialog(List<AdminSale> filtered) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D2B1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.download_rounded, color: AppColors.gold, size: 22),
            const SizedBox(width: 8),
            Text('Exportar ${filtered.length} vendas',
                style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Escolha o formato de exportação:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _ExportButton(
              icon: Icons.table_chart_rounded,
              label: 'Copiar CSV',
              color: const Color(0xFF1B5E20),
              onTap: () {
                Navigator.pop(ctx);
                _copyToClipboard(_toCsv(filtered), 'CSV');
              },
            ),
            const SizedBox(height: 8),
            _ExportButton(
              icon: Icons.data_object_rounded,
              label: 'Copiar JSON',
              color: const Color(0xFF0D47A1),
              onTap: () {
                Navigator.pop(ctx);
                _copyToClipboard(_toJson(filtered), 'JSON');
              },
            ),
            const SizedBox(height: 8),
            _ExportButton(
              icon: Icons.content_copy_rounded,
              label: 'Copiar lista simples',
              color: const Color(0xFF4A148C),
              onTap: () {
                Navigator.pop(ctx);
                final lines = filtered
                    .map((s) =>
                        '${_fmtDate(s.createdAt)} | ${s.productNome} | '
                        '${s.clienteNome.isNotEmpty ? s.clienteNome : s.clienteEmail} | '
                        'R\$${s.valor.toStringAsFixed(2)} | ${s.statusLabel}')
                    .join('\n');
                _copyToClipboard(lines, 'Lista');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar',
                style: TextStyle(color: Colors.white54)),
          )
        ],
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange: _dateRange,
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
  }

  // ── KPIs ────────────────────────────────────────────────────────────────────

  Widget _kpiRow(List<AdminSale> all) {
    final total = all.length;
    final aprovadas = all.where((s) => s.status == 'aprovado').length;
    final volume =
        all.where((s) => s.status == 'aprovado').fold(0.0, (a, s) => a + s.valor);
    final comissoes =
        all.where((s) => s.status == 'aprovado').fold(0.0, (a, s) => a + s.comissao);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _KpiCard(
              label: 'Total Vendas',
              value: '$total',
              icon: Icons.receipt_long_rounded,
              color: Colors.blue[300]!),
          const SizedBox(width: 8),
          _KpiCard(
              label: 'Aprovadas',
              value: '$aprovadas',
              icon: Icons.check_circle_rounded,
              color: AppColors.primary),
          const SizedBox(width: 8),
          _KpiCard(
              label: 'Volume Total',
              value: 'R\$ ${volume.toStringAsFixed(2)}',
              icon: Icons.attach_money_rounded,
              color: AppColors.gold),
          const SizedBox(width: 8),
          _KpiCard(
              label: 'Comissões Pagas',
              value: 'R\$ ${comissoes.toStringAsFixed(2)}',
              icon: Icons.volunteer_activism_rounded,
              color: Colors.purple[300]!),
        ],
      ),
    );
  }

  // ── Build principal ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<AdminService>();
    final allSales = svc.sales;

    // Listas por aba
    final todas = _filter(allSales, null);
    final aprovadas = _filter(allSales, 'aprovado');
    final pendentes = _filter(allSales, 'pendente');
    final canceladas = _filter(allSales, 'cancelado');

    // Lista da aba ativa (para export)
    final List<AdminSale> currentList = [todas, aprovadas, pendentes, canceladas]
        [_tabCtrl.index.clamp(0, 3)];

    return Column(
      children: [
        // ── KPIs ──
        _kpiRow(todas),

        // ── Barra de busca + filtros ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Column(
            children: [
              // Busca
              TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText:
                      'Buscar cliente, produto, afiliado, payment ID…',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF0D2B1A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              const SizedBox(height: 8),

              // Filtros: tipo + data + export
              Row(
                children: [
                  // Tipo chips
                  _TipoChip(
                    label: 'Todos',
                    selected: _tipoFiltro == null,
                    onTap: () => setState(() => _tipoFiltro = null),
                  ),
                  const SizedBox(width: 6),
                  _TipoChip(
                    label: 'Mensal',
                    selected: _tipoFiltro == 'pixRecorrente',
                    color: Colors.blue[700]!,
                    onTap: () => setState(() => _tipoFiltro =
                        _tipoFiltro == 'pixRecorrente' ? null : 'pixRecorrente'),
                  ),
                  const SizedBox(width: 6),
                  _TipoChip(
                    label: 'Único',
                    selected: _tipoFiltro == 'pixAvulso',
                    color: Colors.purple[700]!,
                    onTap: () => setState(() => _tipoFiltro =
                        _tipoFiltro == 'pixAvulso' ? null : 'pixAvulso'),
                  ),
                  const Spacer(),

                  // Date range picker
                  GestureDetector(
                    onTap: _pickDateRange,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: _dateRange != null
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : const Color(0xFF0D2B1A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _dateRange != null
                              ? AppColors.primary
                              : Colors.white24,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 14,
                              color: _dateRange != null
                                  ? AppColors.primary
                                  : Colors.white54),
                          const SizedBox(width: 4),
                          Text(
                            _dateRange != null
                                ? '${_fmtDateShort(_dateRange!.start)}–${_fmtDateShort(_dateRange!.end)}'
                                : 'Data',
                            style: TextStyle(
                              fontSize: 11,
                              color: _dateRange != null
                                  ? AppColors.primary
                                  : Colors.white54,
                            ),
                          ),
                          if (_dateRange != null) ...[
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => setState(() => _dateRange = null),
                              child: const Icon(Icons.close,
                                  size: 12, color: Colors.white54),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Export button
                  IconButton(
                    onPressed: () => _showExportDialog(currentList),
                    icon: const Icon(Icons.download_rounded),
                    color: AppColors.gold,
                    tooltip: 'Exportar',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.gold.withValues(alpha: 0.1),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── TabBar ──
        Container(
          color: const Color(0xFF071A10),
          child: TabBar(
            controller: _tabCtrl,
            onTap: (_) => setState(() {}),
            indicatorColor: AppColors.gold,
            labelColor: AppColors.gold,
            unselectedLabelColor: Colors.white38,
            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            tabs: [
              Tab(text: 'Todas (${todas.length})'),
              Tab(text: 'Aprovadas (${aprovadas.length})'),
              Tab(text: 'Pendentes (${pendentes.length})'),
              Tab(text: 'Canceladas (${canceladas.length})'),
            ],
          ),
        ),

        // ── Conteúdo ──
        Expanded(
          child: svc.isLoadingData
              ? const Center(
                  child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _SalesList(sales: todas, onExport: () => _showExportDialog(todas)),
                    _SalesList(
                        sales: aprovadas,
                        onExport: () => _showExportDialog(aprovadas)),
                    _SalesList(
                        sales: pendentes,
                        onExport: () => _showExportDialog(pendentes)),
                    _SalesList(
                        sales: canceladas,
                        onExport: () => _showExportDialog(canceladas)),
                  ],
                ),
        ),
      ],
    );
  }
}

// ── Lista de vendas ────────────────────────────────────────────────────────────
class _SalesList extends StatelessWidget {
  final List<AdminSale> sales;
  final VoidCallback onExport;

  const _SalesList({required this.sales, required this.onExport});

  @override
  Widget build(BuildContext context) {
    if (sales.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            const Text('Nenhuma venda encontrada',
                style: TextStyle(color: Colors.white38, fontSize: 14)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        if (context.mounted) {
          await context.read<AdminService>().loadSales();
        }
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
        itemCount: sales.length,
        itemBuilder: (ctx, i) => _SaleCard(sale: sales[i]),
      ),
    );
  }
}

// ── Card de venda ──────────────────────────────────────────────────────────────
class _SaleCard extends StatelessWidget {
  final AdminSale sale;

  const _SaleCard({required this.sale});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2B1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1A4030), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linha 1: produto + status + tipo
            Row(
              children: [
                Expanded(
                  child: Text(
                    sale.productNome,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Tipo badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: sale.chargeType == 'pixRecorrente'
                        ? Colors.blue[900]!.withValues(alpha: 0.8)
                        : Colors.purple[900]!.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    sale.chargeTypeLabel,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: sale.chargeType == 'pixRecorrente'
                            ? Colors.blue[200]
                            : Colors.purple[200]),
                  ),
                ),
                const SizedBox(width: 6),
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: sale.statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: sale.statusColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    sale.statusLabel,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: sale.statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Linha 2: cliente
            Row(
              children: [
                const Icon(Icons.person_outline_rounded,
                    size: 13, color: Colors.white38),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    sale.clienteNome.isNotEmpty
                        ? '${sale.clienteNome}'
                            '${sale.clienteEmail.isNotEmpty ? ' · ${sale.clienteEmail}' : ''}'
                        : sale.clienteEmail.isNotEmpty
                            ? sale.clienteEmail
                            : 'Cliente não identificado',
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Linha 3: afiliado + data
            Row(
              children: [
                const Icon(Icons.link_rounded,
                    size: 13, color: Colors.white38),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    sale.affiliateCode.isNotEmpty
                        ? '${sale.affiliateCode}'
                            '${sale.affiliateNome.isNotEmpty ? ' · ${sale.affiliateNome}' : ''}'
                        : 'Sem afiliado',
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _fmtDate(sale.createdAt),
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Linha 4: valores + botão docs
            Row(
              children: [
                _ValorBadge(
                    label: 'Valor',
                    value:
                        'R\$ ${sale.valor.toStringAsFixed(2)}',
                    color: AppColors.gold),
                const SizedBox(width: 8),
                _ValorBadge(
                    label: 'Comissão',
                    value:
                        'R\$ ${sale.comissao.toStringAsFixed(2)}',
                    color: AppColors.primary),
                const Spacer(),
                // Botão Ver Documentos
                GestureDetector(
                  onTap: () => _showDocsDialog(context, sale),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder_open_rounded, size: 12, color: Colors.blue),
                        SizedBox(width: 4),
                        Text('Docs', style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                if (sale.paymentId.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: sale.paymentId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Payment ID copiado'),
                            duration: Duration(seconds: 1)),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.fingerprint_rounded,
                            size: 12, color: Colors.white24),
                        const SizedBox(width: 3),
                        Text(
                          '#${sale.paymentId.length > 10 ? sale.paymentId.substring(0, 10) : sale.paymentId}…',
                          style: const TextStyle(
                              color: Colors.white24, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dialog de documentos ───────────────────────────────────────────────────────
void _showDocsDialog(BuildContext context, AdminSale sale) {
  showDialog(
    context: context,
    builder: (ctx) => _SaleDocsDialog(sale: sale),
  );
}

class _SaleDocsDialog extends StatefulWidget {
  final AdminSale sale;
  const _SaleDocsDialog({required this.sale});
  @override
  State<_SaleDocsDialog> createState() => _SaleDocsDialogState();
}

class _SaleDocsDialogState extends State<_SaleDocsDialog> {
  bool _loading = true;
  Map<String, dynamic>? _docsData;
  String? _error;

  static const _docLabels = {
    'cnh': 'CNH',
    'selfie': 'Selfie / Foto',
    'comp_residencia': 'Comprovante de Residência',
    'comp_renda': 'Comprovante de Renda',
    'geolocalizacao': 'Geolocalização',
    'certidao': 'Certidão de Nascimento',
    // ── Novos ────────────────────────────────────────────────────────────────
    'foto_moto':      'Fotos da Moto',
    'foto_carro':     'Fotos do Carro',
    'foto_celular':   'Fotos do Celular',
    'print_imei':     'Print do IMEI',
    'foto_doc_moto':  'Fotos Documento da Moto',
    'foto_doc_carro': 'Fotos Documento do Carro',
    'nota_fiscal':    'Nota Fiscal (se tiver)',
  };

  /// Para chaves de campos personalizados (ex: "ano_moto_1234567890"),
  /// remove o sufixo numérico e converte underscores em espaços capitalizados.
  static String _resolveLabel(String key) {
    if (_docLabels.containsKey(key)) return _docLabels[key]!;
    // Remove sufixo numérico de timestamp (últimos dígitos após o último _)
    final cleaned = key.replaceAll(RegExp(r'_\d+$'), '');
    return cleaned
        .split('_')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await CfApiService.getSaleDocs(widget.sale.id);
      if (!mounted) return;
      if (result == null) {
        setState(() { _error = 'Nenhum documento encontrado para esta venda.'; _loading = false; });
        return;
      }
      final raw = result['docs_data'];
      Map<String, dynamic> docs = {};
      if (raw is Map) {
        docs = Map<String, dynamic>.from(raw);
      } else if (raw is String) {
        try { docs = Map<String, dynamic>.from(json.decode(raw)); } catch (_) {}
      }
      setState(() { _docsData = docs; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Erro: $e'; _loading = false; });
    }
  }

  void _copyLink() {
    final link = 'https://api.sharewallet.com.br/api/sale-docs/${widget.sale.id}';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copiado!'), duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0D2B1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.folder_copy_rounded, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                const Expanded(child: Text('Documentos da Venda',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15))),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Venda: ${widget.sale.id}',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
            Text('Cliente: ${widget.sale.clienteNome.isNotEmpty ? widget.sale.clienteNome : widget.sale.clienteEmail}',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const Divider(color: Colors.white12, height: 20),
            if (_loading)
              const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: Colors.blue),
              ))
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(_error!, style: const TextStyle(color: Colors.orange, fontSize: 13)),
              )
            else ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: (_docsData ?? {}).entries.map((e) {
                      final label   = _resolveLabel(e.key);
                      final val     = e.value?.toString() ?? '';
                      final isImg   = val.startsWith('data:image');
                      final isGeo   = e.key == 'geolocalizacao';
                      final isCustomField = !isImg && !isGeo &&
                          !_docLabels.containsKey(e.key);

                      // Tenta decodificar JSON de geolocalização
                      Map<String, dynamic>? geoMap;
                      if (isGeo) {
                        try { geoMap = json.decode(val) as Map<String, dynamic>; } catch (_) {}
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isGeo
                                      ? Icons.my_location_rounded
                                      : isCustomField
                                          ? Icons.edit_note_rounded
                                          : Icons.insert_drive_file_rounded,
                                  size: 13,
                                  color: isGeo
                                      ? Colors.blue
                                      : isCustomField
                                          ? Colors.amber
                                          : Colors.white38,
                                ),
                                const SizedBox(width: 5),
                                Text(label, style: TextStyle(
                                    color: isGeo
                                        ? Colors.blue[200]
                                        : isCustomField
                                            ? Colors.amber[200]
                                            : Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (isGeo && geoMap != null) ...[
                              // Card GPS
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      const Icon(Icons.location_on_rounded, size: 14, color: Colors.blue),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Lat: ${(geoMap['lat'] as num).toStringAsFixed(6)}',
                                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                    ]),
                                    const SizedBox(height: 2),
                                    Row(children: [
                                      const SizedBox(width: 18),
                                      Text(
                                        'Lng: ${(geoMap['lng'] as num).toStringAsFixed(6)}',
                                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                    ]),
                                    if (geoMap['acc'] != null) ...[
                                      const SizedBox(height: 2),
                                      Row(children: [
                                        const SizedBox(width: 18),
                                        Text(
                                          'Precisão: ±${(geoMap['acc'] as num).toStringAsFixed(0)}m',
                                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                                        ),
                                      ]),
                                    ],
                                    if (geoMap['ts'] != null) ...[
                                      const SizedBox(height: 2),
                                      Row(children: [
                                        const SizedBox(width: 18),
                                        Text(
                                          'Capturado: ${geoMap['ts'].toString().replaceAll('T', ' ').split('.').first}',
                                          style: const TextStyle(color: Colors.white38, fontSize: 10),
                                        ),
                                      ]),
                                    ],
                                    const SizedBox(height: 8),
                                    // Botão Google Maps
                                    GestureDetector(
                                      onTap: () {
                                        final lat = geoMap!['lat'];
                                        final lng = geoMap['lng'];
                                        final mapsUrl = 'https://www.google.com/maps?q=$lat,$lng';
                                        Clipboard.setData(ClipboardData(text: mapsUrl));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Link do Google Maps copiado!'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.map_rounded, size: 13, color: Colors.blue),
                                            SizedBox(width: 5),
                                            Text('Copiar link Google Maps',
                                                style: TextStyle(fontSize: 11, color: Colors.blue)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (isImg) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  val,
                                  height: 120,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Text('Erro ao carregar imagem',
                                          style: TextStyle(color: Colors.red, fontSize: 11)),
                                ),
                              ),
                            ] else ...[
                              // Campo personalizado (texto livre digitado pelo comprador)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.amber.withValues(alpha: 0.25)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.edit_note_rounded,
                                        size: 15, color: Colors.amber),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        val.isEmpty ? '—' : val,
                                        style: TextStyle(
                                          color: val.isEmpty
                                              ? Colors.white24
                                              : Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _copyLink,
                icon: const Icon(Icons.link_rounded, size: 16),
                label: const Text('Copiar link de documentos'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ─────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2B1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 10)),
                Text(value,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TipoChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _TipoChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.25) : const Color(0xFF0D2B1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? c : Colors.white24, width: selected ? 1.5 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? c : Colors.white54,
          ),
        ),
      ),
    );
  }
}

class _ValorBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ValorBadge(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 9)),
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ExportButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _fmtDateShort(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
