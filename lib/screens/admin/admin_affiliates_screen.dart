import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/admin_service.dart';
import '../../models/subscription_model.dart';
import '../../theme/app_theme.dart';

class AdminAffiliatesScreen extends StatefulWidget {
  const AdminAffiliatesScreen({super.key});

  @override
  State<AdminAffiliatesScreen> createState() => _AdminAffiliatesScreenState();
}

class _AdminAffiliatesScreenState extends State<AdminAffiliatesScreen> {
  String _search = '';
  String _filter = 'todos';

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
            child: svc.isLoadingData
                ? const Center(child: CircularProgressIndicator())
                : afiliados.isEmpty
                    ? const Center(
                        child: Text('Nenhum afiliado encontrado'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: afiliados.length,
                        itemBuilder: (ctx, i) => _AffiliateCard(
                          affiliate: afiliados[i],
                          onToggle: () =>
                              _toggleStatus(context, svc, afiliados[i]),
                          onDetails: () =>
                              _showDetails(context, afiliados[i]),
                          onEdit: () =>
                              _showEditSheet(context, svc, afiliados[i]),
                          onDelete: () =>
                              _confirmDelete(context, svc, afiliados[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ── Toggle status ativo/suspenso ─────────────────────────────────────────
  Future<void> _toggleStatus(
      BuildContext context, AdminService svc, AdminAffiliate a) async {
    final newStatus = a.status == 'ativo' ? 'suspenso' : 'ativo';
    final label = newStatus == 'ativo' ? 'ativar' : 'suspender';

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
            '${newStatus == 'ativo' ? 'Ativar' : 'Suspender'} Afiliado'),
        content: Text('Tem certeza que deseja $label "${a.nome}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  newStatus == 'ativo' ? AppColors.success : AppColors.error,
            ),
            child: Text(newStatus == 'ativo' ? 'Ativar' : 'Suspender'),
          ),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      await svc.updateAffiliateStatus(a.id, newStatus);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Afiliado ${newStatus == 'ativo' ? 'ativado' : 'suspenso'}!'),
          backgroundColor:
              newStatus == 'ativo' ? AppColors.success : AppColors.error,
        ));
      }
    }
  }

  // ── Detalhes ─────────────────────────────────────────────────────────────
  void _showDetails(BuildContext context, AdminAffiliate a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AffiliateDetailSheet(
          affiliate: a, svc: context.read<AdminService>()),
    );
  }

  // ── Editar ───────────────────────────────────────────────────────────────
  void _showEditSheet(
      BuildContext context, AdminService svc, AdminAffiliate a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditAffiliateSheet(
        affiliate: a,
        onSave: (data) async {
          final ok = await svc.editAffiliate(a.id, data);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(ok
                  ? 'Afiliado atualizado com sucesso!'
                  : 'Erro ao atualizar afiliado.'),
              backgroundColor: ok ? AppColors.success : AppColors.error,
            ));
          }
        },
      ),
    );
  }

  // ── Excluir ──────────────────────────────────────────────────────────────
  Future<void> _confirmDelete(
      BuildContext context, AdminService svc, AdminAffiliate a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppColors.error, size: 24),
            SizedBox(width: 8),
            Text('Excluir Afiliado',
                style: TextStyle(color: AppColors.error, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 14),
                children: [
                  const TextSpan(text: 'Tem certeza que deseja excluir '),
                  TextSpan(
                    text: a.nome,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: '?'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.2)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Esta ação irá:',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AppColors.error)),
                  SizedBox(height: 6),
                  _BulletItem('Excluir o afiliado permanentemente'),
                  _BulletItem('Remover carteira e saldo'),
                  _BulletItem('Cancelar assinaturas ativas'),
                  _BulletItem('Esta ação não pode ser desfeita'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete_rounded, size: 16),
            label: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      final success = await svc.deleteAffiliate(a.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success
              ? '${a.nome} excluído com sucesso!'
              : 'Erro ao excluir afiliado.'),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ));
      }
    }
  }
}

// ── Widget auxiliar para lista de bullets no diálogo ─────────────────────────
class _BulletItem extends StatelessWidget {
  final String text;
  const _BulletItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ',
              style:
                  TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

// ── Bottom sheet de edição ────────────────────────────────────────────────────
class _EditAffiliateSheet extends StatefulWidget {
  final AdminAffiliate affiliate;
  final Future<void> Function(Map<String, dynamic> data) onSave;
  const _EditAffiliateSheet(
      {required this.affiliate, required this.onSave});

  @override
  State<_EditAffiliateSheet> createState() => _EditAffiliateSheetState();
}

class _EditAffiliateSheetState extends State<_EditAffiliateSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomeCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _cpfCtrl;
  late TextEditingController _telCtrl;
  late TextEditingController _pixCtrl;
  late String _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.affiliate;
    _nomeCtrl = TextEditingController(text: a.nome);
    _emailCtrl = TextEditingController(text: a.email);
    _cpfCtrl = TextEditingController(text: a.cpf);
    _telCtrl = TextEditingController(text: a.telefone);
    _pixCtrl = TextEditingController(text: a.pixKey ?? '');
    _status = a.status;
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _cpfCtrl.dispose();
    _telCtrl.dispose();
    _pixCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    await widget.onSave({
      'nome': _nomeCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'cpf': _cpfCtrl.text.trim(),
      'telefone': _telCtrl.text.trim(),
      'pix_key': _pixCtrl.text.trim(),
      'status': _status,
    });

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.affiliate;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit_rounded,
                          color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Editar Afiliado',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary)),
                          Text(a.affiliateCode,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.textHint),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Formulário
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    controller: ctrl,
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Nome
                      _FormField(
                        label: 'Nome completo',
                        controller: _nomeCtrl,
                        icon: Icons.person_rounded,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Informe o nome'
                                : null,
                      ),
                      const SizedBox(height: 14),

                      // Email
                      _FormField(
                        label: 'E-mail',
                        controller: _emailCtrl,
                        icon: Icons.email_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),

                      // CPF
                      _FormField(
                        label: 'CPF',
                        controller: _cpfCtrl,
                        icon: Icons.badge_rounded,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 14),

                      // Telefone
                      _FormField(
                        label: 'Telefone / WhatsApp',
                        controller: _telCtrl,
                        icon: Icons.phone_rounded,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 14),

                      // PIX
                      _FormField(
                        label: 'Chave PIX',
                        controller: _pixCtrl,
                        icon: Icons.pix_rounded,
                        hint: 'CPF, e-mail, telefone ou chave aleatória',
                      ),
                      const SizedBox(height: 20),

                      // Status
                      const Text('Status',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _StatusOption(
                            label: 'Ativo',
                            icon: Icons.check_circle_rounded,
                            color: AppColors.success,
                            selected: _status == 'ativo',
                            onTap: () => setState(() => _status = 'ativo'),
                          ),
                          const SizedBox(width: 10),
                          _StatusOption(
                            label: 'Suspenso',
                            icon: Icons.block_rounded,
                            color: AppColors.error,
                            selected: _status == 'suspenso',
                            onTap: () => setState(() => _status = 'suspenso'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Botão salvar
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                              : const Icon(Icons.save_rounded, size: 18),
                          label: Text(
                            _saving ? 'Salvando...' : 'Salvar alterações',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Campo de formulário reutilizável ─────────────────────────────────────────
class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? hint;
  final String? Function(String?)? validator;

  const _FormField({
    required this.label,
    required this.controller,
    required this.icon,
    this.keyboardType,
    this.hint,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18, color: AppColors.textHint),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          ),
        ),
      ],
    );
  }
}

// ── Seletor de status ─────────────────────────────────────────────────────────
class _StatusOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _StatusOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.12)
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : AppColors.cardBorder,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: selected ? color : AppColors.textHint, size: 18),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: selected ? color : AppColors.textSecondary,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.normal,
                      fontSize: 13)),
            ],
          ),
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
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AffiliateCard({
    required this.affiliate,
    required this.onToggle,
    required this.onDetails,
    required this.onEdit,
    required this.onDelete,
  });

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
              // ── Linha principal: avatar + info + saldo + menu ─────────────
              Row(
                children: [
                  _AvatarCircle(
                      nome: affiliate.nome, status: affiliate.status),
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
                                fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary
                                    .withValues(alpha: 0.1),
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
                  // Saldo + menu de ações
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
                      const SizedBox(height: 4),
                      // Menu 3 pontos
                      _ActionMenu(
                        onEdit: onEdit,
                        onDelete: onDelete,
                        onToggle: onToggle,
                        isActive: isActive,
                      ),
                    ],
                  ),
                ],
              ),

              const Divider(height: 16),

              // ── Linha de stats ────────────────────────────────────────────
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
                  // Botão suspender/ativar compacto
                  OutlinedButton(
                    onPressed: onToggle,
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          isActive ? AppColors.error : AppColors.success,
                      side: BorderSide(
                          color: isActive
                              ? AppColors.error.withValues(alpha: 0.5)
                              : AppColors.success.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      textStyle: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700),
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

// ── Menu de ações (3 pontos) ──────────────────────────────────────────────────
class _ActionMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;
  final bool isActive;

  const _ActionMenu({
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (v) {
        if (v == 'edit') onEdit();
        if (v == 'delete') onDelete();
        if (v == 'toggle') onToggle();
      },
      icon: const Icon(Icons.more_vert_rounded,
          color: AppColors.textHint, size: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_rounded, size: 16, color: AppColors.primary),
              SizedBox(width: 10),
              Text('Editar dados',
                  style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'toggle',
          child: Row(
            children: [
              Icon(
                isActive ? Icons.block_rounded : Icons.check_circle_rounded,
                size: 16,
                color: isActive ? AppColors.warning : AppColors.success,
              ),
              const SizedBox(width: 10),
              Text(
                isActive ? 'Suspender' : 'Ativar',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_rounded, size: 16, color: AppColors.error),
              SizedBox(width: 10),
              Text('Excluir afiliado',
                  style: TextStyle(fontSize: 13, color: AppColors.error)),
            ],
          ),
        ),
      ],
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
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800),
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
          color:
              selected ? color.withValues(alpha: 0.15) : AppColors.surface,
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
            style:
                const TextStyle(color: AppColors.textHint, fontSize: 10)),
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

// ── Modal de detalhes do afiliado com abas ────────────────────────────────────
class _AffiliateDetailSheet extends StatefulWidget {
  final AdminAffiliate affiliate;
  final AdminService svc;
  const _AffiliateDetailSheet(
      {required this.affiliate, required this.svc});

  @override
  State<_AffiliateDetailSheet> createState() => _AffiliateDetailSheetState();
}

class _AffiliateDetailSheetState extends State<_AffiliateDetailSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<SubscriptionModel> _subs = [];
  bool _loadingSubs = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadSubs();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadSubs() async {
    setState(() => _loadingSubs = true);
    try {
      final all = widget.svc.subscriptions;
      _subs = all
          .where((s) => s.affiliateCode == widget.affiliate.affiliateCode)
          .toList();
      _subs.sort((a, b) {
        if (a.status == SubscriptionStatus.ativa &&
            b.status != SubscriptionStatus.ativa) { return -1; }
        if (b.status == SubscriptionStatus.ativa &&
            a.status != SubscriptionStatus.ativa) { return 1; }
        return b.dataInicio.compareTo(a.dataInicio);
      });
    } catch (e) {
      debugPrint('[AffDetail] Erro ao carregar subs: $e');
    }
    if (mounted) setState(() => _loadingSubs = false);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.affiliate;
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    final subsAtivas =
        _subs.where((s) => s.status == SubscriptionStatus.ativa).toList();
    final comissaoPendente =
        subsAtivas.fold(0.0, (sum, s) => sum + s.valorComissao);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  _AvatarCircle(nome: a.nome, status: a.status),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.nome,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary)),
                        Text(a.email,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            _StatusBadge(status: a.status),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(a.affiliateCode,
                                  style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textHint),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Cards financeiros
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(14),
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
                          label: 'Saldo Disponível',
                          value: fmt.format(a.saldoDisponivel),
                          icon: Icons.account_balance_wallet_rounded),
                      _FinanceItem(
                          label: 'Comissão Total',
                          value: fmt.format(a.totalComissoes),
                          icon: Icons.attach_money_rounded),
                      _FinanceItem(
                          label: 'Total Sacado',
                          value: fmt.format(a.totalSacado),
                          icon: Icons.send_rounded),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 20),
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
                      _FinanceItem(
                          label: 'A Receber',
                          value: fmt.format(comissaoPendente),
                          icon: Icons.pending_actions_rounded),
                    ],
                  ),
                ],
              ),
            ),

            // TabBar
            Container(
              margin: const EdgeInsets.only(top: 12),
              color: const Color(0xFF071A10),
              child: TabBar(
                controller: _tab,
                labelColor: AppColors.gold,
                unselectedLabelColor: Colors.white54,
                indicatorColor: AppColors.gold,
                tabs: const [
                  Tab(
                      icon: Icon(Icons.person_rounded, size: 16),
                      text: 'Dados'),
                  Tab(
                      icon: Icon(Icons.history_rounded, size: 16),
                      text: 'Histórico'),
                ],
              ),
            ),

            // Conteúdo das abas
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  // ── Aba Dados ──────────────────────────────────────────────
                  ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(20),
                    children: [
                      _DetailRow(
                          label: 'Código de Afiliado',
                          value: a.affiliateCode),
                      if (a.sponsorCode != null &&
                          a.sponsorCode!.isNotEmpty)
                        _DetailRow(
                            label: 'Indicado por',
                            value: a.sponsorCode!),
                      _DetailRow(
                          label: 'CPF',
                          value:
                              a.cpf.isNotEmpty ? a.cpf : '—'),
                      _DetailRow(
                          label: 'Telefone',
                          value: a.telefone.isNotEmpty
                              ? a.telefone
                              : '—'),
                      if (a.pixKey != null && a.pixKey!.isNotEmpty)
                        _DetailRow(
                            label: 'Chave PIX', value: a.pixKey!),
                      _DetailRow(
                          label: 'Cadastrado em',
                          value: DateFormat('dd/MM/yyyy')
                              .format(a.createdAt)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.gold
                                  .withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.pending_actions_rounded,
                                    color: AppColors.gold, size: 14),
                                SizedBox(width: 6),
                                Text('Comissão a Receber',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        color: AppColors.gold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${subsAtivas.length} assinatura${subsAtivas.length != 1 ? 's' : ''} ativa${subsAtivas.length != 1 ? 's' : ''}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary),
                                ),
                                Text(
                                  fmt.format(comissaoPendente),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: AppColors.gold),
                                ),
                              ],
                            ),
                            if (subsAtivas.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              const Text(
                                'por mês (estimativa)',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textHint),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  // ── Aba Histórico ──────────────────────────────────────────
                  _loadingSubs
                      ? const Center(child: CircularProgressIndicator())
                      : _subs.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.inbox_rounded,
                                      size: 48,
                                      color: AppColors.textHint),
                                  SizedBox(height: 12),
                                  Text(
                                      'Nenhuma assinatura encontrada',
                                      style: TextStyle(
                                          color:
                                              AppColors.textSecondary)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: scrollCtrl,
                              padding: const EdgeInsets.all(12),
                              itemCount: _subs.length,
                              itemBuilder: (_, i) => _SubHistoryCard(
                                  sub: _subs[i], fmt: fmt),
                            ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card de assinatura no histórico ──────────────────────────────────────────
class _SubHistoryCard extends StatelessWidget {
  final SubscriptionModel sub;
  final NumberFormat fmt;
  const _SubHistoryCard({required this.sub, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final dtFmt = DateFormat('dd/MM/yyyy');
    final statusColor = sub.statusColor;
    final isRecorrente = sub.chargeType.name == 'pixRecorrente';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isRecorrente ? AppColors.primary : AppColors.info)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isRecorrente
                  ? Icons.autorenew_rounded
                  : Icons.pix_rounded,
              color:
                  isRecorrente ? AppColors.primary : AppColors.info,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(sub.productNome,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isRecorrente
                                ? AppColors.primary
                                : AppColors.info)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isRecorrente ? 'Mensal' : 'Avulso',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isRecorrente
                                ? AppColors.primary
                                : AppColors.info),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      'Início: ${dtFmt.format(sub.dataInicio)}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textHint),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      fmt.format(sub.valor),
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary),
                    ),
                    const Text(' · ',
                        style:
                            TextStyle(color: AppColors.textHint)),
                    Text(
                      'Comissão: ${fmt.format(sub.valorComissao)}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gold),
                    ),
                  ],
                ),
                if (sub.motivo != null && sub.motivo!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(sub.motivo!,
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.warning)),
                  ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Text(sub.statusLabel,
                style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
