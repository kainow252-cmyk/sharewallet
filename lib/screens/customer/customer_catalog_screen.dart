// ===========================================================================
// customer_catalog_screen.dart - ShareWallet
// ---------------------------------------------------------------------------
// Catálogo de produtos para o cliente.
// O ref do afiliado indicador (sponsor) é fixo em todos os links de compra.
// ===========================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/customer_service.dart';
import '../../services/product_service.dart';
import '../../models/customer_model.dart';
import '../../models/product_model.dart';
import '../../screens/products/buy_screen.dart';

class CustomerCatalogScreen extends StatefulWidget {
  const CustomerCatalogScreen({super.key});

  @override
  State<CustomerCatalogScreen> createState() => _CustomerCatalogScreenState();
}

class _CustomerCatalogScreenState extends State<CustomerCatalogScreen> {
  String _busca = '';
  String _categoriaFiltro = 'Todos';
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductService>().loadProducts();
    });
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    final productSvc = context.read<ProductService>();
    final customerSvc = context.read<CustomerService>();
    await Future.wait([
      productSvc.loadProducts(),
      customerSvc.refreshProdutos(),
    ]);
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final productSvc = context.watch<ProductService>();
    final customerSvc = context.watch<CustomerService>();
    final customer = customerSvc.currentCustomer;

    // Produtos já comprados pelo cliente (por ID)
    final compradosIds =
        customerSvc.produtos.map((p) => p.productId).toSet();

    // Filtra produtos
    final todos = productSvc.products
        .where((p) => p.ativo)
        .toList();
    final categorias = ['Todos', ...{...todos.map((p) => p.categoria)}
        .where((c) => c.isNotEmpty)];

    final filtrados = todos.where((p) {
      final matchBusca = _busca.isEmpty ||
          p.nome.toLowerCase().contains(_busca.toLowerCase()) ||
          p.descricao.toLowerCase().contains(_busca.toLowerCase());
      final matchCateg = _categoriaFiltro == 'Todos' ||
          p.categoria == _categoriaFiltro;
      return matchBusca && matchCateg;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── AppBar ──────────────────────────────────────────────────
            _buildSliverAppBar(customer),

            // ── Barra de busca ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSearchBar(),
            ),

            // ── Filtro de categorias ─────────────────────────────────────
            if (categorias.length > 1)
              SliverToBoxAdapter(
                child: _buildCategoryFilter(categorias),
              ),

            // ── Contador de resultados ────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  '${filtrados.length} produto${filtrados.length != 1 ? "s" : ""}',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            ),

            // ── Lista de produtos ─────────────────────────────────────────
            if (_refreshing && todos.isEmpty)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
              )
            else if (filtrados.isEmpty)
              SliverToBoxAdapter(child: _buildEmpty())
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final produto = filtrados[i];
                    final jaComprou = compradosIds.contains(produto.id);
                    return _CatalogCard(
                      product: produto,
                      jaComprou: jaComprou,
                      sponsorRef: _getSponsorRef(customer),
                      onComprar: () => _irParaCompra(produto, customer),
                    );
                  },
                  childCount: filtrados.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  // ── Retorna o ref do sponsor (afiliado indicador) ─────────────────────────
  String _getSponsorRef(CustomerModel? customer) {
    if (customer == null) return '';
    // Prioridade: username > affiliateCode > ''
    if (customer.sponsorUsername.isNotEmpty) return customer.sponsorUsername;
    if (customer.sponsorAffiliateCode.isNotEmpty) {
      return customer.sponsorAffiliateCode;
    }
    return '';
  }

  // ── Navega para a tela de compra, mantendo o sponsor fixo ─────────────────
  void _irParaCompra(ProductModel product, CustomerModel? customer) {
    final sponsorRef = _getSponsorRef(customer);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BuyScreen(
          productId: product.id,
          affiliateCode: sponsorRef,
        ),
      ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _buildSliverAppBar(CustomerModel? customer) {
    final sponsorHandle = customer?.sponsorHandle ?? '';

    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.primary,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: const Text(
        'Produtos',
        style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17),
      ),
      bottom: sponsorHandle.isNotEmpty
          ? PreferredSize(
              preferredSize: const Size.fromHeight(28),
              child: Container(
                width: double.infinity,
                color: AppColors.primary.withValues(alpha: 0.8),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Compras vinculadas a $sponsorHandle',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        onChanged: (v) => setState(() => _busca = v),
        decoration: InputDecoration(
          hintText: 'Buscar produto...',
          prefixIcon:
              const Icon(Icons.search_rounded, color: AppColors.textHint),
          suffixIcon: _busca.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: AppColors.textHint),
                  onPressed: () => setState(() => _busca = ''),
                )
              : null,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(List<String> categorias) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: categorias.length,
        itemBuilder: (context, i) {
          final cat = categorias[i];
          final isSelected = _categoriaFiltro == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (_) => setState(() => _categoriaFiltro = cat),
              selectedColor: AppColors.primary.withValues(alpha: 0.15),
              checkmarkColor: AppColors.primary,
              side: BorderSide(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textHint.withValues(alpha: 0.3),
              ),
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded,
              size: 48, color: AppColors.textHint),
          const SizedBox(height: 12),
          const Text(
            'Nenhum produto encontrado',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: AppColors.textPrimary),
          ),
          if (_busca.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Tente buscar por "$_busca" com outros termos.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Widget: Card de produto no catálogo ──────────────────────────────────
class _CatalogCard extends StatelessWidget {
  final ProductModel product;
  final bool jaComprou;
  final String sponsorRef;
  final VoidCallback onComprar;

  const _CatalogCard({
    required this.product,
    required this.jaComprou,
    required this.sponsorRef,
    required this.onComprar,
  });

  @override
  Widget build(BuildContext context) {
    final isRecorrente = product.recorrente;
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: jaComprou
            ? Border.all(
                color: AppColors.success.withValues(alpha: 0.4), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ícone
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.inventory_2_rounded,
                      color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nome + badge "Já assina"
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              product.nome,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (jaComprou)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.success
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded,
                                      color: AppColors.success, size: 12),
                                  SizedBox(width: 3),
                                  Text(
                                    'Assinado',
                                    style: TextStyle(
                                      color: AppColors.success,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      if (product.categoria.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          product.categoria,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textHint),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Descrição
            if (product.descricao.isNotEmpty) ...[
              Text(
                product.descricao,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5),
              ),
              const SizedBox(height: 10),
            ],
            // Preço + CTA
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fmt.format(product.valor),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      isRecorrente ? '/mês' : 'pagamento único',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textHint),
                    ),
                  ],
                ),
                const Spacer(),
                // Botão comprar / já assinado
                jaComprou
                    ? OutlinedButton.icon(
                        onPressed: onComprar,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Renovar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: onComprar,
                        icon: const Icon(Icons.shopping_cart_rounded,
                            size: 16),
                        label: const Text('Assinar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
