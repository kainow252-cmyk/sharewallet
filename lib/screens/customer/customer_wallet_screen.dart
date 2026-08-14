// ===========================================================================
// customer_wallet_screen.dart - ShareWallet
// ---------------------------------------------------------------------------
// Carteira do cliente: saldo, adicionar crédito, histórico de transações.
// ===========================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/customer_service.dart';

class CustomerWalletScreen extends StatefulWidget {
  const CustomerWalletScreen({super.key});

  @override
  State<CustomerWalletScreen> createState() => _CustomerWalletScreenState();
}

class _CustomerWalletScreenState extends State<CustomerWalletScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _saldoOculto = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerService>().refreshCarteira();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<CustomerService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          await svc.refreshCarteira();
          await svc.refreshProdutos();
        },
        color: AppColors.gold,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Cabeçalho com saldo ───────────────────────────────────────
            SliverToBoxAdapter(child: _buildWalletHeader(svc)),

            // ── Botões de ação ────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildActionButtons(context)),

            // ── Métricas ──────────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildMetrics(svc)),

            // ── Histórico (lista de produtos/transações) ──────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: const Text(
                  'Histórico',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),

            if (svc.produtos.isEmpty)
              SliverToBoxAdapter(child: _buildEmptyHistory())
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _TransactionCard(svc.produtos[i]),
                  childCount: svc.produtos.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  // ── Header com saldo ─────────────────────────────────────────────────────
  Widget _buildWalletHeader(CustomerService svc) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3D2B00),
            Color(0xFF6B4800),
            Color(0xFF8A5D00),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded,
                      color: AppColors.gold, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Minha Carteira',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () =>
                        setState(() => _saldoOculto = !_saldoOculto),
                    icon: Icon(
                      _saldoOculto
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: Colors.white60,
                      size: 20,
                    ),
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(32, 32),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Saldo disponível
              Text(
                'Saldo disponível',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
              ),
              const SizedBox(height: 4),
              _saldoOculto
                  ? const Text(
                      '••••••',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                      ),
                    )
                  : Text(
                      _fmtMoeda(svc.saldoDisponivel),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
              if (svc.saldoPendente > 0) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '+ ${_fmtMoeda(svc.saldoPendente)} pendente',
                    style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Botões de ação ────────────────────────────────────────────────────────
  Widget _buildActionButtons(BuildContext context) {
    return Container(
      color: const Color(0xFF8A5D00),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Row(
          children: [
            Expanded(
              child: _ActionBtn(
                icon: Icons.add_rounded,
                label: 'Adicionar saldo',
                color: AppColors.primary,
                onTap: () => _showAddBalanceSheet(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionBtn(
                icon: Icons.pix_rounded,
                label: 'Pagar com PIX',
                color: const Color(0xFF32BCAD),
                onTap: () => _showPixInfo(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionBtn(
                icon: Icons.help_outline_rounded,
                label: 'Suporte',
                color: AppColors.textSecondary,
                onTap: () => _showSupport(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Métricas ──────────────────────────────────────────────────────────────
  Widget _buildMetrics(CustomerService svc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _MetricTile(
              label: 'Total depositado',
              value: _fmtMoeda(svc.totalDepositado),
              icon: Icons.arrow_downward_rounded,
              iconColor: AppColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MetricTile(
              label: 'Total gasto',
              value: _fmtMoeda(svc.totalGasto),
              icon: Icons.arrow_upward_rounded,
              iconColor: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty history ─────────────────────────────────────────────────────────
  Widget _buildEmptyHistory() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_outlined,
                color: AppColors.gold, size: 30),
          ),
          const SizedBox(height: 12),
          const Text(
            'Nenhuma transação ainda',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Suas compras e depósitos aparecerão aqui.',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── Bottom sheet: adicionar saldo ─────────────────────────────────────────
  void _showAddBalanceSheet(BuildContext context) {
    final amountCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textHint.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Adicionar saldo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'O saldo será confirmado após o pagamento via PIX.',
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              // Campo valor
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Valor (R\$)',
                  prefixIcon: const Icon(Icons.attach_money_rounded,
                      color: AppColors.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Sugestões rápidas
              Row(
                children: [10, 25, 50, 100].map((v) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: OutlinedButton(
                      onPressed: () {
                        amountCtrl.text = '$v,00';
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('R\$ $v',
                          style: const TextStyle(
                              color: AppColors.primary, fontSize: 12)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              // Botão gerar PIX
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showPixQrCode(context, amountCtrl.text);
                  },
                  icon: const Icon(Icons.pix_rounded, size: 20),
                  label: const Text('Gerar QR Code PIX'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF32BCAD),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPixQrCode(BuildContext context, String amount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.pix_rounded, color: Color(0xFF32BCAD), size: 22),
            SizedBox(width: 8),
            Text('Pagamento via PIX',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.textHint.withValues(alpha: 0.3)),
              ),
              child: const Center(
                child: Icon(Icons.qr_code_2_rounded,
                    size: 100, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Valor: R\$ ${amount.isEmpty ? "0,00" : amount}',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              'QR Code será gerado após integração com Woovi. Por enquanto, entre em contato com o suporte.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _showPixInfo(BuildContext context) {
    _showAddBalanceSheet(context);
  }

  void _showSupport(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Suporte: suporte@sharewallet.com.br'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  String _fmtMoeda(double v) =>
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(v);
}

// ── Widget: Botão de ação ─────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widget: Métrica tile ──────────────────────────────────────────────────
class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widget: Card de transação (produto comprado) ──────────────────────────
class _TransactionCard extends StatelessWidget {
  final dynamic produto; // CustomerProductModel

  const _TransactionCard(this.produto);

  @override
  Widget build(BuildContext context) {
    final color = produto.isAtivo ? AppColors.success : AppColors.textHint;
    final DateFormat fmt = DateFormat('dd/MM/yyyy', 'pt_BR');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.inventory_2_outlined, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  produto.productNome,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${fmt.format(produto.dataInicio)} • ${produto.statusLabel}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            '- ${produto.valorFormatado}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}
