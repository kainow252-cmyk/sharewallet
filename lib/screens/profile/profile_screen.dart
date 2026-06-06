import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_user_service.dart';
import '../../services/cf_api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _editMode = false;
  bool _saving = false;

  late TextEditingController _nomeCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _telefoneCtrl;
  late TextEditingController _cpfCtrl;
  late TextEditingController _pixCtrl;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    _nomeCtrl     = TextEditingController(text: user?.nome ?? '');
    _emailCtrl    = TextEditingController(text: user?.email ?? '');
    _telefoneCtrl = TextEditingController(text: user?.telefone ?? '');
    _cpfCtrl      = TextEditingController(text: user?.cpf ?? '');
    _pixCtrl      = TextEditingController(text: user?.email ?? '');

    // Recarrega perfil ao abrir (garante dados atualizados)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AuthService>().refreshProfile();
      if (!mounted) return;
      final u = context.read<AuthService>().currentUser;
      if (u != null) {
        _nomeCtrl.text     = u.nome;
        _emailCtrl.text    = u.email;
        _telefoneCtrl.text = u.telefone;
        _cpfCtrl.text      = u.cpf;
        _pixCtrl.text      = u.email;
      }
    });
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _telefoneCtrl.dispose();
    _cpfCtrl.dispose();
    _pixCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final auth = context.read<AuthService>();
      final uid = auth.currentUser?.id ?? '';

      // Salva no Firestore (set+merge — funciona mesmo sem doc existir)
      await FirebaseUserService.atualizarPerfil(
        uid: uid,
        nome: _nomeCtrl.text.trim(),
        telefone: _telefoneCtrl.text.trim(),
        cpf: _cpfCtrl.text.trim(),
        pixKey: _pixCtrl.text.trim(),
      );

      // Sincroniza no D1 (Worker) — upsert: cria o registro se não existir
      // ignore: unawaited_futures
      CfApiService.updateAffiliate(uid, {
        'nome': _nomeCtrl.text.trim(),
        'email': auth.currentUser?.email ?? '',
        'telefone': _telefoneCtrl.text.trim(),
        'cpf': _cpfCtrl.text.trim(),
        'pix_key': _pixCtrl.text.trim(),
        'affiliate_code': auth.currentUser?.affiliateCode ?? '',
      }).catchError((_) => null);

      await auth.refreshProfile();

      if (!mounted) return;
      setState(() { _editMode = false; _saving = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Perfil atualizado com sucesso!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: AppColors.primary,
              actions: [
                if (!_editMode)
                  TextButton.icon(
                    onPressed: () => setState(() => _editMode = true),
                    icon: const Icon(Icons.edit_rounded,
                        color: Colors.white, size: 18),
                    label: const Text('Editar',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  )
                else ...[
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() => _editMode = false),
                    child: const Text('Cancelar',
                        style: TextStyle(color: Colors.white70)),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _salvar,
                    child: _saving
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Salvar',
                            style: TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w800)),
                  ),
                ],
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.darkGreenGradient,
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 44,
                              backgroundColor:
                                  AppColors.gold.withValues(alpha: 0.3),
                              child: Text(
                                (user?.nome.isNotEmpty == true)
                                    ? user!.nome[0].toUpperCase()
                                    : 'A',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.gold,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.verified_rounded,
                                    color: Colors.white, size: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          user?.nome.isNotEmpty == true
                              ? user!.nome
                              : 'Afiliado',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.pix_rounded,
                                color: AppColors.goldLight, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              user?.affiliateCode ?? 'ABC123',
                              style: const TextStyle(
                                  color: AppColors.goldLight,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // ── Minha Conta ──────────────────────────────────────────
                  _Section(
                    title: 'Minha Conta',
                    trailing: _editMode
                        ? null
                        : GestureDetector(
                            onTap: () => setState(() => _editMode = true),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_outlined,
                                    size: 14, color: AppColors.primary),
                                SizedBox(width: 4),
                                Text('Editar',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                    children: [
                      _editMode
                          ? _EditField(
                              ctrl: _nomeCtrl,
                              label: 'Nome completo',
                              icon: Icons.person_rounded,
                              validator: (v) =>
                                  v!.trim().split(' ').length < 2
                                      ? 'Nome e sobrenome'
                                      : null,
                            )
                          : _InfoRow(
                              icon: Icons.person_rounded,
                              label: 'Nome',
                              value: user?.nome.isNotEmpty == true
                                  ? user!.nome
                                  : '—',
                            ),
                      const Divider(height: 1, indent: 52),
                      _InfoRow(
                        icon: Icons.email_outlined,
                        label: 'E-mail',
                        value: user?.email.isNotEmpty == true
                            ? user!.email
                            : '—',
                      ),
                      const Divider(height: 1, indent: 52),
                      _editMode
                          ? _EditField(
                              ctrl: _telefoneCtrl,
                              label: 'Telefone / WhatsApp',
                              icon: Icons.phone_rounded,
                              keyboard: TextInputType.phone,
                            )
                          : _InfoRow(
                              icon: Icons.phone_rounded,
                              label: 'Telefone',
                              value: user?.telefone.isNotEmpty == true
                                  ? user!.telefone
                                  : '—',
                            ),
                      const Divider(height: 1, indent: 52),
                      _editMode
                          ? _EditField(
                              ctrl: _cpfCtrl,
                              label: 'CPF',
                              icon: Icons.badge_rounded,
                              keyboard: TextInputType.number,
                              hint: '000.000.000-00',
                            )
                          : _InfoRow(
                              icon: Icons.badge_rounded,
                              label: 'CPF',
                              value: user?.cpf.isNotEmpty == true
                                  ? _maskCpf(user!.cpf)
                                  : '—',
                            ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── PIX ──────────────────────────────────────────────────
                  _Section(
                    title: 'Recebimento PIX',
                    children: [
                      _editMode
                          ? _EditField(
                              ctrl: _pixCtrl,
                              label: 'Chave PIX (E-mail)',
                              icon: Icons.pix_rounded,
                              keyboard: TextInputType.emailAddress,
                            )
                          : _InfoRow(
                              icon: Icons.pix_rounded,
                              label: 'Chave PIX',
                              value: user?.email.isNotEmpty == true
                                  ? user!.email
                                  : 'Não configurada',
                            ),
                      const Divider(height: 1, indent: 52),
                      _InfoRow(
                        icon: Icons.account_balance_rounded,
                        label: 'Status',
                        value: 'Ativa ✅',
                        valueColor: AppColors.success,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Salvar (modo edição) ──────────────────────────────────
                  if (_editMode) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: PrimaryButton(
                        label: 'Salvar Alterações',
                        icon: Icons.save_rounded,
                        isLoading: _saving,
                        onPressed: _saving ? null : _salvar,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Configurações ─────────────────────────────────────────
                  _Section(
                    title: 'Configurações',
                    children: [
                      _ActionRow(
                        icon: Icons.lock_rounded,
                        label: 'Alterar Senha',
                        onTap: () => _mostrarAlterarSenha(context),
                      ),
                      const Divider(height: 1, indent: 52),
                      _ActionRow(
                        icon: Icons.description_rounded,
                        label: 'Termos de Uso',
                        onTap: () => _mostrarTermos(context),
                      ),
                      const Divider(height: 1, indent: 52),
                      _ActionRow(
                        icon: Icons.privacy_tip_rounded,
                        label: 'Política de Privacidade',
                        onTap: () => _mostrarPolitica(context),
                      ),
                      const Divider(height: 1, indent: 52),
                      _ActionRow(
                        icon: Icons.help_rounded,
                        label: 'Suporte / Ajuda',
                        onTap: () => _mostrarSuporte(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Logout ────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmLogout(context, auth),
                      icon: const Icon(Icons.logout_rounded,
                          color: AppColors.error),
                      label: const Text('Sair da Conta',
                          style: TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Versão
                  const Text(
                    'ShareWallet v1.0.0',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textHint),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _maskCpf(String cpf) {
    final digits = cpf.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 11) return cpf;
    return '${digits.substring(0, 3)}.***.*${digits.substring(9, 11)}';
  }

  void _confirmLogout(BuildContext context, AuthService auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sair da conta?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Você precisará fazer login novamente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await auth.logout();
              if (context.mounted) {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/login', (_) => false);
              }
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sair',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _mostrarTermos(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TermosSheet(
        titulo: 'Termos de Uso',
        conteudo: _termosDeUso,
      ),
    );
  }

  void _mostrarPolitica(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TermosSheet(
        titulo: 'Política de Privacidade',
        conteudo: _politicaDePrivacidade,
      ),
    );
  }

  void _mostrarSuporte(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            const Icon(Icons.support_agent_rounded,
                color: AppColors.primary, size: 48),
            const SizedBox(height: 12),
            const Text('Suporte ShareWallet',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'Entre em contato conosco para dúvidas, problemas técnicos ou sugestões.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            _SupportTile(
              icon: Icons.email_rounded,
              label: 'E-mail',
              value: 'suporte@sharewallet.com.br',
              onTap: () {},
            ),
            const SizedBox(height: 8),
            _SupportTile(
              icon: Icons.chat_rounded,
              label: 'WhatsApp',
              value: '(11) 99999-9999',
              onTap: () {},
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _mostrarAlterarSenha(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AlterarSenhaSheet(),
    );
  }
}

// ── Widgets auxiliares ─────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  const _Section({
    required this.title,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHint,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
            ...children,
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textHint)),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '—' : value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: valueColor ??
                        (value.isEmpty
                            ? AppColors.textHint
                            : AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType? keyboard;
  final String? hint;
  final String? Function(String?)? validator;

  const _EditField({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.keyboard,
    this.hint,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.primary, size: 18),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        ),
        validator: validator,
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionRow(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textHint, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SupportTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _SupportTile(
      {required this.icon,
      required this.label,
      required this.value,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(label,
          style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
      subtitle: Text(value,
          style: const TextStyle(
              fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      trailing:
          const Icon(Icons.open_in_new_rounded, color: AppColors.primary, size: 18),
      onTap: onTap,
      shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.cardBorder),
          borderRadius: BorderRadius.circular(12)),
    );
  }
}

// ── Sheet: Termos / Política ──────────────────────────────────────────────────

class _TermosSheet extends StatelessWidget {
  final String titulo;
  final String conteudo;
  const _TermosSheet({required this.titulo, required this.conteudo});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const Icon(Icons.description_rounded,
                      color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text(titulo,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const Divider(height: 24),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                children: [
                  Text(conteudo,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.7)),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sheet: Alterar Senha ──────────────────────────────────────────────────────

class _AlterarSenhaSheet extends StatefulWidget {
  const _AlterarSenhaSheet();

  @override
  State<_AlterarSenhaSheet> createState() => _AlterarSenhaSheetState();
}

class _AlterarSenhaSheetState extends State<_AlterarSenhaSheet> {
  final _atualCtrl = TextEditingController();
  final _novaCtrl  = TextEditingController();
  final _confCtrl  = TextEditingController();
  bool _loading = false;
  bool _showAtual = false;
  bool _showNova  = false;
  final _key = GlobalKey<FormState>();

  @override
  void dispose() {
    _atualCtrl.dispose(); _novaCtrl.dispose(); _confCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Senha alterada com sucesso!'),
          backgroundColor: AppColors.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Text('Alterar Senha',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _atualCtrl,
                obscureText: !_showAtual,
                decoration: InputDecoration(
                  labelText: 'Senha atual',
                  prefixIcon: const Icon(Icons.lock_outline_rounded,
                      color: AppColors.primary),
                  suffixIcon: IconButton(
                    icon: Icon(_showAtual
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                        color: AppColors.textHint),
                    onPressed: () =>
                        setState(() => _showAtual = !_showAtual),
                  ),
                ),
                validator: (v) =>
                    v!.length < 6 ? 'Mínimo 6 caracteres' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _novaCtrl,
                obscureText: !_showNova,
                decoration: InputDecoration(
                  labelText: 'Nova senha',
                  prefixIcon: const Icon(Icons.lock_rounded,
                      color: AppColors.primary),
                  suffixIcon: IconButton(
                    icon: Icon(_showNova
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                        color: AppColors.textHint),
                    onPressed: () =>
                        setState(() => _showNova = !_showNova),
                  ),
                ),
                validator: (v) =>
                    v!.length < 6 ? 'Mínimo 6 caracteres' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmar nova senha',
                  prefixIcon: Icon(Icons.lock_rounded,
                      color: AppColors.primary),
                ),
                validator: (v) => v != _novaCtrl.text
                    ? 'Senhas não conferem'
                    : null,
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Alterar Senha',
                icon: Icons.save_rounded,
                isLoading: _loading,
                onPressed: _loading ? null : _salvar,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Conteúdo dos Termos ───────────────────────────────────────────────────────

const String _termosDeUso = '''
TERMOS DE USO — SHAREWALLET

Última atualização: junho de 2025

1. ACEITAÇÃO DOS TERMOS
Ao se cadastrar e utilizar o ShareWallet, você concorda com estes Termos de Uso. Caso não concorde, não utilize nossos serviços.

2. SOBRE O SERVIÇO
O ShareWallet é uma plataforma de marketing de afiliados que permite aos usuários divulgar produtos e receber comissões por vendas realizadas através de seus links rastreáveis.

3. CADASTRO E CONTA
• Você deve ter pelo menos 18 anos de idade.
• Forneça informações verdadeiras e mantenha seus dados atualizados.
• É proibido criar múltiplas contas para burlar o sistema de comissões.
• Você é responsável pela segurança da sua senha.

4. COMISSÕES E PAGAMENTOS
• As comissões são pagas via PIX após confirmação do pagamento do cliente final.
• O prazo para liberação das comissões é de até 7 dias úteis após a confirmação.
• O valor mínimo para saque é de R\$ 50,00.
• Comissões estornadas por cancelamento ou chargeback serão descontadas do saldo.

5. CONDUTAS PROIBIDAS
• Spam ou divulgação não autorizada.
• Uso de informações falsas ou enganosas.
• Tentativa de fraude ou manipulação do sistema.
• Uso indevido da marca ShareWallet.

6. RESCISÃO
O ShareWallet reserva-se o direito de suspender ou encerrar contas que violem estes termos, sem aviso prévio, com o estorno das comissões pendentes em casos de fraude comprovada.

7. LIMITAÇÃO DE RESPONSABILIDADE
O ShareWallet não se responsabiliza por perdas indiretas ou danos decorrentes do uso da plataforma.

8. ALTERAÇÕES
Estes termos podem ser alterados a qualquer momento. Notificaremos os usuários por e-mail ou dentro do aplicativo.

9. CONTATO
Dúvidas: suporte@sharewallet.com.br
''';

const String _politicaDePrivacidade = '''
POLÍTICA DE PRIVACIDADE — SHAREWALLET

Última atualização: junho de 2025

1. DADOS COLETADOS
Coletamos: nome completo, CPF, e-mail, telefone, endereço IP e dados de uso da plataforma.

2. USO DOS DADOS
• Processamento de comissões e pagamentos PIX.
• Comunicação sobre sua conta e transações.
• Melhoria dos nossos serviços.
• Cumprimento de obrigações legais.

3. COMPARTILHAMENTO
Seus dados são compartilhados apenas com:
• Mercado Pago (processamento de pagamentos).
• Autoridades quando exigido por lei.
Nunca vendemos seus dados a terceiros.

4. SEGURANÇA
Utilizamos criptografia e boas práticas de segurança para proteger seus dados.

5. SEUS DIREITOS
Você pode solicitar: acesso, correção, exclusão ou portabilidade dos seus dados a qualquer momento pelo e-mail privacidade@sharewallet.com.br.

6. COOKIES
Utilizamos cookies apenas para autenticação e melhoria da experiência do usuário.

7. CONTATO
privacidade@sharewallet.com.br
''';
