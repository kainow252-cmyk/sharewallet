import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      final uid = FirebaseAuth.instance.currentUser?.uid;
      // Cache: só carrega se ainda não tem dados
      context.read<WalletService>().loadData(userId: uid);
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
          final uid = FirebaseAuth.instance.currentUser?.uid;
          // Pull-to-refresh: força recarregamento
          await context.read<WalletService>().loadData(userId: uid, forceRefresh: true);
        },
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            // App Bar Verde
            SliverAppBar(
              expandedHeight: 72,
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
                          horizontal: 16, vertical: 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // ── Logo ícone (sem texto) ──────────────────────
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.gold,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // ── ShareWallet + saudação ──────────────────────
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ShareWallet',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                    height: 1.1,
                                  ),
                                ),
                                Text(
                                  'Olá, ${user?.primeiroNome ?? 'Afiliado'}! 👋',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // ── Notificação + Avatar ────────────────────────
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.notifications_rounded,
                                color: Colors.white70),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 36, minHeight: 36),
                          ),
                          const SizedBox(width: 4),
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
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14),
                              ),
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

                  // ── Card Minha Carteira ─────────────────────────────
                  // Usa SEMPRE wallet.saldoCarteira (D1/Cloudflare) como fonte
                  // única de verdade — sincroniza dashboard com performance
                  _WalletSummaryCard(
                    saldo: wallet.saldoCarteira,
                    isVisible: _saldoVisible,
                    onToggleVisibility: () =>
                        setState(() => _saldoVisible = !_saldoVisible),
                    onTapCarteira: () => MainNavController().goCarteira(),
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
                    comissaoPendente: wallet.saldoPendente,
                  ),

                  const SizedBox(height: 20),

                  // Últimas Comissões
                  SectionTitle(
                    title: 'Últimas Comissões',
                    actionLabel: 'Ver carteira',
                    onAction: () => MainNavController().goCarteira(),
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
            onTap: () => nav.goProducts(),
          ),
          const SizedBox(width: 10),
          _QuickAction(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Carteira',
            color: const Color(0xFF00E5B4),
            onTap: () => nav.goCarteira(),
          ),
          const SizedBox(width: 10),
          _QuickAction(
            icon: Icons.people_alt_rounded,
            label: 'Indicações',
            color: AppColors.info,
            onTap: () => nav.goIndicacoes(),
          ),
          const SizedBox(width: 10),
          _QuickAction(
            icon: Icons.emoji_events_rounded,
            label: 'Ranking',
            color: const Color(0xFFFFD740),
            onTap: () => nav.goRanking(),
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
    // Performance usa mesma fonte D1 — wallet.comissoesEsteMes
    // e wallet.saldoCarteira — garantindo consistência com dashboard
    final comissoesMes = wallet.comissoesEsteMes;
    final saldoDisp    = wallet.saldoCarteira;
    final totalReceb   = wallet.totalRecebido;
    const meta = 500.0;

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
                    label: 'Comissões/mês',
                    value: 'R\$ ${comissoesMes.toStringAsFixed(2).replaceAll(".", ",")}',
                    icon: Icons.monetization_on_rounded,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PerformanceStat(
                    label: 'Saldo disponível',
                    value: 'R\$ ${saldoDisp.toStringAsFixed(2).replaceAll(".", ",")}',
                    icon: Icons.account_balance_wallet_rounded,
                    color: const Color(0xFF00E5B4),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PerformanceStat(
                    label: 'Total recebido',
                    value: 'R\$ ${totalReceb.toStringAsFixed(2).replaceAll(".", ",")}',
                    icon: Icons.trending_up_rounded,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (comissoesMes / meta).clamp(0.0, 1.0),
                backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${((comissoesMes / meta) * 100).clamp(0.0, 100.0).toStringAsFixed(0)}% da meta mensal de R\$ ${meta.toStringAsFixed(0)} atingida',
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

class _WalletSummaryCard extends StatelessWidget {
  final double saldo;
  final bool isVisible;
  final VoidCallback onToggleVisibility;
  final VoidCallback onTapCarteira;

  const _WalletSummaryCard({
    required this.saldo,
    required this.isVisible,
    required this.onToggleVisibility,
    required this.onTapCarteira,
  });

  static const double _saqueMinimo = 100.0;

  @override
  Widget build(BuildContext context) {
    final pct = (saldo / _saqueMinimo).clamp(0.0, 1.0);
    final faltam = (_saqueMinimo - saldo).clamp(0.0, _saqueMinimo);
    final podesSacar = saldo >= _saqueMinimo;

    return GestureDetector(
      onTap: onTapCarteira,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A1628), Color(0xFF0D3B2E)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E5B4).withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded,
                    color: Color(0xFF00E5B4), size: 20),
                const SizedBox(width: 8),
                const Text('💰 Minha Carteira',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                GestureDetector(
                  onTap: onToggleVisibility,
                  child: Icon(
                    isVisible
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    color: Colors.white38,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded,
                    color: Colors.white38, size: 18),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isVisible
                  ? 'R\$ ${saldo.toStringAsFixed(2).replaceAll('.', ',')}'
                  : 'R\$ ••••••',
              style: const TextStyle(
                color: Color(0xFF00E5B4),
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Saldo disponível',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
            ),
            const SizedBox(height: 14),
            // Barra de progresso
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Meta para saque',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 11)),
                          Text('R\$ ${_saqueMinimo.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.1),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF00E5B4)),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        podesSacar
                            ? '✅ Pronto para sacar!'
                            : 'Faltam R\$ ${faltam.toStringAsFixed(2).replaceAll('.', ',')} — ${(pct * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: podesSacar
                              ? const Color(0xFF00E5B4)
                              : Colors.white.withValues(alpha: 0.4),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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
