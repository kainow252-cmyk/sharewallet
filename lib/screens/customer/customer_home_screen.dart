// ===========================================================================
// customer_home_screen.dart - ShareWallet
// ---------------------------------------------------------------------------
// Tela "Início" do Portal do Cliente.
// Exibe: boas-vindas, sponsor, produtos ativos e CTA para descobrir mais.
// ===========================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/customer_service.dart';
import '../../models/customer_model.dart';
import 'customer_nav_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    final svc = context.read<CustomerService>();
    await Future.wait([
      svc.refreshProfile(),
      svc.refreshProdutos(),
      svc.refreshCarteira(),
    ]);
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<CustomerService>();
    final customer = svc.currentCustomer;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── AppBar com gradiente e boas-vindas ────────────────────────
            _buildSliverHeader(customer),

            // ── Cards de resumo (saldo + produtos) ────────────────────────
            SliverToBoxAdapter(
              child: _buildSummaryCards(svc),
            ),

            // ── Sponsor badge ─────────────────────────────────────────────
            if (customer?.hasSponsor == true)
              SliverToBoxAdapter(
                child: _buildSponsorBadge(customer!),
              ),

            // ── Seção: Meus produtos ativos ───────────────────────────────
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                'Meus Produtos Ativos',
                Icons.check_circle_outline_rounded,
                trailing: svc.produtos.isNotEmpty
                    ? TextButton(
                        onPressed: () => CustomerNavController().goCatalog(),
                        child: const Text('Ver mais',
                            style: TextStyle(color: AppColors.primary)),
                      )
                    : null,
              ),
            ),

            if (_refreshing && svc.produtos.isEmpty)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
              )
            else if (svc.produtosAtivos.isEmpty)
              SliverToBoxAdapter(child: _buildEmptyProducts())
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _ProductCard(svc.produtosAtivos[i]),
                  childCount: svc.produtosAtivos.length,
                ),
              ),

            // ── CTA Descubra mais produtos ────────────────────────────────
            SliverToBoxAdapter(
              child: _buildDiscoverCta(),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  // ── Header com gradiente ─────────────────────────────────────────────────
  Widget _buildSliverHeader(CustomerModel? customer) {
    final now = DateTime.now();
    final hora = now.hour;
    String saudacao = hora < 12 ? 'Bom dia' : hora < 18 ? 'Boa tarde' : 'Boa noite';

    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      backgroundColor: AppColors.primary,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0A3D2B),
                Color(0xFF0D5C3D),
                Color(0xFF1A7A52),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Avatar + nome
                  Row(
                    children: [
                      _CustomerAvatar(
                        avatarUrl: customer?.avatarUrl ?? '',
                        nome: customer?.nome ?? 'C',
                        size: 44,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$saudacao,',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              customer?.primeiroNome ?? 'Cliente',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Badge "Cliente"
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.5)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_user_rounded,
                                color: AppColors.gold, size: 13),
                            SizedBox(width: 4),
                            Text(
                              'Cliente',
                              style: TextStyle(
                                color: AppColors.gold,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
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
          ),
        ),
      ),
      // AppBar compacta quando colapsa
      title: Text(
        customer?.primeiroNome ?? 'Início',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ── Cards de resumo ──────────────────────────────────────────────────────
  Widget _buildSummaryCards(CustomerService svc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(
              icon: Icons.account_balance_wallet_rounded,
              iconColor: AppColors.gold,
              label: 'Saldo',
              value: _fmtMoeda(svc.saldoDisponivel),
              subtitle: svc.saldoPendente > 0
                  ? 'R\$ ${_fmtNum(svc.saldoPendente)} pendente'
                  : null,
              onTap: () => CustomerNavController().goWallet(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryCard(
              icon: Icons.inventory_2_outlined,
              iconColor: AppColors.primary,
              label: 'Produtos',
              value: svc.produtosAtivos.length.toString(),
              subtitle: '${svc.produtos.length} total',
              onTap: () => CustomerNavController().goCatalog(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sponsor badge ────────────────────────────────────────────────────────
  Widget _buildSponsorBadge(CustomerModel customer) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.handshake_rounded,
                  color: AppColors.primary, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Indicado por',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                  Text(
                    customer.sponsorNome.isNotEmpty
                        ? '${customer.sponsorNome} • ${customer.sponsorHandle}'
                        : customer.sponsorHandle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.link_rounded,
                color: AppColors.textHint, size: 16),
          ],
        ),
      ),
    );
  }

  // ── Seção header ─────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title, IconData icon,
      {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  // ── Empty state ──────────────────────────────────────────────────────────
  Widget _buildEmptyProducts() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.store_outlined,
                color: AppColors.primary, size: 34),
          ),
          const SizedBox(height: 12),
          const Text(
            'Nenhum produto ativo',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Explore o catálogo e assine o produto ideal para você.',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => CustomerNavController().goCatalog(),
            icon: const Icon(Icons.explore_rounded, size: 18),
            label: const Text('Ver catálogo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Discover CTA ─────────────────────────────────────────────────────────
  Widget _buildDiscoverCta() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: GestureDetector(
        onTap: () => CustomerNavController().goCatalog(),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D5C3D), Color(0xFF1A7A52)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Descubra mais produtos',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Explore o catálogo completo e assine o que precisar.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_forward_rounded,
                    color: Colors.white, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtMoeda(double v) =>
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(v);
  String _fmtNum(double v) =>
      NumberFormat('#,##0.00', 'pt_BR').format(v);
}

// ── Widget: Avatar do cliente ─────────────────────────────────────────────
class _CustomerAvatar extends StatelessWidget {
  final String avatarUrl;
  final String nome;
  final double size;

  const _CustomerAvatar({
    required this.avatarUrl,
    required this.nome,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final initial = nome.isNotEmpty ? nome[0].toUpperCase() : 'C';
    if (avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(avatarUrl),
        onBackgroundImageError: (_, __) {},
        backgroundColor: AppColors.gold.withValues(alpha: 0.3),
        child: null,
      );
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.gold.withValues(alpha: 0.25),
      child: Text(
        initial,
        style: TextStyle(
          color: AppColors.gold,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}

// ── Widget: Summary Card ─────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? subtitle;
  final VoidCallback? onTap;

  const _SummaryCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const Spacer(),
                Icon(Icons.chevron_right_rounded,
                    color: AppColors.textHint, size: 16),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textHint),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Widget: Card de produto ativo ─────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final CustomerProductModel produto;

  const _ProductCard(this.produto);

  @override
  Widget build(BuildContext context) {
    final Color statusColor = produto.isAtivo
        ? AppColors.success
        : produto.isPendente
            ? AppColors.gold
            : AppColors.error;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ícone de categoria
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.inventory_2_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  produto.productNome,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (produto.productCategoria.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    produto.productCategoria,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textHint),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    // Status
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        produto.statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Recorrente badge
                    if (produto.isRecorrente)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Recorrente',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Valor
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                produto.valorFormatado,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              const Text(
                '/mês',
                style: TextStyle(fontSize: 11, color: AppColors.textHint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
