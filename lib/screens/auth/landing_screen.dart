import 'package:flutter/material.dart';

/// Landing Page — Pitch de Cadastro da ShareWallet
/// Layout totalmente centralizado, feature cards em coluna vertical com ícone
/// acima do texto, pitch centralizado e textos com textAlign.center.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  late AnimationController _heroCtrl;
  late AnimationController _cardsCtrl;
  late AnimationController _ctaCtrl;

  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;
  late Animation<double> _cardsFade;
  late Animation<Offset> _cardsSlide;
  late Animation<double> _ctaScale;

  @override
  void initState() {
    super.initState();

    _heroCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _heroFade = CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut);
    _heroSlide = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut));

    _cardsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _cardsFade = CurvedAnimation(parent: _cardsCtrl, curve: Curves.easeOut);
    _cardsSlide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _cardsCtrl, curve: Curves.easeOut));

    _ctaCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _ctaScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _ctaCtrl, curve: Curves.elasticOut),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    await _heroCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    _cardsCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _ctaCtrl.forward();
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _cardsCtrl.dispose();
    _ctaCtrl.dispose();
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
            colors: [Color(0xFF0A1628), Color(0xFF0D3B2E)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: size.height - 80),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ── Hero ─────────────────────────────────────────────
                    SlideTransition(
                      position: _heroSlide,
                      child: FadeTransition(
                        opacity: _heroFade,
                        child: const _HeroSection(),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Pitch centralizado ────────────────────────────────
                    FadeTransition(
                      opacity: _cardsFade,
                      child: const _PitchSection(),
                    ),

                    const SizedBox(height: 28),

                    // ── Feature Cards (vertical centrado) ─────────────────
                    SlideTransition(
                      position: _cardsSlide,
                      child: FadeTransition(
                        opacity: _cardsFade,
                        child: const _FeatureCards(),
                      ),
                    ),

                    const SizedBox(height: 36),

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
                    const _FooterSection(),

                    const SizedBox(height: 24),
                  ],
                ),
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
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 32),

        // Logo com glow
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5B4).withValues(alpha: 0.3),
                blurRadius: 32,
                spreadRadius: 4,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
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
                  size: 52,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 22),

        // Nome da plataforma
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Share',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              TextSpan(
                text: 'Wallet',
                style: TextStyle(
                  color: Color(0xFF00E5B4),
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Subtítulo — centralizado
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
    );
  }
}

// ── Pitch Section — totalmente centralizado ───────────────────────────────────

class _PitchSection extends StatelessWidget {
  const _PitchSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color(0xFF00E5B4).withValues(alpha: 0.2),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF00E5B4).withValues(alpha: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Ícone centralizado
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5B4).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.hub_rounded,
              color: Color(0xFF00E5B4),
              size: 24,
            ),
          ),

          const SizedBox(height: 14),

          // Título centralizado
          const Text(
            'Bem-vindo à ShareWallet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF00E5B4),
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),

          const SizedBox(height: 12),

          // Destaque centralizado
          const Text(
            'Sua rede de contatos é o seu maior ativo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 10),

          // Corpo — centralizado
          Text(
            'Gerencie, rastreie e expanda seus ganhos digitais. '
            'Transforme conexões estratégicas em receita recorrente '
            'e assuma o controle da sua performance financeira.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
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

// ── Feature Cards — ícone acima, texto centralizado ──────────────────────────

class _FeatureCards extends StatelessWidget {
  const _FeatureCards();

  @override
  Widget build(BuildContext context) {
    const features = [
      _FeatureData(
        icon: Icons.track_changes_rounded,
        color: Color(0xFF00E5B4),
        title: 'Rastreamento em tempo real',
        desc: 'Monitore cliques, conversões e\ncomissões instantaneamente.',
      ),
      _FeatureData(
        icon: Icons.pix_rounded,
        color: Color(0xFF00BCD4),
        title: 'Saque via PIX',
        desc: 'Receba seus ganhos direto\nna sua conta em segundos.',
      ),
      _FeatureData(
        icon: Icons.bar_chart_rounded,
        color: Color(0xFFFFD740),
        title: 'Dashboard completo',
        desc: 'Visualize sua performance\ncom métricas detalhadas.',
      ),
    ];

    // Grid 3 colunas — cada card é vertical e centralizado
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: features
          .map((f) => Expanded(child: _FeatureCard(feature: f)))
          .toList(),
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
      margin: const EdgeInsets.symmetric(horizontal: 5),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: feature.color.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Ícone no topo centralizado
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: feature.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(feature.icon, color: feature.color, size: 24),
          ),

          const SizedBox(height: 12),

          // Título centralizado
          Text(
            feature.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 6),

          // Descrição centralizada
          Text(
            feature.desc,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11,
              height: 1.45,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Botão primário
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

        // Botão secundário
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
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
        ),

        const SizedBox(height: 14),

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
    );
  }
}

// ── Footer Section ────────────────────────────────────────────────────────────

class _FooterSection extends StatelessWidget {
  const _FooterSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Divider(
          color: Colors.white.withValues(alpha: 0.08),
          indent: 32,
          endIndent: 32,
        ),
        const SizedBox(height: 16),

        // Social proof row — centralizado
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            _StatChip(value: '10K+', label: 'Afiliados'),
            SizedBox(width: 28),
            _StatChip(value: 'R\$ 2M+', label: 'Pagos'),
            SizedBox(width: 28),
            _StatChip(value: '99.9%', label: 'Uptime'),
          ],
        ),

        const SizedBox(height: 16),

        Text(
          '© 2025 ShareWallet • Todos os direitos reservados',
          textAlign: TextAlign.center,
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF00E5B4),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
