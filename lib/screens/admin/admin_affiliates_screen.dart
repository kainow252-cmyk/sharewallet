import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';

class AdminAffiliatesScreen extends StatefulWidget {
  const AdminAffiliatesScreen({super.key});

  @override
  State<AdminAffiliatesScreen> createState() => _AdminAffiliatesScreenState();
}

class _AdminAffiliatesScreenState extends State<AdminAffiliatesScreen> {
  String _search = '';
  String _filter = 'todos'; // todos, ativo, suspenso

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<AdminService>();
    final afiliados = svc.affiliates.where((a) {
      final matchSearch = _search.isEmpty ||
          a.nome.toLowerCase().contains(_search.toLowerCase()) ||
          a.email.toLowerCase().contains(_search.toLowerCase()) ||
          a.affiliateCode.toLowerCase().contains(_search.toLowerCase());
      final matchFilter = _filter == 'todos' || a.status == _filter;
      return matchSearch && matchFilter;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Afiliados'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => svc.loadAffiliates(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Busca + filtro
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Buscar afiliado...',
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppColors.textHint),
                      suffixIcon: _search.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () => setState(() => _search = ''),
                            )
                          : null,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  initialValue: _filter,
                  onSelected: (v) => setState(() => _filter = v),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _filter != 'todos'
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Icon(
                      Icons.filter_list_rounded,
                      color: _filter != 'todos'
                          ? AppColors.primary
                          : AppColors.textHint,
                      size: 20,
                    ),
                  ),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'todos', child: Text('Todos')),
                    const PopupMenuItem(value: 'ativo', child: Text('Ativos')),
                    const PopupMenuItem(
                        value: 'suspenso', child: Text('Suspensos')),
                  ],
                ),
              ],
            ),
          ),

          // Chips de estatísticas
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                _StatChip(
                  label: '${svc.affiliates.length} total',
                  color: AppColors.primary,
                  selected: _filter == 'todos',
                  onTap: () => setState(() => _filter = 'todos'),
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label:
                      '${svc.affiliates.where((a) => a.status == 'ativo').length} ativos',
                  color: AppColors.success,
                  selected: _filter == 'ativo',
                  onTap: () => setState(() => _filter = 'ativo'),
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label:
                      '${svc.affiliates.where((a) => a.status == 'suspenso').length} suspensos',
                  color: AppColors.error,
                  selected: _filter == 'suspenso',
                  onTap: () => setState(() => _filter = 'suspenso'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Lista
          Expanded(
            child: svc.isLoading
                ? const Center(child: CircularProgressIndicator())
                : afiliados.isEmpty
                    ? const Center(
                        child: Text('Nenhum afiliado encontrado'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: afiliados.length,
                        itemBuilder: (ctx, i) => _AffiliateCard(
                          affiliate: afiliados[i],
                          onToggle: () => _toggleStatus(
                              context, svc, afiliados[i]),
                          onDetails: () =>
                              _showDetails(context, afiliados[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleStatus(
      BuildContext context, AdminService svc, AdminAffiliate a) async {
    final newStatus = a.status == 'ativo' ? 'suspenso' : 'ativo';
    final label = newStatus == 'ativo' ? 'ativar' : 'suspender';

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${newStatus == 'ativo' ? 'Ativar' : 'Suspender'} Afiliado'),
        content: Text(
            'Tem certeza que deseja $label "${a.nome}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == 'ativo'
                  ? AppColors.success
                  : AppColors.error,
            ),
            child: Text(
                newStatus == 'ativo' ? 'Ativar' : 'Suspender'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await svc.updateAffiliateStatus(a.id, newStatus);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Afiliado ${newStatus == 'ativo' ? 'ativado' : 'suspenso'}!'),
            backgroundColor: newStatus == 'ativo'
                ? AppColors.success
                : AppColors.error,
          ),
        );
      }
    }
  }

  void _showDetails(BuildContext context, AdminAffiliate a) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                _AvatarCircle(nome: a.nome, status: a.status),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.nome,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      Text(a.email,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 4),
                      _StatusBadge(status: a.status),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            // Detalhes
            _DetailRow(label: 'Código de Afiliado', value: a.affiliateCode),
            if (a.sponsorCode != null)
              _DetailRow(label: 'Indicado por', value: a.sponsorCode!),
            _DetailRow(label: 'CPF', value: a.cpf),
            _DetailRow(label: 'Telefone', value: a.telefone),
            if (a.pixKey != null)
              _DetailRow(label: 'Chave PIX', value: a.pixKey!),
            _DetailRow(
                label: 'Cadastrado em',
                value: DateFormat('dd/MM/yyyy').format(a.createdAt)),
            const SizedBox(height: 16),

            // Financeiro
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.greenGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _FinanceItem(
                          label: 'Saldo',
                          value: fmt.format(a.saldoDisponivel),
                          icon: Icons.account_balance_wallet_rounded),
                      _FinanceItem(
                          label: 'Total Comissões',
                          value: fmt.format(a.totalComissoes),
                          icon: Icons.attach_money_rounded),
                      _FinanceItem(
                          label: 'Total Sacado',
                          value: fmt.format(a.totalSacado),
                          icon: Icons.send_rounded),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _FinanceItem(
                          label: 'Indicados',
                          value: a.totalIndicados.toString(),
                          icon: Icons.people_rounded),
                      _FinanceItem(
                          label: 'Assinaturas',
                          value: a.totalAssinaturas.toString(),
                          icon: Icons.repeat_rounded),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Card do afiliado ──────────────────────────────────────────────────────────
class _AffiliateCard extends StatelessWidget {
  final AdminAffiliate affiliate;
  final VoidCallback onToggle;
  final VoidCallback onDetails;
  const _AffiliateCard(
      {required this.affiliate,
      required this.onToggle,
      required this.onDetails});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final isActive = affiliate.status == 'ativo';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isActive
                ? AppColors.cardBorder
                : AppColors.error.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: InkWell(
        onTap: onDetails,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _AvatarCircle(nome: affiliate.nome, status: affiliate.status),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(affiliate.nome,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        Text(affiliate.email,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12)),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                affiliate.affiliateCode,
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _StatusBadge(status: affiliate.status),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        fmt.format(affiliate.saldoDisponivel),
                        style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w800,
                            fontSize: 16),
                      ),
                      const Text('saldo',
                          style: TextStyle(
                              color: AppColors.textHint, fontSize: 11)),
                    ],
                  ),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MiniStat(
                      icon: Icons.people_rounded,
                      value: '${affiliate.totalIndicados}',
                      label: 'indicados'),
                  _MiniStat(
                      icon: Icons.repeat_rounded,
                      value: '${affiliate.totalAssinaturas}',
                      label: 'assinaturas'),
                  _MiniStat(
                      icon: Icons.attach_money_rounded,
                      value: fmt.format(affiliate.totalComissoes),
                      label: 'comissões'),
                  ElevatedButton(
                    onPressed: onToggle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isActive ? AppColors.error : AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      textStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                      minimumSize: Size.zero,
                    ),
                    child: Text(isActive ? 'Suspender' : 'Ativar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────
class _AvatarCircle extends StatelessWidget {
  final String nome;
  final String status;
  const _AvatarCircle({required this.nome, required this.status});

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'ativo';
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: isActive
            ? AppColors.greenGradient
            : const LinearGradient(
                colors: [Color(0xFFB71C1C), Color(0xFFD32F2F)]),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          nome.isNotEmpty ? nome[0].toUpperCase() : '?',
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'ativo':
        color = AppColors.success;
        label = 'Ativo';
        break;
      case 'suspenso':
        color = AppColors.error;
        label = 'Suspenso';
        break;
      default:
        color = AppColors.warning;
        label = 'Pendente';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _StatChip(
      {required this.label,
      required this.color,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : AppColors.cardBorder, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: selected ? color : AppColors.textSecondary,
              fontSize: 12,
              fontWeight:
                  selected ? FontWeight.w700 : FontWeight.normal),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _MiniStat(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 14),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 12)),
        Text(label,
            style: const TextStyle(
                color: AppColors.textHint, fontSize: 10)),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

class _FinanceItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _FinanceItem(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13)),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ],
    );
  }
}
