import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firebase_user_service.dart';
import '../../services/cf_api_service.dart';
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

  // -- Cadastro/Login via Google -------------------------------------------------
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
        // Verifica se precisa completar dados (CPF / telefone)
        final user = auth.currentUser;
        final precisaCompletar = (user?.cpf.isEmpty ?? true) ||
            (user?.telefone.isEmpty ?? true);
        if (precisaCompletar && mounted) {
          await _mostrarCompletarCadastro(context, auth);
        } else {
          _showSuccessDialog(false);
        }
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

  // -- Cadastro/Login via Facebook -----------------------------------------------
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
        // Verifica se precisa completar dados (CPF / telefone)
        final user = auth.currentUser;
        final precisaCompletar = (user?.cpf.isEmpty ?? true) ||
            (user?.telefone.isEmpty ?? true);
        if (precisaCompletar && mounted) {
          await _mostrarCompletarCadastro(context, auth);
        } else {
          _showSuccessDialog(false);
        }
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

  // -- Modal: completar dados após login social ---------------------------------
  Future<void> _mostrarCompletarCadastro(
      BuildContext context, AuthService auth) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _CompletarCadastroSheet(
        uid: auth.currentUser?.id ?? '',
        nomeAtual: auth.currentUser?.nome ?? '',
        emailAtual: auth.currentUser?.email ?? '',
      ),
    );

    if (!mounted) return;
    await auth.refreshProfile();
    _showSuccessDialog(false);
  }

  void _showSuccessDialog([bool walletCreated = false]) {
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
              'Sua conta foi criada com sucesso. Você já pode compartilhar seu link e começar a ganhar comissões!',
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
              child: const Row(
                children: [
                  Icon(Icons.pix_rounded, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pagamentos processados via Woovi',
                      style: TextStyle(
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            // scale: 700px = 1.0 (referência); telas menores diminuem proporcionalmente
            final double scale = (constraints.maxHeight / 700).clamp(0.60, 1.0);
            final double fieldHeight = 48.0 * scale;
            final double gap = 10.0 * scale;
            final double hPad = 16.0 * scale;
            final double iconSz = 18.0 * scale;
            final double labelSz = 13.0 * scale;
            final double hintSz = 12.0 * scale;
            final double btnH = 44.0 * scale;

            return Form(
              key: _formKey,
              child: Column(
                children: [
                  // ── Barra de progresso ──────────────────────────────────
                  Container(
                    color: AppColors.primary,
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 10 * scale),
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

                  // ── Conteúdo principal ──────────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                          horizontal: hPad, vertical: gap),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Banner "indicado por" (opcional)
                          if (_sponsorController.text.isNotEmpty) ...[
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(10 * scale),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: AppColors.gold
                                        .withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.person_add_rounded,
                                      color: AppColors.gold, size: iconSz),
                                  SizedBox(width: 8 * scale),
                                  Text(
                                    'Indicado por: ${_sponsorController.text}',
                                    style: TextStyle(
                                        color: AppColors.goldDark,
                                        fontWeight: FontWeight.w600,
                                        fontSize: hintSz),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: gap),
                          ],

                          // ── Campos do formulário ──────────────────────
                          _buildScaledField(
                            controller: _nomeController,
                            label: 'Nome completo',
                            icon: Icons.person_rounded,
                            fieldHeight: fieldHeight,
                            iconSz: iconSz,
                            labelSz: labelSz,
                            validator: (v) => v!.trim().split(' ').length < 2
                                ? 'Informe nome e sobrenome'
                                : null,
                          ),
                          SizedBox(height: gap),
                          _buildScaledField(
                            controller: _cpfController,
                            label: 'CPF',
                            icon: Icons.badge_rounded,
                            keyboardType: TextInputType.number,
                            hint: '000.000.000-00',
                            fieldHeight: fieldHeight,
                            iconSz: iconSz,
                            labelSz: labelSz,
                            hintSz: hintSz,
                            validator: (v) =>
                                v!.length < 11 ? 'CPF inválido' : null,
                          ),
                          SizedBox(height: gap),
                          _buildScaledField(
                            controller: _emailController,
                            label: 'E-mail',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            fieldHeight: fieldHeight,
                            iconSz: iconSz,
                            labelSz: labelSz,
                            validator: (v) =>
                                !v!.contains('@') ? 'E-mail inválido' : null,
                          ),
                          SizedBox(height: gap),
                          _buildScaledField(
                            controller: _telefoneController,
                            label: 'Telefone / WhatsApp',
                            icon: Icons.phone_rounded,
                            keyboardType: TextInputType.phone,
                            hint: '(11) 99999-9999',
                            fieldHeight: fieldHeight,
                            iconSz: iconSz,
                            labelSz: labelSz,
                            hintSz: hintSz,
                            validator: (v) =>
                                v!.length < 10 ? 'Telefone inválido' : null,
                          ),
                          SizedBox(height: gap),

                          // Senha (com toggle)
                          SizedBox(
                            height: fieldHeight,
                            child: TextFormField(
                              controller: _senhaController,
                              obscureText: !_showPassword,
                              style: TextStyle(fontSize: labelSz),
                              decoration: InputDecoration(
                                labelText: 'Senha',
                                labelStyle: TextStyle(fontSize: labelSz),
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: (fieldHeight - labelSz * 1.4) / 2),
                                prefixIcon: Icon(Icons.lock_outline_rounded,
                                    color: AppColors.primary, size: iconSz),
                                prefixIconConstraints: BoxConstraints(
                                    minWidth: iconSz + 24,
                                    minHeight: fieldHeight),
                                suffixIcon: IconButton(
                                  iconSize: iconSz,
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    _showPassword
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    color: AppColors.textHint,
                                    size: iconSz,
                                  ),
                                  onPressed: () => setState(
                                      () => _showPassword = !_showPassword),
                                ),
                              ),
                              validator: (v) =>
                                  v!.length < 6 ? 'Mínimo 6 caracteres' : null,
                            ),
                          ),
                          SizedBox(height: gap),
                          _buildScaledField(
                            controller: _confirmarController,
                            label: 'Confirmar senha',
                            icon: Icons.lock_rounded,
                            obscure: true,
                            fieldHeight: fieldHeight,
                            iconSz: iconSz,
                            labelSz: labelSz,
                            validator: (v) => v != _senhaController.text
                                ? 'Senhas não conferem'
                                : null,
                          ),
                          SizedBox(height: gap),
                          _buildScaledField(
                            controller: _sponsorController,
                            label: 'Código do afiliado (opcional)',
                            icon: Icons.link_rounded,
                            hint: 'Ex: ABC123',
                            fieldHeight: fieldHeight,
                            iconSz: iconSz,
                            labelSz: labelSz,
                            hintSz: hintSz,
                          ),
                          SizedBox(height: gap),

                          // ── Aceite de termos ──────────────────────────
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 32 * scale,
                                height: 32 * scale,
                                child: Checkbox(
                                  value: _aceitouTermos,
                                  onChanged: (v) => setState(
                                      () => _aceitouTermos = v ?? false),
                                  activeColor: AppColors.primary,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                              SizedBox(width: 6 * scale),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: hintSz),
                                    children: const [
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
                            ],
                          ),
                          SizedBox(height: gap * 1.4),

                          // ── Botão principal ───────────────────────────
                          SizedBox(
                            height: btnH,
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: auth.isLoading || _socialLoading
                                  ? null
                                  : _register,
                              icon: auth.isLoading
                                  ? SizedBox(
                                      width: iconSz,
                                      height: iconSz,
                                      child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white))
                                  : Icon(Icons.rocket_launch_rounded,
                                      size: iconSz, color: Colors.white),
                              label: Text(
                                'Criar Conta Grátis',
                                style: TextStyle(
                                    fontSize: labelSz,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          SizedBox(height: gap * 1.4),

                          // ── Divisor "ou cadastre-se com" ──────────────
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color:
                                      AppColors.textHint.withValues(alpha: 0.4),
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10 * scale),
                                child: Text(
                                  'ou cadastre-se com',
                                  style: TextStyle(
                                      color: AppColors.textHint,
                                      fontSize: hintSz),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color:
                                      AppColors.textHint.withValues(alpha: 0.4),
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: gap),

                          // ── Botões sociais ────────────────────────────
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
                                  height: btnH,
                                  fontSize: labelSz,
                                  iconSz: iconSz,
                                ),
                              ),
                              SizedBox(width: 10 * scale),
                              Expanded(
                                child: _RegisterSocialButton(
                                  label: 'Facebook',
                                  icon: Icon(
                                    Icons.facebook_rounded,
                                    color: const Color(0xFF1877F2),
                                    size: iconSz,
                                  ),
                                  onPressed: _socialLoading || auth.isLoading
                                      ? null
                                      : _registerWithFacebook,
                                  isLoading: _socialLoading,
                                  height: btnH,
                                  fontSize: labelSz,
                                  iconSz: iconSz,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: gap),

                          // ── Rodapé segurança ──────────────────────────
                          Center(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10 * scale,
                                  vertical: 6 * scale),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.security_rounded,
                                      color: AppColors.primary, size: iconSz),
                                  SizedBox(width: 5 * scale),
                                  Text(
                                    'Pagamentos seguros via Woovi PIX',
                                    style: TextStyle(
                                        fontSize: hintSz,
                                        color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: gap),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Mantido para compatibilidade (não usado na tela principal mas pode ser usado em outros lugares)
  Widget _buildScaledField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required double fieldHeight,
    required double iconSz,
    required double labelSz,
    double? hintSz,
    TextInputType? keyboardType,
    String? hint,
    bool obscure = false,
    String? Function(String?)? validator,
  }) {
    final double fHintSz = hintSz ?? labelSz;
    return SizedBox(
      height: fieldHeight,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        style: TextStyle(fontSize: labelSz),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(fontSize: labelSz),
          hintStyle: TextStyle(fontSize: fHintSz),
          contentPadding: EdgeInsets.symmetric(
              vertical: (fieldHeight - labelSz * 1.4) / 2),
          prefixIcon: Icon(icon, color: AppColors.primary, size: iconSz),
          prefixIconConstraints:
              BoxConstraints(minWidth: iconSz + 24, minHeight: fieldHeight),
        ),
        validator: validator,
      ),
    );
  }

}

// -- Widget: Botão Social para Cadastro ---------------------------------------

class _RegisterSocialButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double height;
  final double fontSize;
  final double iconSz;

  const _RegisterSocialButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
    this.height = 44,
    this.fontSize = 13,
    this.iconSz = 18,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: BorderSide(
            color: AppColors.textHint.withValues(alpha: 0.4),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: Colors.white,
        ),
        child: isLoading
            ? SizedBox(
                width: iconSz,
                height: iconSz,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: iconSz, height: iconSz, child: icon),
                  SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: fontSize,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// -- Widget: Ícone Google para Cadastro ---------------------------------------

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

// -- Modal: Completar cadastro após login social -------------------------------
class _CompletarCadastroSheet extends StatefulWidget {
  final String uid;
  final String nomeAtual;
  final String emailAtual;

  const _CompletarCadastroSheet({
    required this.uid,
    required this.nomeAtual,
    required this.emailAtual,
  });

  @override
  State<_CompletarCadastroSheet> createState() =>
      _CompletarCadastroSheetState();
}

class _CompletarCadastroSheetState
    extends State<_CompletarCadastroSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeCtrl;
  final _cpfCtrl      = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nomeCtrl = TextEditingController(text: widget.nomeAtual);
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _cpfCtrl.dispose();
    _telefoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final nome     = _nomeCtrl.text.trim();
      final cpf      = _cpfCtrl.text.trim();
      final telefone = _telefoneCtrl.text.trim();

      // Salva no Firestore
      await FirebaseUserService.atualizarPerfil(
        uid: widget.uid,
        nome: nome,
        cpf: cpf,
        telefone: telefone,
        pixKey: widget.emailAtual,
      );

      // Sincroniza no D1
      await CfApiService.updateAffiliate(widget.uid, {
        'nome': nome,
        'cpf': cpf,
        'telefone': telefone,
      });

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),

              // Título
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person_add_rounded,
                        color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Complete seu cadastro',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary)),
                        Text(
                          'Precisamos de mais alguns dados para ativar sua conta',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Banner informativo
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.primary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Estes dados são necessários para processar seus saques via PIX.',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Nome completo
              TextFormField(
                controller: _nomeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome completo *',
                  prefixIcon: Icon(Icons.person_rounded,
                      color: AppColors.primary),
                ),
                validator: (v) => v!.trim().split('').length < 2
                    ? 'Informe nome e sobrenome'
                    : null,
              ),
              const SizedBox(height: 12),

              // CPF
              TextFormField(
                controller: _cpfCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'CPF *',
                  hintText: '000.000.000-00',
                  prefixIcon:
                      Icon(Icons.badge_rounded, color: AppColors.primary),
                ),
                validator: (v) =>
                    v!.replaceAll(RegExp(r'\D'), '').length < 11
                        ? 'CPF inválido'
                        : null,
              ),
              const SizedBox(height: 12),

              // Telefone
              TextFormField(
                controller: _telefoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Celular / WhatsApp *',
                  hintText: '(11) 99999-9999',
                  prefixIcon: Icon(Icons.phone_rounded,
                      color: AppColors.primary),
                ),
                validator: (v) =>
                    v!.replaceAll(RegExp(r'\D'), '').length < 10
                        ? 'Número inválido'
                        : null,
              ),
              const SizedBox(height: 24),

              // Botão salvar
              PrimaryButton(
                label: 'Salvar e Continuar',
                icon: Icons.check_circle_rounded,
                isLoading: _loading,
                onPressed: _loading ? null : _salvar,
              ),
              const SizedBox(height: 8),

              // Pular (opcional)
              Center(
                child: TextButton(
                  onPressed: _loading
                      ? null
                      : () => Navigator.pop(context, false),
                  child: const Text(
                    'Pular por agora (você pode completar no perfil)',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textHint),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
