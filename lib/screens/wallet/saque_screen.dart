import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/withdraw_model.dart';
import '../../services/auth_service.dart';
import '../../services/wallet_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';

class SaqueScreen extends StatefulWidget {
  const SaqueScreen({super.key});

  @override
  State<SaqueScreen> createState() => _SaqueScreenState();
}

class _SaqueScreenState extends State<SaqueScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _valorController = TextEditingController();
  final _pixKeyController = TextEditingController();
  String _pixKeyType = 'EMAIL';
  bool _isLoading = false;
  late TabController _tabController;

  final _currencyFmt =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

  final List<Map<String, dynamic>> _pixTypes = [
    {'value': 'CPF', 'label': 'CPF', 'icon': Icons.badge_rounded},
    {'value': 'EMAIL', 'label': 'E-mail', 'icon': Icons.email_outlined},
    {'value': 'PHONE', 'label': 'Telefone', 'icon': Icons.phone_rounded},
    {
      'value': 'ALEATORIA',
      'label': 'Chave Aleatória',
      'icon': Icons.vpn_key_rounded
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Pré-preenche chave PIX com e-mail do usuário logado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthService>();
      final email = auth.currentUser?.email ?? '';
      if (email.isNotEmpty) {
        _pixKeyController.text = email;
        setState(() => _pixKeyType = 'EMAIL');
      }
      // Garante histórico carregado
      final uid = auth.currentUser?.id;
      if (uid != null) {
        context.read<WalletService>().loadData(userId: uid);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _valorController.dispose();
    _pixKeyController.dispose();
    super.dispose();
  }

  // ── Atalho: preencher valor máximo (saldo disponível) ──────────────────────
  void _setMax(double saldo) {
    _valorController.text =
        saldo.toStringAsFixed(2).replaceAll('.', ',');
  }

  // ── Solicitar Saque ────────────────────────────────────────────────────────
  Future<void> _solicitarSaque() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthService>();
    final wallet = context.read<WalletService>();
    final valor =
        double.tryParse(_valorController.text.replaceAll(',', '.')) ?? 0;
    final saldo = auth.currentUser?.saldo ?? 0;

    if (valor < 10) {
      _showSnack('Valor mínimo para saque é R\$ 10,00', AppColors.warning);
      return;
    }

    if (valor > saldo) {
      _showSnack('Saldo insuficiente', AppColors.error);
      return;
    }

    setState(() => _isLoading = true);

    final result = await wallet.solicitarSaque(
      valor: valor,
      pixKey: _pixKeyController.text.trim(),
      pixKeyType: _pixKeyType,
      saldoAtual: saldo,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      auth.updateSaldo(saldo - valor);
      _valorController.clear();
      _showSuccessDialog(valor);
    } else {
      _showSnack(result.message ?? 'Erro ao solicitar saque', AppColors.error);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  void _showSuccessDialog(double valor) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pix_rounded,
                  color: AppColors.success, size: 56),
            ),
            const SizedBox(height: 16),
            const Text('Saque Solicitado!',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              _currencyFmt.format(valor),
              style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Seu PIX será processado em até 1 hora útil.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.schedule_rounded,
                      color: AppColors.textSecondary, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Processamento: até 1 hora útil',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PrimaryButton(
            label: 'Ver Histórico',
            onPressed: () {
              Navigator.pop(ctx);
              _tabController.animateTo(1);
            },
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final wallet = context.watch<WalletService>();
    final saldo = auth.currentUser?.saldo ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Saques PIX'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.white54,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.pix_rounded, size: 18), text: 'Novo Saque'),
            Tab(icon: Icon(Icons.history_rounded, size: 18), text: 'Histórico'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            // ── Tab 1: Formulário ──────────────────────────────────────────
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Card de saldo ──────────────────────────────────────
                    _SaldoCard(
                      saldo: saldo,
                      totalSacado: wallet.totalSacado,
                      onSetMax: () => _setMax(saldo),
                    ),
                    const SizedBox(height: 24),

                    // ── Valor ──────────────────────────────────────────────
                    const _SectionLabel('Valor do Saque'),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _valorController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary),
                      decoration: const InputDecoration(
                        prefixText: 'R\$ ',
                        prefixStyle: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary),
                        hintText: '0,00',
                        hintStyle: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w300,
                            color: AppColors.textHint),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Informe o valor';
                        final val =
                            double.tryParse(v.replaceAll(',', '.')) ?? 0;
                        if (val < 10) return 'Mínimo R\$ 10,00';
                        if (val > saldo) return 'Saldo insuficiente';
                        return null;
                      },
                    ),

                    // ── Atalhos de valor ───────────────────────────────────
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        ...[50.0, 100.0, 200.0, 500.0].map((v) {
                          final enabled = v <= saldo;
                          return _ValueChip(
                            label: _currencyFmt.format(v),
                            enabled: enabled,
                            onTap: enabled
                                ? () => _valorController.text =
                                    v.toStringAsFixed(2).replaceAll('.', ',')
                                : null,
                          );
                        }),
                        if (saldo >= 10)
                          _ValueChip(
                            label: 'Tudo',
                            enabled: true,
                            isHighlight: true,
                            onTap: () => _setMax(saldo),
                          ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Tipo de chave PIX ──────────────────────────────────
                    const _SectionLabel('Tipo de Chave PIX'),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 3.5,
                      children: _pixTypes.map((t) {
                        final isSelected = _pixKeyType == t['value'];
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _pixKeyType = t['value'] as String;
                              // Pré-preenche por tipo
                              if (t['value'] == 'EMAIL') {
                                final email =
                                    context.read<AuthService>().currentUser?.email ?? '';
                                _pixKeyController.text = email;
                              } else if (t['value'] == 'CPF') {
                                final cpf = context
                                        .read<AuthService>()
                                        .currentUser
                                        ?.cpf ??
                                    '';
                                _pixKeyController.text = cpf;
                              } else if (t['value'] == 'PHONE') {
                                final tel = context
                                        .read<AuthService>()
                                        .currentUser
                                        ?.telefone ??
                                    '';
                                _pixKeyController.text = tel;
                              } else {
                                _pixKeyController.clear();
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.08)
                                  : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.cardBorder,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(t['icon'] as IconData,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textHint,
                                    size: 18),
                                const SizedBox(width: 8),
                                Text(t['label'] as String,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.textSecondary,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // ── Campo de chave PIX ─────────────────────────────────
                    TextFormField(
                      controller: _pixKeyController,
                      decoration: InputDecoration(
                        labelText: 'Chave PIX ($_pixKeyType)',
                        prefixIcon: const Icon(Icons.pix_rounded,
                            color: AppColors.primary),
                        hintText: _pixKeyType == 'CPF'
                            ? '000.000.000-00'
                            : _pixKeyType == 'EMAIL'
                                ? 'seu@email.com'
                                : _pixKeyType == 'PHONE'
                                    ? '(11) 99999-9999'
                                    : 'Chave aleatória UUID',
                        suffixIcon: _pixKeyController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded,
                                    size: 18),
                                onPressed: () {
                                  setState(() => _pixKeyController.clear());
                                },
                              )
                            : null,
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (v) =>
                          v!.isEmpty ? 'Informe sua chave PIX' : null,
                    ),

                    const SizedBox(height: 24),

                    // ── Aviso ──────────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.info.withValues(alpha: 0.3)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  color: AppColors.info, size: 18),
                              SizedBox(width: 8),
                              Text('Informações do Saque',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.info,
                                      fontSize: 14)),
                            ],
                          ),
                          SizedBox(height: 10),
                          _InfoRow(text: 'Transferência PIX instantânea'),
                          _InfoRow(text: 'PIX creditado em até 1 hora útil'),
                          _InfoRow(text: 'Valor mínimo: R\$ 10,00'),
                          _InfoRow(text: 'Sem taxas para o afiliado'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    PrimaryButton(
                      label: 'Solicitar Saque via PIX',
                      onPressed: _solicitarSaque,
                      isLoading: _isLoading,
                      icon: Icons.pix_rounded,
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ── Tab 2: Histórico de saques ─────────────────────────────────
            _HistoricoSaques(
              withdraws: wallet.withdraws,
              isLoading: wallet.isLoading,
              currencyFmt: _currencyFmt,
              dateFmt: _dateFmt,
              totalSacado: wallet.totalSacado,
              onRefresh: () async {
                final auth = context.read<AuthService>();
                await context.read<WalletService>().loadData(
                      userId: auth.currentUser?.id,
                      forceRefresh: true,
                    );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card de saldo ─────────────────────────────────────────────────────────────
class _SaldoCard extends StatelessWidget {
  final double saldo;
  final double totalSacado;
  final VoidCallback onSetMax;

  const _SaldoCard({
    required this.saldo,
    required this.totalSacado,
    required this.onSetMax,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF083D29), Color(0xFF0D5C3D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Linha superior
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Saldo Disponível',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        fmt.format(saldo),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onSetMax,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: const Text(
                    'Sacar Tudo',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          // Linha inferior
          Row(
            children: [
              _MiniStat(
                icon: Icons.pix_rounded,
                label: 'PIX Direto',
                value: 'Instantâneo',
                iconColor: AppColors.goldLight,
              ),
              const SizedBox(width: 16),
              _MiniStat(
                icon: Icons.arrow_upward_rounded,
                label: 'Total Sacado',
                value: fmt.format(totalSacado),
                iconColor: Colors.white70,
              ),
              const SizedBox(width: 16),
              _MiniStat(
                icon: Icons.lock_rounded,
                label: 'Mínimo',
                value: 'R\$ 10,00',
                iconColor: Colors.white70,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 14),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 9)),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chip de valor rápido ──────────────────────────────────────────────────────
class _ValueChip extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool isHighlight;
  final VoidCallback? onTap;

  const _ValueChip({
    required this.label,
    required this.enabled,
    this.isHighlight = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: !enabled
              ? AppColors.surfaceVariant
              : isHighlight
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: !enabled
                ? AppColors.cardBorder
                : isHighlight
                    ? AppColors.primary
                    : AppColors.cardBorder,
            width: isHighlight ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: !enabled
                ? AppColors.textHint
                : isHighlight
                    ? AppColors.primary
                    : AppColors.primary,
          ),
        ),
      ),
    );
  }
}

// ── Label de seção ────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: AppColors.textPrimary),
    );
  }
}

// ── Histórico de Saques ───────────────────────────────────────────────────────
class _HistoricoSaques extends StatelessWidget {
  final List<WithdrawModel> withdraws;
  final bool isLoading;
  final NumberFormat currencyFmt;
  final DateFormat dateFmt;
  final double totalSacado;
  final Future<void> Function() onRefresh;

  const _HistoricoSaques({
    required this.withdraws,
    required this.isLoading,
    required this.currencyFmt,
    required this.dateFmt,
    required this.totalSacado,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: CustomScrollView(
        slivers: [
          // ── Banner resumo ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _HistoricoKpi(
                      label: 'Total Solicitações',
                      value: withdraws.length.toString(),
                      icon: Icons.list_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HistoricoKpi(
                      label: 'Pendentes',
                      value: withdraws
                          .where((w) => w.status == 'pendente')
                          .length
                          .toString(),
                      icon: Icons.hourglass_empty_rounded,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HistoricoKpi(
                      label: 'Total Sacado',
                      value: currencyFmt.format(totalSacado),
                      icon: Icons.pix_rounded,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Lista ou empty state ─────────────────────────────────────────
          if (withdraws.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.pix_rounded,
                          color: AppColors.textHint, size: 48),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Nenhum saque solicitado ainda',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Seus saques aparecerão aqui após\n a primeira solicitação.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.textHint, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _WithdrawCard(
                      w: withdraws[i],
                      currencyFmt: currencyFmt,
                      dateFmt: dateFmt,
                    ),
                  ),
                  childCount: withdraws.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── KPI do histórico ──────────────────────────────────────────────────────────
class _HistoricoKpi extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _HistoricoKpi({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                    fontSize: 13,
                    color: AppColors.textPrimary)),
          ),
          Text(label,
              style: const TextStyle(
                  fontSize: 9, color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Card individual do histórico ──────────────────────────────────────────────
class _WithdrawCard extends StatelessWidget {
  final WithdrawModel w;
  final NumberFormat currencyFmt;
  final DateFormat dateFmt;

  const _WithdrawCard({
    required this.w,
    required this.currencyFmt,
    required this.dateFmt,
  });

  // Normaliza status (suporta D1 em PT e API em UPPER)
  String get _normalizedStatus {
    final s = w.status.toLowerCase();
    if (s == 'approved' || s == 'aprovado') return 'aprovado';
    if (s == 'rejected' || s == 'recusado') return 'recusado';
    if (s == 'processing' || s == 'processando') return 'processando';
    return 'pendente';
  }

  Color get _statusColor {
    switch (_normalizedStatus) {
      case 'aprovado':
        return AppColors.success;
      case 'recusado':
        return AppColors.error;
      case 'processando':
        return AppColors.info;
      default:
        return AppColors.warning;
    }
  }

  String get _statusLabel {
    switch (_normalizedStatus) {
      case 'aprovado':
        return 'Aprovado';
      case 'recusado':
        return 'Recusado';
      case 'processando':
        return 'Processando';
      default:
        return 'Pendente';
    }
  }

  IconData get _statusIcon {
    switch (_normalizedStatus) {
      case 'aprovado':
        return Icons.check_circle_rounded;
      case 'recusado':
        return Icons.cancel_rounded;
      case 'processando':
        return Icons.sync_rounded;
      default:
        return Icons.hourglass_empty_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: _statusColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(
        children: [
          // ── Ícone status ─────────────────────────────────────────────────
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_statusIcon, color: _statusColor, size: 22),
          ),
          const SizedBox(width: 12),

          // ── Detalhes ─────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        currencyFmt.format(w.valor),
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: _statusColor),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _statusLabel,
                        style: TextStyle(
                            color: _statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.pix_rounded,
                        color: AppColors.textHint, size: 12),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        w.pixKey,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded,
                        color: AppColors.textHint, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      dateFmt.format(w.createdAt),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textHint),
                    ),
                    if (w.processedAt != null) ...[
                      const SizedBox(width: 12),
                      const Icon(Icons.check_rounded,
                          color: AppColors.success, size: 12),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Processado: ${dateFmt.format(w.processedAt!)}',
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textHint),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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

// ── Linha de info ─────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final String text;
  const _InfoRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_rounded, color: AppColors.success, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
