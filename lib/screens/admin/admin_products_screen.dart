import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/admin_service.dart';
import '../../models/product_model.dart';
import '../../theme/app_theme.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  String _search = '';

  @override
  void initState() {
    super.initState();
    // Garante carregamento mesmo quando tela é montada pelo IndexedStack
    // antes de loadAll() terminar (timing race condition)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final svc = context.read<AdminService>();
      // Recarrega se a lista estiver vazia (pode ser que loadAll ainda não terminou)
      if (svc.products.isEmpty && !svc.isLoadingProducts) {
        svc.loadProducts();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<AdminService>();
    final produtos = svc.products
        .where((p) =>
            _search.isEmpty ||
            p.nome.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, null),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Novo Produto',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          // Busca
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Buscar produto...',
                prefixIcon:
                    const Icon(Icons.search_rounded, color: AppColors.textHint),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => setState(() => _search = ''),
                      )
                    : null,
              ),
            ),
          ),
          // Resumo
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                _ChipStat(
                    label: '${svc.products.length} total',
                    color: AppColors.primary),
                const SizedBox(width: 8),
                _ChipStat(
                    label:
                        '${svc.products.where((p) => p.ativo).length} ativos',
                    color: AppColors.success),
                const SizedBox(width: 8),
                _ChipStat(
                    label:
                        '${svc.products.where((p) => !p.ativo).length} inativos',
                    color: AppColors.textHint),
              ],
            ),
          ),
          const Divider(height: 8),
          // Lista
          Expanded(
            child: svc.isLoadingProducts
                ? const Center(child: CircularProgressIndicator())
                : produtos.isEmpty
                    ? const Center(child: Text('Nenhum produto encontrado'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 80),
                        itemCount: produtos.length,
                        itemBuilder: (ctx, i) => _ProductCard(
                          product: produtos[i],
                          onEdit: () => _openForm(context, produtos[i]),
                          onToggle: () =>
                              svc.toggleProductStatus(produtos[i].id),
                          onDelete: () =>
                              _confirmDelete(context, svc, produtos[i]),
                          onCopyLink: () => _copyProductLink(context, produtos[i].id),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyProductLink(BuildContext context, String productId) async {
    const baseUrl = 'https://sharewallet.com.br/app/#/produto';
    final link = '$baseUrl/$productId';
    await Clipboard.setData(ClipboardData(text: link));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Link copiado!\n$link',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, AdminService svc, ProductModel p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir Produto'),
        content: Text('Excluir "${p.nome}"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final deleted = await svc.deleteProduct(p.id);
      if (!context.mounted) return;
      if (!deleted) {
        final errorMsg = svc.error ?? 'Erro ao excluir produto';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  Future<void> _openForm(BuildContext context, ProductModel? product) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductFormSheet(product: product),
    );
  }
}

// -- Tile compacto do produto (com expansão) -----------------------------------
class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onCopyLink;
  const _ProductCard(
      {required this.product,
      required this.onEdit,
      required this.onToggle,
      required this.onDelete,
      required this.onCopyLink});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final typeColor = product.chargeTypeColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: product.ativo
                ? AppColors.cardBorder
                : AppColors.error.withValues(alpha: 0.25),
            width: 1),
      ),
      child: Theme(
        // Remove o divider padrão do ExpansionTile
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          childrenPadding: EdgeInsets.zero,
          // ── Linha principal (compacta) ──────────────────────────────────
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(product.chargeTypeIcon, color: typeColor, size: 17),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  product.nome,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              // Badge tipo
              _ChargeBadge(product: product),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 2),
            child: Row(
              children: [
                Text(
                  fmt.format(product.valor),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary),
                ),
                const SizedBox(width: 6),
                Text(
                  '· ${product.comissaoPercent}% → ${fmt.format(product.valorComissao)}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
                if (!product.ativo) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('INATIVO',
                        style: TextStyle(
                            color: AppColors.error,
                            fontSize: 9,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
          ),
          // Switch no trailing (substituindo seta padrão)
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch.adaptive(
                value: product.ativo,
                activeThumbColor: AppColors.primary,
                activeTrackColor: AppColors.primaryLight,
                onChanged: (_) => onToggle(),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const Icon(Icons.expand_more_rounded,
                  size: 18, color: AppColors.textHint),
            ],
          ),
          // ── Detalhes expandidos ──────────────────────────────────────────
          children: [
            Container(
              decoration: const BoxDecoration(
                border: Border(
                    top: BorderSide(color: AppColors.cardBorder, width: 1)),
              ),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Descrição
                  if (product.descricao.isNotEmpty) ...[
                    Text(
                      product.descricao,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Cobrança recorrente
                  if (product.diaCobranca != null)
                    Row(
                      children: [
                        const Icon(Icons.event_repeat_rounded,
                            size: 13, color: AppColors.textHint),
                        const SizedBox(width: 4),
                        Text(
                          'Cobrança todo dia ${product.diaCobranca}',
                          style: const TextStyle(
                              color: AppColors.textHint, fontSize: 12),
                        ),
                      ],
                    ),
                  // Ações
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Copiar link
                      IconButton(
                        onPressed: onCopyLink,
                        icon: const Icon(Icons.link_rounded,
                            color: AppColors.primary, size: 20),
                        tooltip: 'Copiar link do produto',
                        style: IconButton.styleFrom(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.08),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          minimumSize: const Size(36, 36),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_rounded, size: 15),
                          label: const Text('Editar'),
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 7),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: AppColors.error, size: 20),
                        tooltip: 'Excluir',
                        style: IconButton.styleFrom(
                          minimumSize: const Size(36, 36),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -- Formulário de produto -----------------------------------------------------
class _ProductFormSheet extends StatefulWidget {
  final ProductModel? product;
  const _ProductFormSheet({this.product});

  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<_ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nome;
  late TextEditingController _descricao;
  late TextEditingController _valor;
  late TextEditingController _comissao;
  late TextEditingController _diaCobranca;
  late TextEditingController _beneficios;
  late TextEditingController _categoria;
  late TextEditingController _imagemUrl;
  late ChargeType _chargeType;
  late bool _ativo;
  bool _bannerPreviewError = false;
  List<String> _docsRequired = [];
  // Campos de texto personalizados criados pelo admin
  List<CustomField> _customFields = [];

  // Documentos disponíveis para seleção
  static const _docOpts = [
    ('cnh',              'CNH',                       Icons.badge_rounded),
    ('selfie',           'Selfie / Foto',              Icons.face_rounded),
    ('comp_residencia',  'Comprovante de Residência',  Icons.home_rounded),
    ('comp_renda',       'Comprovante de Renda',       Icons.attach_money_rounded),
    ('geolocalizacao',   'Geolocalização',             Icons.location_on_rounded),
    ('certidao',         'Certidão de Nascimento',     Icons.article_rounded),
    // ── Novos ───────────────────────────────────────────────────────────────
    ('foto_moto',        'Fotos da Moto',              Icons.two_wheeler_rounded),
    ('foto_carro',       'Fotos do Carro',             Icons.directions_car_rounded),
    ('foto_celular',     'Fotos do Celular',           Icons.smartphone_rounded),
    ('print_imei',       'Print do IMEI',              Icons.perm_device_information_rounded),
    ('foto_doc_moto',    'Fotos Documento da Moto',    Icons.description_rounded),
    ('foto_doc_carro',   'Fotos Documento do Carro',   Icons.description_rounded),
    ('nota_fiscal',      'Nota Fiscal (se tiver)',     Icons.receipt_long_rounded),
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nome = TextEditingController(text: p?.nome ?? '');
    _descricao = TextEditingController(text: p?.descricao ?? '');
    _valor =
        TextEditingController(text: p != null ? p.valor.toStringAsFixed(2) : '');
    _comissao = TextEditingController(
        text: p != null ? (p.comissao * 100).toStringAsFixed(0) : '');
    _diaCobranca =
        TextEditingController(text: p?.diaCobranca?.toString() ?? '5');
    _beneficios =
        TextEditingController(text: p?.beneficiosList.join('\n') ?? '');
    _categoria = TextEditingController(text: p?.categoria ?? 'geral');
    _imagemUrl = TextEditingController(text: p?.imagemUrl ?? '');
    _chargeType = p?.chargeType ?? ChargeType.pixRecorrente;
    _ativo = p?.ativo ?? true;
    _docsRequired = List<String>.from(p?.docsRequired ?? []);
    _customFields = List<CustomField>.from(p?.customFields ?? []);
  }

  @override
  void dispose() {
    for (final c in [
      _nome, _descricao, _valor, _comissao, _diaCobranca, _beneficios, _categoria, _imagemUrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final svc = context.read<AdminService>();
    final isNew = widget.product == null;
    final diaCobrancaVal = _chargeType == ChargeType.pixRecorrente
        ? int.tryParse(_diaCobranca.text)
        : null;
    final beneficiosStr =
        _beneficios.text.trim().replaceAll('\n', '|');

    final imgUrl = _imagemUrl.text.trim();
    final produto = ProductModel(
      id: widget.product?.id ?? 'p_${DateTime.now().millisecondsSinceEpoch}',
      nome: _nome.text.trim(),
      descricao: _descricao.text.trim(),
      valor: double.tryParse(_valor.text.replaceAll(',', '.')) ?? 0,
      comissao: (double.tryParse(_comissao.text) ?? 0) / 100,
      categoria: _categoria.text.trim(),
      chargeType: _chargeType,
      diaCobranca: diaCobrancaVal,
      periodicidade:
          _chargeType == ChargeType.pixRecorrente ? 'mensal' : null,
      beneficios: beneficiosStr.isEmpty ? null : beneficiosStr,
      ativo: _ativo,
      imagemUrl: imgUrl.isEmpty ? null : imgUrl,
      docsRequired: _docsRequired,
      customFields: _customFields,
    );

    final ok = await svc.saveProduct(produto, isNew: isNew);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isNew ? 'Produto criado!' : 'Produto atualizado!'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      // Mostrar o erro real ao invés de silenciar
      final errorMsg = svc.error ?? 'Erro desconhecido ao salvar produto';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.product == null;
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isNew ? 'Novo Produto' : 'Editar Produto',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),
            // Formulário
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    // -- Tipo de cobrança Pix -----------------------------
                    const Text('Tipo de Cobrança Pix',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    const Text(
                      'Todos os produtos usam Pix como forma de pagamento',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textHint),
                    ),
                    const SizedBox(height: 12),
                    // Opção 1: Pix Recorrente
                    _PixTypeOption(
                      selected: _chargeType == ChargeType.pixRecorrente,
                      icon: Icons.autorenew_rounded,
                      color: const Color(0xFF0D7A5A),
                      title: 'Pix Recorrente',
                      subtitle: 'Cliente autoriza 1x -> débito automático todo mês',
                      badge: 'RECOMENDADO',
                      onTap: () => setState(() => _chargeType = ChargeType.pixRecorrente),
                    ),
                    const SizedBox(height: 10),
                    // Opção 2: Pix Único/Avulso
                    _PixTypeOption(
                      selected: _chargeType == ChargeType.pixAvulso,
                      icon: Icons.pix_rounded,
                      color: const Color(0xFF1976D2),
                      title: 'Pix Único',
                      subtitle: 'QR Code gerado a cada cobrança manualmente',
                      onTap: () => setState(() => _chargeType = ChargeType.pixAvulso),
                    ),
                    const SizedBox(height: 16),

                    // -- Campos principais -------------------------------
                    _Field(
                      controller: _nome,
                      label: 'Nome do Produto',
                      icon: Icons.inventory_2_rounded,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Informe o nome' : null,
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      controller: _descricao,
                      label: 'Descrição',
                      icon: Icons.description_rounded,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _Field(
                            controller: _valor,
                            label: 'Valor (R\$)',
                            icon: Icons.attach_money_rounded,
                            keyboardType: TextInputType.number,
                            validator: (v) => v == null || v.isEmpty
                                ? 'Informe o valor'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Field(
                            controller: _comissao,
                            label: 'Comissão (%)',
                            icon: Icons.percent_rounded,
                            keyboardType: TextInputType.number,
                            validator: (v) => v == null || v.isEmpty
                                ? 'Informe a comissão'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_chargeType != ChargeType.pixAvulso) ...[
                      _Field(
                        controller: _diaCobranca,
                        label: 'Dia de Cobrança (ex: 5)',
                        icon: Icons.event_repeat_rounded,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final d = int.tryParse(v ?? '');
                          if (d == null || d < 1 || d > 28) {
                            return 'Informe um dia entre 1 e 28';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    _Field(
                      controller: _categoria,
                      label: 'Categoria',
                      icon: Icons.category_rounded,
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      controller: _beneficios,
                      label: 'Benefícios (um por linha)',
                      icon: Icons.check_circle_outline_rounded,
                      maxLines: 5,
                      hint: 'Benefício 1\nBenefício 2\n...',
                    ),
                    const SizedBox(height: 12),

                    // -- Banner do produto ----------------------------------
                    const Text('Banner do Produto',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(
                      'Cole a URL de uma imagem para exibir no topo da página de venda',
                      style: TextStyle(fontSize: 11, color: AppColors.textHint),
                    ),
                    const SizedBox(height: 10),
                    // Preview da imagem
                    if (_imagemUrl.text.trim().isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _bannerPreviewError
                            ? Container(
                                height: 120,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.broken_image_rounded,
                                          color: AppColors.error, size: 32),
                                      const SizedBox(height: 6),
                                      Text('URL inválida ou imagem não carregou',
                                          style: TextStyle(
                                              fontSize: 11, color: AppColors.error)),
                                    ],
                                  ),
                                ),
                              )
                            : Image.network(
                                _imagemUrl.text.trim(),
                                // sem height fixo → proporcional à imagem
                                width: double.infinity,
                                fit: BoxFit.fitWidth,
                                errorBuilder: (_, __, ___) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (mounted) setState(() => _bannerPreviewError = true);
                                  });
                                  return const SizedBox.shrink();
                                },
                              ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    // Campo URL
                    TextFormField(
                      controller: _imagemUrl,
                      decoration: InputDecoration(
                        labelText: 'URL da imagem do banner',
                        hintText: 'https://exemplo.com/banner.jpg',
                        prefixIcon: const Icon(Icons.image_rounded,
                            color: AppColors.textHint, size: 20),
                        suffixIcon: _imagemUrl.text.trim().isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    color: AppColors.textHint, size: 18),
                                onPressed: () => setState(() {
                                  _imagemUrl.clear();
                                  _bannerPreviewError = false;
                                }),
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.surfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: AppColors.cardBorder, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: AppColors.primary, width: 1.5),
                        ),
                        labelStyle: const TextStyle(
                            color: AppColors.textHint, fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                      ),
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 13),
                      keyboardType: TextInputType.url,
                      onChanged: (v) => setState(() => _bannerPreviewError = false),
                    ),
                    const SizedBox(height: 12),

                    // -- Status ativo/inativo ------------------------------
                    const Text('Status do Produto',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // Botão Ativo
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _ativo = true),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14, horizontal: 8),
                              decoration: BoxDecoration(
                                color: _ativo
                                    ? AppColors.success.withValues(alpha: 0.12)
                                    : AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _ativo
                                      ? AppColors.success
                                      : AppColors.cardBorder,
                                  width: _ativo ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: _ativo
                                        ? AppColors.success
                                        : AppColors.textHint,
                                    size: 26,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Ativo',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _ativo
                                          ? AppColors.success
                                          : AppColors.textHint,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Visível p/ afiliados',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _ativo
                                          ? AppColors.success.withValues(alpha: 0.8)
                                          : AppColors.textHint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Botão Inativo
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _ativo = false),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14, horizontal: 8),
                              decoration: BoxDecoration(
                                color: !_ativo
                                    ? AppColors.error.withValues(alpha: 0.1)
                                    : AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: !_ativo
                                      ? AppColors.error
                                      : AppColors.cardBorder,
                                  width: !_ativo ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.cancel_rounded,
                                    color: !_ativo
                                        ? AppColors.error
                                        : AppColors.textHint,
                                    size: 26,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Inativo',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: !_ativo
                                          ? AppColors.error
                                          : AppColors.textHint,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Oculto p/ afiliados',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: !_ativo
                                          ? AppColors.error.withValues(alpha: 0.8)
                                          : AppColors.textHint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // -- Documentos obrigatórios ----------------------------
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.folder_copy_rounded,
                                  color: AppColors.primary, size: 18),
                              const SizedBox(width: 8),
                              const Text(
                                'Documentos Obrigatórios',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'O comprador deve enviar estes documentos antes de pagar',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textHint),
                          ),
                          const SizedBox(height: 12),
                          ..._docOpts.map((opt) {
                            final key = opt.$1;
                            final label = opt.$2;
                            final icon = opt.$3;
                            final checked = _docsRequired.contains(key);
                            return InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => setState(() {
                                if (checked) {
                                  _docsRequired.remove(key);
                                } else {
                                  _docsRequired.add(key);
                                }
                              }),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 6, horizontal: 2),
                                child: Row(
                                  children: [
                                    AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 180),
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: checked
                                            ? AppColors.primary
                                            : Colors.transparent,
                                        borderRadius:
                                            BorderRadius.circular(5),
                                        border: Border.all(
                                          color: checked
                                              ? AppColors.primary
                                              : AppColors.textHint,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: checked
                                          ? const Icon(Icons.check_rounded,
                                              size: 15,
                                              color: Colors.white)
                                          : null,
                                    ),
                                    const SizedBox(width: 10),
                                    Icon(icon,
                                        size: 17,
                                        color: checked
                                            ? AppColors.primary
                                            : AppColors.textHint),
                                    const SizedBox(width: 8),
                                    Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: checked
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: checked
                                            ? AppColors.textPrimary
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          if (_docsRequired.isEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Nenhum documento exigido — compra direta',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textHint,
                                  fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Campos personalizados (texto livre) ──────────────
                    _CustomFieldsEditor(
                      fields: _customFields,
                      onChanged: (updated) =>
                          setState(() => _customFields = updated),
                    ),
                    const SizedBox(height: 20),

                    // -- Status ativo/inativo (mantido) ----------------------
                    const SizedBox(height: 0), // espaçamento já dado acima

                    const SizedBox(height: 24),

                    // Botão salvar
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save_rounded),
                        label: Text(
                            isNew ? 'Criar Produto' : 'Salvar Alterações'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -- Widgets auxiliares --------------------------------------------------------

// ── Editor de campos personalizados ───────────────────────────────────────────
class _CustomFieldsEditor extends StatefulWidget {
  final List<CustomField> fields;
  final ValueChanged<List<CustomField>> onChanged;

  const _CustomFieldsEditor({
    required this.fields,
    required this.onChanged,
  });

  @override
  State<_CustomFieldsEditor> createState() => _CustomFieldsEditorState();
}

class _CustomFieldsEditorState extends State<_CustomFieldsEditor> {
  final _labelCtrl = TextEditingController();
  bool _showInput = false;

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  String _slugify(String label) {
    return label
        .toLowerCase()
        .replaceAll(RegExp(r'[áàãâä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòõôö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  void _add() {
    final label = _labelCtrl.text.trim();
    if (label.isEmpty) return;
    final key = '${_slugify(label)}_${DateTime.now().millisecondsSinceEpoch % 100000}';
    final exists = widget.fields
        .any((f) => f.label.toLowerCase() == label.toLowerCase());
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Já existe um campo com este nome.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final newField = CustomField(key: key, label: label, enabled: true);
    widget.onChanged([...widget.fields, newField]);
    _labelCtrl.clear();
    setState(() => _showInput = false);
  }

  void _toggle(int index, bool value) {
    final updated = widget.fields.toList();
    updated[index] = updated[index].copyWith(enabled: value);
    widget.onChanged(updated);
  }

  void _delete(int index) {
    final updated = widget.fields.toList()..removeAt(index);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final enabledCount = widget.fields.where((f) => f.enabled).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabeçalho ────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.edit_note_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Campos Personalizados',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textPrimary),
                ),
              ),
              if (enabledCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$enabledCount ativo${enabledCount > 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'O comprador deve preencher estes campos antes de pagar',
            style: TextStyle(fontSize: 11, color: AppColors.textHint),
          ),
          const SizedBox(height: 14),

          // ── Lista de campos (checkbox style) ─────────────────────────
          if (widget.fields.isNotEmpty)
            ...widget.fields.asMap().entries.map((e) {
              final i = e.key;
              final f = e.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: f.enabled
                      ? AppColors.primary.withValues(alpha: 0.06)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: f.enabled
                        ? AppColors.primary.withValues(alpha: 0.25)
                        : AppColors.cardBorder,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Transform.scale(
                      scale: 1.1,
                      child: Checkbox(
                        value: f.enabled,
                        onChanged: (v) => _toggle(i, v ?? false),
                        activeColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    Icon(Icons.text_fields_rounded,
                        size: 16,
                        color: f.enabled
                            ? AppColors.primary
                            : AppColors.textHint),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _toggle(i, !f.enabled),
                        child: Text(
                          f.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: f.enabled
                                ? AppColors.textPrimary
                                : AppColors.textHint,
                            decoration: f.enabled
                                ? null
                                : TextDecoration.lineThrough,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _delete(i),
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 17, color: AppColors.textHint),
                      tooltip: 'Excluir campo',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 36, minHeight: 36),
                    ),
                  ],
                ),
              );
            }),

          // ── Adicionar novo campo ──────────────────────────────────────
          if (_showInput) ...[
            if (widget.fields.isNotEmpty) const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _labelCtrl,
                    autofocus: true,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Ex: Ano da moto, IMEI do celular...',
                      hintStyle: TextStyle(
                          color: AppColors.textHint, fontSize: 12),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                              color: AppColors.cardBorder, width: 1)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                              color: AppColors.primary, width: 1.5)),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _add,
                  child: Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    _labelCtrl.clear();
                    setState(() => _showInput = false);
                  },
                  child: Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.close_rounded,
                        color: AppColors.textSecondary, size: 20),
                  ),
                ),
              ],
            ),
          ] else ...[
            if (widget.fields.isNotEmpty) const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _showInput = true),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Adicionar campo personalizado',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.fields.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Nenhum campo personalizado — compra direta',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ChargeBadge extends StatelessWidget {
  final ProductModel product;
  const _ChargeBadge({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: product.chargeTypeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: product.chargeTypeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(product.chargeTypeIcon,
              color: product.chargeTypeColor, size: 11),
          const SizedBox(width: 3),
          Text(
            product.chargeTypeLabel,
            style: TextStyle(
                color: product.chargeTypeColor,
                fontSize: 10,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ChipStat extends StatelessWidget {
  final String label;
  final Color color;
  const _ChipStat({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final String? hint;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
      ),
    );
  }
}

// -- Opção visual de tipo de Pix ------------------------------------------------
class _PixTypeOption extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _PixTypeOption({
    required this.selected,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : AppColors.cardBorder,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            // Ícone
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: 0.14)
                    : AppColors.cardBorder.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: selected ? color : AppColors.textHint,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            // Texto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: selected ? color : AppColors.textPrimary,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            // Radio
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? color : AppColors.cardBorder,
                  width: 2,
                ),
                color: selected ? color : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 13)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
