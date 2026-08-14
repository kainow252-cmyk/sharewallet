// ===========================================================================
// customer_profile_screen.dart - ShareWallet
// ---------------------------------------------------------------------------
// Perfil do cliente: exibe dados, sponsor, edição de campos e logout.
// ===========================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/customer_service.dart';
import '../../services/firebase_customer_service.dart';
import '../../models/customer_model.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  bool _editMode = false;
  bool _saving = false;

  final _nomeCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _cpfCtrl = TextEditingController();
  final _pixCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final c = context.read<CustomerService>().currentCustomer;
    if (c != null) {
      _nomeCtrl.text = c.nome;
      _telefoneCtrl.text = c.telefone;
      _cpfCtrl.text = c.cpf;
      _pixCtrl.text = c.pixKey;
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _telefoneCtrl.dispose();
    _cpfCtrl.dispose();
    _pixCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_saving) return;
    setState(() => _saving = true);

    final svc = context.read<CustomerService>();
    final customer = svc.currentCustomer;
    if (customer == null) {
      setState(() => _saving = false);
      return;
    }

    try {
      final ok = await FirebaseCustomerService.atualizarPerfilCliente(
        uid: customer.id,
        nome: _nomeCtrl.text.trim(),
        telefone: _telefoneCtrl.text.trim(),
        cpf: _cpfCtrl.text.trim(),
        pixKey: _pixCtrl.text.trim(),
      );

      if (!mounted) return;
      if (ok) {
        svc.updateCurrentCustomer(
          nome: _nomeCtrl.text.trim(),
          telefone: _telefoneCtrl.text.trim(),
          cpf: _cpfCtrl.text.trim(),
          pixKey: _pixCtrl.text.trim(),
        );
        setState(() {
          _editMode = false;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil atualizado com sucesso!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        setState(() => _saving = false);
        _showError('Erro ao salvar. Tente novamente.');
      }
    } catch (_) {
      setState(() => _saving = false);
      _showError('Erro de conexão.');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sair da conta',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
            'Tem certeza que deseja sair?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<CustomerService>().logout();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/landing', (_) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<CustomerService>();
    final customer = svc.currentCustomer;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Meu Perfil',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          if (!_editMode)
            TextButton(
              onPressed: () => setState(() => _editMode = true),
              child: const Text(
                'Editar',
                style: TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.w600),
              ),
            )
          else ...[
            TextButton(
              onPressed: _saving
                  ? null
                  : () {
                      setState(() => _editMode = false);
                      _loadData(); // desfaz edições
                    },
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white60)),
            ),
            TextButton(
              onPressed: _saving ? null : _salvar,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Salvar',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          children: [
            // ── Header com avatar ──────────────────────────────────────
            _buildProfileHeader(customer),

            const SizedBox(height: 8),

            // ── Sponsor card ───────────────────────────────────────────
            if (customer?.hasSponsor == true)
              _buildSponsorCard(customer!),

            // ── Dados pessoais ─────────────────────────────────────────
            _buildSection(
              'Dados Pessoais',
              [
                _buildField(
                  label: 'Nome completo',
                  ctrl: _nomeCtrl,
                  icon: Icons.person_outline_rounded,
                  enabled: _editMode,
                ),
                _buildField(
                  label: 'E-mail',
                  value: customer?.email ?? '',
                  icon: Icons.email_outlined,
                  enabled: false, // e-mail não editável
                ),
                _buildField(
                  label: 'Telefone',
                  ctrl: _telefoneCtrl,
                  icon: Icons.phone_outlined,
                  enabled: _editMode,
                  keyboardType: TextInputType.phone,
                ),
                _buildField(
                  label: 'CPF',
                  ctrl: _cpfCtrl,
                  icon: Icons.badge_outlined,
                  enabled: _editMode,
                  keyboardType: TextInputType.number,
                ),
              ],
            ),

            // ── Chave PIX ──────────────────────────────────────────────
            _buildSection(
              'Chave PIX',
              [
                _buildField(
                  label: 'Chave PIX',
                  ctrl: _pixCtrl,
                  icon: Icons.pix_rounded,
                  enabled: _editMode,
                  hint: 'CPF, e-mail, telefone ou chave aleatória',
                ),
              ],
            ),

            // ── Conta ──────────────────────────────────────────────────
            _buildSection(
              'Conta',
              [
                _InfoTile(
                  icon: Icons.calendar_today_outlined,
                  label: 'Membro desde',
                  value: customer?.createdAt != null
                      ? '${customer!.createdAt.day.toString().padLeft(2, '0')}/'
                          '${customer.createdAt.month.toString().padLeft(2, '0')}/'
                          '${customer.createdAt.year}'
                      : '-',
                ),
                _InfoTile(
                  icon: Icons.shopping_bag_outlined,
                  label: 'Produtos',
                  value: '${customer?.totalProdutos ?? 0} produto(s)',
                ),
                _InfoTile(
                  icon: Icons.circle,
                  label: 'Status',
                  value: customer?.isAtivo == true ? 'Ativo' : 'Inativo',
                  valueColor: customer?.isAtivo == true
                      ? AppColors.success
                      : AppColors.error,
                ),
              ],
            ),

            // ── Ações ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _ActionListTile(
                    icon: Icons.support_agent_rounded,
                    label: 'Suporte',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('suporte@sharewallet.com.br'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    },
                  ),
                  _ActionListTile(
                    icon: Icons.logout_rounded,
                    label: 'Sair da conta',
                    color: AppColors.error,
                    onTap: _logout,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildProfileHeader(CustomerModel? customer) {
    final initial = customer?.nome.isNotEmpty == true
        ? customer!.nome[0].toUpperCase()
        : 'C';
    final avatarUrl = customer?.avatarUrl ?? '';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A3D2B), Color(0xFF0D5C3D)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        children: [
          // Avatar
          Stack(
            children: [
              avatarUrl.isNotEmpty
                  ? CircleAvatar(
                      radius: 44,
                      backgroundImage: NetworkImage(avatarUrl),
                      backgroundColor:
                          AppColors.gold.withValues(alpha: 0.3),
                    )
                  : CircleAvatar(
                      radius: 44,
                      backgroundColor: AppColors.gold.withValues(alpha: 0.25),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w900,
                          fontSize: 34,
                        ),
                      ),
                    ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF0D5C3D), width: 2),
                  ),
                  child: const Icon(Icons.verified_user_rounded,
                      color: Colors.white, size: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Nome
          Text(
            customer?.nome ?? 'Cliente',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          // Email
          Text(
            customer?.email ?? '',
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 8),
          // Badge cliente
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded, color: AppColors.gold, size: 14),
                SizedBox(width: 4),
                Text(
                  'Portal do Cliente',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sponsor card ──────────────────────────────────────────────────────────
  Widget _buildSponsorCard(CustomerModel customer) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.handshake_rounded,
                color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
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
                      ? customer.sponsorNome
                      : customer.sponsorHandle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                if (customer.sponsorNome.isNotEmpty)
                  Text(
                    customer.sponsorHandle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textHint),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Vínculo permanente',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section builder ───────────────────────────────────────────────────────
  Widget _buildSection(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: List.generate(children.length, (i) {
                return Column(
                  children: [
                    children[i],
                    if (i < children.length - 1)
                      Divider(
                        height: 1,
                        thickness: 1,
                        color:
                            AppColors.textHint.withValues(alpha: 0.1),
                        indent: 48,
                      ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ── Field builder ─────────────────────────────────────────────────────────
  Widget _buildField({
    required String label,
    TextEditingController? ctrl,
    String? value,
    required IconData icon,
    bool enabled = true,
    TextInputType? keyboardType,
    String? hint,
  }) {
    if (enabled && ctrl != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
            border: InputBorder.none,
            labelStyle: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
      leading: Icon(icon, color: AppColors.textHint, size: 20),
      title: Text(
        label,
        style: const TextStyle(
            fontSize: 11, color: AppColors.textSecondary),
      ),
      subtitle: Text(
        ctrl?.text ?? value ?? '-',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      dense: true,
    );
  }
}

// ── Widget: Info tile somente leitura ─────────────────────────────────────
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
      leading: Icon(icon, color: AppColors.textHint, size: 20),
      title: Text(
        label,
        style: const TextStyle(
            fontSize: 11, color: AppColors.textSecondary),
      ),
      subtitle: Text(
        value,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: valueColor ?? AppColors.textPrimary,
        ),
      ),
      dense: true,
    );
  }
}

// ── Widget: Action tile ───────────────────────────────────────────────────
class _ActionListTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _ActionListTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: c, size: 18),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: c,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        trailing: Icon(Icons.chevron_right_rounded,
            color: c.withValues(alpha: 0.5), size: 18),
      ),
    );
  }
}
