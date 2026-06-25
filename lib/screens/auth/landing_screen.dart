import 'package:flutter/material.dart';

/// Landing Page — layout 100% adaptável à altura da tela.
/// Usa LayoutBuilder + Column com Flexible/Expanded para
/// que TODO o conteúdo caiba sem scroll em qualquer dispositivo.
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
        vsync: this, duration: const Duration(milliseconds: 700));
    _heroFade  = CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut);
    _heroSlide = Tween<Offset>(
      begin: const Offset(0, -0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut));

    _cardsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _cardsFade  = CurvedAnimation(parent: _cardsCtrl, curve: Curves.easeOut);
    _cardsSlide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _cardsCtrl, curve: Curves.easeOut));

    _ctaCtrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _ctaScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _ctaCtrl, curve: Curves.elasticOut),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    await _heroCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 80));
    _cardsCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 180));
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final h = constraints.maxHeight;
              // Escala proporiconal: referência = 700px de altura útil
              final scale = (h / 700).clamp(0.7, 1.1);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  children: [

                    // ── Logo + título + subtítulo ───────────────────────────
                    SlideTransition(
                      position: _heroSlide,
                      child: FadeTransition(
                        opacity: _heroFade,
                        child: _HeroSection(scale: scale),
                      ),
                    ),

                    SizedBox(height: 14 * scale),

                    // ── Cards de features (3 colunas) ────────────────────────
                    SlideTransition(
                      position: _cardsSlide,
                      child: FadeTransition(
                        opacity: _cardsFade,
                        child: _FeatureCards(scale: scale),
                      ),
                    ),

                    SizedBox(height: 14 * scale),

                    // ── Stats row ────────────────────────────────────────────
                    FadeTransition(
                      opacity: _cardsFade,
                      child: _StatsRow(scale: scale),
                    ),

                    SizedBox(height: 16 * scale),

                    // ── CTA Buttons ──────────────────────────────────────────
                    ScaleTransition(
                      scale: _ctaScale,
                      child: _CtaSection(
                        scale: scale,
                        onCadastro: () =>
                            Navigator.pushNamed(context, '/register'),
                        onLogin: () =>
                            Navigator.pushNamed(context, '/login'),
                      ),
                    ),

                    SizedBox(height: 10 * scale),

                    // ── Footer mínimo ────────────────────────────────────────
                    FadeTransition(
                      opacity: _heroFade,
                      child: Text(
                        '© ${DateTime.now().year} ShareWallet  •  Todos os direitos reservados',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.2),
                          fontSize: 9 * scale,
                        ),
                      ),
                    ),

                    SizedBox(height: 8 * scale),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Hero Section ────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final double scale;
  const _HeroSection({required this.scale});

  @override
  Widget build(BuildContext context) {
    final logoSize = 72.0 * scale;

    return Column(
      children: [
        SizedBox(height: 18 * scale),

        // Logo
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(logoSize * 0.28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5B4).withValues(alpha: 0.28),
                blurRadius: 28,
                spreadRadius: 3,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(logoSize * 0.28),
            child: Image.asset(
              'assets/images/sharewallet_logo.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A237E), Color(0xFF00BCD4)],
                  ),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: logoSize * 0.54,
                ),
              ),
            ),
          ),
        ),

        SizedBox(height: 14 * scale),

        // Nome ShareWallet
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Share',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30 * scale,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              TextSpan(
                text: 'Wallet',
                style: TextStyle(
                  color: const Color(0xFF00E5B4),
                  fontSize: 30 * scale,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 6 * scale),

        // Tagline
        Text(
          'Transforme conexões em receita recorrente.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 13 * scale,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

// ── Feature Cards ─────────────────────────────────────────────────────────────

class _FeatureCards extends StatelessWidget {
  final double scale;
  const _FeatureCards({required this.scale});

  @override
  Widget build(BuildContext context) {
    const features = [
      _FeatureData(
        icon: Icons.track_changes_rounded,
        color: Color(0xFF00E5B4),
        title: 'Rastreamento',
        desc: 'Cliques, conversões e comissões em tempo real.',
      ),
      _FeatureData(
        icon: Icons.pix_rounded,
        color: Color(0xFF00BCD4),
        title: 'Saque PIX',
        desc: 'Receba seus ganhos direto na conta em segundos.',
      ),
      _FeatureData(
        icon: Icons.bar_chart_rounded,
        color: Color(0xFFFFD740),
        title: 'Dashboard',
        desc: 'Performance com métricas detalhadas.',
      ),
    ];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: features
            .map((f) => Expanded(child: _FeatureCard(feature: f, scale: scale)))
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
  final double scale;
  const _FeatureCard({required this.feature, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: EdgeInsets.symmetric(
          vertical: 14 * scale, horizontal: 8 * scale),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: feature.color.withValues(alpha: 0.20),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42 * scale,
            height: 42 * scale,
            decoration: BoxDecoration(
              color: feature.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(feature.icon,
                color: feature.color, size: 20 * scale),
          ),
          SizedBox(height: 10 * scale),
          Text(
            feature.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11 * scale,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          SizedBox(height: 5 * scale),
          Text(
            feature.desc,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 10 * scale,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final double scale;
  const _StatsRow({required this.scale});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          vertical: 12 * scale, horizontal: 16 * scale),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF00E5B4).withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(value: '10K+', label: 'Afiliados',
              color: const Color(0xFF00E5B4), scale: scale),
          Container(
            width: 1, height: 32 * scale,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          _StatItem(value: 'R\$ 2M+', label: 'Pagos',
              color: const Color(0xFF00BCD4), scale: scale),
          Container(
            width: 1, height: 32 * scale,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          _StatItem(value: '99.9%', label: 'Uptime',
              color: const Color(0xFFFFD740), scale: scale),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final double scale;
  const _StatItem({
    required this.value,
    required this.label,
    required this.color,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 15 * scale,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        SizedBox(height: 2 * scale),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 10 * scale,
          ),
        ),
      ],
    );
  }
}

// ── CTA Section ───────────────────────────────────────────────────────────────

class _CtaSection extends StatelessWidget {
  final VoidCallback onCadastro;
  final VoidCallback onLogin;
  final double scale;

  const _CtaSection({
    required this.onCadastro,
    required this.onLogin,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Botão primário
        SizedBox(
          width: double.infinity,
          height: 50 * scale,
          child: ElevatedButton(
            onPressed: onCadastro,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5B4),
              foregroundColor: const Color(0xFF0A1628),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.rocket_launch_rounded, size: 18 * scale),
                SizedBox(width: 8 * scale),
                Text(
                  'Começar agora  —  é grátis',
                  style: TextStyle(
                    fontSize: 15 * scale,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: 10 * scale),

        // Botão secundário
        SizedBox(
          width: double.infinity,
          height: 46 * scale,
          child: OutlinedButton(
            onPressed: onLogin,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1,
              ),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            child: Text(
              'Já tenho uma conta',
              style: TextStyle(
                fontSize: 14 * scale,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),

        SizedBox(height: 10 * scale),

        Text(
          'Ao criar sua conta você concorda com nossos Termos de Uso.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.25),
            fontSize: 10 * scale,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
