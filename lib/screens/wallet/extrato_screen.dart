import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/wallet_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';

class ExtratoScreen extends StatefulWidget {
  const ExtratoScreen({super.key});

  @override
  State<ExtratoScreen> createState() => _ExtratoScreenState();
}

class _ExtratoScreenState extends State<ExtratoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletService>().loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletService>();
    final extrato = wallet.extratoCompleto;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Extrato'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.gold,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppColors.gold,
          tabs: const [
            Tab(text: 'Todos'),
            Tab(text: 'Comissões'),
            Tab(text: 'Saques'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Resumo
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Row(
              children: [
                _SummaryItem(
                  label: 'Total Comissões',
                  value:
                      'R\$ ${wallet.totalComissoes.toStringAsFixed(2).replaceAll('.', ',')}',
                  color: AppColors.gold,
                ),
                Container(
                    height: 40,
                    width: 1,
                    color: Colors.white.withValues(alpha: 0.2)),
                _SummaryItem(
                  label: 'Total Saques',
                  value: 'R\$ ${wallet.withdraws.fold(0.0, (s, w) => s + w.valor).toStringAsFixed(2).replaceAll('.', ',')}',
                  color: Colors.white,
                ),
                Container(
                    height: 40,
                    width: 1,
                    color: Colors.white.withValues(alpha: 0.2)),
                _SummaryItem(
                  label: 'Transações',
                  value: extrato.length.toString(),
                  color: Colors.white,
                ),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildList(extrato),
                _buildList(
                    extrato.where((e) => e['tipo'] == 'comissao').toList()),
                _buildList(
                    extrato.where((e) => e['tipo'] == 'saque').toList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                color: AppColors.textHint, size: 64),
            SizedBox(height: 16),
            Text('Nenhuma transação',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16)),
          ],
        ),
      );
    }

    // Agrupa por mês
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final date = item['data'] as DateTime;
      final key = DateFormat('MMMM yyyy', 'pt_BR').format(date);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(item);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: grouped.length,
      itemBuilder: (ctx, groupIndex) {
        final month = grouped.keys.elementAt(groupIndex);
        final monthItems = grouped[month]!;
        final monthTotal = monthItems
            .where((i) => i['positivo'] == true)
            .fold(0.0, (s, i) => s + (i['valor'] as double));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Text(
                    month.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHint,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '+R\$ ${monthTotal.toStringAsFixed(2).replaceAll('.', ',')}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
            ...monthItems.map((item) => _ExtratoItem(item: item)),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w800),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ExtratoItem extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ExtratoItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final isPositivo = item['positivo'] as bool;
    final valor = item['valor'] as double;
    final date = item['data'] as DateTime;
    final tipo = item['tipo'] as String;

    final icon = tipo == 'comissao'
        ? Icons.trending_up_rounded
        : Icons.arrow_upward_rounded;
    final color = isPositivo ? AppColors.success : AppColors.error;

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
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['descricao'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(date),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textHint),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isPositivo ? '+' : '-'}R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              StatusBadge(status: item['status'] as String),
            ],
          ),
        ],
      ),
    );
  }
}
