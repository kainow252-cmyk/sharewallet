import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/subscription_model.dart';
import '../../models/product_model.dart';
import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/web_utils.dart';

/// Tela de Relatórios Admin - exporta CSV / JSON das tabelas D1
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  // 3 bools separados - um por aba - evita que o loading de uma aba
  // afete as outras (bug anterior: _exporting único compartilhado).
  bool _exportingAfiliados    = false;
  bool _exportingSaques       = false;
  bool _exportingAssinaturas  = false;
  bool _exportingVendas       = false;
  bool _refreshing = false;

  // Filtros de data
  DateTime? _de;
  DateTime? _ate;

  // Filtro de tipo de cobrança na aba Assinaturas
  // null = todos, 'mensal' = pixRecorrente, 'unico' = pixAvulso
  String? _tipoFiltro;

  final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    // Recarregar dados sempre que a tela for montada
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminService>().loadAll();
    });
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await context.read<AdminService>().loadAll();
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // -- Helpers de data --------------------------------------------------------

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

  // -- Download no browser via JS ---------------------------------------------

  void _downloadCsv(String filename, String csv) {
    try {
      final encoded = base64Encode(utf8.encode(csv));
      final dataUri = 'data:text/csv;charset=utf-8;base64,$encoded';
      downloadFileWeb(dataUri, filename);
    } catch (e) {
      debugPrint('[Reports] Erro download CSV: $e');
    }
  }

  void _downloadJson(String filename, String jsonData) {
    try {
      final encoded = base64Encode(utf8.encode(jsonData));
      final dataUri = 'data:application/json;charset=utf-8;base64,$encoded';
      downloadFileWeb(dataUri, filename);
    } catch (e) {
      debugPrint('[Reports] Erro download JSON: $e');
    }
  }

  /// Gera PDF via data URI base64 com HTML/CSS estilizado.
  /// Abre nova aba com tabela formatada e botão de impressão.
  void _printPdf(String title, String htmlTable) {
    try {
      final now = DateTime.now().toString().substring(0, 16);
      final htmlContent = '''<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<title>$title</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: Arial, sans-serif; font-size: 12px; color: #1a1a2e; padding: 20px; }
  h1 { font-size: 18px; color: #0D5C3D; margin-bottom: 4px; }
  .sub { font-size: 11px; color: #666; margin-bottom: 16px; }
  table { width: 100%; border-collapse: collapse; }
  th { background: #0D5C3D; color: white; padding: 7px 8px; text-align: left; font-size: 11px; }
  td { padding: 6px 8px; border-bottom: 1px solid #e8f5e9; font-size: 11px; }
  tr:nth-child(even) td { background: #f8fffe; }
  .badge { display: inline-block; padding: 2px 6px; border-radius: 4px; font-weight: 700; font-size: 10px; }
  .badge-green { background: #e8f5e9; color: #1B5E20; }
  .badge-blue  { background: #e3f2fd; color: #0D47A1; }
  .badge-amber { background: #fff8e1; color: #F57F17; }
  .badge-red   { background: #fce4ec; color: #B71C1C; }
  @media print { body { padding: 0; } button { display: none; } }
</style>
</head>
<body>
<h1>$title</h1>
<p class="sub">Gerado em: $now | ShareWallet Admin</p>
<button onclick="window.print()" style="margin-bottom:12px;padding:6px 16px;background:#0D5C3D;color:white;border:none;border-radius:6px;cursor:pointer;font-size:12px;">Imprimir / Salvar PDF</button>
$htmlTable
</body></html>''';
      // Abrir como data URI - evita problemas com document.write e popups
      final encoded = base64Encode(utf8.encode(htmlContent));
      final dataUri = 'data:text/html;charset=utf-8;base64,$encoded';
      openUrlInNewTab(dataUri);
    } catch (e) {
      debugPrint('[Reports] Erro PDF: \$e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao gerar PDF: \$e'), backgroundColor: AppColors.error),
      );
    }
  }

  // -- HTML tables para PDF ----------------------------------------------------

  String _htmlAfiliados(List<AdminAffiliate> rows) {
    final buf = StringBuffer();
    buf.write('<table><tr>');
    for (final h in ['Nome','Email','Código','Status','Comissões','Saldo','Assinaturas','Cadastro']) {
      buf.write('<th>$h</th>');
    }
    buf.write('</tr>');
    for (final a in rows) {
      final sc = a.status == 'ativo' ? 'green' : 'amber';
      buf.write('<tr>'
          '<td>${a.nome}</td>'
          '<td>${a.email}</td>'
          '<td>${a.affiliateCode}</td>'
          '<td><span class="badge badge-$sc">${a.status}</span></td>'
          '<td>R\$ ${a.totalComissoes.toStringAsFixed(2)}</td>'
          '<td>R\$ ${a.saldoDisponivel.toStringAsFixed(2)}</td>'
          '<td>${a.totalAssinaturas}</td>'
          '<td>${_dateFmt.format(a.createdAt)}</td>'
          '</tr>');
    }
    buf.write('</table>');
    return buf.toString();
  }

  String _htmlSaques(List<AdminWithdrawal> rows) {
    final buf = StringBuffer();
    buf.write('<table><tr>');
    for (final h in ['Afiliado','Código','Valor','Chave PIX','Status','Solicitado','Tx ID']) {
      buf.write('<th>$h</th>');
    }
    buf.write('</tr>');
    for (final w in rows) {
      final sc = w.status == 'aprovado' ? 'green' : w.status == 'recusado' ? 'red' : 'amber';
      buf.write('<tr>'
          '<td>${w.affiliateNome}</td>'
          '<td>${w.affiliateCode}</td>'
          '<td><strong>R\$ ${w.valor.toStringAsFixed(2)}</strong></td>'
          '<td>${w.pixKey}</td>'
          '<td><span class="badge badge-$sc">${w.statusLabel}</span></td>'
          '<td>${_dateFmt.format(w.solicitadoEm)}</td>'
          '<td>${w.txId ?? ""}</td>'
          '</tr>');
    }
    buf.write('</table>');
    return buf.toString();
  }

  String _htmlAssinaturas(List<SubscriptionModel> rows) {
    final buf = StringBuffer();
    buf.write('<table><tr>');
    for (final h in ['Produto','Afiliado','Código','Tipo','Valor','Comissão','Status','Início','Próx. Cobr.']) {
      buf.write('<th>$h</th>');
    }
    buf.write('</tr>');
    for (final s in rows) {
      final sc = s.status == SubscriptionStatus.ativa ? 'green' :
                 s.status == SubscriptionStatus.cancelada ? 'red' : 'amber';
      final tc = s.chargeType == ChargeType.pixRecorrente ? 'blue' : 'amber';
      final tipo = s.chargeType == ChargeType.pixRecorrente ? 'Mensal' : 'Único';
      final diaStr = s.chargeType == ChargeType.pixRecorrente ? 'Dia ${s.diaCobranca}' : 'N/A';
      buf.write('<tr>'
          '<td>${s.productNome}</td>'
          '<td>${s.affiliateNome ?? s.affiliateCode}</td>'
          '<td>${s.affiliateCode}</td>'
          '<td><span class="badge badge-$tc">$tipo</span></td>'
          '<td>R\$ ${s.valor.toStringAsFixed(2)}</td>'
          '<td>R\$ ${s.valorComissao.toStringAsFixed(2)} (${s.comissaoPercent}%)</td>'
          '<td><span class="badge badge-$sc">${s.statusLabel}</span></td>'
          '<td>${_dateFmt.format(s.dataInicio)}</td>'
          '<td>$diaStr</td>'
          '</tr>');
    }
    buf.write('</table>');
    return buf.toString();
  }

  String _htmlVendas(List<AdminSale> rows) {
    final buf = StringBuffer();
    buf.write('<table><tr>');
    for (final h in ['Data','Cliente','Produto','Afiliado','Tipo','Valor','Comissão','Status','Payment ID']) {
      buf.write('<th>$h</th>');
    }
    buf.write('</tr>');
    final df = DateFormat('dd/MM/yyyy HH:mm');
    for (final v in rows) {
      final sc = v.status == 'aprovado' ? 'green' : v.status == 'cancelado' ? 'red' : 'amber';
      final tc = v.chargeType == 'pixRecorrente' ? 'blue' : 'amber';
      final cliente = v.clienteNome.isNotEmpty ? v.clienteNome :
                      v.clienteEmail.isNotEmpty ? v.clienteEmail : 'N/A';
      final afNome = v.affiliateNome.isNotEmpty ? v.affiliateNome : v.affiliateCode;
      buf.write('<tr>'
          '<td>${df.format(v.createdAt)}</td>'
          '<td>$cliente</td>'
          '<td>${v.productNome}</td>'
          '<td>$afNome</td>'
          '<td><span class="badge badge-$tc">${v.chargeTypeLabel}</span></td>'
          '<td><strong>R\$ ${v.valor.toStringAsFixed(2)}</strong></td>'
          '<td>R\$ ${v.comissao.toStringAsFixed(2)}</td>'
          '<td><span class="badge badge-$sc">${v.statusLabel}</span></td>'
          '<td style="font-size:10px;color:#999;">${v.paymentId.isNotEmpty ? v.paymentId : "-"}</td>'
          '</tr>');
    }
    buf.write('</table>');
    return buf.toString();
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

  // -- Gerador CSV - Vendas -----------------------------------------------------

  String _csvVendas(List<AdminSale> rows) {
    final buf = StringBuffer();
    buf.writeln('Data,Cliente Nome,Cliente Email,Produto,Afiliado Código,Afiliado Nome,'
        'Tipo,Valor (R\$),Comissão (R\$),Status,Payment ID');
    final df = DateFormat('dd/MM/yyyy HH:mm');
    for (final v in rows) {
      buf.writeln([
        _esc(df.format(v.createdAt)),
        _esc(v.clienteNome.isNotEmpty ? v.clienteNome : 'N/A'),
        _esc(v.clienteEmail.isNotEmpty ? v.clienteEmail : 'N/A'),
        _esc(v.productNome),
        _esc(v.affiliateCode),
        _esc(v.affiliateNome.isNotEmpty ? v.affiliateNome : 'N/A'),
        _esc(v.chargeTypeLabel),
        v.valor.toStringAsFixed(2),
        v.comissao.toStringAsFixed(2),
        _esc(v.statusLabel),
        _esc(v.paymentId.isNotEmpty ? v.paymentId : 'N/A'),
      ].join(','));
    }
    return buf.toString();
  }

  // -- Gerador CSV - Afiliados ------------------------------------------------

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

  // -- Gerador CSV - Saques --------------------------------------------------

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

  // -- Gerador CSV - Assinaturas ---------------------------------------------
  // Tipo legível: 'Mensal (PIX Recorrente)' ou 'Único (PIX Avulso)'
  static String _tipoLegivel(ChargeType ct) =>
      ct == ChargeType.pixRecorrente ? 'Mensal (PIX Recorrente)' : 'Único (PIX Avulso)';

  String _csvAssinaturas(List<SubscriptionModel> rows) {
    final buf = StringBuffer();
    buf.writeln(
        'ID,Produto,Nome Afiliado,Código Afiliado,'
        'Valor (R\$),Comissão (R\$),Comissão (%),'
        'Status,Tipo de Cobrança,'
        'Data Início,Data Cancelamento,Próxima Cobrança,Dia Cobrança,'
        'Chave PIX Assinante,Motivo,Meses Ativo,Total Comissões Geradas (R\$)');
    for (final s in rows) {
      buf.writeln([
        _esc(s.id),
        _esc(s.productNome),
        _esc(s.affiliateNome ?? ''),
        _esc(s.affiliateCode),
        s.valor.toStringAsFixed(2),
        s.valorComissao.toStringAsFixed(2),           // R$ correto
        '${s.comissaoPercent}%',                      // percentual legível
        _esc(_statusLegivel(s.status)),
        _esc(_tipoLegivel(s.chargeType)),              // tipo legível
        _dateFmt.format(s.dataInicio),
        s.dataCancelamento != null
            ? _dateFmt.format(s.dataCancelamento!) : '',
        _dateFmt.format(s.proximaCobranca),
        s.chargeType == ChargeType.pixRecorrente
            ? s.diaCobranca.toString() : 'N/A',
        _esc(s.pixKey ?? ''),
        _esc(s.motivo ?? ''),
        s.mesesAtivo.toString(),
        s.totalComissoesGeradas.toStringAsFixed(2),
      ].join(','));
    }
    return buf.toString();
  }

  static String _statusLegivel(SubscriptionStatus st) {
    switch (st) {
      case SubscriptionStatus.ativa:      return 'Ativa';
      case SubscriptionStatus.pendente:   return 'Pendente';
      case SubscriptionStatus.cancelada:  return 'Cancelada';
      case SubscriptionStatus.aguardando: return 'Aguardando';
    }
  }

  static String _esc(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"','""')}"';
    }
    return v;
  }

  // -- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<AdminService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // -- Header com botão refresh -------------------------------------
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                const Icon(Icons.filter_alt_rounded,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Filtrar por período',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textPrimary),
                  ),
                ),
                // Botão Atualizar
                TextButton.icon(
                  onPressed: _refreshing ? null : _refresh,
                  icon: _refreshing
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(_refreshing ? 'Atualizando...' : 'Atualizar'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          // -- Filtro de datas ----------------------------------------------
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      child: Text('->',
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

          // -- Tabs ----------------------------------------------------------
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
              Tab(
                  icon: const Icon(Icons.receipt_long_rounded, size: 18),
                  text: 'Vendas',
                ),
              ],
            ),
          ),

          Expanded(
            child: _buildBody(svc),
          ),
        ],
      ),
    );
  }

  // -- Corpo principal - separado para clareza e garantir height constraint ----
  Widget _buildBody(AdminService svc) {
    // Loading - só mostra spinner se realmente não tem dados ainda
    if (svc.isLoadingData && svc.affiliates.isEmpty && svc.subscriptions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    // Erro de rede (só mostra se lista também está vazia)
    if (svc.error != null && svc.affiliates.isEmpty && svc.subscriptions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  color: AppColors.error, size: 48),
              const SizedBox(height: 12),
              const Text('Erro ao carregar dados',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontSize: 15)),
              const SizedBox(height: 8),
              Text(
                svc.error ?? '',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Tentar novamente'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary),
              ),
            ],
          ),
        ),
      );
    }
    // Dados carregados - exibe as abas
    return TabBarView(
      controller: _tab,
      children: [
                      // -- Afiliados ------------------------------------------
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
                        onDownloadPdf: (rows) => _printPdf(
                          'Relatório de Afiliados',
                          _htmlAfiliados(rows),
                        ),
                        exporting: _exportingAfiliados,
                        onExportingChange: (v) =>
                            setState(() => _exportingAfiliados = v),
                      ),

                      // -- Saques ---------------------------------------------
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
                        onDownloadPdf: (rows) => _printPdf(
                          'Relatório de Saques',
                          _htmlSaques(rows),
                        ),
                        exporting: _exportingSaques,
                        onExportingChange: (v) =>
                            setState(() => _exportingSaques = v),
                      ),

                      // -- Assinaturas ----------------------------------------
                      _ReportTab<SubscriptionModel>(
                        items: svc.subscriptions,
                        dateOf: (s) => s.dataInicio,
                        // Aplica filtro de data E filtro de tipo de cobrança
                        filter: (d) => _inRange(d),
                        typeFilter: _tipoFiltro,
                        typeFilterGetter: (s) => s.chargeType == ChargeType.pixRecorrente
                            ? 'mensal' : 'unico',
                        typeFilterWidget: _buildTipoFilterChips(),
                        csvBuilder: _csvAssinaturas,
                        jsonBuilder: (rows) => jsonEncode(rows
                            .map((s) => {
                                  'id': s.id,
                                  'product_nome': s.productNome,
                                  'affiliate_nome': s.affiliateNome ?? '',
                                  'affiliate_code': s.affiliateCode,
                                  'valor': s.valor,
                                  'valor_comissao': s.valorComissao,
                                  'comissao_percent': s.comissaoPercent,
                                  'status': _statusLegivel(s.status),
                                  'tipo_cobranca': _tipoLegivel(s.chargeType),
                                  'charge_type_raw': s.chargeType.name,
                                  'data_inicio': s.dataInicio.toIso8601String(),
                                  'data_cancelamento':
                                      s.dataCancelamento?.toIso8601String() ?? '',
                                  'proxima_cobranca':
                                      s.proximaCobranca.toIso8601String(),
                                  'dia_cobranca': s.chargeType ==
                                      ChargeType.pixRecorrente
                                      ? s.diaCobranca : null,
                                  'pix_key': s.pixKey ?? '',
                                  'motivo': s.motivo ?? '',
                                  'meses_ativo': s.mesesAtivo,
                                  'total_comissoes_geradas':
                                      s.totalComissoesGeradas,
                                })
                            .toList()),
                        filenameBase: 'assinaturas',
                        summaryWidgets: (rows) {
                          final ativas = rows
                              .where((s) =>
                                  s.status == SubscriptionStatus.ativa)
                              .toList();
                          final mensais = ativas.where((s) =>
                              s.chargeType == ChargeType.pixRecorrente).toList();
                          final unicas = ativas.where((s) =>
                              s.chargeType == ChargeType.pixAvulso).toList();
                          return [
                            _SummaryKpi(
                              label: 'Total',
                              value: rows.length.toString(),
                              icon: Icons.repeat_rounded,
                              color: AppColors.primary,
                            ),
                            _SummaryKpi(
                              label: 'Mensais',
                              value: mensais.length.toString(),
                              icon: Icons.autorenew_rounded,
                              color: AppColors.success,
                            ),
                            _SummaryKpi(
                              label: 'Únicas',
                              value: unicas.length.toString(),
                              icon: Icons.pix_rounded,
                              color: AppColors.info,
                            ),
                            _SummaryKpi(
                              label: 'MRR',
                              value: _fmt.format(mensais.fold(
                                  0.0, (s, a) => s + a.valor)),
                              icon: Icons.trending_up_rounded,
                              color: AppColors.gold,
                            ),
                          ];
                        },
                        rowBuilder: (s) =>
                            _SubscriptionRow(s: s, fmt: _fmt),
                        onDownloadCsv: _downloadCsv,
                        onDownloadJson: _downloadJson,
                        onCopy: _copyToClipboard,
                        exporting: _exportingAssinaturas,
                        onExportingChange: (v) =>
                            setState(() => _exportingAssinaturas = v),
                        onDownloadPdf: (rows) => _printPdf(
                          'Relatório de Assinaturas',
                          _htmlAssinaturas(rows),
                        ),
                      ),

                      // -- Vendas ---------------------------------------------
                      _ReportTab<AdminSale>(
                        items: svc.sales,
                        dateOf: (v) => v.createdAt,
                        filter: _inRange,
                        typeFilter: _tipoFiltro,
                        typeFilterGetter: (v) =>
                            v.chargeType == 'pixRecorrente' ? 'mensal' : 'unico',
                        typeFilterWidget: _buildTipoFilterChips(),
                        csvBuilder: _csvVendas,
                        jsonBuilder: (rows) => jsonEncode(rows.map((v) => {
                              'data': v.createdAt.toIso8601String(),
                              'cliente_nome': v.clienteNome,
                              'cliente_email': v.clienteEmail,
                              'produto': v.productNome,
                              'affiliate_code': v.affiliateCode,
                              'affiliate_nome': v.affiliateNome,
                              'tipo': v.chargeType,
                              'valor': v.valor,
                              'comissao': v.comissao,
                              'status': v.status,
                              'payment_id': v.paymentId,
                            }).toList()),
                        filenameBase: 'vendas',
                        summaryWidgets: (rows) {
                          final aprov = rows.where((v) => v.status == 'aprovado').toList();
                          final volume  = aprov.fold(0.0, (s, v) => s + v.valor);
                          final comiss  = aprov.fold(0.0, (s, v) => s + v.comissao);
                          return [
                            _SummaryKpi(
                              label: 'Total',
                              value: rows.length.toString(),
                              icon: Icons.receipt_long_rounded,
                              color: AppColors.primary,
                            ),
                            _SummaryKpi(
                              label: 'Aprovadas',
                              value: aprov.length.toString(),
                              icon: Icons.check_circle_rounded,
                              color: AppColors.success,
                            ),
                            _SummaryKpi(
                              label: 'Volume',
                              value: _fmt.format(volume),
                              icon: Icons.attach_money_rounded,
                              color: AppColors.gold,
                            ),
                            _SummaryKpi(
                              label: 'Comissões',
                              value: _fmt.format(comiss),
                              icon: Icons.volunteer_activism_rounded,
                              color: AppColors.info,
                            ),
                          ];
                        },
                        rowBuilder: (v) => _VendaRow(v: v, fmt: _fmt),
                        onDownloadCsv: _downloadCsv,
                        onDownloadJson: _downloadJson,
                        onCopy: _copyToClipboard,
                        onDownloadPdf: (rows) => _printPdf(
                          'Relatório de Vendas',
                          _htmlVendas(rows),
                        ),
                        exporting: _exportingVendas,
                        onExportingChange: (v) =>
                            setState(() => _exportingVendas = v),
                      ),
      ],
    );
  }

  // -- Chips de filtro de tipo de cobrança ------------------------------------
  Widget _buildTipoFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_outlined,
              size: 14, color: AppColors.textHint),
          const SizedBox(width: 6),
          const Text('Tipo:',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          _TipoChip(
            label: 'Todos',
            icon: Icons.all_inclusive_rounded,
            selected: _tipoFiltro == null,
            color: AppColors.primary,
            onTap: () => setState(() => _tipoFiltro = null),
          ),
          const SizedBox(width: 6),
          _TipoChip(
            label: 'Mensal',
            icon: Icons.autorenew_rounded,
            selected: _tipoFiltro == 'mensal',
            color: AppColors.success,
            onTap: () => setState(
                () => _tipoFiltro = _tipoFiltro == 'mensal' ? null : 'mensal'),
          ),
          const SizedBox(width: 6),
          _TipoChip(
            label: 'Único',
            icon: Icons.pix_rounded,
            selected: _tipoFiltro == 'unico',
            color: AppColors.info,
            onTap: () => setState(
                () => _tipoFiltro = _tipoFiltro == 'unico' ? null : 'unico'),
          ),
        ],
      ),
    );
  }
}


// -- _DateChip ----------------------------------------------------------------
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

// -- _SummaryKpi ---------------------------------------------------------------
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
    // NÃO usa Expanded aqui - o Row pai no _ReportTab gerencia o layout
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
    );
  }
}

// -- Tab genérica de relatório -------------------------------------------------
class _ReportTab<T> extends StatelessWidget {
  final List<T> items;
  final DateTime Function(T) dateOf;
  final bool Function(DateTime) filter;
  // Filtro de tipo adicional (opcional) — ex: 'mensal' ou 'unico'
  final String? typeFilter;
  final String Function(T)? typeFilterGetter;
  final Widget? typeFilterWidget;
  final String Function(List<T>) csvBuilder;
  final String Function(List<T>) jsonBuilder;
  final String filenameBase;
  final List<Widget> Function(List<T>) summaryWidgets;
  final Widget Function(T) rowBuilder;
  final void Function(String, String) onDownloadCsv;
  final void Function(String, String) onDownloadJson;
  final void Function(String) onCopy;
  // PDF opcional — se null, botão Gerar PDF não aparece
  final void Function(List<T>)? onDownloadPdf;
  final bool exporting;
  final void Function(bool) onExportingChange;

  const _ReportTab({
    required this.items,
    required this.dateOf,
    required this.filter,
    this.typeFilter,
    this.typeFilterGetter,
    this.typeFilterWidget,
    required this.csvBuilder,
    required this.jsonBuilder,
    required this.filenameBase,
    required this.summaryWidgets,
    required this.rowBuilder,
    required this.onDownloadCsv,
    required this.onDownloadJson,
    required this.onCopy,
    this.onDownloadPdf,
    required this.exporting,
    required this.onExportingChange,
  });

  List<T> get _filtered => items.where((i) {
    if (!filter(dateOf(i))) return false;
    if (typeFilter != null && typeFilterGetter != null) {
      if (typeFilterGetter!(i) != typeFilter) return false;
    }
    return true;
  }).toList();

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
      } else if (format == 'pdf') {
        onDownloadPdf!(rows);
        if (ctx.mounted) _showSnack(ctx, '\u2705 PDF gerado! (${rows.length} registros)');
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
        // -- KPIs de resumo -----------------------------------------------
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              // summaryWidgets retorna widgets simples (sem Expanded)
              // Cada KPI ocupa espaço igual via Expanded aqui no Row
              ...summaryWidgets(rows).asMap().entries.map((entry) {
                final isLast = entry.key == summaryWidgets(rows).length - 1;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: isLast ? 0 : 8),
                    child: entry.value,
                  ),
                );
              }),
            ],
          ),
        ),

        // -- Filtro de tipo (opcional, aparece só na aba Assinaturas) -------
        if (typeFilterWidget != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: typeFilterWidget!,
          ),

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
                      'Exportar  -  ${rows.length} registros',
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
                // -- Botão PDF (só aparece se onDownloadPdf foi passado) ------
                if (onDownloadPdf != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: _ExportButton(
                      label: 'Gerar PDF',
                      icon: Icons.picture_as_pdf_rounded,
                      color: const Color(0xFFD32F2F),
                      loading: exporting,
                      onTap: () => _doExport(context, 'pdf'),
                      fullWidth: true,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),


        // -- Tabela / Lista ------------------------------------------------
        Expanded(
          child: rows.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        items.isEmpty
                            ? Icons.inbox_rounded
                            : Icons.search_off_rounded,
                        color: AppColors.textHint,
                        size: 52,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        items.isEmpty
                            ? 'Nenhum registro encontrado'
                            : 'Nenhum registro no período selecionado',
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                      if (items.isEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Os dados aparecerão aqui\nconforme forem gerados no sistema.',
                          style: TextStyle(
                              color: AppColors.textHint, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
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

// -- Botão de exportação -------------------------------------------------------
class _ExportButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback onTap;
  final bool fullWidth;

  const _ExportButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
            vertical: fullWidth ? 9 : 10,
            horizontal: fullWidth ? 16 : 0),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: fullWidth
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  loading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: color),
                        )
                      : Icon(icon, color: color, size: 16),
                  const SizedBox(width: 8),
                  Text(label,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ],
              )
            : Column(
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

// -- Row: Afiliado (ExpansionTile compacto) ------------------------------------
class _AffiliateRow extends StatelessWidget {
  final AdminAffiliate a;
  final NumberFormat fmt;
  const _AffiliateRow({required this.a, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final statusColor = a.status == 'ativo' ? AppColors.success : AppColors.warning;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        margin: const EdgeInsets.only(bottom: 0),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          iconColor: AppColors.textHint,
          collapsedIconColor: AppColors.textHint,
          leading: Container(
            width: 32, height: 32,
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
                    fontSize: 14),
              ),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(a.nome,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(a.status,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          subtitle: Text(
            '${a.affiliateCode} · ${fmt.format(a.totalComissoes)} comissões',
            style: const TextStyle(fontSize: 10, color: AppColors.textHint),
          ),
          children: [
            const Divider(color: AppColors.cardBorder, height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.email_outlined, size: 12, color: AppColors.textHint),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(a.email,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _Mini(label: 'Código', value: a.affiliateCode),
                const SizedBox(width: 16),
                _Mini(label: 'Comissões', value: fmt.format(a.totalComissoes), color: AppColors.gold),
                const SizedBox(width: 16),
                _Mini(label: 'Saldo', value: fmt.format(a.saldoDisponivel), color: AppColors.success),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// -- Row: Saque ----------------------------------------------------------------
class _WithdrawalRow extends StatelessWidget {
  final AdminWithdrawal w;
  final NumberFormat fmt;
  const _WithdrawalRow({required this.w, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy HH:mm');
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: w.statusColor.withValues(alpha: 0.3)),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          iconColor: AppColors.textHint,
          collapsedIconColor: AppColors.textHint,
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: w.statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.pix_rounded, color: w.statusColor, size: 18),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(w.affiliateNome,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 6),
              Text(fmt.format(w.valor),
                  style: TextStyle(
                      color: w.statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: w.statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(w.statusLabel,
                    style: TextStyle(
                        color: w.statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          subtitle: Text(
            w.pixKey,
            style: const TextStyle(fontSize: 10, color: AppColors.textHint),
            overflow: TextOverflow.ellipsis,
          ),
          children: [
            const Divider(color: AppColors.cardBorder, height: 1),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _Mini(label: 'Status', value: w.statusLabel, color: w.statusColor),
                _Mini(label: 'Solicitado', value: df.format(w.solicitadoEm)),
                if (w.txId != null && w.txId!.isNotEmpty)
                  _Mini(label: 'Tx ID', value: w.txId!.length > 12 ? w.txId!.substring(0, 12) + '…' : w.txId!),
              ],
            ),
            if (w.motivo != null && w.motivo!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 11, color: AppColors.error),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(w.motivo!,
                        style: const TextStyle(color: AppColors.error, fontSize: 11)),
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

// -- Row: Assinatura -----------------------------------------------------------
class _SubscriptionRow extends StatelessWidget {
  final SubscriptionModel s;
  final NumberFormat fmt;
  const _SubscriptionRow({required this.s, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy');
    final isMensal = s.chargeType == ChargeType.pixRecorrente;
    final tipoColor = isMensal ? const Color(0xFF0D7A5A) : AppColors.info;
    final tipoLabel = isMensal ? 'Mensal' : 'Único';
    final tipoIcon  = isMensal ? Icons.autorenew_rounded : Icons.pix_rounded;

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
          // Ícone com badge de tipo
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: s.statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(tipoIcon, color: tipoColor, size: 20),
              ),
              Positioned(
                right: -4, top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: tipoColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(tipoLabel,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          fmt.format(s.valor),
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 13),
                        ),
                        Text(
                          '+ ${fmt.format(s.valorComissao)} comissão',  // R$ correto
                          style: const TextStyle(
                              color: AppColors.gold,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  '${s.affiliateNome ?? s.affiliateCode} - ${s.affiliateCode}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
                if (s.pixKey != null && s.pixKey!.isNotEmpty)
                  Text(
                    'PIX: ${s.pixKey}',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textHint),
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _Mini(
                        label: 'Status',
                        value: s.statusLabel,
                        color: s.statusColor),
                    const SizedBox(width: 10),
                    _Mini(
                        label: 'Comissão',
                        value: '${s.comissaoPercent}%',   // percentual correto
                        color: AppColors.gold),
                    const SizedBox(width: 10),
                    _Mini(
                        label: 'Início',
                        value: df.format(s.dataInicio)),
                    if (isMensal) ...[
                      const SizedBox(width: 10),
                      _Mini(
                          label: 'Próx. cobr.',
                          value: 'Dia ${s.diaCobranca}'),
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

// -- Row: Venda ----------------------------------------------------------------
class _VendaRow extends StatelessWidget {
  final AdminSale v;
  final NumberFormat fmt;
  const _VendaRow({required this.v, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy HH:mm');
    final isMensal = v.chargeType == 'pixRecorrente';
    final tipoColor = isMensal ? const Color(0xFF0D7A5A) : AppColors.info;
    final tipoLabel = isMensal ? 'Mensal' : 'Único';
    final tipoIcon  = isMensal ? Icons.autorenew_rounded : Icons.pix_rounded;
    final cliente   = v.clienteNome.isNotEmpty ? v.clienteNome
                    : v.clienteEmail.isNotEmpty ? v.clienteEmail
                    : 'Cliente não identificado';

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: v.statusColor.withValues(alpha: 0.3)),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          iconColor: AppColors.textHint,
          collapsedIconColor: AppColors.textHint,
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: tipoColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(tipoIcon, color: tipoColor, size: 18),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(v.productNome,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 6),
              Text(fmt.format(v.valor),
                  style: TextStyle(
                      color: v.statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: v.statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(v.statusLabel,
                    style: TextStyle(
                        color: v.statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          subtitle: Text(
            '$cliente · $tipoLabel',
            style: const TextStyle(fontSize: 10, color: AppColors.textHint),
            overflow: TextOverflow.ellipsis,
          ),
          children: [
            const Divider(color: AppColors.cardBorder, height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_rounded, size: 11, color: AppColors.textHint),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    v.clienteNome.isNotEmpty && v.clienteEmail.isNotEmpty
                        ? '${v.clienteNome} · ${v.clienteEmail}'
                        : cliente,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (v.affiliateCode.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(
                  children: [
                    const Icon(Icons.handshake_rounded, size: 11, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        v.affiliateNome.isNotEmpty
                            ? '${v.affiliateNome} (${v.affiliateCode})'
                            : v.affiliateCode,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _Mini(label: 'Data', value: df.format(v.createdAt)),
                if (v.comissao > 0)
                  _Mini(label: 'Comissão', value: fmt.format(v.comissao), color: AppColors.gold),
                if (v.paymentId.isNotEmpty)
                  _Mini(
                      label: 'Payment ID',
                      value: v.paymentId.length > 12
                          ? '${v.paymentId.substring(0, 12)}\u2026'
                          : v.paymentId,
                      color: AppColors.textHint),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// -- Micro texto label+valor ---------------------------------------------------
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

// -- Chip de filtro de tipo de cobrança ----------------------------------------
class _TipoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _TipoChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.14) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : AppColors.cardBorder,
              width: selected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: selected ? color : AppColors.textHint),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.normal,
                  color: selected ? color : AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
