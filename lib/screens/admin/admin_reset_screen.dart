import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';

/// Tela de reset/limpeza de dados — apaga vendas, assinaturas ou saques do D1.
/// Cada ação exige confirmação em dois passos: primeiro toque abre diálogo de
/// aviso; o usuário precisa digitar "CONFIRMAR" para prosseguir.
class AdminResetScreen extends StatelessWidget {
  const AdminResetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          // -- Aviso principal ------------------------------------------------
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF3A0000),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: AppColors.error, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Zona de Perigo',
                          style: TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                      SizedBox(height: 3),
                      Text(
                        'As ações abaixo apagam dados permanentemente do banco de dados. '
                        'Produtos e afiliados cadastrados NÃO são afetados.',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // -- Cards de cada tipo de reset ------------------------------------
          _ResetCard(
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFFD32F2F),
            title: 'Zerar Vendas',
            subtitle: 'Remove todos os registros de vendas (tabela sales).',
            details: [
              'Histórico de vendas apagado',
              'Saldos e comissões dos afiliados NÃO são afetados',
              'Produtos continuam intactos',
            ],
            target: 'sales',
            confirmLabel: 'ZERAR VENDAS',
          ),

          const SizedBox(height: 12),

          _ResetCard(
            icon: Icons.repeat_rounded,
            color: const Color(0xFFB71C1C),
            title: 'Zerar Assinaturas',
            subtitle: 'Remove todas as assinaturas (tabela subscriptions).',
            details: [
              'Todas as assinaturas apagadas (ativas, pendentes, canceladas)',
              'Campo total_assinaturas dos afiliados é zerado',
              'Comissões e saldos NÃO são afetados',
            ],
            target: 'subscriptions',
            confirmLabel: 'ZERAR ASSINATURAS',
          ),

          const SizedBox(height: 12),

          _ResetCard(
            icon: Icons.pix_rounded,
            color: const Color(0xFF880E4F),
            title: 'Zerar Saques',
            subtitle: 'Remove todos os saques solicitados (tabela withdrawals).',
            details: [
              'Todos os saques apagados (aprovados, pendentes, recusados)',
              'Campo total_sacado dos afiliados é zerado',
              'Saldos disponíveis NÃO são afetados',
            ],
            target: 'withdrawals',
            confirmLabel: 'ZERAR SAQUES',
          ),

          const SizedBox(height: 20),

          // -- Divider + Configurações ---------------------------------------
          Row(
            children: [
              Expanded(
                child: Divider(
                    color: const Color(0xFF6C3CE1).withValues(alpha: 0.3), thickness: 1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('CONFIGURAÇÕES',
                    style: TextStyle(
                        color: const Color(0xFF6C3CE1).withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2)),
              ),
              Expanded(
                child: Divider(
                    color: const Color(0xFF6C3CE1).withValues(alpha: 0.3), thickness: 1),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // -- Card reset token Woovi ----------------------------------------
          const _WooviResetCard(),

          const SizedBox(height: 20),

          // -- Divider + Reset Total -----------------------------------------
          Row(
            children: [
              Expanded(
                child: Divider(
                    color: AppColors.error.withValues(alpha: 0.3), thickness: 1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('RESET TOTAL',
                    style: TextStyle(
                        color: AppColors.error.withValues(alpha: 0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2)),
              ),
              Expanded(
                child: Divider(
                    color: AppColors.error.withValues(alpha: 0.3), thickness: 1),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _ResetCard(
            icon: Icons.delete_forever_rounded,
            color: const Color(0xFF4A0000),
            title: 'Zerar TUDO',
            subtitle:
                'Apaga vendas + assinaturas + saques + wallets e zera todos os '
                'totais dos afiliados. Mantém apenas produtos e cadastros.',
            details: [
              '⚠️ Vendas, assinaturas e saques: todos apagados',
              '⚠️ Wallets: todas zeradas',
              '⚠️ Afiliados: saldo, comissões, saques e indicados zerados',
              '✅ Produtos: intocados',
              '✅ Cadastros de afiliados: intocados',
              '✅ Token Woovi: intocado (use o card acima para resetar)',
              '✅ Config de menus e login: intocadas',
            ],
            target: 'all',
            confirmLabel: 'ZERAR TUDO',
            isMega: true,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ResetCard extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final List<String> details;
  final String target;
  final String confirmLabel;
  final bool isMega;

  const _ResetCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.details,
    required this.target,
    required this.confirmLabel,
    this.isMega = false,
  });

  @override
  State<_ResetCard> createState() => _ResetCardState();
}

class _ResetCardState extends State<_ResetCard> {
  bool _loading = false;
  bool _expanded = false;

  Future<void> _onTap() async {
    final confirmed = await _showConfirmDialog();
    if (!confirmed || !mounted) return;

    setState(() => _loading = true);
    try {
      final svc = context.read<AdminService>();
      final res = await svc.resetData(widget.target);
      if (!mounted) return;

      if (res != null && res['success'] == true) {
        final results = res['results'] as Map? ?? {};
        final lines = <String>[];
        if (results['sales'] != null) {
          lines.add('Vendas: ${(results['sales'] as Map)['deleted'] ?? 0} registros apagados');
        }
        if (results['subscriptions'] != null) {
          lines.add('Assinaturas: ${(results['subscriptions'] as Map)['deleted'] ?? 0} registros apagados');
        }
        if (results['withdrawals'] != null) {
          lines.add('Saques: ${(results['withdrawals'] as Map)['deleted'] ?? 0} registros apagados');
        }
        if (results['wallets'] != null) lines.add('Wallets: zeradas');
        if (results['affiliates_totals'] != null) lines.add('Totais afiliados: zerados');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✅ ${widget.title} concluído!\n${lines.join(' • ')}'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ));
        }
      } else {
        if (mounted) {
          final errMsg = res?['error'] ?? 'Erro desconhecido';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('❌ Erro: $errMsg'),
            backgroundColor: AppColors.error,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Erro inesperado: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _showConfirmDialog() async {
    final controller = TextEditingController();
    bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDlg) {
          final typed = controller.text.trim().toUpperCase();
          final canConfirm = typed == 'CONFIRMAR';
          return AlertDialog(
            backgroundColor: const Color(0xFF1A0505),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                  color: AppColors.error.withValues(alpha: 0.4), width: 1.5),
            ),
            title: Row(
              children: [
                Icon(Icons.warning_rounded, color: AppColors.error, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w800,
                        fontSize: 16),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Esta ação é IRREVERSÍVEL. Os dados serão apagados '
                  'permanentemente do banco de dados.',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.details
                        .map((d) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text('• $d',
                                  style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11,
                                      height: 1.3)),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Digite  CONFIRMAR  para continuar:',
                  style: TextStyle(
                      color: AppColors.error.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => setDlg(() {}),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2),
                  decoration: InputDecoration(
                    hintText: 'CONFIRMAR',
                    hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.2),
                        letterSpacing: 2),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.error),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancelar',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5))),
              ),
              FilledButton(
                onPressed:
                    canConfirm ? () => Navigator.pop(ctx, true) : null,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      canConfirm ? AppColors.error : Colors.grey.shade800,
                ),
                child: Text(widget.confirmLabel,
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          );
        });
      },
    );
    controller.dispose();
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: widget.isMega
            ? const Color(0xFF1C0505)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isMega
              ? AppColors.error.withValues(alpha: 0.6)
              : AppColors.error.withValues(alpha: 0.25),
          width: widget.isMega ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // -- Header ---------------------------------------------------------
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title,
                            style: TextStyle(
                                color: widget.isMega
                                    ? AppColors.error
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(widget.subtitle,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                height: 1.3)),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.textHint,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // -- Detalhes expandíveis -------------------------------------------
          if (_expanded) ...[
            Divider(
                height: 1,
                color: AppColors.error.withValues(alpha: 0.2),
                indent: 14,
                endIndent: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...widget.details.map((d) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              d.startsWith('⚠️')
                                  ? Icons.warning_amber_rounded
                                  : d.startsWith('✅')
                                      ? Icons.check_circle_rounded
                                      : Icons.remove_rounded,
                              size: 14,
                              color: d.startsWith('⚠️')
                                  ? AppColors.warning
                                  : d.startsWith('✅')
                                      ? AppColors.success
                                      : AppColors.textHint,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                d.replaceAll('⚠️ ', '').replaceAll('✅ ', ''),
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                    height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 12),
                  // -- Botão de ação ------------------------------------------
                  SizedBox(
                    width: double.infinity,
                    child: _loading
                        ? Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: widget.color),
                                  ),
                                  const SizedBox(width: 10),
                                  Text('Apagando dados...',
                                      style: TextStyle(
                                          color: widget.color,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          )
                        : FilledButton.icon(
                            onPressed: _onTap,
                            style: FilledButton.styleFrom(
                              backgroundColor: widget.color,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: Icon(widget.icon, size: 16),
                            label: Text(widget.confirmLabel,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    letterSpacing: 0.5)),
                          ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card específico para resetar o token Woovi (AppID)
// ─────────────────────────────────────────────────────────────────────────────
class _WooviResetCard extends StatefulWidget {
  const _WooviResetCard();

  @override
  State<_WooviResetCard> createState() => _WooviResetCardState();
}

class _WooviResetCardState extends State<_WooviResetCard> {
  static const _wooviPurple = Color(0xFF6C3CE1);
  bool _loading   = false;
  bool _expanded  = false;
  String? _status; // null = inicial, 'ok', 'erro'

  Future<void> _resetToken() async {
    final confirmed = await _showConfirm();
    if (!confirmed || !mounted) return;

    setState(() { _loading = true; _status = null; });
    try {
      final res = await http.post(
        Uri.parse('https://api.sharewallet.com.br/api/admin/woovi-config'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'appId':       '',
          'verified':    false,
          'accountName': '',
          'pixKey':      '',
          'pixKeyType':  '',
          'webhookUrl':  '',
        }),
      ).timeout(const Duration(seconds: 10));

      final ok = res.statusCode >= 200 && res.statusCode < 300;
      setState(() => _status = ok ? 'ok' : 'erro');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? '✅ Token Woovi removido com sucesso! Configure um novo em Pagamentos.'
              : '❌ Erro ao resetar token Woovi (status ${res.statusCode})'),
          backgroundColor: ok ? AppColors.success : AppColors.error,
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      setState(() => _status = 'erro');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Erro: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _showConfirm() async {
    final ctrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        final canConfirm = ctrl.text.trim().toUpperCase() == 'CONFIRMAR';
        return AlertDialog(
          backgroundColor: const Color(0xFF0D0520),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: _wooviPurple.withValues(alpha: 0.5), width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.key_off_rounded, color: _wooviPurple, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text('Resetar Token Woovi',
                    style: TextStyle(
                        color: _wooviPurple,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'O AppID (token) da Woovi será removido do banco de dados.\n\n'
                'Pagamentos PIX via Woovi ficarão indisponíveis até você '
                'configurar um novo token em Admin → Pagamentos.',
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Digite  CONFIRMAR  para continuar:',
                style: TextStyle(
                    color: _wooviPurple.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setDlg(() {}),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2),
                decoration: InputDecoration(
                  hintText: 'CONFIRMAR',
                  hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.2), letterSpacing: 2),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: _wooviPurple.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _wooviPurple),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar',
                  style:
                      TextStyle(color: Colors.white.withValues(alpha: 0.5))),
            ),
            FilledButton(
              onPressed: canConfirm ? () => Navigator.pop(ctx, true) : null,
              style: FilledButton.styleFrom(
                backgroundColor:
                    canConfirm ? _wooviPurple : Colors.grey.shade800,
              ),
              child: const Text('RESETAR TOKEN',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      }),
    );
    ctrl.dispose();
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    const purple = _wooviPurple;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0520),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: purple.withValues(alpha: 0.35), width: 1),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: purple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.key_off_rounded,
                        color: purple, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Resetar Token Woovi (AppID)',
                            style: TextStyle(
                                color: purple,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                        SizedBox(height: 2),
                        Text(
                          'Remove o AppID da Woovi do banco. PIX fica indisponível até novo cadastro.',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  // Badge de status
                  if (_status == 'ok')
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('RESETADO',
                          style: TextStyle(
                              color: AppColors.success,
                              fontSize: 9,
                              fontWeight: FontWeight.w800)),
                    ),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.textHint,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Detalhes expandíveis
          if (_expanded) ...[
            Divider(
                height: 1,
                color: purple.withValues(alpha: 0.2),
                indent: 14,
                endIndent: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailRow(Icons.check_circle_rounded, AppColors.success,
                      'Dados de vendas/assinaturas: intocados'),
                  _DetailRow(Icons.check_circle_rounded, AppColors.success,
                      'Cadastros de afiliados: intocados'),
                  _DetailRow(Icons.warning_amber_rounded, AppColors.warning,
                      'Pagamentos PIX: indisponíveis até novo token'),
                  _DetailRow(Icons.info_outline_rounded, purple,
                      'Após resetar, vá em Admin → Pagamentos para configurar novo AppID'),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: _loading
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: purple),
                                  ),
                                  SizedBox(width: 10),
                                  Text('Removendo token...',
                                      style: TextStyle(
                                          color: purple,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          )
                        : FilledButton.icon(
                            onPressed: _resetToken,
                            style: FilledButton.styleFrom(
                              backgroundColor: purple,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.key_off_rounded, size: 16),
                            label: const Text('RESETAR TOKEN WOOVI',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    letterSpacing: 0.5)),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _DetailRow(this.icon, this.color, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    height: 1.3)),
          ),
        ],
      ),
    );
  }
}
