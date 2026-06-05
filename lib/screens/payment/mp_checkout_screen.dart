import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/product_model.dart';
import '../../services/mercadopago_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../dashboard/main_nav_screen.dart';

// ── Tela principal de checkout MP ─────────────────────────────────────────────

class MpCheckoutScreen extends StatefulWidget {
  final ProductModel product;
  final String affiliateCode;

  const MpCheckoutScreen({
    super.key,
    required this.product,
    required this.affiliateCode,
  });

  @override
  State<MpCheckoutScreen> createState() => _MpCheckoutScreenState();
}

class _MpCheckoutScreenState extends State<MpCheckoutScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Formulário dados cliente
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _cpfCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _isLoading = false;
  MpCheckoutResult? _checkoutResult;
  _CheckoutStep _step = _CheckoutStep.form;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Pré-preencher dados do usuário logado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthService>();
      final user = auth.currentUser;
      if (user != null) {
        _nomeCtrl.text = user.nome;
        _emailCtrl.text = user.email;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nomeCtrl.dispose();
    _cpfCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _iniciarCheckout() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _step = _CheckoutStep.loading;
    });

    final mpSvc = context.read<MercadoPagoService>();
    final auth = context.read<AuthService>();
    final user = auth.currentUser;

    final result = await mpSvc.criarPreferenciaAssinatura(
      produtoId: widget.product.id,
      produtoNome: widget.product.nome,
      produtoDescricao: widget.product.descricao,
      valor: widget.product.valor,
      affiliateId: user?.id ?? 'demo_user_1',
      affiliateCode: widget.affiliateCode,
      clienteNome: _nomeCtrl.text.trim(),
      clienteEmail: _emailCtrl.text.trim(),
      clienteCpf: _cpfCtrl.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _checkoutResult = result;
      _step = result.success ? _CheckoutStep.checkout : _CheckoutStep.error;
    });
  }

  Future<void> _abrirMercadoPago() async {
    if (_checkoutResult?.checkoutUrl == null) return;

    final mpSvc = context.read<MercadoPagoService>();
    final opened = await mpSvc.abrirCheckout(_checkoutResult!.checkoutUrl!);

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível abrir o navegador. Copie o link.'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  Future<void> _simularPagamento() async {
    setState(() => _isLoading = true);

    final mpSvc = context.read<MercadoPagoService>();
    final auth = context.read<AuthService>();
    final user = auth.currentUser;

    final ok = await mpSvc.simularPagamentoAprovado(
      userId: user?.id ?? 'demo_user_1',
      produtoId: widget.product.id,
      produtoNome: widget.product.nome,
      valor: widget.product.valor,
      affiliateId: user?.id ?? 'demo_user_1',
      affiliateCode: widget.affiliateCode,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (ok) _step = _CheckoutStep.success;
    });

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao simular pagamento. Tente novamente.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            // Logo MP pequena
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF009EE3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'MP',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text('Checkout ShareWallet'),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _buildStep(),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _CheckoutStep.form:
        return _FormStep(
          key: const ValueKey('form'),
          product: widget.product,
          formKey: _formKey,
          nomeCtrl: _nomeCtrl,
          cpfCtrl: _cpfCtrl,
          emailCtrl: _emailCtrl,
          isLoading: _isLoading,
          onSubmit: _iniciarCheckout,
        );
      case _CheckoutStep.loading:
        return const _LoadingStep(key: ValueKey('loading'));
      case _CheckoutStep.checkout:
        return _CheckoutLinkStep(
          key: const ValueKey('checkout'),
          product: widget.product,
          checkoutUrl: _checkoutResult?.checkoutUrl ?? '',
          preferenceId: _checkoutResult?.preferenceId ?? '',
          onAbrirMP: _abrirMercadoPago,
          onSimular: _simularPagamento,
          isLoading: _isLoading,
        );
      case _CheckoutStep.success:
        return _SuccessStep(
          key: const ValueKey('success'),
          product: widget.product,
          onContinue: () {
            Navigator.pop(context);
            MainNavController().goCarteira();
          },
        );
      case _CheckoutStep.error:
        return _ErrorStep(
          key: const ValueKey('error'),
          message: _checkoutResult?.errorMessage ?? 'Erro desconhecido',
          onRetry: () => setState(() => _step = _CheckoutStep.form),
        );
    }
  }
}

enum _CheckoutStep { form, loading, checkout, success, error }

// ── Step 1: Formulário ────────────────────────────────────────────────────────

class _FormStep extends StatelessWidget {
  final ProductModel product;
  final GlobalKey<FormState> formKey;
  final TextEditingController nomeCtrl;
  final TextEditingController cpfCtrl;
  final TextEditingController emailCtrl;
  final bool isLoading;
  final VoidCallback onSubmit;

  const _FormStep({
    super.key,
    required this.product,
    required this.formKey,
    required this.nomeCtrl,
    required this.cpfCtrl,
    required this.emailCtrl,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Card produto ───────────────────────────────────────────────
            _ProductCard(product: product),
            const SizedBox(height: 24),

            // ── Badge sandbox ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFE083)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.science_rounded,
                      color: Color(0xFFE65100), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Modo Sandbox — Pagamentos de teste. Use o usuário TESTUSER319132183442306970',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF7B3F00),
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const _SectionHeader(icon: Icons.person_rounded, title: 'Seus Dados'),
            const SizedBox(height: 12),

            _Field(
              controller: nomeCtrl,
              label: 'Nome completo',
              icon: Icons.person_outline_rounded,
              validator: (v) =>
                  v!.trim().split(' ').length < 2 ? 'Informe nome e sobrenome' : null,
            ),
            const SizedBox(height: 12),
            _Field(
              controller: emailCtrl,
              label: 'E-mail',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  v!.contains('@') ? null : 'E-mail inválido',
            ),
            const SizedBox(height: 12),
            _Field(
              controller: cpfCtrl,
              label: 'CPF (opcional)',
              icon: Icons.badge_rounded,
              keyboardType: TextInputType.number,
              hint: '000.000.000-00',
            ),
            const SizedBox(height: 28),

            // ── Resumo ────────────────────────────────────────────────────
            _ResumoCard(product: product),
            const SizedBox(height: 20),

            // ── Botão ─────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: isLoading ? null : onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF009EE3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 3,
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.payment_rounded, size: 20),
                          SizedBox(width: 10),
                          Text('Ir para o Pagamento',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                '🔒 Pagamento 100% seguro via Mercado Pago',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint.withValues(alpha: 0.9)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ── Step 2: Loading ───────────────────────────────────────────────────────────

class _LoadingStep extends StatelessWidget {
  const _LoadingStep({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF009EE3).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              color: Color(0xFF009EE3),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Preparando checkout...',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Conectando ao Mercado Pago',
            style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Step 3: Link Checkout ─────────────────────────────────────────────────────

class _CheckoutLinkStep extends StatelessWidget {
  final ProductModel product;
  final String checkoutUrl;
  final String preferenceId;
  final VoidCallback onAbrirMP;
  final VoidCallback onSimular;
  final bool isLoading;

  const _CheckoutLinkStep({
    super.key,
    required this.product,
    required this.checkoutUrl,
    required this.preferenceId,
    required this.onAbrirMP,
    required this.onSimular,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final comissao = MercadoPagoService.calcularComissao(product.valor);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF009EE3).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFF009EE3).withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF009EE3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('MP',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Checkout Gerado!',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: AppColors.textPrimary)),
                      Text('Preferência: ${preferenceId.length > 20 ? '...${preferenceId.substring(preferenceId.length - 16)}' : preferenceId}',
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textHint)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('SANDBOX',
                      style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                          fontSize: 10)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Resumo do produto ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.nome,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.textPrimary)),
                    Text('Mensalidade: ${product.valorFormatado}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'R\$ ${comissao.toStringAsFixed(2)}/mês',
                      style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w800,
                          fontSize: 14),
                    ),
                    const Text('sua comissão',
                        style: TextStyle(
                            fontSize: 10, color: AppColors.textHint)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Botão principal: Abrir MP ────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: onAbrirMP,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF009EE3),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.open_in_browser_rounded, size: 20),
                  SizedBox(width: 10),
                  Text('Abrir Checkout Mercado Pago',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── Copiar link ──────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: checkoutUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🔗 Link copiado! Cole no navegador.'),
                    backgroundColor: Color(0xFF009EE3),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copiar link de pagamento',
                  style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF009EE3)),
                foregroundColor: const Color(0xFF009EE3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Divider ──────────────────────────────────────────────────────
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('ou simule aqui mesmo',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textHint)),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 12),

          // ── Botão: Simular pagamento aprovado ────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: isLoading ? null : onSimular,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success.withValues(alpha: 0.12),
                foregroundColor: AppColors.success,
                elevation: 0,
                side: const BorderSide(color: AppColors.success, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.success),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 20),
                        SizedBox(width: 8),
                        Text('Simular Pagamento Aprovado',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Simula aprovação → credita comissão na sua carteira',
              style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textHint.withValues(alpha: 0.8)),
            ),
          ),
          const SizedBox(height: 20),

          // ── Dados de teste sandbox ───────────────────────────────────────
          _SandboxInfo(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Step 4: Sucesso ───────────────────────────────────────────────────────────

class _SuccessStep extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onContinue;

  const _SuccessStep({
    super.key,
    required this.product,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final comissao = MercadoPagoService.calcularComissao(product.valor);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // ── Animação sucesso ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.success.withValues(alpha: 0.1),
                  AppColors.primary.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 72,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Assinatura Ativada!',
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            '${product.nome} foi ativado com sucesso.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),

          // ── Comissão creditada ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1B5E20),
                  AppColors.primary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.account_balance_wallet_rounded,
                        color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Comissão Creditada',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'R\$ ${comissao.toStringAsFixed(2)}/mês',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enquanto a assinatura estiver ativa',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Detalhes recorrência ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _SuccessDetail(
                  icon: Icons.pix_rounded,
                  label: 'Método',
                  value: 'Pix Automático',
                  color: const Color(0xFF32BCAD),
                ),
                const Divider(height: 20),
                _SuccessDetail(
                  icon: Icons.calendar_today_rounded,
                  label: 'Próxima cobrança',
                  value: 'em 30 dias',
                  color: AppColors.primary,
                ),
                const Divider(height: 20),
                _SuccessDetail(
                  icon: Icons.percent_rounded,
                  label: 'Comissão',
                  value: '20% — R\$ ${comissao.toStringAsFixed(2)}/mês',
                  color: AppColors.gold,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_wallet_rounded, size: 20),
                  SizedBox(width: 10),
                  Text('Ver Minha Carteira',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Step 5: Erro ──────────────────────────────────────────────────────────────

class _ErrorStep extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorStep({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: AppColors.error, size: 56),
            ),
            const SizedBox(height: 20),
            const Text(
              'Erro no Checkout',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar Novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final comissao = MercadoPagoService.calcularComissao(product.valor);
    final catColors = {
      'seguros': const Color(0xFF1565C0),
      'capitalizacao': const Color(0xFF6A1B9A),
      'assistencia': const Color(0xFF00695C),
      'beneficios': const Color(0xFFE65100),
      'cursos': const Color(0xFF2E7D32),
    };
    final catColor =
        catColors[product.categoria.toLowerCase()] ?? AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: catColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_catIcon(product.categoria),
                color: catColor, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.nome,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  product.categoria,
                  style: TextStyle(
                      fontSize: 11,
                      color: catColor,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                product.valorFormatado,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
              ),
              Text(
                'sua comissão: R\$ ${comissao.toStringAsFixed(2)}',
                style: TextStyle(
                    fontSize: 10,
                    color: AppColors.success,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _catIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'seguros':
        return Icons.shield_rounded;
      case 'capitalizacao':
        return Icons.savings_rounded;
      case 'assistencia':
        return Icons.home_repair_service_rounded;
      case 'beneficios':
        return Icons.card_giftcard_rounded;
      case 'cursos':
        return Icons.school_rounded;
      default:
        return Icons.inventory_2_rounded;
    }
  }
}

class _ResumoCard extends StatelessWidget {
  final ProductModel product;
  const _ResumoCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final comissao = MercadoPagoService.calcularComissao(product.valor);
    final anuais = comissao * 12;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            const Color(0xFF009EE3).withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          _ResumoRow(
            label: 'Produto',
            value: product.nome,
          ),
          const Divider(height: 16),
          _ResumoRow(
            label: 'Mensalidade',
            value: product.valorFormatado,
            bold: true,
          ),
          const Divider(height: 16),
          _ResumoRow(
            label: 'Sua comissão/mês',
            value: 'R\$ ${comissao.toStringAsFixed(2)}',
            color: AppColors.success,
            bold: true,
          ),
          const Divider(height: 16),
          _ResumoRow(
            label: 'Potencial anual',
            value: 'R\$ ${anuais.toStringAsFixed(2)}',
            color: AppColors.gold,
          ),
        ],
      ),
    );
  }
}

class _ResumoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool bold;

  const _ResumoRow({
    required this.label,
    required this.value,
    this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _SandboxInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCE93D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: Color(0xFF7B1FA2), size: 16),
              SizedBox(width: 8),
              Text(
                'Dados de Teste Sandbox',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7B1FA2),
                    fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _InfoRow(label: 'Usuário:', value: 'TESTUSER319132183442306970'),
          _InfoRow(label: 'Senha:', value: 'O3gLaNsAT6'),
          _InfoRow(label: 'Ambiente:', value: 'Mercado Pago Sandbox'),
          _InfoRow(
              label: 'Cartão teste:',
              value: '5031 4332 1540 6351 • CVV 123'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7B1FA2))),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF4A148C))),
          ),
        ],
      ),
    );
  }
}

class _SuccessDetail extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SuccessDetail({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Text(label,
            style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color)),
      ],
    );
  }
}

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
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.textPrimary)),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? hint;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.hint,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
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
}
