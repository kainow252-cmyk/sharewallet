import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/product_service.dart';
import '../../services/auth_service.dart';
import '../../models/product_model.dart';
import '../../theme/app_theme.dart';
import '../dashboard/main_nav_screen.dart';

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

    // PopScope: intercepta botão Voltar do sistema (Android/iOS) quando esta
    // tela está dentro do MainNavScreen (IndexedStack). Sem isso, Navigator.pop()
    // destrói o MainNavScreen inteiro e cai na tela de login.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          // Volta para a aba Home (índice 0) em vez de sair do app
          MainNavController().goHome();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          automaticallyImplyLeading: false,
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
                // -- Filtro chips - Categoria -----------------------------
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      // -- Filtro chips - Tipo de Cobrança ------------------
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

                // -- Banner info ------------------------------------------
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
                            '100% Pix  -  Recorrente (autoriza 1x, débito automático)'
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

                // -- Lista por categoria ou filtrada ----------------------
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
      ),
    );
  }

  // -- Controle de seções abertas/fechadas
  final Set<String> _expandedCategories = {};

  // -- Seções por categoria — design profissional agrupado --------------------
  List<Widget> _buildCategorySections(
      ProductService ps, List<ProductModel> baseList) {
    final Map<String, List<ProductModel>> grouped = {};
    for (final p in baseList) {
      grouped.putIfAbsent(p.categoria, () => []).add(p);
    }

    final catOrder = ['seguros', 'capitalizacao', 'assistencia', 'beneficios', 'cursos'];
    final orderedKeys = [
      ...catOrder.where((k) => grouped.containsKey(k)),
      ...grouped.keys.where((k) => !catOrder.contains(k)),
    ];

    // Inicializa todas expandidas na primeira renderização
    if (_expandedCategories.isEmpty && orderedKeys.isNotEmpty) {
      _expandedCategories.addAll(orderedKeys);
    }

    final widgets = <Widget>[];

    for (final cat in orderedKeys) {
      final products = grouped[cat]!;
      final label = ProductService.categoryLabels[cat] ?? _capitalizeFirst(cat);
      final iconData = _catIconData(cat);
      final color = _catColor(cat);
      final isExpanded = _expandedCategories.contains(cat);

      final avgComissao = products.isEmpty
          ? 0
          : (products.map((p) => p.comissaoPercent).reduce((a, b) => a + b) /
                  products.length)
              .round();

      // Se TODOS os produtos da categoria têm iconName definido,
      // o ícone já identifica a categoria — não precisamos do header de texto.
      final allHaveIcon = products.every(
          (p) => p.iconName != null && p.iconName!.isNotEmpty);

      // Ícone efetivo para o header compacto: usa o iconName do primeiro produto
      // (todos têm o mesmo quando allHaveIcon=true), com fallback para categoria.
      final compactIconData = allHaveIcon
          ? (ProductIconHelper.fromName(products.first.iconName) ?? iconData)
          : iconData;

      // Cada categoria = um card unificado (header + produtos internos)
      widgets.add(
        SliverToBoxAdapter(
          child: _CategorySection(
            cat: cat,
            iconData: compactIconData,
            label: label,
            color: color,
            count: products.length,
            comissao: avgComissao,
            products: products,
            isExpanded: isExpanded,
            hideHeader: allHaveIcon,
            onToggle: () => setState(() {
              if (isExpanded) {
                _expandedCategories.remove(cat);
              } else {
                _expandedCategories.add(cat);
              }
            }),
          ),
        ),
      );
    }

    widgets.add(const SliverToBoxAdapter(child: SizedBox(height: 80)));
    return widgets;
  }

  String _capitalizeFirst(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // -- Drawer de categoria (menu hamburguer) — chips visuais + busca ----------
  void _showCategoryDrawer(BuildContext context, ProductService ps) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CategoryDrawerSheet(ps: ps),
    );
  }

  IconData _catIconData(String cat) {
    switch (cat.toLowerCase()) {
      case 'seguros':        return Icons.security_rounded;
      case 'capitalizacao':  return Icons.savings_rounded;
      case 'assistencia':    return Icons.handshake_rounded;
      case 'beneficios':     return Icons.card_giftcard_rounded;
      case 'cursos':         return Icons.school_rounded;
      case 'entretenimento': return Icons.movie_rounded;
      case 'garantias':      return Icons.verified_user_rounded;
      case 'todos':          return Icons.apps_rounded;
      default:               return Icons.label_rounded;
    }
  }

  Color _catColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'seguros':        return const Color(0xFF1565C0);
      case 'capitalizacao':  return const Color(0xFF6A1B9A);
      case 'assistencia':    return const Color(0xFF00695C);
      case 'beneficios':     return const Color(0xFFE65100);
      case 'cursos':         return const Color(0xFF2E7D32);
      case 'entretenimento': return const Color(0xFFAD1457);
      case 'garantias':      return const Color(0xFF00838F);
      default:               return AppColors.primary;
    }
  }
}

// -- Bottom sheet de filtro por categoria — chips visuais + busca --------------
class _CategoryDrawerSheet extends StatefulWidget {
  final ProductService ps;
  const _CategoryDrawerSheet({required this.ps});

  @override
  State<_CategoryDrawerSheet> createState() => _CategoryDrawerSheetState();
}

class _CategoryDrawerSheetState extends State<_CategoryDrawerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Helpers replicados localmente para evitar acesso à classe pai
  static IconData _icon(String cat) {
    switch (cat.toLowerCase()) {
      case 'seguros':        return Icons.security_rounded;
      case 'capitalizacao':  return Icons.savings_rounded;
      case 'assistencia':    return Icons.handshake_rounded;
      case 'beneficios':     return Icons.card_giftcard_rounded;
      case 'cursos':         return Icons.school_rounded;
      case 'entretenimento': return Icons.movie_rounded;
      case 'garantias':      return Icons.verified_user_rounded;
      case 'todos':          return Icons.apps_rounded;
      default:               return Icons.label_rounded;
    }
  }

  static Color _color(String cat) {
    switch (cat.toLowerCase()) {
      case 'seguros':        return const Color(0xFF1565C0);
      case 'capitalizacao':  return const Color(0xFF6A1B9A);
      case 'assistencia':    return const Color(0xFF00695C);
      case 'beneficios':     return const Color(0xFFE65100);
      case 'cursos':         return const Color(0xFF2E7D32);
      case 'entretenimento': return const Color(0xFFAD1457);
      case 'garantias':      return const Color(0xFF00838F);
      default:               return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ps = widget.ps;

    // Filtra categorias pelo texto de busca (excluindo 'todos' da lista filtrada)
    final allCats = ps.categories.where((c) => c != 'todos').toList();
    final filtered = _query.isEmpty
        ? allCats
        : allCats.where((c) {
            final label =
                ProductService.categoryLabels[c] ?? c;
            return label.toLowerCase().contains(_query.toLowerCase());
          }).toList();

    return Padding(
      // Sobe o sheet quando teclado abre
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle ─────────────────────────────────────────────────────
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Título ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Categorias',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: AppColors.textPrimary)),
                        Text('Toque para filtrar produtos',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                  // Botão Limpar filtro
                  if (ps.selectedCategory != 'todos')
                    TextButton.icon(
                      onPressed: () {
                        ps.setCategory('todos');
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.close_rounded,
                          size: 14, color: AppColors.error),
                      label: const Text('Limpar',
                          style: TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Campo de busca ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchCtrl,
                autofocus: false,
                textInputAction: TextInputAction.search,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Buscar categoria...',
                  hintStyle: const TextStyle(
                      color: AppColors.textHint, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.textHint, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded,
                              size: 18, color: AppColors.textHint),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: AppColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: AppColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Chip "Todos" sempre visível ─────────────────────────────────
            if (_query.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildChip(
                  context: context,
                  ps: ps,
                  cat: 'todos',
                  label: 'Todos os produtos',
                  count: ps.products.length,
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20),
                child: Divider(
                    height: 1, color: AppColors.cardBorder),
              ),
              const SizedBox(height: 10),
            ],

            // ── Grid de chips de categoria ──────────────────────────────────
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.search_off_rounded,
                        color: AppColors.textHint, size: 20),
                    const SizedBox(width: 8),
                    Text('Nenhuma categoria encontrada para "$_query"',
                        style: const TextStyle(
                            color: AppColors.textHint,
                            fontSize: 13)),
                  ],
                ),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: filtered.map((cat) {
                      final label =
                          ProductService.categoryLabels[cat] ?? cat;
                      final count = ps.products
                          .where((p) => p.categoria == cat)
                          .length;
                      return _buildChip(
                        context: context,
                        ps: ps,
                        cat: cat,
                        label: label,
                        count: count,
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required BuildContext context,
    required ProductService ps,
    required String cat,
    required String label,
    required int count,
  }) {
    final color = _color(cat);
    final icon = _icon(cat);
    final isSelected = cat == ps.selectedCategory;

    return GestureDetector(
      onTap: () {
        ps.setCategory(cat);
        Navigator.pop(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? color
                : AppColors.cardBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.30),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : color,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected
                    ? FontWeight.w800
                    : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -- Barra de filtro por tipo de cobrança --------------------------------------
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
    {'key': 'todos',  'label': 'Todos',  'icon': Icons.apps_rounded},
    {'key': 'mensal', 'label': 'Mensal', 'icon': Icons.autorenew_rounded},
    {'key': 'unico',  'label': 'Único',  'icon': Icons.qr_code_2_rounded},
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
          final icon   = item['icon'] as IconData;
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
                    Icon(
                      icon,
                      size: 18,
                      color: isSel ? Colors.white : chipColor,
                    ),
                    const SizedBox(height: 3),
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

// -- Seção de categoria — card unificado profissional -------------------------
// Header + produtos internos agrupados em um único container
class _CategorySection extends StatelessWidget {
  final String cat;
  final IconData iconData;
  final String label;
  final Color color;
  final int count;
  final int comissao;
  final List<ProductModel> products;
  final bool isExpanded;
  final bool hideHeader; // true quando todos os produtos têm iconName
  final VoidCallback onToggle;

  const _CategorySection({
    required this.cat,
    required this.iconData,
    required this.label,
    required this.color,
    required this.count,
    required this.comissao,
    required this.products,
    required this.isExpanded,
    required this.onToggle,
    this.hideHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isExpanded
              ? color.withValues(alpha: 0.30)
              : color.withValues(alpha: 0.14),
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isExpanded ? 0.07 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Column(
          children: [
            // ── Header da categoria ──────────────────────────────────────
            // Quando hideHeader=true, exibe apenas uma barra compacta com
            // ícone+seta (sem nome — o ícone já identifica a categoria)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onToggle,
                splashColor: color.withValues(alpha: 0.08),
                highlightColor: color.withValues(alpha: 0.04),
                child: Container(
                  padding: hideHeader
                      ? const EdgeInsets.fromLTRB(14, 10, 12, 10)
                      : const EdgeInsets.fromLTRB(14, 13, 12, 13),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: isExpanded ? 0.09 : 0.05),
                        color.withValues(alpha: isExpanded ? 0.04 : 0.02),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: hideHeader
                      // ── Modo compacto: apenas ícone + contador + seta ──
                      ? Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.30),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(iconData,
                                  color: Colors.white, size: 17),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Spacer(),
                            AnimatedRotation(
                              turns: isExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 250),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.10),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: color,
                                  size: 15,
                                ),
                              ),
                            ),
                          ],
                        )
                      // ── Modo completo: ícone + nome + badges + seta ──
                      : Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(11),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Icon(iconData,
                                  color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    label,
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Row(
                                    children: [
                                      Container(
                                        width: 5,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.5),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        '$count produto${count != 1 ? 's' : ''}',
                                        style: TextStyle(
                                          color: AppColors.textHint,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.success
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                            color: AppColors.success
                                                .withValues(alpha: 0.25),
                                          ),
                                        ),
                                        child: Text(
                                          '$comissao% comissão',
                                          style: const TextStyle(
                                            color: AppColors.success,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            AnimatedRotation(
                              turns: isExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 250),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.10),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: color,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),

            // ── Produtos (animação de expansão suave) ────────────────────
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 260),
              crossFadeState: isExpanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Column(
                children: [
                  // Divisor com cor da categoria
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withValues(alpha: 0.0),
                          color.withValues(alpha: 0.25),
                          color.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                  // Lista de produtos
                  ...products.asMap().entries.map((e) {
                    final i = e.key;
                    final p = e.value;
                    final isLast = i == products.length - 1;
                    return Column(
                      children: [
                        _ProductCardInline(
                          product: p,
                          accentColor: color,
                          isLast: isLast,
                        ),
                        if (!isLast)
                          Divider(
                            height: 1,
                            indent: 56,
                            endIndent: 14,
                            color: AppColors.cardBorder
                                .withValues(alpha: 0.6),
                          ),
                      ],
                    );
                  }),
                  const SizedBox(height: 4),
                ],
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// -- Card de produto INLINE (dentro do card da categoria) ---------------------
// Design profissional: sem borda própria, usa o container da categoria
class _ProductCardInline extends StatelessWidget {
  final ProductModel product;
  final Color accentColor;
  final bool isLast;
  const _ProductCardInline({
    required this.product,
    required this.accentColor,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final p = product;
    final auth = context.read<AuthService>();
    // Usa @username no link se disponível (bonito e memorável): ?ref=@gelci
    // O Worker resolve tanto username quanto affiliate_code → afiliado correto.
    // Fallback: affiliate_code (ex: LHH5ZO) garante rastreio mesmo sem username.
    final user = auth.currentUser;
    final affiliateRef = (user?.username.isNotEmpty == true)
        ? '@${user!.username}'
        : (user?.affiliateCode.isNotEmpty == true ? user!.affiliateCode : 'REF');
    final affiliateCode = affiliateRef;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding:
            const EdgeInsets.only(left: 14, right: 12, top: 4, bottom: 4),
        childrenPadding:
            const EdgeInsets.fromLTRB(14, 0, 14, 14),
        iconColor: AppColors.textHint,
        collapsedIconColor: AppColors.textHint,
        // ── Linha resumo compacta ──────────────────────────────────────────
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accentColor.withValues(alpha: 0.20)),
          ),
          child: Center(
            child: Icon(
              ProductIconHelper.fromName(p.iconName) ??
                  _CategoryIconAvatar._icon(p.categoria),
              color: accentColor,
              size: 18,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                p.nome,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            // Badge tipo Pix
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: p.chargeTypeColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: p.chargeTypeColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(p.chargeTypeIcon,
                      color: p.chargeTypeColor, size: 10),
                  const SizedBox(width: 3),
                  Text(
                    p.chargeTypeLabel,
                    style: TextStyle(
                        color: p.chargeTypeColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Row(
            children: [
              Text(
                p.valorFormatado,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
              ),
              if (p.periodicidade != null)
                Text(
                  '/${p.periodicidade}',
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textHint),
                ),
              const SizedBox(width: 8),
              // Badge comissão
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  gradient: AppColors.greenGradient,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${p.comissaoPercent}% · ${p.comissaoFormatada}${p.recorrente ? "/mês" : ""}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        // ── Conteúdo expandido ─────────────────────────────────────────────
        children: [
          const SizedBox(height: 8),
          if (p.descricao.isNotEmpty)
            Text(
              p.descricao,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.5),
            ),
          if (p.isPixRecorrente && p.diaCobranca != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 11, color: AppColors.textHint),
              const SizedBox(width: 4),
              Text('Cobrança todo dia ${p.diaCobranca}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textHint)),
            ]),
          ],
          if (p.beneficiosList.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.checklist_rounded,
                  color: AppColors.primary, size: 13),
              const SizedBox(width: 5),
              const Text('O que o cliente recebe',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 6),
            ...p.beneficiosList.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(children: [
                    const Icon(Icons.check_circle_outline_rounded,
                        color: AppColors.success, size: 12),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(b,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary))),
                  ]),
                )),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () =>
                  _showShareSheet(context, p, affiliateCode),
              icon: const Icon(Icons.share_rounded,
                  size: 14, color: Colors.white),
              label: const Text('Divulgar produto',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showShareSheet(
      BuildContext context, ProductModel product, String affiliateCode) {
    final link =
        'https://payment.sharewallet.com.br/app/#/produto/${product.id}?ref=$affiliateCode';
    final isRecorrente = product.isPixRecorrente;
    final comissaoLabel = isRecorrente
        ? 'Comissão: ${product.comissaoFormatada}/mês · ${product.comissaoPercent}%'
        : 'Comissão por venda: ${product.comissaoFormatada} · ${product.comissaoPercent}%';
    final instrucaoText = isRecorrente
        ? 'Envie este link para seu cliente. Ele preenche os dados e autoriza o débito automático mensal via PIX.'
        : 'Envie este link para seu cliente. Ele preenche os dados e gera o PIX para pagamento único.';

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
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    gradient: AppColors.greenGradient,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.share_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Divulgar produto',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppColors.textPrimary)),
                    Text(
                      isRecorrente
                          ? 'Assinatura mensal  -  débito automático PIX'
                          : 'Pagamento único  -  QR Code PIX',
                      style: TextStyle(
                          fontSize: 12,
                          color: product.chargeTypeColor,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.monetization_on_rounded,
                    color: AppColors.success, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.nome,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.textPrimary)),
                      Text(comissaoLabel,
                          style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(children: [
                const Icon(Icons.link_rounded,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(link,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.primary),
                        overflow: TextOverflow.ellipsis)),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: link));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content:
                            Text('Link copiado! Compartilhe com seu cliente.'),
                        backgroundColor: AppColors.success));
                  },
                  icon: const Icon(Icons.copy_rounded,
                      color: AppColors.primary, size: 18),
                ),
              ]),
            ),
            const SizedBox(height: 8),
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
              child: Text(instrucaoText,
                  style: TextStyle(
                      fontSize: 12,
                      color: isRecorrente
                          ? AppColors.primary
                          : const Color(0xFF6D4C00),
                      height: 1.5)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: link));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Link copiado!'),
                      backgroundColor: AppColors.success));
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                icon: const Icon(Icons.copy_all_rounded, color: Colors.white),
                label: const Text('Copiar link de divulgação',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -- Card de produto (ExpansionTile compacto) — mantido para modo filtrado ----
class _ProductCard extends StatelessWidget {
  final ProductModel product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final p = product;
    final auth = context.read<AuthService>();
    // Usa @username no link se disponível: ?ref=@gelci
    // Worker resolve username → affiliate_code → afiliado correto.
    final user2 = auth.currentUser;
    final affiliateCode = (user2?.username.isNotEmpty == true)
        ? '@${user2!.username}'
        : (user2?.affiliateCode.isNotEmpty == true ? user2!.affiliateCode : 'REF');

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: p.isPixRecorrente
                ? AppColors.primary.withValues(alpha: 0.3)
                : AppColors.cardBorder,
            width: p.isPixRecorrente ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          iconColor: AppColors.textHint,
          collapsedIconColor: AppColors.textHint,
          // ── Linha resumo ────────────────────────────────────────────────────
          leading: _CategoryIconAvatarSmall(
              categoria: p.categoria, iconName: p.iconName),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  p.nome,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              _ChargeBadge(product: p),
            ],
          ),
          subtitle: Row(
            children: [
              Text(
                p.valorFormatado,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
              ),
              if (p.periodicidade != null)
                Text(
                  '/${p.periodicidade}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textHint),
                ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  gradient: AppColors.greenGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${p.comissaoPercent}% · ${p.comissaoFormatada}${p.recorrente ? "/mês" : ""}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          // ── Conteúdo expandido ───────────────────────────────────────────────
          children: [
            const Divider(color: AppColors.cardBorder, height: 1),
            const SizedBox(height: 10),

            // Descrição
            Text(
              p.descricao,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.5),
            ),

            // Dia de cobrança
            if (p.isPixRecorrente && p.diaCobranca != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 12, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Text(
                    'Cobrança todo dia ${p.diaCobranca}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textHint),
                  ),
                ],
              ),
            ],

            // Benefícios
            if (p.beneficiosList.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.checklist_rounded,
                      color: AppColors.primary, size: 13),
                  const SizedBox(width: 5),
                  const Text(
                    'O que o cliente recebe',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...p.beneficiosList.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded,
                            color: AppColors.success, size: 13),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(b,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ),
                      ],
                    ),
                  )),
            ],

            const SizedBox(height: 10),
            // Botão Divulgar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    _showShareSheet(context, p, affiliateCode),
                icon: const Icon(Icons.share_rounded,
                    size: 15, color: Colors.white),
                label: const Text(
                  'Divulgar produto',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -- Bottom sheet: compartilhar link rastreável ---------------------------
  void _showShareSheet(
      BuildContext context, ProductModel product, String affiliateCode) {
    final link =
        'https://payment.sharewallet.com.br/app/#/produto/${product.id}?ref=$affiliateCode';

    // Textos específicos por tipo de produto
    final isRecorrente = product.isPixRecorrente;
    final comissaoLabel = isRecorrente
        ? 'Comissão: ${product.comissaoFormatada}/mês * ${product.comissaoPercent}%'
        : 'Comissão por venda: ${product.comissaoFormatada} * ${product.comissaoPercent}%';
    final instrucaoText = isRecorrente
        ? 'Envie este link para seu cliente. Ele preenche os dados e autoriza o débito automático mensal via PIX.'
        : 'Envie este link para seu cliente. Ele preenche os dados e gera o PIX para pagamento único.';

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
                            ? 'Assinatura mensal  -  débito automático PIX'
                            : 'Pagamento único  -  QR Code PIX',
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
                            content: Text('Link copiado! Compartilhe com seu cliente.'),
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
                        content: Text('Link copiado!'),
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

// -- Avatar de ícone da categoria no card de produto (versão compacta 38px) ----
class _CategoryIconAvatarSmall extends StatelessWidget {
  final String categoria;
  final String? iconName; // ícone personalizado do produto (sobrepõe categoria)
  const _CategoryIconAvatarSmall({required this.categoria, this.iconName});

  @override
  Widget build(BuildContext context) {
    final color = _CategoryIconAvatar._color(categoria);
    // Usa iconName personalizado se existir, senão usa ícone da categoria
    final icon = ProductIconHelper.fromName(iconName) ?? _CategoryIconAvatar._icon(categoria);
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Center(child: Icon(icon, color: color, size: 20)),
    );
  }
}

// -- Avatar de ícone da categoria no card de produto ---------------------------
class _CategoryIconAvatar extends StatelessWidget {
  final String categoria;
  const _CategoryIconAvatar({required this.categoria});

  static IconData _icon(String cat) {
    switch (cat.toLowerCase()) {
      case 'seguros':        return Icons.security_rounded;
      case 'capitalizacao':  return Icons.savings_rounded;
      case 'assistencia':    return Icons.handshake_rounded;
      case 'beneficios':     return Icons.card_giftcard_rounded;
      case 'cursos':         return Icons.school_rounded;
      case 'entretenimento': return Icons.movie_rounded;
      case 'garantias':      return Icons.verified_user_rounded;
      default:               return Icons.label_rounded;
    }
  }

  static Color _color(String cat) {
    switch (cat.toLowerCase()) {
      case 'seguros':        return const Color(0xFF1565C0);
      case 'capitalizacao':  return const Color(0xFF6A1B9A);
      case 'assistencia':    return const Color(0xFF00695C);
      case 'beneficios':     return const Color(0xFFE65100);
      case 'cursos':         return const Color(0xFF2E7D32);
      case 'entretenimento': return const Color(0xFFAD1457);
      case 'garantias':      return const Color(0xFF00838F);
      default:               return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(categoria);
    final icon  = _icon(categoria);
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Center(
        child: Icon(icon, color: color, size: 26),
      ),
    );
  }
}

// -- Badge tipo de cobrança -----------------------------------------------------
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
