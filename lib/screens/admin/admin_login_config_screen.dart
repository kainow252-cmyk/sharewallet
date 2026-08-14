import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../services/app_config_service.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AdminLoginConfigScreen — controla métodos de login + cria usuários via Admin
// ─────────────────────────────────────────────────────────────────────────────
class AdminLoginConfigScreen extends StatefulWidget {
  const AdminLoginConfigScreen({super.key});

  @override
  State<AdminLoginConfigScreen> createState() => _AdminLoginConfigScreenState();
}

class _AdminLoginConfigScreenState extends State<AdminLoginConfigScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late AppLoginConfig _draft;
  bool _saving = false;

  // Formulário criar usuário
  final _formKey    = GlobalKey<FormState>();
  final _nomeCtrl   = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _senhaCtrl  = TextEditingController();
  final _sponsorCtrl = TextEditingController();
  bool _showPass    = false;
  bool _creating    = false;
  String? _createResult;
  bool   _createOk  = false;

  @override
  void initState() {
    super.initState();
    _tabs  = TabController(length: 2, vsync: this);
    _draft = context.read<AppConfigService>().loginConfig;
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    _sponsorCtrl.dispose();
    super.dispose();
  }

  // ── Salvar config de login ────────────────────────────────────────────────
  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await context.read<AppConfigService>().saveLoginConfig(_draft);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Configurações salvas!' : 'Erro ao salvar. Tente novamente.'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    if (ok) {
      // Recarrega a config local
      if (mounted) context.read<AppConfigService>().load(forceRemote: true);
    }
  }

  // ── Reset para defaults ────────────────────────────────────────────────────
  void _reset() {
    setState(() {
      _draft = const AppLoginConfig();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Configurações resetadas para padrão'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Criar usuário via Admin ───────────────────────────────────────────────
  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _creating = true; _createResult = null; });

    try {
      final res = await http.post(
        Uri.parse('https://api.sharewallet.com.br/api/admin/create-user'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'nome':  _nomeCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'senha': _senhaCtrl.text,
          'codigo_patrocinador': _sponsorCtrl.text.trim().isEmpty
              ? null
              : _sponsorCtrl.text.trim().toUpperCase(),
        }),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final body = json.decode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 || res.statusCode == 201) {
        final code = body['affiliate_code'] ?? '';
        setState(() {
          _createOk     = true;
          _createResult = 'Usuário criado!\n'
              'E-mail: ${_emailCtrl.text.trim()}\n'
              'Código afiliado: $code';
        });
        _nomeCtrl.clear();
        _emailCtrl.clear();
        _senhaCtrl.clear();
        _sponsorCtrl.clear();
      } else {
        setState(() {
          _createOk     = false;
          _createResult = body['error'] ?? 'Erro ao criar usuário.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _createOk     = false;
        _createResult = 'Erro de conexão: $e';
      });
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // ── Tab bar ────────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabs,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.login_rounded, size: 18), text: 'Métodos de Login'),
                Tab(icon: Icon(Icons.person_add_rounded, size: 18), text: 'Criar Usuário'),
              ],
            ),
          ),

          // ── Conteúdo das abas ─────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _buildLoginMethodsTab(),
                _buildCreateUserTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Aba 1: Métodos de Login ───────────────────────────────────────────────
  Widget _buildLoginMethodsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header
          _SectionHeader(
            icon: Icons.security_rounded,
            title: 'Métodos de Acesso',
            subtitle: 'Controle como os usuários podem entrar no app',
          ),
          const SizedBox(height: 20),

          // Preview card
          _PreviewCard(config: _draft),
          const SizedBox(height: 20),

          // Card de toggles
          _GroupCard(
            icon: Icons.toggle_on_rounded,
            title: 'Login Social',
            subtitle: 'Opções de login com redes sociais',
            accentColor: const Color(0xFF4285F4),
            children: [
              _LoginToggle(
                icon: Icons.g_mobiledata_rounded,
                iconColor: const Color(0xFFEA4335),
                label: 'Login com Google',
                subtitle: 'Permite entrar usando conta Google',
                value: _draft.loginGoogle,
                onChanged: (v) => setState(() =>
                    _draft = _draft.copyWith(loginGoogle: v)),
              ),
              _LoginToggle(
                icon: Icons.facebook_rounded,
                iconColor: const Color(0xFF1877F2),
                label: 'Login com Facebook',
                subtitle: 'Permite entrar usando conta Facebook',
                value: _draft.loginFacebook,
                onChanged: (v) => setState(() =>
                    _draft = _draft.copyWith(loginFacebook: v)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _GroupCard(
            icon: Icons.app_registration_rounded,
            title: 'Cadastro Público',
            subtitle: 'Permite que usuários se cadastrem sozinhos',
            accentColor: const Color(0xFF00BFA5),
            children: [
              _LoginToggle(
                icon: Icons.how_to_reg_rounded,
                iconColor: AppColors.primary,
                label: 'Cadastro público ativo',
                subtitle: 'Mostra "Cadastre-se" na tela de login e permite registro público',
                value: _draft.loginCadastroPublico,
                onChanged: (v) => setState(() =>
                    _draft = _draft.copyWith(loginCadastroPublico: v)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Aviso quando cadastro está desativado
          if (!_draft.loginCadastroPublico)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppColors.warning, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Cadastro público desativado. Use a aba "Criar Usuário" para adicionar novos afiliados manualmente.',
                      style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),

          // Botões salvar / reset
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _reset,
                  icon: const Icon(Icons.restore_rounded, size: 18),
                  label: const Text('Resetar'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    foregroundColor: AppColors.textSecondary,
                    side: BorderSide(color: AppColors.textHint.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(_saving ? 'Salvando...' : 'Salvar Configurações'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── Aba 2: Criar Usuário ──────────────────────────────────────────────────
  Widget _buildCreateUserTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.person_add_alt_1_rounded,
            title: 'Criar Usuário Manualmente',
            subtitle: 'O admin cria login e senha para o usuário diretamente',
          ),
          const SizedBox(height: 20),

          // Resultado da criação
          if (_createResult != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _createOk
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _createOk
                      ? AppColors.success.withValues(alpha: 0.4)
                      : AppColors.error.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _createOk ? Icons.check_circle_rounded : Icons.error_rounded,
                    color: _createOk ? AppColors.success : AppColors.error,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _createResult!,
                      style: TextStyle(
                        fontSize: 13,
                        color: _createOk ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Formulário
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE8EBF0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10, offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nome
                  TextFormField(
                    controller: _nomeCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Nome completo *',
                      prefixIcon: const Icon(Icons.person_outline_rounded,
                          color: AppColors.primary),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFFF8F9FA),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                  ),
                  const SizedBox(height: 14),

                  // E-mail
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'E-mail *',
                      prefixIcon: const Icon(Icons.email_outlined,
                          color: AppColors.primary),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFFF8F9FA),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Informe o e-mail';
                      if (!v.contains('@')) return 'E-mail inválido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Senha
                  TextFormField(
                    controller: _senhaCtrl,
                    obscureText: !_showPass,
                    decoration: InputDecoration(
                      labelText: 'Senha *',
                      prefixIcon: const Icon(Icons.lock_outline_rounded,
                          color: AppColors.primary),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showPass
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: AppColors.textHint,
                        ),
                        onPressed: () => setState(() => _showPass = !_showPass),
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFFF8F9FA),
                      helperText: 'Mínimo 6 caracteres',
                    ),
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                  ),
                  const SizedBox(height: 14),

                  // Código patrocinador (opcional)
                  TextFormField(
                    controller: _sponsorCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Código do patrocinador (opcional)',
                      prefixIcon: const Icon(Icons.people_alt_outlined,
                          color: AppColors.textHint),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFFF8F9FA),
                      helperText: 'Deixe vazio se não tiver patrocinador',
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Botão criar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _creating ? null : _createUser,
                      icon: _creating
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.person_add_rounded, size: 20),
                      label: Text(
                        _creating ? 'Criando usuário...' : 'Criar Usuário',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Info box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: AppColors.primary, size: 16),
                    SizedBox(width: 6),
                    Text('Como funciona',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            fontSize: 13)),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '• O usuário é criado no Firebase com e-mail + senha\n'
                  '• Um código de afiliado único é gerado automaticamente\n'
                  '• O usuário já pode fazer login com as credenciais informadas\n'
                  '• Passe o e-mail e senha para o usuário por WhatsApp/e-mail',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Preview visual da tela de login ──────────────────────────────────────────
class _PreviewCard extends StatelessWidget {
  final AppLoginConfig config;
  const _PreviewCard({required this.config});

  @override
  Widget build(BuildContext context) {
    final showSocial   = config.loginGoogle || config.loginFacebook;
    final showCadastro = config.loginCadastroPublico;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EBF0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.preview_rounded, size: 16, color: AppColors.textHint),
              const SizedBox(width: 6),
              Text('Preview da tela de login',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          // Simulação visual compacta
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE0E4EA)),
            ),
            child: Column(
              children: [
                // Campos de email/senha sempre visíveis
                _PreviewField(icon: Icons.email_outlined, label: 'E-mail'),
                const SizedBox(height: 6),
                _PreviewField(icon: Icons.lock_outline_rounded, label: 'Senha'),
                const SizedBox(height: 8),
                // Botão entrar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('Entrar',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ),
                ),
                // Botões sociais (se algum ativo)
                if (showSocial) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('ou entre com',
                          style: TextStyle(
                              fontSize: 10, color: AppColors.textHint)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (config.loginGoogle)
                        Expanded(
                          child: _PreviewSocialBtn(
                            label: 'Google',
                            color: const Color(0xFFEA4335),
                          ),
                        ),
                      if (config.loginGoogle && config.loginFacebook)
                        const SizedBox(width: 6),
                      if (config.loginFacebook)
                        Expanded(
                          child: _PreviewSocialBtn(
                            label: 'Facebook',
                            color: const Color(0xFF1877F2),
                          ),
                        ),
                    ],
                  ),
                ],
                // Cadastre-se
                if (showCadastro) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Não tem conta? ',
                          style: TextStyle(
                              fontSize: 10, color: AppColors.textSecondary)),
                      Text('Cadastre-se',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewField extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PreviewField({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFDDE1E9)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textHint)),
        ],
      ),
    );
  }
}

class _PreviewSocialBtn extends StatelessWidget {
  final String label;
  final Color color;
  const _PreviewSocialBtn({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Center(
        child: Text(label,
            style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SectionHeader(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: AppColors.greenGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final List<Widget> children;

  const _GroupCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EBF0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header do card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: accentColor, size: 17),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.textPrimary)),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: const Color(0xFFE8EBF0)),
          ...children.map((c) => Column(
                children: [c, Divider(height: 1, color: const Color(0xFFE8EBF0))],
              )),
        ],
      ),
    );
  }
}

class _LoginToggle extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _LoginToggle({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: value
                          ? AppColors.textPrimary
                          : AppColors.textHint,
                    )),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
