import 'package:flutter/material.dart';

/// Landing Page — Pitch de Cadastro da ShareWallet
/// Exibida após a splash, antes do login, para usuários não autenticados.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  late AnimationController _heroController;
  late AnimationController _cardsController;
  late AnimationController _ctaController;

  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;
  late Animation<double> _cardsFade;
  late Animation<Offset> _cardsSlide;
  late Animation<double> _ctaScale;

  @override
  void initState() {
    super.initState();

    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _heroFade =
        CurvedAnimation(parent: _heroController, curve: Curves.easeOut);
    _heroSlide = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _heroController, curve: Curves.easeOut));

    _cardsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _cardsFade =
        CurvedAnimation(parent: _cardsController, curve: Curves.easeOut);
    _cardsSlide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _cardsController, curve: Curves.easeOut));

    _ctaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _ctaScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _ctaController, curve: Curves.elasticOut),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    await _heroController.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    _cardsController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _ctaController.forward();
  }

  @override
  void dispose() {
    _heroController.dispose();
    _cardsController.dispose();
    _ctaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A1628),
              Color(0xFF0D3B2E),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: size.height - 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Hero Section ──────────────────────────────────────
                  SlideTransition(
                    position: _heroSlide,
                    child: FadeTransition(
                      opacity: _heroFade,
                      child: _HeroSection(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Pitch text ────────────────────────────────────────
                  FadeTransition(
                    opacity: _cardsFade,
                    child: _PitchSection(),
                  ),

                  const SizedBox(height: 24),

                  // ── Feature Cards ─────────────────────────────────────
                  SlideTransition(
                    position: _cardsSlide,
                    child: FadeTransition(
                      opacity: _cardsFade,
                      child: _FeatureCards(),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── CTA Buttons ───────────────────────────────────────
                  ScaleTransition(
                    scale: _ctaScale,
                    child: _CtaSection(
                      onCadastro: () =>
                          Navigator.pushNamed(context, '/register'),
                      onLogin: () => Navigator.pushNamed(context, '/login'),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Footer ────────────────────────────────────────────
                  _FooterSection(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hero Section ──────────────────────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
      child: Column(
        children: [
          // Logo
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5B4).withValues(alpha: 0.25),
                  blurRadius: 30,
                  spreadRadius: 4,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/images/sharewallet_logo.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1A237E), Color(0xFF00BCD4)],
                    ),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Nome da plataforma
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'Share',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                TextSpan(
                  text: 'Wallet',
                  style: TextStyle(
                    color: Color(0xFF00E5B4),
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Subtítulo
          const Text(
            'Transforme suas conexões estratégicas\nem receita recorrente.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w400,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pitch Section ─────────────────────────────────────────────────────────────
class _PitchSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color(0xFF00E5B4).withValues(alpha: 0.2),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF00E5B4).withValues(alpha: 0.04),
      ),
      child: Column(
        children: [
          // Ícone decorativo
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5B4).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.hub_rounded,
                  color: Color(0xFF00E5B4),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Bem-vindo à ShareWallet',
                  style: TextStyle(
                    color: Color(0xFF00E5B4),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Sua rede de contatos é o seu maior ativo.\n\n'
            'Nós fornecemos a infraestrutura tecnológica para você '
            'gerenciar, rastrear e expandir seus ganhos digitais. '
            'Transforme suas conexões estratégicas em receita recorrente '
            'e assuma o controle da sua performance financeira.',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 13,
              height: 1.7,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Feature Cards ─────────────────────────────────────────────────────────────
class _FeatureCards extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final features = [
      _FeatureData(
        icon: Icons.track_changes_rounded,
        color: const Color(0xFF00E5B4),
        title: 'Rastreamento em tempo real',
        desc: 'Monitore cliques, conversões e comissões instantaneamente.',
      ),

      _FeatureData(
        icon: Icons.pix_rounded,
        color: const Color(0xFF00BCD4),
        title: 'Saque via PIX',
        desc: 'Receba seus ganhos direto na sua conta em segundos.',
      ),
      _FeatureData(
        icon: Icons.bar_chart_rounded,
        color: const Color(0xFFFFD740),
        title: 'Dashboard completo',
        desc: 'Visualize sua performance com gráficos e métricas detalhadas.',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: features
            .map((f) => _FeatureCard(feature: f))
            .toList(),
      ),
    );
  }
}

class _FeatureData {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  const _FeatureData({
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
  });
}

class _FeatureCard extends StatelessWidget {
  final _FeatureData feature;
  const _FeatureCard({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: feature.color.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: feature.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(feature.icon, color: feature.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  feature.desc,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    height: 1.4,
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

// ── CTA Section ───────────────────────────────────────────────────────────────
class _CtaSection extends StatelessWidget {
  final VoidCallback onCadastro;
  final VoidCallback onLogin;

  const _CtaSection({required this.onCadastro, required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Botão primário: Cadastrar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onCadastro,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5B4),
                foregroundColor: const Color(0xFF0A1628),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
                shadowColor: const Color(0xFF00E5B4).withValues(alpha: 0.4),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rocket_launch_rounded, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Começar agora — é grátis',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Botão secundário: Já tenho conta
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onLogin,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Já tenho uma conta',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Nota de privacidade
          Text(
            'Ao criar sua conta você concorda com nossos\nTermos de Uso e Política de Privacidade.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Footer Section ────────────────────────────────────────────────────────────
class _FooterSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Divisor
        Divider(
          color: Colors.white.withValues(alpha: 0.08),
          indent: 40,
          endIndent: 40,
        ),
        const SizedBox(height: 12),

        // Estatísticas / Social Proof
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StatChip(value: '10K+', label: 'Afiliados'),
            const SizedBox(width: 24),
            _StatChip(value: 'R\$ 2M+', label: 'Pagos'),
            const SizedBox(width: 24),
            _StatChip(value: '99.9%', label: 'Uptime'),
          ],
        ),

        const SizedBox(height: 16),

        Text(
          '© 2025 ShareWallet • Todos os direitos reservados',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.2),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  const _StatChip({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF00E5B4),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
