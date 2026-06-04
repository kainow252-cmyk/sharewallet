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
    if (ok == true) await svc.deleteProduct(p.id);
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
    _chargeType = p?.chargeType ?? ChargeType.pixAutomatico;
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
    final diaCobrancaVal = _chargeType != ChargeType.unico
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
          _chargeType == ChargeType.unico ? null : 'mensal',
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
                    // ── Tipo de cobrança ─────────────────────────────────
                    const Text('Tipo de Cobrança',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 10),
                    Row(
                      children: ChargeType.values.map((ct) {
                        final selected = _chargeType == ct;
                        final label = ct == ChargeType.pixAutomatico
                            ? 'Pix Automático'
                            : ct == ChargeType.pixAvulso
                                ? 'Pix Avulso'
                                : 'Pagamento Único';
                        final icon = ct == ChargeType.pixAutomatico
                            ? Icons.autorenew_rounded
                            : ct == ChargeType.pixAvulso
                                ? Icons.pix_rounded
                                : Icons.shopping_bag_rounded;
                        final color = ct == ChargeType.pixAutomatico
                            ? const Color(0xFF0D7A5A)
                            : ct == ChargeType.pixAvulso
                                ? AppColors.info
                                : AppColors.warning;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _chargeType = ct),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 4),
                              decoration: BoxDecoration(
                                color: selected
                                    ? color.withValues(alpha: 0.12)
                                    : AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? color
                                      : AppColors.cardBorder,
                                  width: selected ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(icon,
                                      color: selected
                                          ? color
                                          : AppColors.textHint,
                                      size: 20),
                                  const SizedBox(height: 4),
                                  Text(
                                    label,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.normal,
                                      color: selected
                                          ? color
                                          : AppColors.textHint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
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
                    if (_chargeType != ChargeType.unico) ...[
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

                    // Status ativo
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: SwitchListTile.adaptive(
                        value: _ativo,
                        onChanged: (v) => setState(() => _ativo = v),
                        title: const Text('Produto Ativo',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          _ativo
                              ? 'Visível para afiliados'
                              : 'Oculto para afiliados',
                          style: TextStyle(
                              color: _ativo
                                  ? AppColors.success
                                  : AppColors.error,
                              fontSize: 12),
                        ),
                        activeThumbColor: AppColors.primary,
                        activeTrackColor: AppColors.primaryLight,
                        contentPadding: EdgeInsets.zero,
                      ),
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
