// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../utils/web_utils.dart';

// Importações condicionais web vs stub
import 'extrato_export_web.dart'
    if (dart.library.io) 'extrato_export_stub.dart' as _platform;

// ─────────────────────────────────────────────────────────────────────────────
// ExtratoExportService — gera CSV e PDF do extrato e faz download/share
// ─────────────────────────────────────────────────────────────────────────────
class ExtratoExportService {
  static final _fmtDate = DateFormat('dd/MM/yyyy HH:mm');

  // ── Gera conteúdo CSV ──────────────────────────────────────────────────────
  static String buildCsv(List<Map<String, dynamic>> extrato) {
    final sb = StringBuffer();
    // Cabeçalho
    sb.writeln('Data;Tipo;Descrição;Valor;Status');
    for (final item in extrato) {
      final date = item['data'] as DateTime;
      final tipo = (item['tipo'] as String).toUpperCase();
      final desc = (item['descricao'] as String).replaceAll(';', ',');
      final valor = item['valor'] as double;
      final sinal = (item['positivo'] as bool) ? '+' : '-';
      final status = item['status'] as String;
      sb.writeln(
        '${_fmtDate.format(date)};$tipo;$desc;$sinal${valor.toStringAsFixed(2).replaceAll('.', ',')};$status',
      );
    }
    return sb.toString();
  }

  // ── Gera conteúdo HTML para PDF ────────────────────────────────────────────
  static String buildHtml({
    required List<Map<String, dynamic>> extrato,
    required double totalComissoes,
    required double totalSaques,
    required String nomeAfiliado,
  }) {
    final geradoEm = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final saldoLiquido = totalComissoes - totalSaques;

    final rows = extrato.map((item) {
      final date = item['data'] as DateTime;
      final tipo = (item['tipo'] as String);
      final desc = item['descricao'] as String;
      final valor = item['valor'] as double;
      final isPos = item['positivo'] as bool;
      final status = item['status'] as String;
      final color = isPos ? '#1B8A4A' : '#C0392B';
      final sinal = isPos ? '+' : '-';
      final tipoLabel = tipo == 'comissao' ? 'Comissão' : 'Saque';

      return '''
        <tr>
          <td>${_fmtDate.format(date)}</td>
          <td><span class="badge badge-${tipo}">${tipoLabel}</span></td>
          <td>$desc</td>
          <td style="color:${color};font-weight:700">${sinal}R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}</td>
          <td><span class="status">${status}</span></td>
        </tr>''';
    }).join('\n');

    return '''<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Extrato ShareWallet</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: 'Segoe UI', Arial, sans-serif; background: #f5f7f5; color: #1a1a1a; }
  .container { max-width: 900px; margin: 0 auto; padding: 32px 24px; }

  /* Header */
  .header { background: linear-gradient(135deg, #0A5C36 0%, #1B8A4A 100%);
    color: white; border-radius: 16px; padding: 28px 32px; margin-bottom: 24px;
    display: flex; justify-content: space-between; align-items: center; }
  .header-logo { display: flex; align-items: center; gap: 12px; }
  .logo-icon { width: 48px; height: 48px; background: rgba(255,255,255,0.2);
    border-radius: 12px; display: flex; align-items: center; justify-content: center;
    font-size: 24px; }
  .header-title { font-size: 22px; font-weight: 800; letter-spacing: 0.3px; }
  .header-sub { font-size: 13px; opacity: 0.8; margin-top: 2px; }
  .header-info { text-align: right; font-size: 12px; opacity: 0.85; line-height: 1.6; }

  /* Cards resumo */
  .summary { display: grid; grid-template-columns: repeat(3, 1fr); gap: 14px; margin-bottom: 24px; }
  .card { background: white; border-radius: 12px; padding: 18px 20px;
    border: 1px solid #E2EAE5; box-shadow: 0 1px 4px rgba(0,0,0,0.05); }
  .card-label { font-size: 11px; color: #6B7280; font-weight: 600;
    text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 6px; }
  .card-value { font-size: 20px; font-weight: 800; }
  .green { color: #1B8A4A; }
  .red { color: #C0392B; }
  .blue { color: #2563EB; }

  /* Tabela */
  .table-wrap { background: white; border-radius: 14px; border: 1px solid #E2EAE5;
    overflow: hidden; box-shadow: 0 1px 4px rgba(0,0,0,0.05); }
  .table-header { padding: 16px 20px; border-bottom: 1px solid #E2EAE5;
    display: flex; justify-content: space-between; align-items: center; }
  .table-title { font-size: 15px; font-weight: 700; }
  .table-count { font-size: 12px; color: #6B7280; }
  table { width: 100%; border-collapse: collapse; }
  thead th { background: #F9FAFB; padding: 10px 16px; text-align: left;
    font-size: 11px; font-weight: 700; color: #6B7280; text-transform: uppercase;
    letter-spacing: 0.5px; border-bottom: 1px solid #E5E7EB; }
  tbody td { padding: 12px 16px; font-size: 13px; border-bottom: 1px solid #F3F4F6; }
  tbody tr:last-child td { border-bottom: none; }
  tbody tr:hover { background: #F9FAFB; }

  /* Badges */
  .badge { display: inline-block; padding: 3px 10px; border-radius: 20px;
    font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.3px; }
  .badge-comissao { background: #D1FAE5; color: #065F46; }
  .badge-saque { background: #FEE2E2; color: #991B1B; }
  .status { display: inline-block; padding: 2px 8px; border-radius: 6px;
    font-size: 11px; font-weight: 600; background: #F3F4F6; color: #374151; }

  /* Rodapé */
  .footer { margin-top: 24px; text-align: center; font-size: 11px; color: #9CA3AF; line-height: 1.8; }

  @media print {
    body { background: white; }
    .container { padding: 16px; }
    .no-print { display: none !important; }
  }
</style>
</head>
<body>
<div class="container">

  <!-- Header -->
  <div class="header">
    <div class="header-logo">
      <div class="logo-icon">💳</div>
      <div>
        <div class="header-title">ShareWallet</div>
        <div class="header-sub">Extrato de Afiliado</div>
      </div>
    </div>
    <div class="header-info">
      <div><strong>${nomeAfiliado.isNotEmpty ? nomeAfiliado : 'Afiliado'}</strong></div>
      <div>Gerado em: $geradoEm</div>
      <div>${extrato.length} transações</div>
    </div>
  </div>

  <!-- Resumo -->
  <div class="summary">
    <div class="card">
      <div class="card-label">Total Comissões</div>
      <div class="card-value green">R\$ ${totalComissoes.toStringAsFixed(2).replaceAll('.', ',')}</div>
    </div>
    <div class="card">
      <div class="card-label">Total Saques</div>
      <div class="card-value red">R\$ ${totalSaques.toStringAsFixed(2).replaceAll('.', ',')}</div>
    </div>
    <div class="card">
      <div class="card-label">Saldo Líquido</div>
      <div class="card-value ${saldoLiquido >= 0 ? 'green' : 'red'}">R\$ ${saldoLiquido.toStringAsFixed(2).replaceAll('.', ',')}</div>
    </div>
  </div>

  <!-- Tabela de transações -->
  <div class="table-wrap">
    <div class="table-header">
      <div class="table-title">Histórico de Transações</div>
      <div class="table-count">${extrato.length} registros</div>
    </div>
    <table>
      <thead>
        <tr>
          <th>Data</th>
          <th>Tipo</th>
          <th>Descrição</th>
          <th>Valor</th>
          <th>Status</th>
        </tr>
      </thead>
      <tbody>
        $rows
      </tbody>
    </table>
  </div>

  <!-- Rodapé -->
  <div class="footer">
    <div>ShareWallet — Plataforma de Afiliados</div>
    <div>Documento gerado automaticamente em $geradoEm</div>
    <div>Este extrato é informativo e não tem validade fiscal.</div>
  </div>

</div>

<!-- Botão de imprimir/salvar como PDF (só na tela) -->
<div class="no-print" style="position:fixed;bottom:24px;right:24px;">
  <button onclick="window.print()" style="background:#1B8A4A;color:white;border:none;
    padding:14px 24px;border-radius:12px;font-size:14px;font-weight:700;
    cursor:pointer;box-shadow:0 4px 12px rgba(27,138,74,0.4);">
    🖨️ Imprimir / Salvar PDF
  </button>
</div>
</body>
</html>''';
  }

  // ── Download / Share (delega para implementação da plataforma) ───────────
  static Future<void> downloadCsv({
    required List<Map<String, dynamic>> extrato,
    required String nomeAfiliado,
  }) async {
    final csv = buildCsv(extrato);
    final fileName =
        'extrato_sharewallet_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';

    // APK WebView: kIsWeb=true mas window.open/blob falham — usa share nativo
    if (kIsWeb && !isNativeApp()) {
      _platform.downloadFileWeb(
        content: csv,
        fileName: fileName,
        mimeType: 'text/csv;charset=utf-8;',
      );
    } else {
      await _platform.shareFileNative(
        content: utf8.encode(csv),
        fileName: fileName,
        mimeType: 'text/csv',
        subject: 'Extrato ShareWallet',
      );
    }
  }

  static Future<void> openPdf({
    required List<Map<String, dynamic>> extrato,
    required double totalComissoes,
    required double totalSaques,
    required String nomeAfiliado,
  }) async {
    final html = buildHtml(
      extrato: extrato,
      totalComissoes: totalComissoes,
      totalSaques: totalSaques,
      nomeAfiliado: nomeAfiliado,
    );
    final fileName =
        'extrato_sharewallet_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.html';

    // APK WebView: kIsWeb=true mas window.open/_blank é bloqueado — usa share nativo
    if (kIsWeb && !isNativeApp()) {
      _platform.openHtmlBlob(html_: html, fileName: fileName);
    } else {
      await _platform.shareFileNative(
        content: utf8.encode(html),
        fileName: fileName,
        mimeType: 'text/html',
        subject: 'Extrato ShareWallet',
      );
    }
  }
}
