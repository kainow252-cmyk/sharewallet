import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../models/product_model.dart';
import '../../services/product_service.dart';
import '../../services/mercadopago_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';

/// Tela pública acessada pelo COMPRADOR via link rastreável do afiliado.
/// Não exige login. URL: /#/produto/:id?ref=AFFILIATE_CODE
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
  // ── Produto ──────────────────────────────────────────────────────────────
  ProductModel? _product;
  bool _loadingProduct = true;
  String? _loadError;

  // ── Formulário ────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();

  // Dados pessoais
  final _nomeCtrl     = TextEditingController();
  final _cpfCtrl      = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _celularCtrl  = TextEditingController();
  final _nascCtrl     = TextEditingController();

  // Endereço
  final _cepCtrl      = TextEditingController();
  final _ruaCtrl      = TextEditingController();
  final _numeroCtrl   = TextEditingController();
  final _compCtrl     = TextEditingController();
  final _bairroCtrl   = TextEditingController();
  final _cidadeCtrl   = TextEditingController();
  final _estadoCtrl   = TextEditingController();

  // PIX Recorrente
  bool _autorizou = false;

  // ── Estado de submissão ───────────────────────────────────────────────────
  bool _isSubmitting = false;

  // ── Resultado: QR Code gerado ─────────────────────────────────────────────
  MpCheckoutResult? _pixResult;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();    _cpfCtrl.dispose();
    _emailCtrl.dispose();   _celularCtrl.dispose();
    _nascCtrl.dispose();    _cepCtrl.dispose();
    _ruaCtrl.dispose();     _numeroCtrl.dispose();
    _compCtrl.dispose();    _bairroCtrl.dispose();
    _cidadeCtrl.dispose();  _estadoCtrl.dispose();
    super.dispose();
  }

  // ── Carrega produto ───────────────────────────────────────────────────────
  Future<void> _loadProduct() async {
    setState(() { _loadingProduct = true; _loadError = null; });
    try {
      final ps = context.read<ProductService>();
      await ps.loadProducts();
      final found = ps.products.where((p) => p.id == widget.productId).firstOrNull;
      if (!mounted) return;
      if (found == null) {
        setState(() { _loadError = 'Produto não encontrado.'; _loadingProduct = false; });
      } else {
        setState(() { _product = found; _loadingProduct = false; });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() { _loadError = 'Erro ao carregar produto. Tente novamente.'; _loadingProduct = false; });
    }
  }

  // ── Busca CEP via ViaCEP ──────────────────────────────────────────────────
  Future<void> _buscarCep() async {
    final cep = _cepCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (cep.length != 8) return;
    try {
      final resp = await http
          .get(Uri.parse('https://viacep.com.br/ws/$cep/json/'))
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (data['erro'] == null) {
          if (!mounted) return;
          setState(() {
            _ruaCtrl.text    = data['logradouro'] ?? '';
            _bairroCtrl.text = data['bairro']     ?? '';
            _cidadeCtrl.text = data['localidade'] ?? '';
            _estadoCtrl.text = data['uf']         ?? '';
          });
        }
      }
    } catch (_) {}
  }

  // ── Gera PIX via Mercado Pago ─────────────────────────────────────────────
  Future<void> _gerarPix() async {
    if (!_formKey.currentState!.validate()) return;

    if (_product!.isPixRecorrente && !_autorizou) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marque a caixa de autorização para continuar'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() { _isSubmitting = true; _pixResult = null; });

    final mp = context.read<MercadoPagoService>();

    final result = await mp.criarPix(
      produtoId:     _product!.id,
      produtoNome:   _product!.nome,
      valor:         _product!.valor,
      affiliateId:   widget.affiliateCode,
      affiliateCode: widget.affiliateCode,
      clienteNome:   _nomeCtrl.text.trim(),
      clienteCpf:    _cpfCtrl.text.trim(),
      clienteEmail:  _emailCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() { _isSubmitting = false; _pixResult = result; });

    if (result.success) {
      // Rola para o QR Code
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Erro ao gerar PIX. Tente novamente.'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  final _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Icon(Icons.account_balance_wallet_rounded,
                color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            const Text('ShareWallet',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
      body: _loadingProduct
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _loadError != null
              ? _buildError()
              : _buildBody(),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.link_off_rounded, size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text(_loadError!, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadProduct,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            label: const Text('Tentar novamente',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ),
  );

  Widget _buildBody() {
    final product = _product!;
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Card do produto ──────────────────────────────────────────────
            _ProductCard(product: product),
            const SizedBox(height: 24),

            // ── Dados Pessoais ───────────────────────────────────────────────
            _sectionTitle(Icons.person_rounded, 'Dados Pessoais'),
            const SizedBox(height: 12),
            _field(_nomeCtrl, 'Nome completo *', Icons.person_outline_rounded,
                validator: (v) => v!.trim().split(' ').length < 2
                    ? 'Informe nome e sobrenome' : null),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _field(_cpfCtrl, 'CPF *', Icons.badge_rounded,
                  hint: '000.000.000-00',
                  keyboard: TextInputType.number,
                  validator: (v) =>
                      v!.replaceAll(RegExp(r'\D'), '').length < 11
                          ? 'CPF inválido' : null)),
              const SizedBox(width: 10),
              Expanded(child: _field(_nascCtrl, 'Nascimento *', Icons.cake_rounded,
                  hint: 'DD/MM/AAAA',
                  keyboard: TextInputType.datetime,
                  validator: (v) => v!.trim().isEmpty ? 'Obrigatório' : null)),
            ]),
            const SizedBox(height: 10),
            _field(_emailCtrl, 'E-mail *', Icons.email_rounded,
                hint: 'seu@email.com',
                keyboard: TextInputType.emailAddress,
                validator: (v) => !v!.contains('@') ? 'E-mail inválido' : null),
            const SizedBox(height: 10),
            _field(_celularCtrl, 'Celular / WhatsApp *', Icons.phone_rounded,
                hint: '(11) 99999-9999',
                keyboard: TextInputType.phone,
                validator: (v) =>
                    v!.replaceAll(RegExp(r'\D'), '').length < 10
                        ? 'Celular inválido' : null),
            const SizedBox(height: 24),

            // ── Endereço ─────────────────────────────────────────────────────
            _sectionTitle(Icons.location_on_rounded, 'Endereço'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                flex: 2,
                child: _field(_cepCtrl, 'CEP *', Icons.pin_drop_rounded,
                    hint: '00000-000',
                    keyboard: TextInputType.number,
                    validator: (v) =>
                        v!.replaceAll(RegExp(r'\D'), '').length < 8
                            ? 'CEP inválido' : null,
                    onChanged: (v) {
                      if (v.replaceAll(RegExp(r'\D'), '').length == 8) {
                        _buscarCep();
                      }
                    }),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: _field(_ruaCtrl, 'Rua / Logradouro *', Icons.streetview_rounded,
                    validator: (v) => v!.trim().isEmpty ? 'Obrigatório' : null),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                flex: 1,
                child: _field(_numeroCtrl, 'Número *', Icons.tag_rounded,
                    keyboard: TextInputType.number,
                    validator: (v) => v!.trim().isEmpty ? 'Obrigatório' : null),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _field(_compCtrl, 'Complemento', Icons.apartment_rounded),
              ),
            ]),
            const SizedBox(height: 10),
            _field(_bairroCtrl, 'Bairro *', Icons.map_rounded,
                validator: (v) => v!.trim().isEmpty ? 'Obrigatório' : null),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                flex: 3,
                child: _field(_cidadeCtrl, 'Cidade *', Icons.location_city_rounded,
                    validator: (v) => v!.trim().isEmpty ? 'Obrigatório' : null),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: _field(_estadoCtrl, 'UF *', Icons.flag_rounded,
                    hint: 'SP',
                    validator: (v) => v!.trim().length < 2 ? 'Inválido' : null),
              ),
            ]),
            const SizedBox(height: 24),

            // ── Autorização PIX Recorrente ────────────────────────────────────
            if (product.isPixRecorrente) ...[
              _AuthBox(
                product: product,
                autorizou: _autorizou,
                onChanged: (v) => setState(() => _autorizou = v ?? false),
              ),
              const SizedBox(height: 20),
            ],

            // ── Como funciona ─────────────────────────────────────────────────
            _HowItWorks(product: product),
            const SizedBox(height: 24),

            // ── Botão gerar PIX ───────────────────────────────────────────────
            if (_pixResult == null || !_pixResult!.success)
              PrimaryButton(
                label: product.isPixRecorrente
                    ? 'Autorizar e Gerar PIX Recorrente'
                    : 'Gerar QR Code PIX — ${product.valorFormatado}',
                icon: product.isPixRecorrente
                    ? Icons.autorenew_rounded
                    : Icons.qr_code_rounded,
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _gerarPix,
              ),

            // ── QR Code PIX ───────────────────────────────────────────────────
            if (_pixResult != null && _pixResult!.success) ...[
              _PixQrCard(result: _pixResult!, product: product),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => setState(() { _pixResult = null; }),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Corrigir dados'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],

            const SizedBox(height: 12),
            Center(
              child: Text(
                '🔒 Pagamento 100% via PIX — processado pelo Mercado Pago',
                style: TextStyle(fontSize: 11,
                    color: AppColors.textHint.withValues(alpha: 0.8)),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Helpers de UI ─────────────────────────────────────────────────────────

  Widget _sectionTitle(IconData icon, String title) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 18),
      ),
      const SizedBox(width: 10),
      Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary)),
    ],
  );

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    String? hint,
    TextInputType? keyboard,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) =>
      TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        ),
        validator: validator,
      );
}

// ── Card do produto ───────────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final ProductModel product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
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
                child: Icon(product.chargeTypeIcon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.nome,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    Text(product.chargeTypeLabel,
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(product.valorFormatado,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                  if (product.periodicidade != null)
                    Text('/${product.periodicidade}',
                        style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ],
          ),
          if (product.descricao.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(product.descricao,
                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Caixa de autorização PIX Recorrente ──────────────────────────────────────
class _AuthBox extends StatelessWidget {
  final ProductModel product;
  final bool autorizou;
  final ValueChanged<bool?> onChanged;
  const _AuthBox({required this.product, required this.autorizou, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dia = product.diaCobranca ?? 5;
    DateTime proxima = DateTime(now.year, now.month, dia);
    if (proxima.isBefore(now)) proxima = DateTime(now.year, now.month + 1, dia);
    final months = ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];
    final dataStr =
        '${proxima.day.toString().padLeft(2,'0')}/${months[proxima.month - 1]}/${proxima.year}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: autorizou
            ? AppColors.success.withValues(alpha: 0.06)
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: autorizou
              ? AppColors.success.withValues(alpha: 0.4) : AppColors.cardBorder,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 18),
            SizedBox(width: 8),
            Text('Autorização de Débito Automático',
                style: TextStyle(fontWeight: FontWeight.w700,
                    fontSize: 14, color: AppColors.textPrimary)),
          ]),
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
              'todo dia $dia de cada mês, referente ao plano "${product.nome}".',
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: autorizou, onChanged: onChanged,
                activeColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 11),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: AppColors.textSecondary,
                          fontSize: 13, height: 1.4),
                      children: [
                        const TextSpan(text: 'Concordo e autorizo o '),
                        TextSpan(text: 'Pix Recorrente',
                            style: TextStyle(color: AppColors.primary,
                                fontWeight: FontWeight.w700)),
                        TextSpan(text: ' com início em $dataStr. '
                            'Posso cancelar a qualquer momento.'),
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
class _HowItWorks extends StatelessWidget {
  final ProductModel product;
  const _HowItWorks({required this.product});

  @override
  Widget build(BuildContext context) {
    final steps = product.isPixRecorrente ? [
      '1️⃣  Preencha seus dados cadastrais acima',
      '2️⃣  Autorize o débito automático mensal',
      '3️⃣  Um QR Code PIX será gerado para a 1ª cobrança',
      '4️⃣  Após o pagamento, as próximas cobranças são automáticas todo dia ${product.diaCobranca ?? 5}',
      '5️⃣  Cancele quando quiser, sem multa',
    ] : [
      '1️⃣  Preencha seus dados cadastrais acima',
      '2️⃣  Clique em "Gerar QR Code PIX"',
      '3️⃣  Escaneie o QR Code ou copie o código no seu banco',
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
          Row(children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFF1976D2), size: 16),
            const SizedBox(width: 8),
            Text(
              product.isPixRecorrente
                  ? 'Como funciona o Pix Recorrente'
                  : 'Como funciona o Pix Único',
              style: const TextStyle(fontWeight: FontWeight.w700,
                  color: Color(0xFF1976D2), fontSize: 13),
            ),
          ]),
          const SizedBox(height: 10),
          ...steps.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text(s,
                style: const TextStyle(fontSize: 12,
                    color: Color(0xFF1565C0), height: 1.5)),
          )),
        ],
      ),
    );
  }
}

// ── QR Code PIX gerado pelo Mercado Pago ─────────────────────────────────────
class _PixQrCard extends StatefulWidget {
  final MpCheckoutResult result;
  final ProductModel product;
  const _PixQrCard({required this.result, required this.product});

  @override
  State<_PixQrCard> createState() => _PixQrCardState();
}

class _PixQrCardState extends State<_PixQrCard> {
  bool _copiou = false;

  void _copiar(BuildContext context) {
    if (widget.result.pixCode == null) return;
    Clipboard.setData(ClipboardData(text: widget.result.pixCode!));
    setState(() => _copiou = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Código PIX copiado!'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 3),
      ),
    );
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _copiou = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final p = widget.product;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: 0.1),
            blurRadius: 16, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header sucesso
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.isPixRecorrente
                            ? 'PIX Recorrente Gerado!'
                            : 'QR Code PIX Gerado!',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16,
                            color: AppColors.success),
                      ),
                      Text(
                        'Valor: ${p.valorFormatado}${p.isPixRecorrente ? '/mês' : ''}',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF009EE3).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.pix_rounded, color: Color(0xFF009EE3), size: 14),
                      SizedBox(width: 4),
                      Text('Mercado Pago',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                              color: Color(0xFF009EE3))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // QR Code imagem
          if (r.pixQrBase64 != null && r.pixQrBase64!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Image.memory(
                base64Decode(r.pixQrBase64!),
                width: 200, height: 200,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Escaneie com o app do seu banco',
                style: TextStyle(fontSize: 12, color: AppColors.textHint)),
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('ou', style: TextStyle(color: AppColors.textHint)),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Código Copia e Cola
          if (r.pixCode != null && r.pixCode!.isNotEmpty) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('PIX Copia e Cola',
                  style: TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 13, color: AppColors.textPrimary)),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pix_rounded, color: Color(0xFF009EE3), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(r.pixCode!,
                        style: const TextStyle(fontSize: 10,
                            color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => _copiar(context),
                    icon: Icon(
                      _copiou ? Icons.check_rounded : Icons.copy_rounded,
                      color: _copiou ? AppColors.success : AppColors.primary,
                      size: 20,
                    ),
                    tooltip: 'Copiar código',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _copiar(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _copiou ? AppColors.success : const Color(0xFF009EE3),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(_copiou ? Icons.check_rounded : Icons.copy_all_rounded,
                    color: Colors.white),
                label: Text(
                  _copiou ? 'Código Copiado!' : 'Copiar Código PIX',
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_rounded, color: AppColors.warning, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Este PIX expira em 30 minutos. '
                    'Realize o pagamento pelo app do seu banco.',
                    style: TextStyle(fontSize: 12,
                        color: AppColors.warning, height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          if (r.preferenceId != null) ...[
            const SizedBox(height: 8),
            Text('ID do pagamento: ${r.preferenceId}',
                style: const TextStyle(fontSize: 10,
                    color: AppColors.textHint)),
          ],
        ],
      ),
    );
  }
}
