import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _pulseController;

  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    // Logo: fade + scale elástico
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _logoFade = CurvedAnimation(parent: _logoController, curve: Curves.easeIn);
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    // Texto: fade + slide up
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _textFade = CurvedAnimation(parent: _textController, curve: Curves.easeIn);
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));

    // Pulse suave no loading indicator
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    // 1. Anima o logo
    await _logoController.forward();
    // 2. Texto aparece logo depois
    await Future.delayed(const Duration(milliseconds: 100));
    _textController.forward();

    // 3. Inicializa auth em paralelo
    if (!mounted) return;
    final auth = context.read<AuthService>();
    await auth.init();
    if (!mounted) return;

    // 4. Pausa mínima para o usuário ver a splash
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    if (auth.isLoggedIn) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      // Vai para landing page (pitch) antes do login
      Navigator.pushReplacementNamed(context, '/landing');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A1628), // azul escuro profundo
              Color(0xFF0D3B2E), // verde escuro
              Color(0xFF0A1628),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Partículas decorativas de fundo
              ..._buildDecorativeCircles(),

              // Conteúdo principal
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── Logo ──────────────────────────────────────────────
                    ScaleTransition(
                      scale: _logoScale,
                      child: FadeTransition(
                        opacity: _logoFade,
                        child: _ShareWalletLogo(),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Nome + tagline ────────────────────────────────────
                    SlideTransition(
                      position: _textSlide,
                      child: FadeTransition(
                        opacity: _textFade,
                        child: Column(
                          children: [
                            // Nome: Share + Wallet
                            RichText(
                              text: const TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Share',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 38,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'Wallet',
                                    style: TextStyle(
                                      color: Color(0xFF00E5B4), // teal vibrante
                                      fontSize: 38,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Tagline
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFF00E5B4).withValues(alpha: 0.3),
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                color: const Color(0xFF00E5B4).withValues(alpha: 0.06),
                              ),
                              child: const Text(
                                'Transforme suas conexões em receita recorrente.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.2,
                                  height: 1.5,
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

              // ── Loading indicator no rodapé ───────────────────────────
              Positioned(
                bottom: 48,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _textFade,
                  child: Column(
                    children: [
                      FadeTransition(
                        opacity: _pulse,
                        child: const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Color(0xFF00E5B4),
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Carregando...',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                          letterSpacing: 1.5,
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

  // Círculos decorativos de fundo
  List<Widget> _buildDecorativeCircles() {
    return [
      Positioned(
        top: -60,
        right: -60,
        child: _GlowCircle(
          size: 200,
          color: const Color(0xFF00E5B4).withValues(alpha: 0.06),
        ),
      ),
      Positioned(
        bottom: -80,
        left: -80,
        child: _GlowCircle(
          size: 280,
          color: const Color(0xFF0D5C3D).withValues(alpha: 0.3),
        ),
      ),
      Positioned(
        top: 120,
        left: -40,
        child: _GlowCircle(
          size: 120,
          color: const Color(0xFF00E5B4).withValues(alpha: 0.04),
        ),
      ),
    ];
  }
}

// ── Widget: Logo ShareWallet ──────────────────────────────────────────────────
class _ShareWalletLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5B4).withValues(alpha: 0.3),
            blurRadius: 40,
            spreadRadius: 5,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Image.asset(
          'assets/images/sharewallet_logo.png',
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _FallbackLogo(),
        ),
      ),
    );
  }
}

// Fallback caso o asset não carregue
class _FallbackLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A237E), Color(0xFF7B1FA2), Color(0xFF00BCD4)],
        ),
      ),
      child: const Icon(
        Icons.account_balance_wallet_rounded,
        color: Colors.white,
        size: 60,
      ),
    );
  }
}

// ── Widget: Círculo com glow ──────────────────────────────────────────────────
class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
