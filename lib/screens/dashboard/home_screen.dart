import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/wallet_service.dart';
import '../../services/product_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../models/sale_model.dart';
import 'package:intl/intl.dart';
import 'main_nav_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _saldoVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletService>().loadData();
      context.read<ProductService>().loadProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final wallet = context.watch<WalletService>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<WalletService>().loadData();
        },
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            // App Bar Verde
            SliverAppBar(
              expandedHeight: 120,
              pinned: true,
              backgroundColor: AppColors.primary,
              elevation: 0,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.darkGreenGradient,
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const AppLogo(size: 32),
                              const Spacer(),
                              IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.notifications_rounded,
                                    color: Colors.white70),
                              ),
                              GestureDetector(
                                onTap: () => MainNavController().goProfile(),
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor:
                                      AppColors.gold.withValues(alpha: 0.3),
                                  child: Text(
                                    user?.primeiroNome.substring(0, 1) ?? 'U',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Olá, ${user?.primeiroNome ?? 'Afiliado'}! 👋',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // Card de Saldo
                  BalanceCard(
                    saldo: user?.saldo ?? 0,
                    isVisible: _saldoVisible,
                    onToggleVisibility: () =>
                        setState(() => _saldoVisible = !_saldoVisible),
                  ),

                  const SizedBox(height: 16),

                  // Botões rápidos
                  _buildQuickActions(context),

                  const SizedBox(height: 20),

                  // Estatísticas
                  StatsRow(
                    indicados: wallet.totalIndicados,
                    vendas: wallet.totalVendas,
                    comissoes: wallet.totalComissoes,
                  ),

                  const SizedBox(height: 20),

                  // Link de afiliado
                  AffiliateLinkCard(
                    link: user?.linkAfiliado ?? 'plataforma.com/ref/ABC123',
                    code: user?.affiliateCode ?? 'ABC123',
                  ),

                  const SizedBox(height: 20),

                  // Últimas Comissões
                  SectionTitle(
                    title: 'Últimas Comissões',
                    actionLabel: 'Ver extrato',
                    onAction: () => MainNavController().goExtrato(),
                  ),
                  const SizedBox(height: 10),

                  if (wallet.isLoading)
                    _buildLoadingSales()
                  else
                    _buildSalesList(wallet),

                  const SizedBox(height: 20),

                  // Performance do mês
                  _buildMonthlyPerformance(wallet),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final nav = MainNavController();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _QuickAction(
            icon: Icons.store_rounded,
            label: 'Produtos',
            color: AppColors.primary,
            onTap: () => nav.goProducts(),   // troca aba — sem nova aba
          ),
          const SizedBox(width: 10),
          _QuickAction(
            icon: Icons.pix_rounded,
            label: 'Sacar PIX',
            color: AppColors.gold,
            onTap: () => nav.goSaque(),      // troca aba — sem nova aba
          ),
          const SizedBox(width: 10),
          _QuickAction(
            icon: Icons.receipt_long_rounded,
            label: 'Extrato',
            color: AppColors.info,
            onTap: () => nav.goExtrato(),    // troca aba — sem nova aba
          ),
          const SizedBox(width: 10),
          _QuickAction(
            icon: Icons.share_rounded,
            label: 'Indicar',
            color: AppColors.success,
            onTap: () => nav.goProducts(),   // vai para produtos para compartilhar
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSales() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: List.generate(
          3,
          (i) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                const LoadingShimmer(height: 42, width: 42, borderRadius: 10),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      LoadingShimmer(height: 14, width: 120),
                      SizedBox(height: 6),
                      LoadingShimmer(height: 12, width: 80),
                    ],
                  ),
                ),
                const LoadingShimmer(height: 20, width: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSalesList(WalletService wallet) {
    final sales = wallet.salesCompleted.take(5).toList();
    if (sales.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: const Column(
          children: [
            Icon(Icons.receipt_long_outlined,
                color: AppColors.textHint, size: 48),
            SizedBox(height: 12),
            Text('Nenhuma venda ainda',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text('Compartilhe seu link para começar a ganhar!',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textHint, fontSize: 13)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: sales.map((sale) => _SaleItem(sale: sale)).toList(),
      ),
    );
  }

  Widget _buildMonthlyPerformance(WalletService wallet) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF8E7), Color(0xFFFFF3CC)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.emoji_events_rounded,
                      color: AppColors.gold, size: 20),
                ),
                const SizedBox(width: 10),
                const Text('Performance do Mês',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _PerformanceStat(
                    label: 'Comissões',
                    value:
                        'R\$ ${wallet.comissoesEsteMes.toStringAsFixed(2).replaceAll('.', ',')}',
                    icon: Icons.monetization_on_rounded,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PerformanceStat(
                    label: 'Meta mensal',
                    value: 'R\$ 500,00',
                    icon: Icons.flag_rounded,
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (wallet.comissoesEsteMes / 500).clamp(0.0, 1.0),
                backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${((wallet.comissoesEsteMes / 500) * 100).clamp(0.0, 100.0).toStringAsFixed(0)}% da meta atingida',
              style: const TextStyle(
                  color: AppColors.goldDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaleItem extends StatelessWidget {
  final SaleModel sale;
  const _SaleItem({required this.sale});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd/MM HH:mm').format(sale.createdAt);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.shopping_bag_rounded,
                color: AppColors.success, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sale.productNome,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(date,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textHint)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${sale.comissaoFormatada}',
                style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w800,
                    fontSize: 14),
              ),
              const SizedBox(height: 2),
              StatusBadge(status: sale.status),
            ],
          ),
        ],
      ),
    );
  }
}

class _PerformanceStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _PerformanceStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}
