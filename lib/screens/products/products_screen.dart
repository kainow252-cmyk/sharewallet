import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/product_service.dart';
import '../../services/auth_service.dart';
import '../../models/product_model.dart';
import '../../theme/app_theme.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  // Filtro de tipo de cobrança: 'todos' | 'mensal' | 'unico'
  String _chargeFilter = 'todos';

  List<ProductModel> _applyChargeFilter(List<ProductModel> products) {
    switch (_chargeFilter) {
      case 'mensal':
        return products.where((p) => p.isPixRecorrente).toList();
      case 'unico':
        return products.where((p) => p.isPixAvulso).toList();
      default:
        return products;
    }
  }
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // forceRefresh: true garante que produto novo criado no admin apareça aqui
      context.read<ProductService>().loadProducts(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ps = context.watch<ProductService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Produtos'),
            const SizedBox(width: 8),
            if (!ps.isLoading && ps.products.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_applyChargeFilter(ps.filteredProducts).length}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        actions: [
          // Menu hamburguer de categorias
          Builder(
            builder: (ctx) => IconButton(
              onPressed: () => _showCategoryDrawer(ctx, ps),
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.menu_rounded),
                  if (ps.selectedCategory != 'todos')
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              tooltip: 'Filtrar por categoria',
            ),
          ),
        ],
      ),
      body: ps.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => ps.loadProducts(forceRefresh: true),
              child: CustomScrollView(
              slivers: [
                // ── Filtro chips — Categoria ─────────────────────────────
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      Container(
                        height: 56,
                        color: AppColors.surface,
                        padding: const EdgeInsets.only(top: 4),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          itemCount: ps.categories.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 8),
                          itemBuilder: (ctx, i) {
                            final cat = ps.categories[i];
                            final isSelected = cat == ps.selectedCategory;
                            final label =
                                ProductService.categoryLabels[cat] ?? cat;
                            final icon = _catIcon(cat);
                            return GestureDetector(
                              onTap: () => ps.setCategory(cat),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.cardBorder,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(icon,
                                        style:
                                            const TextStyle(fontSize: 13)),
                                    const SizedBox(width: 5),
                                    Text(
                                      label,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.textSecondary,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // ── Filtro chips — Tipo de Cobrança ──────────────────
                      _ChargeFilterBar(
                        selected: _chargeFilter,
                        onSelect: (v) => setState(() => _chargeFilter = v),
                        counts: {
                          'todos': ps.filteredProducts.length,
                          'mensal': ps.filteredProducts
                              .where((p) => p.isPixRecorrente)
                              .length,
                          'unico': ps.filteredProducts
                              .where((p) => p.isPixAvulso)
                              .length,
                        },
                      ),

                      const Divider(height: 1),
                    ],
                  ),
                ),

                // ── Banner info ──────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF083D29), Color(0xFF0D5C3D)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.pix_rounded,
                            color: Colors.white70, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '100% Pix — Recorrente (autoriza 1x, débito automático) '
                            'ou Único (QR Code a cada cobrança).',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Lista por categoria ou filtrada ──────────────────────
                if (ps.selectedCategory == 'todos')
                  // Modo "Todos": agrupa por categoria com cabeçalhos
                  ..._buildCategorySections(ps, _applyChargeFilter(ps.products))
                else
                  // Modo filtrado: lista simples
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _ProductCard(
                            product: _applyChargeFilter(
                                ps.filteredProducts)[i]),
                        childCount: _applyChargeFilter(
                            ps.filteredProducts).length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
    );
  }

  // ── Seções por categoria ──────────────────────────────────────────────────
  List<Widget> _buildCategorySections(
      ProductService ps, List<ProductModel> baseList) {
    final Map<String, List<ProductModel>> grouped = {};
    for (final p in baseList) {
      grouped.putIfAbsent(p.categoria, () => []).add(p);
    }

    final widgets = <Widget>[];
    final catOrder = ['seguros', 'capitalizacao', 'assistencia', 'beneficios', 'cursos'];
    final orderedKeys = [
      ...catOrder.where((k) => grouped.containsKey(k)),
      ...grouped.keys.where((k) => !catOrder.contains(k)),
    ];

    for (final cat in orderedKeys) {
      final products = grouped[cat]!;
      final label = ProductService.categoryLabels[cat] ?? cat;
      final icon = _catIcon(cat);
      final color = _catColor(cat);

      widgets.add(
        SliverToBoxAdapter(
          child: _CategoryHeader(
            icon: icon,
            label: label,
            color: color,
            count: products.length,
          ),
        ),
      );
      widgets.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _ProductCard(product: products[i]),
              childCount: products.length,
            ),
          ),
        ),
      );
    }

    // Espaço no final
    widgets.add(const SliverToBoxAdapter(child: SizedBox(height: 80)));
    return widgets;
  }

  // ── Drawer de categoria (menu hamburguer) ────────────────────────────────
  void _showCategoryDrawer(BuildContext context, ProductService ps) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Título
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.category_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Filtrar por Categoria',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppColors.textPrimary)),
                    Text('Selecione uma categoria',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
                const Spacer(),
                if (ps.selectedCategory != 'todos')
                  TextButton(
                    onPressed: () {
                      ps.setCategory('todos');
                      Navigator.pop(context);
                    },
                    child: const Text('Limpar',
                        style: TextStyle(color: AppColors.error, fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            // Lista de categorias
            ...ps.categories.map((cat) {
              final label = ProductService.categoryLabels[cat] ?? cat;
              final icon = _catIcon(cat);
              final color = _catColor(cat);
              final isSelected = cat == ps.selectedCategory;
              final count = cat == 'todos'
                  ? ps.products.length
                  : ps.products.where((p) => p.categoria == cat).length;

              return InkWell(
                onTap: () {
                  ps.setCategory(cat);
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(color: color.withValues(alpha: 0.4))
                        : null,
                  ),
                  child: Row(
                    children: [
                      // Ícone
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(icon, style: const TextStyle(fontSize: 20)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Label
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: isSelected
                                ? color
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      // Contagem
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withValues(alpha: 0.15)
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? color : AppColors.textHint,
                          ),
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.check_circle_rounded,
                            color: color, size: 20),
                      ],
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _catIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'seguros': return '🛡️';
      case 'capitalizacao': return '💰';
      case 'assistencia': return '🔧';
      case 'beneficios': return '🎁';
      case 'cursos': return '📚';
      case 'entretenimento': return '🎯';
      case 'garantias': return '✅';
      case 'todos': return '🏷️';
      default: return '📦';
    }
  }

  Color _catColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'seguros': return const Color(0xFF1565C0);
      case 'capitalizacao': return const Color(0xFF6A1B9A);
      case 'assistencia': return const Color(0xFF00695C);
      case 'beneficios': return const Color(0xFFE65100);
      case 'cursos': return const Color(0xFF2E7D32);
      default: return AppColors.primary;
    }
  }
}

// ── Barra de filtro por tipo de cobrança ──────────────────────────────────────
class _ChargeFilterBar extends StatelessWidget {
  final String selected;
  final void Function(String) onSelect;
  final Map<String, int> counts;

  const _ChargeFilterBar({
    required this.selected,
    required this.onSelect,
    required this.counts,
  });

  static const _items = [
    {'key': 'todos',  'label': 'Todos',  'icon': Icons.apps_rounded,         'emoji': '🏷️'},
    {'key': 'mensal', 'label': 'Mensal', 'icon': Icons.autorenew_rounded,     'emoji': '🔄'},
    {'key': 'unico',  'label': 'Único',  'icon': Icons.qr_code_2_rounded,     'emoji': '⚡'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: _items.map((item) {
          final key    = item['key'] as String;
          final label  = item['label'] as String;
          final emoji  = item['emoji'] as String;
          final count  = counts[key] ?? 0;
          final isSel  = selected == key;

          // Cor por tipo
          Color chipColor;
          switch (key) {
            case 'mensal': chipColor = AppColors.primary; break;
            case 'unico':  chipColor = const Color(0xFFE65100); break;
            default:       chipColor = AppColors.textSecondary; break;
          }

          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSel
                      ? chipColor
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSel
                        ? chipColor
                        : AppColors.cardBorder,
                    width: isSel ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        color: isSel ? Colors.white : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight:
                            isSel ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSel
                            ? Colors.white.withValues(alpha: 0.25)
                            : AppColors.cardBorder,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: isSel
                              ? Colors.white
                              : AppColors.textHint,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Cabeçalho de categoria ────────────────────────────────────────────────────

class _CategoryHeader extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;
  final int count;

  const _CategoryHeader({
    required this.icon,
    required this.label,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Ícone categoria
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          // Label + contagem
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  '$count produto${count > 1 ? 's' : ''} disponíve${count > 1 ? 'is' : 'l'}',
                  style: TextStyle(
                    color: color.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Badge comissão
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: const Text(
              '20% comissão',
              style: TextStyle(
                color: AppColors.success,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card de produto ────────────────────────────────────────────────────────────

class _ProductCard extends StatefulWidget {
  final ProductModel product;
  const _ProductCard({required this.product});

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final auth = context.read<AuthService>();
    final affiliateCode = auth.currentUser?.affiliateCode ?? 'ABC123';
    final categoryIcon = ProductService.categoryIcons[product.categoria] ?? '📦';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: product.isPixRecorrente
              ? AppColors.primary.withValues(alpha: 0.25)
              : AppColors.cardBorder,
          width: product.isPixRecorrente ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ícone categoria
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(categoryIcon,
                        style: const TextStyle(fontSize: 28)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nome + badge tipo de cobrança
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              product.nome,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _ChargeBadge(product: product),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.descricao,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Preço + comissão ─────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Valor
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Valor',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textHint)),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            product.valorFormatado,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (product.periodicidade != null)
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 3, bottom: 3),
                              child: Text(
                                '/${product.periodicidade}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textHint),
                              ),
                            ),
                        ],
                      ),
                      if (product.isPixRecorrente && product.diaCobranca != null)
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded,
                                size: 11, color: AppColors.textHint),
                            const SizedBox(width: 3),
                            Text(
                              'Todo dia ${product.diaCobranca}',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textHint),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                // Sua comissão
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: AppColors.greenGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        product.comissaoFormatada,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${product.comissaoPercent}% comissão',
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w500),
                      ),
                      if (product.recorrente)
                        const Text(
                          'por mês',
                          style: TextStyle(
                              color: Colors.white60,
                              fontSize: 10),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Benefícios (expansível) ──────────────────────────────────────────
          if (product.beneficiosList.isNotEmpty) ...[
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.checklist_rounded,
                        color: AppColors.primary, size: 16),
                    const SizedBox(width: 6),
                    const Text(
                      'O que o cliente recebe',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Column(
                  children: product.beneficiosList
                      .map((b) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline_rounded,
                                    color: AppColors.success, size: 14),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(b,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary)),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
          ],

          const Divider(height: 1, indent: 16, endIndent: 16),

          // ── Ações: Divulgar link rastreável ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _showShareSheet(context, product, affiliateCode),
                    icon: const Icon(Icons.share_rounded,
                        size: 16, color: Colors.white),
                    label: const Text(
                      'Divulgar',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
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

  // ── Bottom sheet: compartilhar link rastreável ───────────────────────────
  void _showShareSheet(
      BuildContext context, ProductModel product, String affiliateCode) {
    final link =
        'https://sharewallet.com.br/app/#/produto/${product.id}?ref=$affiliateCode';

    // Textos específicos por tipo de produto
    final isRecorrente = product.isPixRecorrente;
    final comissaoLabel = isRecorrente
        ? 'Comissão: ${product.comissaoFormatada}/mês  •  ${product.comissaoPercent}%'
        : 'Comissão por venda: ${product.comissaoFormatada}  •  ${product.comissaoPercent}%';
    final instrucaoText = isRecorrente
        ? '💡 Envie este link para seu cliente. Ele preenche os dados e autoriza o débito automático mensal via PIX.'
        : '💡 Envie este link para seu cliente. Ele preenche os dados e gera o PIX para pagamento único.';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Cabeçalho
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppColors.greenGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.share_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Divulgar produto',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppColors.textPrimary),
                      ),
                      Text(
                        isRecorrente
                            ? 'Assinatura mensal — débito automático PIX'
                            : 'Pagamento único — QR Code PIX',
                        style: TextStyle(
                            fontSize: 12,
                            color: product.chargeTypeColor,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                // Badge tipo
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: product.chargeTypeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: product.chargeTypeColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(product.chargeTypeIcon, color: product.chargeTypeColor, size: 13),
                      const SizedBox(width: 4),
                      Text(product.chargeTypeLabel,
                          style: TextStyle(
                              fontSize: 10,
                              color: product.chargeTypeColor,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Comissão em destaque
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.monetization_on_rounded,
                      color: AppColors.success, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.nome,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.textPrimary),
                        ),
                        Text(
                          comissaoLabel,
                          style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Box do link
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      link,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.primary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: link));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('✅ Link copiado! Compartilhe com seu cliente.'),
                            backgroundColor: AppColors.success),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded,
                        color: AppColors.primary, size: 18),
                    tooltip: 'Copiar link',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Instrução contextual por tipo
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isRecorrente
                    ? AppColors.primary.withValues(alpha: 0.06)
                    : const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: isRecorrente
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : const Color(0xFFFFCC02).withValues(alpha: 0.5)),
              ),
              child: Text(
                instrucaoText,
                style: TextStyle(
                    fontSize: 12,
                    color: isRecorrente
                        ? AppColors.primary
                        : const Color(0xFF6D4C00),
                    height: 1.5),
              ),
            ),
            const SizedBox(height: 16),

            // Botão copiar link
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: link));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('✅ Link copiado!'),
                        backgroundColor: AppColors.success),
                  );
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                icon: const Icon(Icons.copy_all_rounded,
                    color: Colors.white),
                label: const Text(
                  'Copiar link de divulgação',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Badge tipo de cobrança ─────────────────────────────────────────────────────
class _ChargeBadge extends StatelessWidget {
  final ProductModel product;
  const _ChargeBadge({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: product.chargeTypeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: product.chargeTypeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(product.chargeTypeIcon,
              color: product.chargeTypeColor, size: 11),
          const SizedBox(width: 4),
          Text(
            product.chargeTypeLabel,
            style: TextStyle(
                color: product.chargeTypeColor,
                fontSize: 10,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
