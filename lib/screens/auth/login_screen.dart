import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _showPassword = false;
  bool _socialLoading = false;

  @override
  void initState() {
    super.initState();
    // Verifica redirect pendente do Google Sign-In (web)
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkRedirectResult());
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  // Verifica se voltou de um redirect do Google Sign-In
  Future<void> _checkRedirectResult() async {
    final result = await FirebaseAuthService.getRedirectResult();
    if (!mounted || result == null) return;
    if (result.success) {
      final auth = context.read<AuthService>();
      final ok = await auth.loginWithFirebase(
        uid: result.uid!,
        email: result.email ?? '',
        displayName: result.displayName,
        idToken: result.idToken,
        provider: 'google',
      );
      if (!mounted) return;
      if (ok) Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthService>();
    final ok = await auth.login(_emailController.text.trim(), _senhaController.text);
    if (!mounted) return;
    if (ok) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Erro ao fazer login'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ── Login com Google ──────────────────────────────────────────────────────────
  Future<void> _loginWithGoogle() async {
    setState(() => _socialLoading = true);
    final auth = context.read<AuthService>();

    final result = await FirebaseAuthService.signInWithGoogle();
    if (!mounted) return;
    setState(() => _socialLoading = false);

    if (result.success) {
      final ok = await auth.loginWithFirebase(
        uid: result.uid!,
        email: result.email ?? '',
        displayName: result.displayName,
        idToken: result.idToken,
        provider: 'google',
      );
      if (!mounted) return;
      if (ok) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        _showError(auth.error ?? 'Erro ao entrar com Google');
      }
    } else {
      final err = result.error ?? '';
      if (err == 'UNAUTHORIZED_DOMAIN') {
        _showDomainError();
      } else if (err.startsWith('FIREBASE_ERR:') || err.startsWith('ERR:')) {
        // Mostra erro real para diagnóstico
        _showError(err);
      } else if (err.isNotEmpty && err != 'Login com Google cancelado.') {
        _showError(err);
      }
    }
  }

  // ── Login com Facebook ────────────────────────────────────────────────────────
  Future<void> _loginWithFacebook() async {
    setState(() => _socialLoading = true);
    final auth = context.read<AuthService>();

    final result = await FirebaseAuthService.signInWithFacebook();
    if (!mounted) return;
    setState(() => _socialLoading = false);

    if (result.success) {
      // Em modo Dev do Meta, email pode vir null — usar uid como fallback
      final fbEmail = (result.email?.isNotEmpty == true)
          ? result.email!
          : '${result.uid}@facebook-login.com';

      final ok = await auth.loginWithFirebase(
        uid: result.uid!,
        email: fbEmail,
        displayName: result.displayName,
        idToken: result.idToken,
        provider: 'facebook',
      );
      if (!mounted) return;
      if (ok) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        _showError(auth.error ?? 'Erro ao entrar com Facebook');
      }
    } else {
      final err = result.error ?? '';
      if (err == 'FACEBOOK_NOT_CONFIGURED') {
        _showFacebookConfigError();
      } else if (err == 'FACEBOOK_DOMAIN_ERROR') {
        _showFacebookDomainError();
      } else if (err.isNotEmpty && err != 'Login com Facebook cancelado.') {
        _showError(err);
      }
    }
  }

  // ── Esqueceu a senha ──────────────────────────────────────────────────────────
  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('Informe seu e-mail para redefinir a senha.');
      return;
    }
    final result = await FirebaseAuthService.sendPasswordReset(email);
    if (!mounted) return;
    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('E-mail de redefinição enviado para $email'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      _showError(result.error ?? 'Erro ao enviar e-mail.');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  // ── Dialog: Facebook não configurado ─────────────────────────────────────────
  void _showFacebookConfigError() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.settings_outlined, color: Color(0xFF1877F2), size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Facebook Login — Configuração necessária',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Para ativar o login com Facebook, siga estes passos:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 14),
            _StepItem(
              step: '1',
              text: 'Acesse developers.facebook.com → Crie ou use um app existente',
            ),
            _StepItem(
              step: '2',
              text: 'Adicione o produto "Login do Facebook" ao seu app Meta',
            ),
            _StepItem(
              step: '3',
              text: 'Copie o App ID e o App Secret do painel Meta',
            ),
            _StepItem(
              step: '4',
              text: 'No Firebase Console → Authentication → Sign-in method → Facebook → ative e cole o App ID + Secret',
            ),
            _StepItem(
              step: '5',
              text: 'No Meta Console → Configurações → Login do Facebook → URIs de redirecionamento OAuth válidos → adicione:\nhttps://affiliate-wallet-75853.firebaseapp.com/__/auth/handler',
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1877F2).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1877F2).withValues(alpha: 0.25)),
              ),
              child: const Text(
                '💡 Enquanto isso, use login com Google ou e-mail e senha.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF1877F2),
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1877F2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  // ── Dialog: Facebook — domínio não autorizado ─────────────────────────────────
  void _showFacebookDomainError() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.gold, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Domínio não autorizado no Facebook',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'O domínio de preview não está autorizado no Meta for Developers.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 14),
            _StepItem(
              step: '1',
              text: 'Acesse developers.facebook.com → Seu App → Configurações → Básico',
            ),
            _StepItem(
              step: '2',
              text: 'Em "Domínios do App", adicione:\nsandbox.novita.ai',
            ),
            _StepItem(
              step: '3',
              text: 'Salve e tente novamente.',
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: const Text(
                '💡 Enquanto isso, use login com Google ou e-mail e senha.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  void _showDomainError() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.gold, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Google não autorizado neste domínio',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Para ativar o Google Sign-In neste ambiente de preview, adicione o domínio no Firebase Console:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 14),
            _StepItem(
              step: '1',
              text: 'Acesse Firebase Console → Authentication → Settings',
            ),
            _StepItem(
              step: '2',
              text: 'Aba "Authorized domains" → clique em Add domain',
            ),
            _StepItem(
              step: '3',
              text: 'Adicione: sandbox.novita.ai\nSalve e tente novamente.',
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: const Text(
                '💡 Enquanto isso, use login com e-mail e senha — funciona normalmente.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGreenGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Expanded(
                flex: 2,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E5B4).withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.asset(
                            'assets/images/sharewallet_logo.png',
                            width: 80, height: 80, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.account_balance_wallet_rounded,
                              color: Colors.white, size: 45,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: 'Share',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            TextSpan(
                              text: 'Wallet',
                              style: TextStyle(
                                color: Color(0xFF00E5B4),
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Transforme conexões em receita recorrente.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),

              // Form
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Entrar',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Acesse sua conta de afiliado',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                          ),
                          const SizedBox(height: 28),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'E-mail',
                              prefixIcon: Icon(Icons.email_outlined, color: AppColors.primary),
                            ),
                            validator: (v) =>
                                v!.isEmpty ? 'Informe seu e-mail' : null,
                          ),
                          const SizedBox(height: 16),
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
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _forgotPassword,
                              child: const Text('Esqueceu a senha?',
                                  style: TextStyle(color: AppColors.primary)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          PrimaryButton(
                            label: 'Entrar',
                            onPressed: auth.isLoading || _socialLoading ? null : _login,
                            isLoading: auth.isLoading,
                            icon: Icons.login_rounded,
                          ),

                          // ── Divisor "ou" ──────────────────────────────────
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
                                  'ou entre com',
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

                          // ── Botões sociais ────────────────────────────────
                          Row(
                            children: [
                              // Google
                              Expanded(
                                child: _SocialButton(
                                  label: 'Google',
                                  icon: _GoogleIcon(),
                                  onPressed: _socialLoading || auth.isLoading
                                      ? null
                                      : _loginWithGoogle,
                                  isLoading: _socialLoading,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Facebook / Meta
                              Expanded(
                                child: _SocialButton(
                                  label: 'Facebook',
                                  icon: const Icon(
                                    Icons.facebook_rounded,
                                    color: Color(0xFF1877F2),
                                    size: 22,
                                  ),
                                  onPressed: _socialLoading || auth.isLoading
                                      ? null
                                      : _loginWithFacebook,
                                  isLoading: _socialLoading,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Não tem conta? ',
                                  style: TextStyle(color: AppColors.textSecondary)),
                              GestureDetector(
                                onTap: () =>
                                    Navigator.pushNamed(context, '/register'),
                                child: const Text(
                                  'Cadastre-se',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
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

// ── Widget: Botão Social (Google / Facebook) ──────────────────────────────────

class _SocialButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _SocialButton({
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

// ── Widget: Ícone Google (letras coloridas G) ─────────────────────────────────

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GoogleIconPainter(),
    );
  }
}

class _GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Vermelho (topo-direita)
    final paintRed = Paint()..color = const Color(0xFFEA4335);
    // Azul (esquerda)
    final paintBlue = Paint()..color = const Color(0xFF4285F4);
    // Amarelo (baixo-direita)
    final paintYellow = Paint()..color = const Color(0xFFFBBC05);
    // Verde (baixo-esquerda)
    final paintGreen = Paint()..color = const Color(0xFF34A853);

    // Círculo de fundo branco
    canvas.drawCircle(center, radius, Paint()..color = Colors.white);

    // Arco vermelho
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.85),
      -1.1,
      2.2,
      true,
      paintRed,
    );
    // Arco azul
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.85),
      1.1,
      2.2,
      true,
      paintBlue,
    );
    // Arco amarelo
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.85),
      -1.1 + 3.14 / 2,
      1.1,
      true,
      paintYellow,
    );
    // Arco verde
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.85),
      1.1 + 3.14 / 2,
      1.1,
      true,
      paintGreen,
    );

    // Círculo branco central para o "G"
    canvas.drawCircle(center, radius * 0.55, Paint()..color = Colors.white);

    // Barra branca horizontal do "G"
    final barPaint = Paint()..color = paintBlue.color;
    canvas.drawRect(
      Rect.fromLTWH(center.dx, center.dy - radius * 0.12,
          radius * 0.7, radius * 0.24),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Widget: Step item para o dialog de erro de domínio ───────────────────────

class _StepItem extends StatelessWidget {
  final String step;
  final String text;
  const _StepItem({required this.step, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              step,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
