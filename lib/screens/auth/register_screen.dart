import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';

class RegisterScreen extends StatefulWidget {
  final String? sponsorCode;
  const RegisterScreen({super.key, this.sponsorCode});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _cpfController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarController = TextEditingController();
  final _sponsorController = TextEditingController();
  bool _showPassword = false;
  bool _aceitouTermos = false;
  bool _socialLoading = false;
  // ignore: prefer_final_fields
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    if (widget.sponsorCode != null) {
      _sponsorController.text = widget.sponsorCode!;
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _cpfController.dispose();
    _emailController.dispose();
    _telefoneController.dispose();
    _senhaController.dispose();
    _confirmarController.dispose();
    _sponsorController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_aceitouTermos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aceite os termos para continuar'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final auth = context.read<AuthService>();
    final result = await auth.register(
      nome: _nomeController.text.trim(),
      cpf: _cpfController.text.trim(),
      email: _emailController.text.trim(),
      telefone: _telefoneController.text.trim(),
      senha: _senhaController.text,
      pixKey: _emailController.text.trim(), // usa email como chave PIX padrão
      pixKeyType: 'EMAIL',
      sponsorCode: _sponsorController.text.trim().isEmpty
          ? null
          : _sponsorController.text.trim(),
    );

    if (!mounted) return;
    if (result.success) {
      _showSuccessDialog(result.walletCreated);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ── Cadastro/Login via Google ─────────────────────────────────────────────────
  Future<void> _registerWithGoogle() async {
    setState(() => _socialLoading = true);
    final auth = context.read<AuthService>();

    final result = await FirebaseAuthService.signInWithGoogle();
    if (!mounted) return;

    if (result.success) {
      // Cria/busca afiliado no backend via Firebase UID
      final ok = await auth.loginWithFirebase(
        uid: result.uid!,
        email: result.email ?? '',
        displayName: result.displayName,
        idToken: result.idToken,
        provider: 'google',
        sponsorCode: _sponsorController.text.trim().isEmpty
            ? null
            : _sponsorController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _socialLoading = false);
      if (ok) {
        _showSuccessDialog(false);
      } else {
        _showError(auth.error ?? 'Erro ao criar conta com Google');
      }
    } else {
      setState(() => _socialLoading = false);
      if (result.error != null && result.error != 'Login com Google cancelado.') {
        _showError(result.error!);
      }
    }
  }

  // ── Cadastro/Login via Facebook ───────────────────────────────────────────────
  Future<void> _registerWithFacebook() async {
    setState(() => _socialLoading = true);
    final auth = context.read<AuthService>();

    final result = await FirebaseAuthService.signInWithFacebook();
    if (!mounted) return;

    if (result.success) {
      final ok = await auth.loginWithFirebase(
        uid: result.uid!,
        email: result.email ?? '',
        displayName: result.displayName,
        idToken: result.idToken,
        provider: 'facebook',
        sponsorCode: _sponsorController.text.trim().isEmpty
            ? null
            : _sponsorController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _socialLoading = false);
      if (ok) {
        _showSuccessDialog(false);
      } else {
        _showError(auth.error ?? 'Erro ao criar conta com Facebook');
      }
    } else {
      setState(() => _socialLoading = false);
      if (result.error != null && result.error != 'Login com Facebook cancelado.') {
        _showError(result.error!);
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  void _showSuccessDialog([bool wooviCreated = false]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 60),
            ),
            const SizedBox(height: 16),
            const Text('Conta criada!',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text(
              'Sua subconta PIX Woovi foi criada automaticamente. Você já pode receber comissões!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pix_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      wooviCreated
                          ? 'Subconta Woovi ativada via PIX'
                          : 'Configure sua chave PIX no Perfil',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PrimaryButton(
            label: 'Ir para o Painel',
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacementNamed(context, '/home');
            },
            icon: Icons.dashboard_rounded,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Criar Conta'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Steps
              Container(
                color: AppColors.primary,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: List.generate(3, (i) {
                    return Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: i <= _currentStep
                                    ? AppColors.gold
                                    : Colors.white.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          if (i < 2) const SizedBox(width: 4),
                        ],
                      ),
                    );
                  }),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_sponsorController.text.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppColors.gold.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person_add_rounded,
                                  color: AppColors.gold, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Indicado por: ${_sponsorController.text}',
                                style: const TextStyle(
                                    color: AppColors.goldDark,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _buildField(
                        controller: _nomeController,
                        label: 'Nome completo',
                        icon: Icons.person_rounded,
                        validator: (v) =>
                            v!.trim().split(' ').length < 2 ? 'Informe nome e sobrenome' : null,
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        controller: _cpfController,
                        label: 'CPF',
                        icon: Icons.badge_rounded,
                        keyboardType: TextInputType.number,
                        hint: '000.000.000-00',
                        validator: (v) => v!.length < 11 ? 'CPF inválido' : null,
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        controller: _emailController,
                        label: 'E-mail',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) =>
                            !v!.contains('@') ? 'E-mail inválido' : null,
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        controller: _telefoneController,
                        label: 'Telefone / WhatsApp',
                        icon: Icons.phone_rounded,
                        keyboardType: TextInputType.phone,
                        hint: '(11) 99999-9999',
                        validator: (v) => v!.length < 10 ? 'Telefone inválido' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _senhaController,
                        obscureText: !_showPassword,
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: const Icon(Icons.lock_outline_rounded,
                              color: AppColors.primary),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: AppColors.textHint,
                            ),
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                          ),
                        ),
                        validator: (v) =>
                            v!.length < 6 ? 'Mínimo 6 caracteres' : null,
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        controller: _confirmarController,
                        label: 'Confirmar senha',
                        icon: Icons.lock_rounded,
                        obscure: true,
                        validator: (v) => v != _senhaController.text
                            ? 'Senhas não conferem'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        controller: _sponsorController,
                        label: 'Código do afiliado (opcional)',
                        icon: Icons.link_rounded,
                        hint: 'Ex: ABC123',
                      ),
                      const SizedBox(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _aceitouTermos,
                            onChanged: (v) =>
                                setState(() => _aceitouTermos = v ?? false),
                            activeColor: AppColors.primary,
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: RichText(
                                text: const TextSpan(
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13),
                                  children: [
                                    TextSpan(text: 'Aceito os '),
                                    TextSpan(
                                      text: 'Termos de Uso',
                                      style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    TextSpan(text: ' e a '),
                                    TextSpan(
                                      text: 'Política de Privacidade',
                                      style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        label: 'Criar Conta Grátis',
                        onPressed: auth.isLoading || _socialLoading
                            ? null
                            : _register,
                        isLoading: auth.isLoading,
                        icon: Icons.rocket_launch_rounded,
                      ),

                      // ── Divisor "ou cadastre-se com" ──────────────────────
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: AppColors.textHint.withValues(alpha: 0.4),
                              thickness: 1,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'ou cadastre-se com',
                              style: TextStyle(
                                color: AppColors.textHint,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: AppColors.textHint.withValues(alpha: 0.4),
                              thickness: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Botões sociais ────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: _RegisterSocialButton(
                              label: 'Google',
                              icon: _GoogleRegisterIcon(),
                              onPressed: _socialLoading || auth.isLoading
                                  ? null
                                  : _registerWithGoogle,
                              isLoading: _socialLoading,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _RegisterSocialButton(
                              label: 'Facebook',
                              icon: const Icon(
                                Icons.facebook_rounded,
                                color: Color(0xFF1877F2),
                                size: 22,
                              ),
                              onPressed: _socialLoading || auth.isLoading
                                  ? null
                                  : _registerWithFacebook,
                              isLoading: _socialLoading,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.pix_rounded,
                                  color: AppColors.primary, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Subconta Woovi criada automaticamente',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                              ),
                            ],
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? hint,
    bool obscure = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary),
      ),
      validator: validator,
    );
  }
}

// ── Widget: Botão Social para Cadastro ───────────────────────────────────────

class _RegisterSocialButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _RegisterSocialButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 13),
        side: BorderSide(
          color: AppColors.textHint.withValues(alpha: 0.4),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: Colors.white,
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 22, height: 22, child: icon),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Widget: Ícone Google para Cadastro ───────────────────────────────────────

class _GoogleRegisterIcon extends StatelessWidget {
  const _GoogleRegisterIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GooglePainter());
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = Colors.white);

    final colors = [
      const Color(0xFFEA4335),
      const Color(0xFF4285F4),
      const Color(0xFFFBBC05),
      const Color(0xFF34A853),
    ];

    for (int i = 0; i < 4; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r * 0.85),
        i * 1.57,
        1.57,
        true,
        Paint()..color = colors[i],
      );
    }
    canvas.drawCircle(c, r * 0.55, Paint()..color = Colors.white);
    canvas.drawRect(
      Rect.fromLTWH(c.dx, c.dy - r * 0.12, r * 0.7, r * 0.24),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
