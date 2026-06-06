import 'package:flutter/material.dart';
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
      if (svc.products.isEmpty && !svc.isLoading) {
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
      appBar: AppBar(
        title: const Text('Produtos'),
        actions: [
          // Botão de refresh manual
          if (svc.isLoading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Recarregar produtos',
              onPressed: () => svc.loadProducts(),
            ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Novo produto',
            onPressed: () => _openForm(context, null),
          ),
        ],
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
            child: svc.isLoading
                ? const Center(child: CircularProgressIndicator())
                : produtos.isEmpty
                    ? const Center(child: Text('Nenhum produto encontrado'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: produtos.length,
                        itemBuilder: (ctx, i) => _ProductCard(
                          product: produtos[i],
                          onEdit: () => _openForm(context, produtos[i]),
                          onToggle: () =>
                              svc.toggleProductStatus(produtos[i].id),
                          onDelete: () =>
                              _confirmDelete(context, svc, produtos[i]),
                        ),
                      ),
          ),
        ],
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

// ── Card do produto ───────────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  const _ProductCard(
      {required this.product,
      required this.onEdit,
      required this.onToggle,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: product.ativo
                ? AppColors.cardBorder
                : AppColors.error.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Ícone do tipo
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: product.chargeTypeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(product.chargeTypeIcon,
                      color: product.chargeTypeColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.nome,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          _ChargeBadge(product: product),
                          const SizedBox(width: 6),
                          if (!product.ativo)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('INATIVO',
                                  style: TextStyle(
                                      color: AppColors.error,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Switch ativo
                Switch.adaptive(
                  value: product.ativo,
                  activeThumbColor: AppColors.primary,
                  activeTrackColor: AppColors.primaryLight,
                  onChanged: (_) => onToggle(),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Valores
            Row(
              children: [
                _InfoChip(
                    label: 'Valor',
                    value: fmt.format(product.valor),
                    color: AppColors.primary),
                const SizedBox(width: 8),
                _InfoChip(
                    label: 'Comissão',
                    value: '${product.comissaoPercent}%',
                    color: AppColors.success),
                const SizedBox(width: 8),
                _InfoChip(
                    label: 'Para afiliado',
                    value: fmt.format(product.valorComissao),
                    color: AppColors.gold),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              product.descricao,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (product.diaCobranca != null) ...[
              const SizedBox(height: 6),
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
            ],

            const Divider(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('Editar'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.error),
                  tooltip: 'Excluir',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Formulário de produto ─────────────────────────────────────────────────────
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
  late ChargeType _chargeType;
  late bool _ativo;

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
    _chargeType = p?.chargeType ?? ChargeType.pixRecorrente;
    _ativo = p?.ativo ?? true;
  }

  @override
  void dispose() {
    for (final c in [
      _nome, _descricao, _valor, _comissao, _diaCobranca, _beneficios, _categoria
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
                    // ── Tipo de cobrança Pix ─────────────────────────────
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
                      subtitle: 'Cliente autoriza 1x → débito automático todo mês',
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

                    // ── Campos principais ───────────────────────────────
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

                    // ── Status ativo/inativo ──────────────────────────────
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

// ── Widgets auxiliares ────────────────────────────────────────────────────────
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

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _InfoChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  color: color.withValues(alpha: 0.7), fontSize: 9)),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
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

// ── Opção visual de tipo de Pix ────────────────────────────────────────────────
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
