import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/cf_api_service.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Tela Admin — Configurações de Limites de Saque
// ─────────────────────────────────────────────────────────────────────────────
class AdminWithdrawalConfigScreen extends StatefulWidget {
  const AdminWithdrawalConfigScreen({super.key});

  @override
  State<AdminWithdrawalConfigScreen> createState() =>
      _AdminWithdrawalConfigScreenState();
}

class _AdminWithdrawalConfigScreenState
    extends State<AdminWithdrawalConfigScreen> {
  bool _loading = true;
  bool _saving = false;

  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();

  // Valores atuais salvos (para comparar e mostrar badge "salvo")
  double _savedMin = 0;
  double _savedMax = 0;

  static final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final cfg = await CfApiService.getWithdrawalConfig();
      final min = (cfg['min_saque'] as num?)?.toDouble() ?? 0;
      final max = (cfg['max_saque'] as num?)?.toDouble() ?? 0;
      _savedMin = min;
      _savedMax = max;
      _minCtrl.text = min > 0 ? min.toStringAsFixed(2).replaceAll('.', ',') : '';
      _maxCtrl.text = max > 0 ? max.toStringAsFixed(2).replaceAll('.', ',') : '';
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  double _parseReais(String v) {
    if (v.trim().isEmpty) return 0;
    return double.tryParse(v.trim().replaceAll('.', '').replaceAll(',', '.')) ?? 0;
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final minVal = _parseReais(_minCtrl.text);
    final maxVal = _parseReais(_maxCtrl.text);

    if (maxVal > 0 && minVal > maxVal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O mínimo não pode ser maior que o máximo.'),
          backgroundColor: AppColors.error,
        ),
      );
      setState(() => _saving = false);
      return;
    }

    final ok = await CfApiService.saveWithdrawalConfig(
      minSaque: minVal,
      maxSaque: maxVal,
    );

    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) {
        _savedMin = minVal;
        _savedMax = maxVal;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Limites de saque salvos com sucesso!'
            : 'Erro ao salvar. Tente novamente.'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
  }

  Future<void> _limpar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover limites?'),
        content: const Text(
          'Isso vai zerar o mínimo e o máximo — afiliados poderão sacar qualquer valor (sujeito ao saldo disponível).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Remover', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    final success = await CfApiService.saveWithdrawalConfig(minSaque: 0, maxSaque: 0);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (success) {
        _savedMin = 0;
        _savedMax = 0;
        _minCtrl.clear();
        _maxCtrl.clear();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Limites removidos!' : 'Erro ao remover limites.'),
        backgroundColor: success ? AppColors.primary : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final temLimites = _savedMin > 0 || _savedMax > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Banner explicativo ────────────────────────────────────────
              _InfoBanner(
                icon: Icons.account_balance_wallet_rounded,
                title: 'Limites Globais de Saque',
                subtitle:
                    'Define os valores mínimo e máximo que qualquer afiliado pode sacar por solicitação. '
                    'Zero (0) significa sem limite para aquele parâmetro.',
              ),

              const SizedBox(height: 20),

              // ── Status atual ─────────────────────────────────────────────
              _StatusCard(
                minSaque: _savedMin,
                maxSaque: _savedMax,
                fmt: _fmt,
              ),

              const SizedBox(height: 20),

              // ── Formulário ───────────────────────────────────────────────
              _SectionCard(
                title: 'VALOR MÍNIMO DE SAQUE',
                icon: Icons.arrow_downward_rounded,
                iconColor: AppColors.info,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Afiliados não poderão solicitar saques abaixo deste valor.\n'
                      'Deixe em branco ou coloque 0 para sem mínimo.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _minCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.,]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Valor mínimo (R\$)',
                        hintText: 'Ex: 50,00',
                        prefixIcon: Icon(Icons.arrow_downward_rounded,
                            color: AppColors.info, size: 20),
                        prefixText: 'R\$ ',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final n = _parseReais(v);
                        if (n < 0) return 'Valor deve ser positivo';
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              _SectionCard(
                title: 'VALOR MÁXIMO DE SAQUE',
                icon: Icons.arrow_upward_rounded,
                iconColor: AppColors.warning,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Afiliados não poderão solicitar saques acima deste valor por solicitação.\n'
                      'Deixe em branco ou coloque 0 para sem máximo.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _maxCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.,]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Valor máximo (R\$)',
                        hintText: 'Ex: 5000,00',
                        prefixIcon: Icon(Icons.arrow_upward_rounded,
                            color: AppColors.warning, size: 20),
                        prefixText: 'R\$ ',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final n = _parseReais(v);
                        if (n < 0) return 'Valor deve ser positivo';
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Botão Salvar ─────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _salvar,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded, size: 20),
                  label: Text(
                    _saving ? 'Salvando...' : 'Salvar Limites',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              if (temLimites) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _limpar,
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    label: const Text('Remover Limites',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // ── Exemplos práticos ─────────────────────────────────────────
              _ExamplesCard(),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares
// ─────────────────────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status atual dos limites ──────────────────────────────────────────────────
class _StatusCard extends StatelessWidget {
  final double minSaque;
  final double maxSaque;
  final NumberFormat fmt;

  const _StatusCard({
    required this.minSaque,
    required this.maxSaque,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final temMin = minSaque > 0;
    final temMax = maxSaque > 0;
    final ativo = temMin || temMax;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ativo
              ? AppColors.success.withValues(alpha: 0.35)
              : AppColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ativo
                    ? Icons.check_circle_outline_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: ativo ? AppColors.success : AppColors.textHint,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Status atual',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHint,
                    letterSpacing: 0.5),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ativo
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ativo ? 'LIMITES ATIVOS' : 'SEM LIMITES',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: ativo ? AppColors.success : AppColors.textHint,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _LimitTile(
                  label: 'Mínimo',
                  value: temMin ? fmt.format(minSaque) : 'Sem limite',
                  icon: Icons.arrow_downward_rounded,
                  color: AppColors.info,
                  active: temMin,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LimitTile(
                  label: 'Máximo',
                  value: temMax ? fmt.format(maxSaque) : 'Sem limite',
                  icon: Icons.arrow_upward_rounded,
                  color: AppColors.warning,
                  active: temMax,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LimitTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool active;

  const _LimitTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active
            ? color.withValues(alpha: 0.08)
            : AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active
              ? color.withValues(alpha: 0.25)
              : AppColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: active ? color : AppColors.textHint)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: active ? AppColors.textPrimary : AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Container de seção ────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textHint,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ── Exemplos práticos ─────────────────────────────────────────────────────────
class _ExamplesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  color: AppColors.gold, size: 18),
              SizedBox(width: 8),
              Text(
                'EXEMPLOS DE USO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textHint,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ExampleRow(
            icon: Icons.arrow_downward_rounded,
            color: AppColors.info,
            text: 'Mínimo R\$ 50,00 → Afiliados com menos que isso precisam acumular antes de sacar.',
          ),
          const SizedBox(height: 8),
          _ExampleRow(
            icon: Icons.arrow_upward_rounded,
            color: AppColors.warning,
            text: 'Máximo R\$ 5.000,00 → Saques maiores precisam de aprovação manual fora da plataforma.',
          ),
          const SizedBox(height: 8),
          _ExampleRow(
            icon: Icons.block_rounded,
            color: AppColors.textHint,
            text: 'Mínimo 0 + Máximo 0 → Sem restrições globais. Apenas limites por afiliado (tela Afiliados) se houver.',
          ),
        ],
      ),
    );
  }
}

class _ExampleRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _ExampleRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 12),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12, height: 1.5),
          ),
        ),
      ],
    );
  }
}
