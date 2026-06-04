import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product_model.dart';
import '../../services/subscription_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import 'my_subscriptions_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  final ProductModel product;
  final String affiliateCode;

  const SubscriptionScreen({
    super.key,
    required this.product,
    required this.affiliateCode,
  });

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _cpfCtrl = TextEditingController();
  final _celularCtrl = TextEditingController();
  final _pixKeyCtrl = TextEditingController();
  bool _autorizou = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _cpfCtrl.dispose();
    _celularCtrl.dispose();
    _pixKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmarAssinatura() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_autorizou) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Autorize o débito automático para continuar'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final svc = context.read<SubscriptionService>();
    final result = await svc.subscribe(
      product: widget.product,
      clienteNome: _nomeCtrl.text.trim(),
      clienteCpf: _cpfCtrl.text.trim(),
      clienteCelular: _celularCtrl.text.trim(),
      clientePixKey: _pixKeyCtrl.text.trim(),
      affiliateCode: widget.affiliateCode,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      _showSuccessDialog(result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Erro ao criar assinatura'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showSuccessDialog(SubscribeResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 60),
            ),
            const SizedBox(height: 16),
            const Text('Assinatura Ativada!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'O Pix Automático foi configurado. O débito de ${widget.product.valorFormatado} será realizado todo dia ${widget.product.diaCobranca ?? 5}.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            // Comissão que o afiliado vai receber
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: AppColors.greenGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.monetization_on_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Você ganha ${widget.product.comissaoFormatada}/mês',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PrimaryButton(
            label: 'Ver Minhas Assinaturas',
            icon: Icons.subscriptions_rounded,
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const MySubscriptionsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final proximaCobranca = _proximaCobranca(product.diaCobranca ?? 5);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Assinar Plano'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Resumo do plano ────────────────────────────────────────────
              _PlanSummaryCard(product: product, proximaCobranca: proximaCobranca),
              const SizedBox(height: 24),

              // ── Dados do cliente ───────────────────────────────────────────
              const _SectionHeader(
                icon: Icons.person_rounded,
                title: 'Dados do Assinante',
              ),
              const SizedBox(height: 12),
              _buildField(
                controller: _nomeCtrl,
                label: 'Nome completo',
                icon: Icons.person_outline_rounded,
                validator: (v) => v!.trim().split(' ').length < 2
                    ? 'Informe nome e sobrenome'
                    : null,
              ),
              const SizedBox(height: 12),
              _buildField(
                controller: _cpfCtrl,
                label: 'CPF',
                icon: Icons.badge_rounded,
                keyboardType: TextInputType.number,
                hint: '000.000.000-00',
                validator: (v) => v!.replaceAll(RegExp(r'\D'), '').length < 11
                    ? 'CPF inválido'
                    : null,
              ),
              const SizedBox(height: 12),
              _buildField(
                controller: _celularCtrl,
                label: 'Celular / WhatsApp',
                icon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
                hint: '(11) 99999-9999',
                validator: (v) =>
                    v!.replaceAll(RegExp(r'\D'), '').length < 10
                        ? 'Celular inválido'
                        : null,
              ),
              const SizedBox(height: 12),
              _buildField(
                controller: _pixKeyCtrl,
                label: 'Chave PIX',
                icon: Icons.pix_rounded,
                hint: 'CPF, e-mail, celular ou chave aleatória',
                validator: (v) => v!.isEmpty ? 'Informe a chave PIX' : null,
              ),
              const SizedBox(height: 24),

              // ── Caixa de autorização ───────────────────────────────────────
              _AuthorizationBox(
                product: product,
                autorizou: _autorizou,
                onChanged: (v) => setState(() => _autorizou = v ?? false),
                proximaCobranca: proximaCobranca,
              ),
              const SizedBox(height: 20),

              // ── Como funciona ──────────────────────────────────────────────
              _HowItWorksCard(product: product),
              const SizedBox(height: 24),

              // ── Botão confirmar ────────────────────────────────────────────
              PrimaryButton(
                label: product.isPixAutomatico
                    ? 'Autorizar Pix Automático'
                    : 'Confirmar Assinatura',
                icon: product.isPixAutomatico
                    ? Icons.autorenew_rounded
                    : Icons.check_rounded,
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _confirmarAssinatura,
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Autorização segura via PIX — sem necessidade de cartão',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint.withValues(alpha: 0.8)),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary),
      ),
      validator: validator,
    );
  }

  DateTime _proximaCobranca(int dia) {
    final now = DateTime.now();
    DateTime proxima = DateTime(now.year, now.month, dia);
    if (proxima.isBefore(now)) {
      proxima = DateTime(now.year, now.month + 1, dia);
    }
    return proxima;
  }
}

// ── Widget: Resumo do plano ───────────────────────────────────────────────────

class _PlanSummaryCard extends StatelessWidget {
  final ProductModel product;
  final DateTime proximaCobranca;

  const _PlanSummaryCard({
    required this.product,
    required this.proximaCobranca,
  });

  @override
  Widget build(BuildContext context) {
    final months = ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];
    final dataStr =
        '${proximaCobranca.day.toString().padLeft(2,'0')}/${months[proximaCobranca.month - 1]}/${proximaCobranca.year}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.darkGreenGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(product.chargeTypeIcon,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.nome,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800),
                    ),
                    Text(
                      product.chargeTypeLabel,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _InfoChip(
                  icon: Icons.attach_money_rounded,
                  label: product.valorFormatado,
                  sub: product.periodicidade != null
                      ? '/${product.periodicidade}'
                      : ''),
              const SizedBox(width: 12),
              _InfoChip(
                  icon: Icons.calendar_today_rounded,
                  label: 'Todo dia ${product.diaCobranca ?? 5}',
                  sub: 'débito automático'),
              const SizedBox(width: 12),
              _InfoChip(
                  icon: Icons.event_rounded,
                  label: '1ª cobrança',
                  sub: dataStr),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.star_rounded,
                    color: AppColors.gold, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Sua comissão: ${product.comissaoFormatada}/mês (${product.comissaoPercent}%)',
                  style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  const _InfoChip(
      {required this.icon, required this.label, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
            if (sub.isNotEmpty)
              Text(sub,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ── Widget: Caixa de autorização ──────────────────────────────────────────────

class _AuthorizationBox extends StatelessWidget {
  final ProductModel product;
  final bool autorizou;
  final ValueChanged<bool?> onChanged;
  final DateTime proximaCobranca;

  const _AuthorizationBox({
    required this.product,
    required this.autorizou,
    required this.onChanged,
    required this.proximaCobranca,
  });

  @override
  Widget build(BuildContext context) {
    final months = ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];
    final dataStr =
        '${proximaCobranca.day.toString().padLeft(2,'0')}/${months[proximaCobranca.month - 1]}/${proximaCobranca.year}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: autorizou
            ? AppColors.success.withValues(alpha: 0.06)
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: autorizou
              ? AppColors.success.withValues(alpha: 0.4)
              : AppColors.cardBorder,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Autorização de Débito',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Autorizo o débito mensal de ${product.valorFormatado} via Pix Automático, todo dia ${product.diaCobranca ?? 5} de cada mês, referente ao plano "${product.nome}".',
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.5),
                ),
                const SizedBox(height: 10),
                // Timeline das próximas cobranças
                _ChargeTimeline(
                    product: product, primeiradata: proximaCobranca),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: autorizou,
                onChanged: onChanged,
                activeColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 11),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.4),
                      children: [
                        const TextSpan(
                            text: 'Concordo e autorizo o '),
                        TextSpan(
                          text: 'Pix Automático',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text:
                              ' com início em $dataStr. Poderei cancelar a qualquer momento.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Timeline de cobranças ─────────────────────────────────────────────────────

class _ChargeTimeline extends StatelessWidget {
  final ProductModel product;
  final DateTime primeiradata;

  const _ChargeTimeline(
      {required this.product, required this.primeiradata});

  @override
  Widget build(BuildContext context) {
    final months = ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];

    DateTime next = primeiradata;
    final dates = <DateTime>[next];
    for (int i = 1; i < 3; i++) {
      next = DateTime(next.year, next.month + 1, product.diaCobranca ?? 5);
      dates.add(next);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Próximas cobranças:',
          style: TextStyle(
              fontSize: 11,
              color: AppColors.textHint,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Row(
          children: dates.map((d) {
            final label =
                '${d.day.toString().padLeft(2,'0')}/${months[d.month - 1]}';
            final isFirst = d == dates.first;
            return Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 6),
                      decoration: BoxDecoration(
                        color: isFirst
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isFirst
                              ? AppColors.primary.withValues(alpha: 0.3)
                              : AppColors.cardBorder,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.pix_rounded,
                            size: 14,
                            color: isFirst
                                ? AppColors.primary
                                : AppColors.textHint,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isFirst
                                    ? AppColors.primary
                                    : AppColors.textSecondary),
                          ),
                          Text(
                            product.valorFormatado,
                            style: TextStyle(
                                fontSize: 10,
                                color: isFirst
                                    ? AppColors.primary
                                    : AppColors.textHint),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (d != dates.last)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 3),
                      child: Icon(Icons.arrow_forward_rounded,
                          size: 12, color: AppColors.textHint),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Widget: Como funciona ─────────────────────────────────────────────────────

class _HowItWorksCard extends StatelessWidget {
  final ProductModel product;
  const _HowItWorksCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBDEFB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: Color(0xFF1976D2), size: 16),
              SizedBox(width: 8),
              Text('Como funciona o Pix Automático',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1976D2),
                      fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          ...[
            '1️⃣  Autorize uma única vez — sem cartão de crédito',
            '2️⃣  Todo dia ${product.diaCobranca ?? 5}, o valor é debitado automaticamente da sua conta PIX',
            '3️⃣  Se o saldo for insuficiente, o banco tenta novamente em até 3 dias',
            '4️⃣  Cancele quando quiser, sem multa ou fidelidade',
          ].map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  item,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1565C0),
                      height: 1.5),
                ),
              )),
        ],
      ),
    );
  }
}

// ── Widget auxiliar ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.textPrimary),
        ),
      ],
    );
  }
}
