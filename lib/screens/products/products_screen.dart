import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/product_service.dart';
import '../../services/auth_service.dart';
import '../../services/mercadopago_service.dart';
import '../../models/product_model.dart';
import '../../theme/app_theme.dart';
import 'subscription_screen.dart';
import '../payment/mp_checkout_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductService>().loadProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ps = context.watch<ProductService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Produtos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filtro categorias ──────────────────────────────────────────────
          if (!ps.isLoading)
            Container(
              height: 50,
              color: AppColors.surface,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: ps.categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final cat = ps.categories[i];
                  final isSelected = cat == ps.selectedCategory;
                  final label = ProductService.categoryLabels[cat] ?? cat;
                  return GestureDetector(
                    onTap: () => ps.setCategory(cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
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
                      child: Text(
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
                    ),
                  );
                },
              ),
            ),
          const Divider(height: 1),

          // ── Banner info ────────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF083D29), Color(0xFF0D5C3D)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.autorenew_rounded, color: Colors.white70, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Assinatura via Pix Automático — o cliente autoriza uma vez e paga todo mês sem abrir o app!',
                    style: TextStyle(
                        color: Colors.white, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          // ── Lista de produtos ──────────────────────────────────────────────
          Expanded(
            child: ps.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    itemCount: ps.filteredProducts.length,
                    itemBuilder: (ctx, i) =>
                        _ProductCard(product: ps.filteredProducts[i]),
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
          color: product.isPixAutomatico
              ? AppColors.primary.withValues(alpha: 0.25)
              : AppColors.cardBorder,
          width: product.isPixAutomatico ? 1.5 : 1,
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
                      if (product.isPixAutomatico && product.diaCobranca != null)
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

          // ── Ações: Divulgar + Assinar ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Botão Divulgar link
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _showShareSheet(context, product, affiliateCode),
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: const Text('Divulgar',
                        style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Botão principal: Assinar / Comprar
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => _assinar(context, product),
                    icon: Icon(
                      product.isPixAutomatico
                          ? Icons.autorenew_rounded
                          : Icons.pix_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: Text(
                      product.isPixAutomatico
                          ? 'Assinar — Pix Automático'
                          : product.isPixAvulso
                              ? 'Pagar com Pix'
                              : 'Comprar Agora',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: product.isPixAutomatico
                          ? AppColors.primary
                          : AppColors.gold,
                      padding: const EdgeInsets.symmetric(vertical: 11),
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

  // ── Abre tela de checkout Mercado Pago ──────────────────────────────────────
  void _assinar(BuildContext context, ProductModel product) {
    final auth = context.read<AuthService>();
    final affiliateCode = auth.currentUser?.affiliateCode ?? 'ABC123';

    // Abre modal para escolher fluxo: MP Checkout ou Pix Automático legado
    _showCheckoutOptions(context, product, affiliateCode);
  }

  void _showCheckoutOptions(
      BuildContext context, ProductModel product, String affiliateCode) {
    final comissao = MercadoPagoService.calcularComissao(product.valor);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Cabeçalho produto
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.inventory_2_rounded,
                      color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.nome,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppColors.textPrimary),
                      ),
                      Text(
                        'Sua comissão: R\$ ${comissao.toStringAsFixed(2)}/mês',
                        style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Text(
                  product.valorFormatado,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Opção 1: Mercado Pago (recomendado)
            _CheckoutOption(
              icon: Icons.payment_rounded,
              iconColor: const Color(0xFF009EE3),
              badge: 'RECOMENDADO',
              badgeColor: AppColors.success,
              title: 'Pagar com Mercado Pago',
              subtitle: 'Checkout seguro • Pix, cartão ou boleto',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MpCheckoutScreen(
                      product: product,
                      affiliateCode: affiliateCode,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Opção 2: Pix Automático legado
            _CheckoutOption(
              icon: Icons.autorenew_rounded,
              iconColor: const Color(0xFF32BCAD),
              title: 'Autorizar Pix Automático',
              subtitle: 'Débito automático mensal no banco',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SubscriptionScreen(
                      product: product,
                      affiliateCode: affiliateCode,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Cancelar
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom sheet de compartilhamento ──────────────────────────────────────
  void _showShareSheet(
      BuildContext context, ProductModel product, String affiliateCode) {
    final link =
        'https://plataforma.com/assinar/${product.id}?ref=$affiliateCode';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(product.nome,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(
              'Comissão: ${product.comissaoFormatada}/mês (${product.comissaoPercent}%)',
              style: const TextStyle(
                  color: AppColors.success, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(product.chargeTypeIcon,
                    color: product.chargeTypeColor, size: 14),
                const SizedBox(width: 6),
                Text(
                  product.chargeTypeLabel,
                  style: TextStyle(
                      color: product.chargeTypeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Link
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(link,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.primary),
                        overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: link));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Link copiado! ✅'),
                            backgroundColor: AppColors.success),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded,
                        color: AppColors.primary, size: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Fechar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: link));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Link copiado! ✅'),
                            backgroundColor: AppColors.success),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary),
                    icon: const Icon(Icons.share_rounded, color: Colors.white),
                    label: const Text('Compartilhar',
                        style: TextStyle(color: Colors.white)),
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

// ── Widget: Opção de checkout ─────────────────────────────────────────────────

class _CheckoutOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback onTap;

  const _CheckoutOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.badge,
    this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: iconColor.withValues(alpha: 0.2), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.textPrimary),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (badgeColor ?? AppColors.success)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge!,
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: badgeColor ?? AppColors.success),
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
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: AppColors.textHint),
            ],
          ),
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
