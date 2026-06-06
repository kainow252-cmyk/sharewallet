import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product_model.dart';
import '../../services/product_service.dart';
import '../../services/subscription_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';

/// Tela pública acessada pelo COMPRADOR via link rastreável.
/// Não exige autenticação — qualquer pessoa com o link pode comprar.
/// URL: /produto/:productId?ref=AFFILIATE_CODE
class BuyScreen extends StatefulWidget {
  final String productId;
  final String affiliateCode;

  const BuyScreen({
    super.key,
    required this.productId,
    required this.affiliateCode,
  });

  @override
  State<BuyScreen> createState() => _BuyScreenState();
}

class _BuyScreenState extends State<BuyScreen> {
  ProductModel? _product;
  bool _loadingProduct = true;
  String? _loadError;

  // Campos do comprador
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _cpfCtrl = TextEditingController();
  final _celularCtrl = TextEditingController();
  final _pixKeyCtrl = TextEditingController();
  bool _autorizou = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _cpfCtrl.dispose();
    _celularCtrl.dispose();
    _pixKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    setState(() {
      _loadingProduct = true;
      _loadError = null;
    });
    try {
      final ps = context.read<ProductService>();
      await ps.loadProducts();
      final found = ps.products
          .where((p) => p.id == widget.productId)
          .firstOrNull;
      if (!mounted) return;
      if (found == null) {
        setState(() {
          _loadError = 'Produto não encontrado.';
          _loadingProduct = false;
        });
      } else {
        setState(() {
          _product = found;
          _loadingProduct = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Erro ao carregar produto. Tente novamente.';
        _loadingProduct = false;
      });
    }
  }

  Future<void> _confirmar() async {
    if (!_formKey.currentState!.validate()) return;

    // PIX Recorrente exige autorização explícita
    if (_product!.isPixRecorrente && !_autorizou) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marque a caixa de autorização para continuar'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final svc = context.read<SubscriptionService>();
    final result = await svc.subscribe(
      product: _product!,
      clienteNome: _nomeCtrl.text.trim(),
      clienteCpf: _cpfCtrl.text.trim(),
      clienteCelular: _celularCtrl.text.trim(),
      clientePixKey: _pixKeyCtrl.text.trim(),
      affiliateCode: widget.affiliateCode,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.success) {
      _showSuccess(result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Erro ao processar. Tente novamente.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showSuccess(SubscribeResult result) {
    final product = _product!;
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
                  color: AppColors.success, size: 64),
            ),
            const SizedBox(height: 16),
            Text(
              product.isPixRecorrente
                  ? 'Pix Recorrente Ativado!'
                  : 'Pedido Recebido!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            Text(
              product.isPixRecorrente
                  ? 'Seu débito automático de ${product.valorFormatado} foi configurado para todo dia ${product.diaCobranca ?? 5}.'
                  : 'O QR Code PIX foi gerado. Realize o pagamento de ${product.valorFormatado} para ativar o plano.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F7FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBDEFB)),
              ),
              child: const Text(
                '✅ Você receberá uma confirmação no celular informado.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1565C0),
                    height: 1.5),
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Concluído',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('ShareWallet'),
        leading: const SizedBox.shrink(),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Image.asset(
              'assets/images/logo.png',
              height: 28,
              errorBuilder: (_, __, ___) => const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppColors.primary),
            ),
          ),
        ],
      ),
      body: _loadingProduct
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _loadError != null
              ? _buildError()
              : _buildForm(),
    );
  }

  // ── Tela de erro ─────────────────────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.link_off_rounded,
                size: 64, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadProduct,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text('Tentar novamente',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Formulário do comprador ───────────────────────────────────────────────────
  Widget _buildForm() {
    final product = _product!;
    final proximaCobranca = _proximaCobranca(product.diaCobranca ?? 5);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Card do produto ────────────────────────────────────────────────
            _ProductSummary(product: product, proximaCobranca: proximaCobranca),
            const SizedBox(height: 24),

            // ── Seção: Dados do comprador ─────────────────────────────────────
            _SectionHeader(
              icon: Icons.person_rounded,
              title: 'Seus dados',
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
              validator: (v) =>
                  v!.replaceAll(RegExp(r'\D'), '').length < 11
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
              label: 'Sua chave PIX',
              icon: Icons.pix_rounded,
              hint: 'CPF, e-mail, celular ou chave aleatória',
              validator: (v) =>
                  v!.isEmpty ? 'Informe sua chave PIX' : null,
            ),
            const SizedBox(height: 24),

            // ── Autorização (somente PIX Recorrente) ──────────────────────────
            if (product.isPixRecorrente) ...[
              _AuthorizationBox(
                product: product,
                autorizou: _autorizou,
                onChanged: (v) => setState(() => _autorizou = v ?? false),
                proximaCobranca: proximaCobranca,
              ),
              const SizedBox(height: 20),
            ],

            // ── Como funciona ──────────────────────────────────────────────────
            _HowItWorksCard(product: product),
            const SizedBox(height: 24),

            // ── Botão confirmar ────────────────────────────────────────────────
            PrimaryButton(
              label: product.isPixRecorrente
                  ? 'Autorizar Pix Recorrente'
                  : 'Gerar QR Code PIX',
              icon: product.isPixRecorrente
                  ? Icons.autorenew_rounded
                  : Icons.qr_code_rounded,
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : _confirmar,
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Pagamento 100% via PIX — seguro e instantâneo',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint.withValues(alpha: 0.8)),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
          ],
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

// ── Resumo do produto ─────────────────────────────────────────────────────────
class _ProductSummary extends StatelessWidget {
  final ProductModel product;
  final DateTime proximaCobranca;
  const _ProductSummary({required this.product, required this.proximaCobranca});

  @override
  Widget build(BuildContext context) {
    final months = [
      'Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'
    ];
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
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
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
          const SizedBox(height: 16),
          Row(
            children: [
              _Chip(
                icon: Icons.attach_money_rounded,
                label: product.valorFormatado,
                sub: product.periodicidade != null
                    ? '/${product.periodicidade}'
                    : '',
              ),
              const SizedBox(width: 10),
              if (product.isPixRecorrente) ...[
                _Chip(
                  icon: Icons.calendar_today_rounded,
                  label: 'Todo dia ${product.diaCobranca ?? 5}',
                  sub: 'débito automático',
                ),
                const SizedBox(width: 10),
                _Chip(
                  icon: Icons.event_rounded,
                  label: '1ª cobrança',
                  sub: dataStr,
                ),
              ] else
                _Chip(
                  icon: Icons.qr_code_rounded,
                  label: 'Pix Único',
                  sub: 'QR Code gerado',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  const _Chip({required this.icon, required this.label, required this.sub});

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
            Icon(icon, color: Colors.white70, size: 15),
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

// ── Autorização PIX Recorrente ────────────────────────────────────────────────
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
    final months = [
      'Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'
    ];
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
          const Row(
            children: [
              Icon(Icons.lock_outline_rounded,
                  color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Text(
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
            child: Text(
              'Autorizo o débito de ${product.valorFormatado} via Pix Recorrente, '
              'todo dia ${product.diaCobranca ?? 5} de cada mês, '
              'referente ao plano "${product.nome}".',
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  height: 1.5),
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
                        const TextSpan(text: 'Concordo e autorizo o '),
                        TextSpan(
                          text: 'Pix Recorrente',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text:
                              ' com início em $dataStr. Posso cancelar a qualquer momento.',
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

// ── Como funciona ─────────────────────────────────────────────────────────────
class _HowItWorksCard extends StatelessWidget {
  final ProductModel product;
  const _HowItWorksCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final steps = product.isPixRecorrente
        ? [
            '1️⃣  Autorize uma única vez — sem cartão de crédito',
            '2️⃣  Todo dia ${product.diaCobranca ?? 5}, o valor é debitado automaticamente via Pix',
            '3️⃣  Se o saldo for insuficiente, o banco tenta novamente em até 3 dias',
            '4️⃣  Cancele quando quiser, sem multa',
          ]
        : [
            '1️⃣  Preencha seus dados acima',
            '2️⃣  Um QR Code Pix será gerado no valor de ${product.valorFormatado}',
            '3️⃣  Escaneie ou copie o código no seu banco',
            '4️⃣  Confirmação imediata após o pagamento',
          ];

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
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: Color(0xFF1976D2), size: 16),
              const SizedBox(width: 8),
              Text(
                product.isPixRecorrente
                    ? 'Como funciona o Pix Recorrente'
                    : 'Como funciona o Pix Único',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1976D2),
                    fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...steps.map((item) => Padding(
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

// ── Auxiliar ──────────────────────────────────────────────────────────────────
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
