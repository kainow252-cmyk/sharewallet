import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/web_utils.dart';
import '../../models/product_model.dart';
import '../../services/product_service.dart';
import '../../services/cf_api_service.dart';
import '../../services/woovi_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show FileUploadInputElement, FileReader, window;

// --- Chaves para auto-fill ----------------------------------------------------
const _kNome     = 'buyer_nome';
const _kCpf      = 'buyer_cpf';
const _kEmail    = 'buyer_email';
const _kCelular  = 'buyer_celular';
const _kNasc     = 'buyer_nasc';
const _kCep      = 'buyer_cep';
const _kRua      = 'buyer_rua';
const _kNumero   = 'buyer_numero';
const _kComp     = 'buyer_comp';
const _kBairro   = 'buyer_bairro';
const _kCidade   = 'buyer_cidade';
const _kEstado   = 'buyer_estado';

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
  // -- Produto --------------------------------------------------------------
  ProductModel? _product;
  bool _loadingProduct = true;
  String? _loadError;

  // -- Formulário ------------------------------------------------------------
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
  // -- Estado de submissão ---------------------------------------------------
  bool _isSubmitting = false;

  // -- Resultado Pix Único: QR Code gerado (Woovi) ----------------------------
  ChargeResult? _pixResult;

  // -- Resultado Pix Automático: assinatura gerada (Woovi) ------------------
  SubscriptionResult? _preapprovalResult;

  // -- Polling de status do pagamento --------------------------------------
  Timer?  _pollingTimer;
  bool    _paymentApproved = false;
  static const _workerBase = 'https://api.sharewallet.com.br';

  // -- Controle de tela de parabéns -----------------------------------------
  bool _showSuccessScreen = false;

  // -- Controle de banner de produto (landing) --------------------------------
  // true = mostra landing page com botões; false = mostra formulário de compra
  bool _showBanner = true;

  // -- Etapa de upload de documentos (antes do pagamento) -------------------
  bool _showDocUpload = false;
  Map<String, String> _uploadedDocs = {}; // tipo -> base64
  String? _saleDocId; // ID do registro salvo na API

  @override
  void initState() {
    super.initState();
    _loadProduct();
    _carregarDadosSalvos();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _nomeCtrl.dispose();    _cpfCtrl.dispose();
    _emailCtrl.dispose();   _celularCtrl.dispose();
    _nascCtrl.dispose();    _cepCtrl.dispose();
    _ruaCtrl.dispose();     _numeroCtrl.dispose();
    _compCtrl.dispose();    _bairroCtrl.dispose();
    _cidadeCtrl.dispose();  _estadoCtrl.dispose();
    super.dispose();
  }

  // -- Avança da landing page para a próxima etapa --------------------------
  void _onLandingContinue() {
    final product = _product;
    if (product == null) return;
    if (product.requiresDocs) {
      setState(() { _showDocUpload = true; _showBanner = false; });
    } else {
      setState(() { _showBanner = false; });
    }
  }

  Future<void> _carregarDadosSalvos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nome = prefs.getString(_kNome) ?? '';
      if (nome.isEmpty) return; // Nenhum dado salvo, primeiro acesso
      if (!mounted) return;
      setState(() {
        _nomeCtrl.text    = nome;
        _cpfCtrl.text     = prefs.getString(_kCpf)     ?? '';
        _emailCtrl.text   = prefs.getString(_kEmail)   ?? '';
        _celularCtrl.text = prefs.getString(_kCelular) ?? '';
        _nascCtrl.text    = prefs.getString(_kNasc)    ?? '';
        _cepCtrl.text     = prefs.getString(_kCep)     ?? '';
        _ruaCtrl.text     = prefs.getString(_kRua)     ?? '';
        _numeroCtrl.text  = prefs.getString(_kNumero)  ?? '';
        _compCtrl.text    = prefs.getString(_kComp)    ?? '';
        _bairroCtrl.text  = prefs.getString(_kBairro)  ?? '';
        _cidadeCtrl.text  = prefs.getString(_kCidade)  ?? '';
        _estadoCtrl.text  = prefs.getString(_kEstado)  ?? '';
      });
    } catch (_) {}
  }

  // -- Auto-fill: salva dados após compra bem-sucedida ----------------------
  Future<void> _salvarDadosCliente() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kNome,    _nomeCtrl.text.trim());
      await prefs.setString(_kCpf,     _cpfCtrl.text.trim());
      await prefs.setString(_kEmail,   _emailCtrl.text.trim());
      await prefs.setString(_kCelular, _celularCtrl.text.trim());
      await prefs.setString(_kNasc,    _nascCtrl.text.trim());
      await prefs.setString(_kCep,     _cepCtrl.text.trim());
      await prefs.setString(_kRua,     _ruaCtrl.text.trim());
      await prefs.setString(_kNumero,  _numeroCtrl.text.trim());
      await prefs.setString(_kComp,    _compCtrl.text.trim());
      await prefs.setString(_kBairro,  _bairroCtrl.text.trim());
      await prefs.setString(_kCidade,  _cidadeCtrl.text.trim());
      await prefs.setString(_kEstado,  _estadoCtrl.text.trim());
    } catch (_) {}
  }

  // -- Carrega produto -------------------------------------------------------
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

  // -- Busca CEP via ViaCEP --------------------------------------------------
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

  // -- Polling de status do pagamento PIX ---------------------------------
  void _iniciarPolling(String paymentId) {
    if (paymentId.isEmpty) return;
    _pollingTimer?.cancel();
    int tentativas = 0;
    // 60 tentativas × 5s = 5 minutos de polling
    // Pix pode demorar até 3-4 min para confirmar dependendo do banco
    const maxTentativas = 60;

    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted || tentativas >= maxTentativas) { timer.cancel(); return; }
      tentativas++;
      try {
        final r = await http.get(
          Uri.parse('$_workerBase/api/payment-status/$paymentId'),
        ).timeout(const Duration(seconds: 10));
        if (!mounted) { timer.cancel(); return; }
        if (r.statusCode == 200) {
          final body = jsonDecode(r.body);
          final data = (body['result'] ?? body) as Map<String, dynamic>?;
          final status = data?['status'] as String? ?? '';
          // Aceitar 'approved' (MP) ou 'ativa' (D1) como pagamento confirmado
          final pago = status == 'approved' || status == 'ativa';
          if (pago && !_paymentApproved) {
            timer.cancel();
            setState(() => _paymentApproved = true);
            if (mounted) {
              setState(() => _showSuccessScreen = true);
            }
            _salvarDadosCliente().catchError((_) {});
          }
        }
      } catch (_) {}
    });
  }

  // -- Gera pagamento via Woovi -------------------------------------------
  // Pix Avulso:    cria charge → QR Code + copia-e-cola + polling
  // Pix Automático: cria subscription → QR Code PAYMENT_ON_APPROVAL
  Future<void> _gerarPix() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _isSubmitting = true; _pixResult = null; _preapprovalResult = null; });

    // correlationID único por tentativa de pagamento
    final correlationID = 'sw_${widget.productId}_${widget.affiliateCode}_${DateTime.now().millisecondsSinceEpoch}';
    // userId do afiliado (dono do produto / recebedor da comissão)
    final affiliateUserId = widget.affiliateCode;

    // Helper: exibe snackbar com mensagem de erro
    void mostrarErro(String msg) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 8),
        ),
      );
    }

    // -- PIX Avulso: cria charge ----------------------------------------
    if (_product!.isPixAvulso) {
      final valorCents    = (_product!.valor * 100).round();
      final comissaoCents = (_product!.valorComissao * 100).round();

      final result = await WooviService.createCharge(
        correlationID:    correlationID,
        valueCents:       valorCents,
        userId:           affiliateUserId,
        affiliateCode:    widget.affiliateCode,
        productId:        _product!.id,
        productNome:      _product!.nome,
        commissionCents:  comissaoCents,
        customerName:     _nomeCtrl.text.trim(),
        customerEmail:    _emailCtrl.text.trim(),
        customerCpf:      _cpfCtrl.text.trim(),
        customerPhone:    _celularCtrl.text.trim().isNotEmpty ? _celularCtrl.text.trim() : null,
        comment:          _product!.nome,
        onError:          mostrarErro,
      );

      if (!mounted) return;
      setState(() { _isSubmitting = false; _pixResult = result; });

      if (result != null && result.hasQrCode) {
        _iniciarPolling(result.saleId);
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
            );
          }
        });
      }
      return;
    }

    // -- PIX Automático: cria assinatura recorrente (Banco Central) --------
    setState(() { _preapprovalResult = null; });

    final valorCents    = (_product!.valor * 100).round();
    final comissaoCents = (_product!.valorComissao * 100).round();

    final result = await WooviService.createSubscription(
      correlationID:   correlationID,
      valueCents:      valorCents,
      userId:          affiliateUserId,
      affiliateCode:   widget.affiliateCode,
      productId:       _product!.id,
      productNome:     _product!.nome,
      commissionCents: comissaoCents,
      customerName:    _nomeCtrl.text.trim(),
      customerCpf:     _cpfCtrl.text.replaceAll(RegExp(r'\D'), ''),
      customerEmail:   _emailCtrl.text.trim(),
      customerPhone:   _celularCtrl.text.trim().isNotEmpty ? _celularCtrl.text.trim() : null,
      zipcode:         _cepCtrl.text.replaceAll(RegExp(r'\D'), ''),
      street:          _ruaCtrl.text.trim(),
      number:          _numeroCtrl.text.trim().isNotEmpty ? _numeroCtrl.text.trim() : 'S/N',
      neighborhood:    _bairroCtrl.text.trim(),
      city:            _cidadeCtrl.text.trim(),
      state:           _estadoCtrl.text.trim().toUpperCase(),
      complement:      _compCtrl.text.trim(),
      comment:         _product!.nome,
      onError:         mostrarErro,
    );

    if (!mounted) return;
    setState(() { _isSubmitting = false; _preapprovalResult = result; });

    if (result != null && result.hasQrCode) {
      _salvarDadosCliente().catchError((_) {});
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  final _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    // -- Tela de parabéns (pós-pagamento) ------------------------------------
    if (_showSuccessScreen && _product != null) {
      return _PurchaseSuccessScreen(
        product: _product!,
        clienteNome: _nomeCtrl.text.trim(),
        clienteEmail: _emailCtrl.text.trim(),
        onVoltar: () => setState(() {
          _showSuccessScreen = false;
          _pixResult = null;
          _preapprovalResult = null;
          _paymentApproved = false;
        }),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet_rounded,
                color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text('ShareWallet',
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

    // -- Banner de produto (landing page) ------------------------------------
    if (_showBanner) {
      return _ProductLandingPage(
        product: product,
        onAssinar: product.isPixRecorrente ? _onLandingContinue : null,
        onComprar: product.isPixAvulso ? _onLandingContinue : null,
        // Produto que tem os dois tipos de cobrança
        onAssinarRecorrente: product.isPixRecorrente ? _onLandingContinue : null,
        onComprarAvulso: product.isPixAvulso ? _onLandingContinue : null,
      );
    }

    // -- Etapa de upload de documentos --------------------------------------
    if (_showDocUpload) {
      return _DocUploadStep(
        product: product,
        onBack: () => setState(() { _showDocUpload = false; _showBanner = true; }),
        onContinue: (docs) async {
          setState(() { _uploadedDocs = docs; _showDocUpload = false; });
          // Salva os docs na API com ID provisório
          final saleId = 'pre_${DateTime.now().millisecondsSinceEpoch}';
          final affiliateCode = widget.affiliateCode;
          final docId = await CfApiService.uploadSaleDocs(
            saleId: saleId,
            productId: product.id,
            affiliateCode: affiliateCode,
            clienteNome: _nomeCtrl.text.trim(),
            clienteEmail: _emailCtrl.text.trim(),
            docsData: docs,
          );
          if (mounted) setState(() { _saleDocId = docId; });
        },
      );
    }

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -- Card compacto do produto + botão voltar discreto ------------
            Stack(
              children: [
                _ProductCard(product: product),
                Positioned(
                  top: 8,
                  left: 8,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _showBanner = true;
                      _pixResult = null;
                      _preapprovalResult = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // -- Banner auto-fill se há dados salvos --------------------------
            if (_nomeCtrl.text.isNotEmpty) ...[
              _AutoFillBanner(nome: _nomeCtrl.text),
              const SizedBox(height: 16),
            ],

            // -- Dados Pessoais -----------------------------------------------
            _sectionTitle(Icons.person_rounded, 'Dados Pessoais'),
            const SizedBox(height: 12),
            _field(_nomeCtrl, 'Nome completo *', Icons.person_outline_rounded,
                validator: (v) => v!.trim().split('').length < 2
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

            // -- Endereço -----------------------------------------------------
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

            const SizedBox(height: 24),

            // -- Como funciona -------------------------------------------------
            _HowItWorks(product: product),
            const SizedBox(height: 24),

            // -- Botão principal -------------------------------------------
            // Pix Único: mostrar botão enquanto não há resultado
            if (product.isPixAvulso &&
                (_pixResult == null || !_pixResult!.hasQrCode))
              PrimaryButton(
                label: 'Gerar QR Code PIX  -  ${product.valorFormatado}',
                icon: Icons.qr_code_rounded,
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _gerarPix,
              ),

            // Pix Recorrente: mostrar botão enquanto não há assinatura gerada
            if (product.isPixRecorrente &&
                (_preapprovalResult == null || !_preapprovalResult!.hasQrCode))
              PrimaryButton(
                label: 'Assinar agora  -  ${product.valorFormatado}/mês',
                icon: Icons.autorenew_rounded,
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _gerarPix,
              ),

            // -- PIX Único: QR Code ----------------------------------------
            if (_pixResult != null && _pixResult!.hasQrCode && product.isPixAvulso) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _paymentApproved
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: _paymentApproved ? AppColors.success : AppColors.warning,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_paymentApproved)
                      const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18)
                    else
                      SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(AppColors.warning),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      _paymentApproved
                          ? 'Pagamento confirmado!'
                          : 'Aguardando pagamento PIX...',
                      style: TextStyle(
                        color: _paymentApproved ? AppColors.success : AppColors.warning,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              _PixQrCard(result: _pixResult!, product: product),
              const SizedBox(height: 8),
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

            // -- PIX Automático: Card de autorização Woovi ---------------
            if (_preapprovalResult != null &&
                _preapprovalResult!.hasQrCode &&
                product.isPixRecorrente) ...[
              _PreapprovalCard(
                result: _preapprovalResult!,
                product: product,
                onNovaTentativa: () => setState(() { _preapprovalResult = null; }),
              ),
            ],

            const SizedBox(height: 12),
            Center(
              child: Text(
                'Pagamento 100% via PIX  -  processado pela Woovi',
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

  // -- Helpers de UI ---------------------------------------------------------

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

// --- Banner de auto-fill -----------------------------------------------------
class _AutoFillBanner extends StatelessWidget {
  final String nome;
  const _AutoFillBanner({required this.nome});

  @override
  Widget build(BuildContext context) {
    final primeiroNome = nome.trim().split(' ').first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_pin_circle_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Olá, $primeiroNome! Seus dados foram preenchidos automaticamente.',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Tela de Parabéns pós-pagamento -----------------------------------------
class _PurchaseSuccessScreen extends StatefulWidget {
  final ProductModel product;
  final String clienteNome;
  final String clienteEmail;
  final VoidCallback onVoltar;

  const _PurchaseSuccessScreen({
    required this.product,
    required this.clienteNome,
    required this.clienteEmail,
    required this.onVoltar,
  });

  @override
  State<_PurchaseSuccessScreen> createState() => _PurchaseSuccessScreenState();
}

class _PurchaseSuccessScreenState extends State<_PurchaseSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double>   _scaleAnim;
  late Animation<double>   _fadeAnim;

  final GlobalKey _repaintKey = GlobalKey();
  bool _baixando = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.elasticOut);
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // -- Captura o widget como imagem PNG --------------------------------------
  Future<Uint8List?> _capturarImagem() async {
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  // -- Download genérico (Web usa dart:html, mobile usa url_launcher) ----------
  Future<void> _downloadArquivo({
    required String nomeArquivo,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final base64Data = base64Encode(bytes);
    final dataUri = 'data:$mimeType;base64,$base64Data';
    if (kIsWeb) {
      downloadFileWeb(dataUri, nomeArquivo);
    } else {
      openUrlInNewTab(dataUri);
    }
  }

  // -- Baixar como PDF (HTML via data URI) ----------------------------------
  Future<void> _baixarPdf() async {
    setState(() => _baixando = true);
    try {
      final dataHora = _formatarDataHora(DateTime.now());
      final primeiroNome = widget.clienteNome.isNotEmpty
          ? widget.clienteNome.split(' ').first : 'Cliente';

      // Gera HTML estilizado como comprovante
      final htmlContent = '''
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<title>Comprovante ShareWallet</title>
<style>
  body { font-family: Arial, sans-serif; margin: 0; padding: 32px; background: #f5f5f5; }
  .card { background: white; border-radius: 16px; padding: 32px; max-width: 600px; margin: 0 auto; box-shadow: 0 4px 20px rgba(0,0,0,0.1); }
  .header { background: #1B5E20; color: white; border-radius: 12px; padding: 24px; text-align: center; }
  .header h1 { margin: 0; font-size: 28px; }
  .header p { margin: 4px 0 0; font-size: 14px; opacity: 0.9; }
  h2 { color: #1B5E20; text-align: center; margin: 24px 0 8px; }
  .subtitle { text-align: center; color: #555; margin: 0 0 24px; }
  .details { border: 2px solid #A5D6A7; border-radius: 12px; padding: 20px; }
  .details h3 { color: #1B5E20; margin: 0 0 12px; }
  .row { display: flex; padding: 6px 0; border-bottom: 1px solid #f0f0f0; }
  .row:last-child { border-bottom: none; }
  .label { font-weight: bold; color: #555; min-width: 100px; }
  .value { color: #222; }
  .footer { text-align: center; color: #999; font-size: 11px; margin-top: 24px; }
  @media print { body { background: white; } }
</style>
</head>
<body>
<div class="card">
  <div class="header">
    <h1>ShareWallet</h1>
    <p>Comprovante de Compra</p>
  </div>
  <h2>Parabéns pela sua compra!</h2>
  <p class="subtitle">Olá, $primeiroNome! Sua compra foi confirmada com sucesso.</p>
  <div class="details">
    <h3>Detalhes da Compra</h3>
    <div class="row"><span class="label">Produto:</span><span class="value">${widget.product.nome}</span></div>
    <div class="row"><span class="label">Valor:</span><span class="value">${widget.product.valorFormatado}</span></div>
    <div class="row"><span class="label">Tipo:</span><span class="value">${widget.product.chargeTypeLabel}</span></div>
    ${widget.clienteNome.isNotEmpty ? '<div class="row"><span class="label">Cliente:</span><span class="value">${widget.clienteNome}</span></div>' : ''}
    ${widget.clienteEmail.isNotEmpty ? '<div class="row"><span class="label">E-mail:</span><span class="value">${widget.clienteEmail}</span></div>' : ''}
    <div class="row"><span class="label">Data/Hora:</span><span class="value">$dataHora</span></div>
    <div class="row"><span class="label">Pagamento:</span><span class="value">PIX — Confirmado ✓</span></div>
  </div>
  <div class="footer">Documento gerado em $dataHora — ShareWallet © ${DateTime.now().year}</div>
</div>
<script>window.onload = function() { window.print(); }</script>
</body>
</html>''';

      final encoded = base64Encode(utf8.encode(htmlContent));
      final dataUri = 'data:text/html;charset=utf-8;base64,$encoded';
      openUrlInNewTab(dataUri);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF gerado! Use Ctrl+P para imprimir/salvar.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar PDF: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _baixando = false);
    }
  }



  // -- Baixar como PNG --------------------------------------------------------
  Future<void> _baixarPng() async {
    setState(() => _baixando = true);
    try {
      final bytes = await _capturarImagem();
      if (bytes == null) throw Exception('Não foi possível capturar a imagem');
      await _downloadArquivo(
        nomeArquivo: 'comprovante_sharewallet.png',
        bytes: bytes,
        mimeType: 'image/png',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar PNG: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _baixando = false);
    }
  }

  // -- Baixar como JPG --------------------------------------------------------
  Future<void> _baixarJpg() async {
    setState(() => _baixando = true);
    try {
      final bytes = await _capturarImagem();
      if (bytes == null) throw Exception('Falha ao capturar imagem');
      // Salva como PNG (web não distingue JPG/PNG no download)
      await _downloadArquivo(
        nomeArquivo: 'comprovante_sharewallet.jpg',
        bytes: bytes,
        mimeType: 'image/png',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagem salva com sucesso!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar JPG: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _baixando = false);
    }
  }

  String _formatarDataHora(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final primeiroNome = widget.clienteNome.isNotEmpty
        ? widget.clienteNome.trim().split(' ').first : 'Cliente';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet_rounded,
                color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text('ShareWallet', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // -- Widget capturável para screenshot ----------------------------
            RepaintBoundary(
              key: _repaintKey,
              child: _buildComprovanteWidget(primeiroNome),
            ),

            const SizedBox(height: 28),

            // -- Botões de Download --------------------------------------------
            _buildDownloadSection(),

            const SizedBox(height: 20),

            // -- Voltar --------------------------------------------------------
            OutlinedButton.icon(
              onPressed: widget.onVoltar,
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text('Comprar outro produto'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // -- Widget do comprovante premium (também capturado para imagem) ----------
  Widget _buildComprovanteWidget(String primeiroNome) {
    // Protocolo único baseado no timestamp atual
    final protocolo = 'SW${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final dataHoraAtual = _formatarDataHora(DateTime.now());
    final temImagem = widget.product.imagemUrl != null &&
        widget.product.imagemUrl!.isNotEmpty;

    return Container(
      color: AppColors.background,
      child: Column(
        children: [

          // ── Card principal do comprovante ──────────────────────────────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.cardBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [

                // ── Header com gradiente + animação ─────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                  decoration: const BoxDecoration(
                    gradient: AppColors.darkGreenGradient,
                  ),
                  child: Column(
                    children: [
                      // Logo + check animado
                      FadeTransition(
                        opacity: _fadeAnim,
                        child: ScaleTransition(
                          scale: _scaleAnim,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Anel externo pulsante
                              Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                              // Ícone central
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.95),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: AppColors.success,
                                  size: 40,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      FadeTransition(
                        opacity: _fadeAnim,
                        child: Column(
                          children: [
                            Text(
                              'Pagamento Confirmado!',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    offset: const Offset(0, 1),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Olá, $primeiroNome! Sua compra foi aprovada.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.85),
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Imagem do produto (se disponível) ────────────────────────
                if (temImagem) ...[
                  Container(
                    width: double.infinity,
                    height: 180,
                    color: const Color(0xFF0A3D28),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          widget.product.imagemUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.primaryDark,
                            child: const Icon(Icons.image_not_supported_rounded,
                                color: Colors.white38, size: 40),
                          ),
                        ),
                        // Gradiente sutil sobre a imagem
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.45),
                              ],
                            ),
                          ),
                        ),
                        // Badge "Produto Adquirido" sobre a imagem
                        Positioned(
                          bottom: 12, right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_rounded,
                                    color: Colors.white, size: 13),
                                SizedBox(width: 4),
                                Text('Produto Adquirido',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    )),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Detalhes do produto ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ícone do tipo de produto
                      if (!temImagem)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(right: 14),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(widget.product.chargeTypeIcon,
                              color: AppColors.primary, size: 26),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.product.nome,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    widget.product.chargeTypeLabel,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Valor em destaque
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            widget.product.valorFormatado,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    color: AppColors.success, size: 11),
                                SizedBox(width: 3),
                                Text('Pago',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.success,
                                    )),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Divisor ──────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              AppColors.cardBorder.withValues(alpha: 0),
                              AppColors.cardBorder,
                            ]),
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.receipt_long_rounded,
                            color: AppColors.primary, size: 14),
                      ),
                      Expanded(
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              AppColors.cardBorder,
                              AppColors.cardBorder.withValues(alpha: 0),
                            ]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Dados do comprador ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    children: [
                      _infoRowPremium(
                        icon: Icons.person_rounded,
                        label: 'Comprador',
                        value: widget.clienteNome,
                        iconColor: const Color(0xFF1565C0),
                        bgColor: const Color(0xFF1565C0),
                      ),
                      if (widget.clienteEmail.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _infoRowPremium(
                          icon: Icons.email_rounded,
                          label: 'E-mail',
                          value: widget.clienteEmail,
                          iconColor: const Color(0xFF6A1B9A),
                          bgColor: const Color(0xFF6A1B9A),
                        ),
                      ],
                      const SizedBox(height: 10),
                      _infoRowPremium(
                        icon: Icons.calendar_today_rounded,
                        label: 'Data',
                        value: dataHoraAtual,
                        iconColor: const Color(0xFFF57C00),
                        bgColor: const Color(0xFFF57C00),
                      ),
                      const SizedBox(height: 10),
                      _infoRowPremium(
                        icon: Icons.pix_rounded,
                        label: 'Pagamento',
                        value: 'PIX — Processado com segurança',
                        iconColor: const Color(0xFF00796B),
                        bgColor: const Color(0xFF00796B),
                      ),
                      const SizedBox(height: 10),
                      _infoRowPremium(
                        icon: Icons.tag_rounded,
                        label: 'Protocolo',
                        value: protocolo,
                        iconColor: AppColors.primary,
                        bgColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),

                // ── Rodapé com linha decorativa ──────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    border: Border(
                      top: BorderSide(color: AppColors.cardBorder, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.security_rounded,
                          color: AppColors.success, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Compra verificada e protegida  •  ShareWallet © ${DateTime.now().year}',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textHint.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }

  // -- InfoRow premium com ícone colorido com fundo -------------------------
  Widget _infoRowPremium({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: bgColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHint,
                    letterSpacing: 0.3,
                  )),
              const SizedBox(height: 1),
              Text(value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1),
            ],
          ),
        ),
      ],
    );
  }

  // Mantido para compatibilidade (usado no PDF HTML)
  Widget _infoRow(IconData icon, String label, String value) => Row(
    children: [
      Icon(icon, color: AppColors.primary, size: 16),
      const SizedBox(width: 8),
      Text('$label: ', style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
      Expanded(
        child: Text(value,
            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
            overflow: TextOverflow.ellipsis),
      ),
    ],
  );

  // -- Seção de botões de download -------------------------------------------
  Widget _buildDownloadSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.download_rounded, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text('Salvar Comprovante',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Baixe uma cópia do seu comprovante de compra:',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (_baixando)
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 8),
                  Text('Gerando arquivo...', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            )
          else
            Column(
              children: [
                // PDF
                _DownloadButton(
                  icon: Icons.picture_as_pdf_rounded,
                  label: 'Baixar como PDF',
                  subtitle: 'Comprovante completo em PDF',
                  color: const Color(0xFFD32F2F),
                  onTap: _baixarPdf,
                ),
                const SizedBox(height: 10),
                // PNG
                _DownloadButton(
                  icon: Icons.image_rounded,
                  label: 'Baixar como PNG',
                  subtitle: 'Imagem de alta qualidade',
                  color: const Color(0xFF1565C0),
                  onTap: _baixarPng,
                ),
                const SizedBox(height: 10),
                // JPG
                _DownloadButton(
                  icon: Icons.photo_camera_rounded,
                  label: 'Baixar como JPG',
                  subtitle: 'Imagem compacta',
                  color: const Color(0xFF6A1B9A),
                  onTap: _baixarJpg,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// --- Botão de download estilizado --------------------------------------------
class _DownloadButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _DownloadButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: color)),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: color, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

// -- Landing page p\u00fablica do produto (banner de convers\u00e3o) ----------------------
class _ProductLandingPage extends StatefulWidget {
  final ProductModel product;
  final VoidCallback? onAssinar;
  final VoidCallback? onComprar;
  final VoidCallback? onAssinarRecorrente;
  final VoidCallback? onComprarAvulso;

  const _ProductLandingPage({
    required this.product,
    this.onAssinar,
    this.onComprar,
    this.onAssinarRecorrente,
    this.onComprarAvulso,
  });

  @override
  State<_ProductLandingPage> createState() => _ProductLandingPageState();
}

class _ProductLandingPageState extends State<_ProductLandingPage> {

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final isRec = product.isPixRecorrente;
    final isAv  = product.isPixAvulso;

    // Benefícios extraídos da descrição (linhas com bullet • ou -)
    final beneficios = _extrairBeneficios(product.descricao);
    final descricaoCompleta = _descricaoSemBeneficios(product.descricao);

    return SingleChildScrollView(
      child: Column(
        children: [
          // ── Hero banner do produto ──────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: AppColors.darkGreenGradient,
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo topo
                    Row(children: [
                      const Icon(Icons.account_balance_wallet_rounded,
                          color: Colors.white70, size: 18),
                      const SizedBox(width: 6),
                      const Text('ShareWallet',
                          style: TextStyle(color: Colors.white70,
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(children: [
                          const Icon(Icons.lock_rounded,
                              color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          const Text('Pix Seguro',
                              style: TextStyle(color: Colors.white,
                                  fontSize: 11, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ]),
                    // Banner de imagem do produto (se tiver)
                    if (product.imagemUrl != null &&
                        product.imagemUrl!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          product.imagemUrl!,
                          width: double.infinity,
                          // sem height fixo → ajusta proporcionalmente
                          fit: BoxFit.fitWidth,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          loadingBuilder: (ctx, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              height: 160,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white54,
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                    ] else
                      const SizedBox(height: 24),

                    // ── Ícone + nome + preço (tudo em linha) ───────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Ícone
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(product.chargeTypeIcon,
                              color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 14),
                        // Nome + badge
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                product.nome,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(product.chargeTypeLabel,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Preço (direita)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              product.valorFormatado,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5),
                            ),
                            if (isRec)
                              const Text(
                                '/mês',
                                style: TextStyle(
                                    color: Colors.white60, fontSize: 12),
                              ),
                          ],
                        ),
                      ],
                    ),

                    // Descrição completa (sem truncamento)
                    if (descricaoCompleta.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        descricaoCompleta,
                        softWrap: true,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.6,
                            fontWeight: FontWeight.w400),
                      ),

                    ],
                  ],
                ),
              ),
            ),
          ),

          // ── Benefícios ─────────────────────────────────────────────────
          if (beneficios.isNotEmpty)
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.star_rounded,
                          color: AppColors.primary, size: 16),
                    ),
                    const SizedBox(width: 8),
                    const Text('O que está incluído',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.textPrimary)),
                  ]),
                  const SizedBox(height: 12),
                  ...beneficios.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Text(b,
                            style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textPrimary,
                                height: 1.4))),
                      ],
                    ),
                  )),
                ],
              ),
            ),

          // ── Selos de confiança ──────────────────────────────────────────
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SeloConfianca(
                    icon: Icons.pix_rounded,
                    label: 'Pix Oficial',
                    cor: const Color(0xFF009EE3)),
                const SizedBox(width: 20),
                _SeloConfianca(
                    icon: Icons.lock_rounded,
                    label: '100% Seguro',
                    cor: AppColors.primary),
                const SizedBox(width: 20),
                _SeloConfianca(
                    icon: Icons.flash_on_rounded,
                    label: 'Imediato',
                    cor: const Color(0xFFF57C00)),
              ],
            ),
          ),

          // ── Botões de ação ──────────────────────────────────────────────
          Container(
            color: AppColors.background,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Botão Assinar (Pix Recorrente)
                if (isRec)
                  _BotaoAcao(
                    label: 'Assinar agora',
                    sublabel: '${product.valorFormatado}/mês · Cancele quando quiser',
                    icon: Icons.autorenew_rounded,
                    cor: AppColors.primary,
                    onTap: widget.onAssinarRecorrente ?? widget.onAssinar ?? () {},
                  ),

                if (isRec) const SizedBox(height: 12),

                // Botão Comprar (Pix Único)
                if (isAv)
                  _BotaoAcao(
                    label: 'Comprar agora',
                    sublabel: '${product.valorFormatado} · Pagamento único via Pix',
                    icon: Icons.qr_code_rounded,
                    cor: isRec
                        ? const Color(0xFF2E7D32)
                        : AppColors.primary,
                    outline: isRec,
                    onTap: widget.onComprarAvulso ?? widget.onComprar ?? () {},
                  ),

                const SizedBox(height: 20),

                // Rodapé de segurança
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.security_rounded,
                        size: 14, color: AppColors.textHint),
                    const SizedBox(width: 6),
                    Text(
                      'Pagamento processado via Pix • Dados protegidos',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _extrairBeneficios(String descricao) {
    final linhas = descricao.split('\n');
    return linhas
        .where((l) => l.trim().startsWith('•') ||
                      l.trim().startsWith('-') ||
                      l.trim().startsWith('✅') ||
                      l.trim().startsWith('✔'))
        .map((l) => l.trim().replaceAll(RegExp(r'^[•\-✅✔]\s*'), '').trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  String _descricaoSemBeneficios(String descricao) {
    final linhas = descricao.split('\n');
    final semBeneficios = linhas
        .where((l) => !l.trim().startsWith('•') &&
                      !l.trim().startsWith('-') &&
                      !l.trim().startsWith('✅') &&
                      !l.trim().startsWith('✔'))
        .join('\n')
        .trim();
    return semBeneficios;
  }
}

// -- Botão de ação do banner --------------------------------------------------
class _BotaoAcao extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final Color cor;
  final bool outline;
  final VoidCallback onTap;

  const _BotaoAcao({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.cor,
    required this.onTap,
    this.outline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: outline ? Colors.transparent : cor,
            border: outline
                ? Border.all(color: cor, width: 2)
                : null,
            borderRadius: BorderRadius.circular(14),
            boxShadow: outline ? null : [
              BoxShadow(
                color: cor.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: outline
                      ? cor.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon,
                    color: outline ? cor : Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            color: outline ? cor : Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(sublabel,
                        style: TextStyle(
                            color: outline
                                ? cor.withValues(alpha: 0.7)
                                : Colors.white.withValues(alpha: 0.8),
                            fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: outline ? cor : Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// -- Selo de confiança --------------------------------------------------------
class _SeloConfianca extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color cor;
  const _SeloConfianca(
      {required this.icon, required this.label, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: cor, size: 18),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: cor,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// -- Card do produto -----------------------------------------------------------
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

// -- Caixa de autorização PIX Recorrente --------------------------------------
// -- Como funciona -------------------------------------------------------------
class _HowItWorks extends StatelessWidget {
  final ProductModel product;
  const _HowItWorks({required this.product});

  @override
  Widget build(BuildContext context) {
    final steps = product.isPixRecorrente ? [
      '1. Preencha seus dados e clique em "Assinar agora"',
      '2. Escaneie o QR Code gerado com o app do seu banco',
      '3. Escolha seu banco (Nubank, BB, Itaú, Bradesco, Caixa...)',
      '4. Autorize uma única vez no app do seu banco',
      '5. As cobranças mensais seguintes são automáticas — sem novo QR Code',
    ] : [
      '1. Preencha seus dados cadastrais acima',
      '2. Clique em "Gerar QR Code PIX"',
      '3. Escaneie o QR Code ou copie o código no seu banco',
      '4. Confirmação imediata após o pagamento',
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
                  ? 'Como funciona a Assinatura'
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

// -- Card de Autorização Pix Automático (Woovi) --------------------------------
// Exibido após criar a assinatura — instrui o cliente a escanear o QR Code
// que paga a 1ª parcela e autoriza as cobranças futuras (Jornada 3).
class _PreapprovalCard extends StatefulWidget {
  final SubscriptionResult result;
  final ProductModel product;
  final VoidCallback onNovaTentativa;

  const _PreapprovalCard({
    required this.result,
    required this.product,
    required this.onNovaTentativa,
  });

  @override
  State<_PreapprovalCard> createState() => _PreapprovalCardState();
}

class _PreapprovalCardState extends State<_PreapprovalCard> {
  bool _copiou = false;

  void _copiarCodigo() {
    final code = widget.result.brCode;
    if (code.isEmpty) return;
    Clipboard.setData(ClipboardData(text: code));
    setState(() => _copiou = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Código PIX copiado!'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 3),
      ),
    );
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _copiou = false);
    });
  }

  void _abrirLink() {
    final url = widget.result.paymentLinkUrl;
    if (url.isEmpty) return;
    openUrlInNewTab(url);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final p = widget.product;

    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6C3CE1).withValues(alpha: 0.6), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C3CE1).withValues(alpha: 0.10),
            blurRadius: 18, offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header roxo Woovi ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C3CE1), Color(0xFF4A1FA8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.autorenew_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Assinatura Gerada!',
                          style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w800, fontSize: 17)),
                      Text('${p.valorFormatado}/mês • Pix Automático',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Woovi',
                      style: TextStyle(color: Colors.white,
                          fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Instrução compacta
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: Color(0xFF6C3CE1), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Escaneie o QR Code com o app do seu banco para pagar '
                        'a 1ª parcela e autorizar as cobranças mensais automáticas.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // QR Code + Copia e Cola lado a lado (layout compacto)
                if (r.brCode.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // QR Code menor à esquerda
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: QrImageView(
                          data: r.brCode,
                          version: QrVersions.auto,
                          size: 120,
                          backgroundColor: Colors.white,
                          errorCorrectionLevel: QrErrorCorrectLevel.M,
                          errorStateBuilder: (_, __) => const SizedBox(
                            width: 120,
                            height: 120,
                            child: Icon(Icons.qr_code_2_rounded,
                                size: 80, color: AppColors.textHint),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Copia e Cola à direita
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('PIX Copia e Cola',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  color: AppColors.textPrimary,
                                )),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      r.brCode,
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: AppColors.textSecondary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 4,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _copiarCodigo,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 28, minHeight: 28),
                                    icon: Icon(
                                      _copiou
                                          ? Icons.check_rounded
                                          : Icons.copy_rounded,
                                      color: _copiou
                                          ? AppColors.success
                                          : const Color(0xFF6C3CE1),
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 38,
                              child: ElevatedButton.icon(
                                onPressed: _copiarCodigo,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _copiou
                                      ? AppColors.success
                                      : const Color(0xFF6C3CE1),
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: Icon(
                                  _copiou
                                      ? Icons.check_rounded
                                      : Icons.copy_all_rounded,
                                  color: Colors.white,
                                  size: 15,
                                ),
                                label: Text(
                                  _copiou ? 'Copiado!' : 'Copiar Código',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                // Link externo (compacto)
                if (r.paymentLinkUrl.isNotEmpty) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: OutlinedButton.icon(
                      onPressed: _abrirLink,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        side: const BorderSide(
                            color: Color(0xFF6C3CE1), width: 1),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded,
                          color: Color(0xFF6C3CE1), size: 15),
                      label: const Text('Abrir link de pagamento',
                          style: TextStyle(
                            color: Color(0xFF6C3CE1),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          )),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Nota de cobrança automática (compacta)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_rounded,
                          color: AppColors.success, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Próximas cobranças automáticas via Banco Central.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.success.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: widget.onNovaTentativa,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                    ),
                    child: const Text(
                      'Corrigir dados / Tentar novamente',
                      style: TextStyle(
                        color: AppColors.textHint,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -- QR Code PIX Avulso gerado pela Woovi -------------------------------------
class _PixQrCard extends StatefulWidget {
  final ChargeResult result;
  final ProductModel product;
  const _PixQrCard({required this.result, required this.product});

  @override
  State<_PixQrCard> createState() => _PixQrCardState();
}

class _PixQrCardState extends State<_PixQrCard> {
  bool _copiou = false;

  void _copiar(BuildContext context) {
    final code = widget.result.brCode;
    if (code.isEmpty) return;
    Clipboard.setData(ClipboardData(text: code));
    setState(() => _copiou = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Código PIX copiado!'),
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
                      const Text(
                        'QR Code PIX Gerado!',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16,
                            color: AppColors.success),
                      ),
                      Text(
                        'Valor: ${p.valorFormatado}',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C3CE1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.pix_rounded, color: Color(0xFF6C3CE1), size: 14),
                      SizedBox(width: 4),
                      Text('Woovi',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                              color: Color(0xFF6C3CE1))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // QR Code image (URL Woovi)
          if (r.qrCodeImage.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Image.network(
                r.qrCodeImage,
                width: 200, height: 200,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.qr_code_2_rounded, size: 160, color: AppColors.textHint),
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

          if (r.brCode.isNotEmpty) ...[
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
                  const Icon(Icons.pix_rounded,
                      color: Color(0xFF6C3CE1), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(r.brCode,
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
                      color: _copiou ? AppColors.success
                          : const Color(0xFF6C3CE1),
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
                  backgroundColor: _copiou ? AppColors.success
                      : const Color(0xFF6C3CE1),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(_copiou ? Icons.check_rounded
                    : Icons.copy_all_rounded, color: Colors.white),
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
            child: const Row(
              children: [
                Icon(Icons.timer_rounded, color: AppColors.warning, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Este PIX expira em 24 horas. '
                    'Realize o pagamento pelo app do seu banco.',
                    style: TextStyle(fontSize: 12,
                        color: AppColors.warning, height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          if (r.saleId.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('ID: ${r.saleId}',
                style: const TextStyle(fontSize: 10,
                    color: AppColors.textHint)),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FIM DO ARQUIVO — todo código abaixo foi removido (classes MP legadas)
// ---------------------------------------------------------------------------

// ─────────────────────────────────────────────────────────────────────────────
// Widget de upload de documentos obrigatórios
// ─────────────────────────────────────────────────────────────────────────────
class _DocUploadStep extends StatefulWidget {
  final ProductModel product;
  final VoidCallback onBack;
  final Future<void> Function(Map<String, String> docs) onContinue;

  const _DocUploadStep({
    required this.product,
    required this.onBack,
    required this.onContinue,
  });

  @override
  State<_DocUploadStep> createState() => _DocUploadStepState();
}

class _DocUploadStepState extends State<_DocUploadStep> {
  /// chave → valor
  /// Para documentos normais: base64 da imagem ("data:image/...")
  /// Para geolocalização: string JSON  '{"lat":..,"lng":..,"acc":..,"ts":..}'
  /// Para campos personalizados: texto digitado pelo comprador
  final Map<String, String> _docs = {};

  /// Controllers de texto para cada campo personalizado (key → controller)
  late final Map<String, TextEditingController> _fieldCtrls;

  /// Controla o estado de carregamento individual por chave
  final Map<String, bool> _loading = {};

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fieldCtrls = {
      for (final f in widget.product.activeCustomFields)
        f.key: TextEditingController()
    };
  }

  @override
  void dispose() {
    for (final c in _fieldCtrls.values) c.dispose();
    super.dispose();
  }

  // ── Metadados de cada tipo de documento ──────────────────────────────────
  static const _docInfo = <String, (String, IconData, bool)>{
    // chave: (label, ícone, isGeo)
    'cnh':             ('CNH (Carteira de Habilitação)', Icons.badge_rounded,            false),
    'selfie':          ('Selfie / Foto com documento',   Icons.face_rounded,              false),
    'comp_residencia': ('Comprovante de Residência',     Icons.home_rounded,              false),
    'comp_renda':      ('Comprovante de Renda',          Icons.attach_money_rounded,      false),
    'geolocalizacao':  ('Geolocalização',                Icons.my_location_rounded,       true),
    'certidao':        ('Certidão de Nascimento',        Icons.article_rounded,           false),
  };

  // ── Ação genérica por tipo ───────────────────────────────────────────────
  Future<void> _handle(String docKey) async {
    final info = _docInfo[docKey];
    final isGeo = info?.$3 ?? false;
    if (isGeo) {
      await _captureGeo();
    } else {
      await _pickImageWeb(docKey);
    }
  }

  // ── Captura GPS via browser Geolocation API ──────────────────────────────
  Future<void> _captureGeo() async {
    setState(() => _loading['geolocalizacao'] = true);
    try {
      final completer = Completer<Map<String, dynamic>>();

      // Usa JS interop para chamar navigator.geolocation.getCurrentPosition
      // ignore: undefined_prefixed_name
      html.window.navigator.geolocation.getCurrentPosition(
        maximumAge: Duration.zero,
        timeout: const Duration(seconds: 15),
        enableHighAccuracy: true,
      ).then((pos) {
        completer.complete({
          'lat': pos.coords!.latitude,
          'lng': pos.coords!.longitude,
          'acc': pos.coords!.accuracy,
          'ts': DateTime.now().toIso8601String(),
        });
      }).catchError((dynamic e) {
        // e é um GeolocationPositionError com código 1=PERMISSION_DENIED 2=UNAVAILABLE 3=TIMEOUT
        completer.completeError(e);
      });

      final coords = await completer.future;
      final value = json.encode(coords);
      if (mounted) setState(() => _docs['geolocalizacao'] = value);
    } catch (e) {
      if (!mounted) return;
      final s = e.toString();
      final msg = s.contains('User denied') || s.contains('PERMISSION') || s.contains('code: 1')
          ? 'Permissão de localização negada.\nPermita o acesso à localização no browser e tente novamente.'
          : s.contains('code: 2') || s.contains('POSITION_UNAVAILABLE')
              ? 'Não foi possível determinar sua localização. Verifique se o GPS está ativo.'
              : s.contains('code: 3') || s.contains('TIMEOUT')
                  ? 'Tempo esgotado ao obter localização. Tente novamente.'
                  : 'Erro ao capturar localização. Verifique as permissões do browser.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading.remove('geolocalizacao'));
    }
  }

  // ── Seleciona imagem via input[type=file] (web) ──────────────────────────
  Future<void> _pickImageWeb(String docKey) async {
    setState(() => _loading[docKey] = true);
    try {
      final input = html.FileUploadInputElement()..accept = 'image/*';
      input.click();
      await input.onChange.first;
      if (input.files == null || input.files!.isEmpty) return;
      final file = input.files![0];
      final reader = html.FileReader();
      reader.readAsDataUrl(file);
      await reader.onLoad.first;
      final result = reader.result as String;
      if (mounted) setState(() => _docs[docKey] = result);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao selecionar imagem. Tente novamente.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading.remove(docKey));
    }
  }

  // ── Texto de status exibido no card da geolocalização ───────────────────
  String _geoStatusText(String raw) {
    try {
      final m = json.decode(raw) as Map;
      final lat  = (m['lat'] as num).toStringAsFixed(6);
      final lng  = (m['lng'] as num).toStringAsFixed(6);
      final acc  = (m['acc'] as num).toStringAsFixed(0);
      return '$lat, $lng  (±${acc}m)';
    } catch (_) {
      return 'Localização capturada ✓';
    }
  }

  bool get _allDone =>
      widget.product.docsRequired.every((k) => _docs.containsKey(k)) &&
      widget.product.activeCustomFields.every(
          (f) => _fieldCtrls[f.key]?.text.trim().isNotEmpty == true);

  Future<void> _submit() async {
    if (!_allDone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete todos os itens obrigatórios para continuar.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      // Mescla respostas dos campos personalizados no mapa de docs
      for (final f in widget.product.activeCustomFields) {
        final text = _fieldCtrls[f.key]?.text.trim() ?? '';
        if (text.isNotEmpty) _docs[f.key] = text;
      }
      await widget.onContinue(_docs);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final docs = widget.product.docsRequired;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabeçalho ────────────────────────────────────────────────────
          Row(
            children: [
              GestureDetector(
                onTap: widget.onBack,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: AppColors.textPrimary, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Documentos Obrigatórios',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Text('Envie os documentos antes de pagar',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Card informativo ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Para finalizar sua compra, precisamos verificar alguns dados. '
                    'Fotos devem ser nítidas e legíveis.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Lista de itens ───────────────────────────────────────────────
          ...docs.map((docKey) {
            final info   = _docInfo[docKey];
            final label  = info?.$1 ?? docKey;
            final icon   = info?.$2 ?? Icons.upload_file_rounded;
            final isGeo  = info?.$3 ?? false;
            final done   = _docs.containsKey(docKey);
            final busy   = _loading[docKey] == true;

            // Texto de subtítulo
            String subtitle;
            if (busy) {
              subtitle = isGeo ? 'Obtendo localização...' : 'Carregando...';
            } else if (done) {
              subtitle = isGeo
                  ? _geoStatusText(_docs[docKey]!)
                  : 'Enviado ✓  Toque para trocar';
            } else {
              subtitle = isGeo
                  ? 'Toque para capturar sua localização GPS'
                  : 'Toque para enviar foto';
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: busy ? null : () => _handle(docKey),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: done
                        ? AppColors.success.withValues(alpha: 0.07)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: done ? AppColors.success : AppColors.cardBorder,
                      width: done ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Ícone / spinner
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: done
                              ? AppColors.success.withValues(alpha: 0.1)
                              : isGeo
                                  ? Colors.blue.withValues(alpha: 0.08)
                                  : AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: busy
                            ? Padding(
                                padding: const EdgeInsets.all(10),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: isGeo ? Colors.blue : AppColors.primary,
                                ),
                              )
                            : done
                                ? Icon(Icons.check_circle_rounded,
                                    color: AppColors.success, size: 24)
                                : Icon(icon,
                                    color: isGeo ? Colors.blue : AppColors.primary,
                                    size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: done
                                        ? AppColors.success
                                        : AppColors.textPrimary)),
                            const SizedBox(height: 2),
                            Text(subtitle,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: done
                                        ? AppColors.success.withValues(alpha: 0.8)
                                        : AppColors.textHint)),
                          ],
                        ),
                      ),
                      Icon(
                        done
                            ? Icons.check_rounded
                            : (isGeo ? Icons.my_location_rounded : Icons.camera_alt_rounded),
                        color: done
                            ? AppColors.success
                            : AppColors.textHint,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          // ── Campos personalizados (texto livre) ──────────────────────────
          if (widget.product.activeCustomFields.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            const Text(
              'Informações adicionais',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...widget.product.activeCustomFields.map((f) {
              final ctrl = _fieldCtrls[f.key]!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: AnimatedBuilder(
                  animation: ctrl,
                  builder: (_, __) {
                    final filled = ctrl.text.trim().isNotEmpty;
                    return TextFormField(
                      controller: ctrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: f.label,
                        hintText: 'Digite ${f.label.toLowerCase()}',
                        prefixIcon: Icon(
                          Icons.edit_note_rounded,
                          color: filled
                              ? AppColors.success
                              : AppColors.primary,
                          size: 20,
                        ),
                        suffixIcon: filled
                            ? const Icon(Icons.check_circle_rounded,
                                color: AppColors.success, size: 20)
                            : null,
                        filled: true,
                        fillColor: filled
                            ? AppColors.success.withValues(alpha: 0.05)
                            : AppColors.surfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                              color: AppColors.cardBorder, width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: filled
                                ? AppColors.success
                                : AppColors.cardBorder,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                              color: AppColors.primary, width: 2),
                        ),
                        labelStyle: TextStyle(
                          color: filled
                              ? AppColors.success
                              : AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary),
                    );
                  },
                ),
              );
            }),
          ],

          const SizedBox(height: 8),

          // Progresso
          LinearProgressIndicator(
            value: docs.isEmpty
                ? 1.0
                : _docs.length / docs.length,
            backgroundColor: AppColors.cardBorder,
            valueColor:
                AlwaysStoppedAnimation<Color>(AppColors.success),
            borderRadius: BorderRadius.circular(4),
            minHeight: 6,
          ),
          const SizedBox(height: 6),
          Text(
            '${_docs.length} de ${docs.length} itens concluídos',
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),

          // Botão continuar
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting
                  ? null
                  : (_allDone ? _submit : null),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.arrow_forward_rounded),
              label: Text(_isSubmitting
                  ? 'Salvando...'
                  : _allDone
                      ? 'Continuar para Pagamento'
                      : 'Complete todos os itens'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _allDone
                    ? AppColors.primary
                    : AppColors.textHint,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
