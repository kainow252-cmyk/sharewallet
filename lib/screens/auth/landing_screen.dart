import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/app_config_service.dart';
import 'register_screen.dart';

// ── APK Install constants ────────────────────────────────────────────────────
const _apkFallbackUrl = 'https://api.sharewallet.com.br/api/app/download';

const _androidIntentUrl =
    'intent://app.sharewallet.com.br/#Intent;'
    'scheme=https;'
    'package=com.affiliatewallet.wallet;'
    'S.browser_fallback_url=https%3A%2F%2Fapi.sharewallet.com.br%2Fapi%2Fapp%2Fdownload;'
    'end';

/// Landing Page — scroll livre, layout limpo, sem justify.
class LandingScreen extends StatefulWidget {
  final String? sponsorCode;
  const LandingScreen({super.key, this.sponsorCode});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleInstall(BuildContext context) async {
    final uri = Uri.parse(_androidIntentUrl);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        await launchUrl(Uri.parse(_apkFallbackUrl), mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (context.mounted) {
        await launchUrl(Uri.parse(_apkFallbackUrl), mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showCadastro =
        context.watch<AppConfigService>().loginConfig.loginCadastroPublico;
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF071020),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF071020), Color(0xFF0A2218), Color(0xFF071020)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _fade,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                    20, 28, 20, mq.padding.bottom + 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [

                    // ── Logo ──────────────────────────────────────────────
                    _buildLogo(),

                    const SizedBox(height: 20),

                    // ── Brand name ────────────────────────────────────────
                    RichText(
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

                    const SizedBox(height: 8),

                    // ── Tagline ───────────────────────────────────────────
                    const Text(
                      'Transforme conexões em receita recorrente.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF8BA8A0),
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Card destaque ─────────────────────────────────────
                    _WelcomeCard(),

                    const SizedBox(height: 20),

                    // ── Features — lista vertical limpa ───────────────────
                    _FeatureList(),

                    const SizedBox(height: 20),

                    // ── Stats row ─────────────────────────────────────────
                    _StatsRow(),

                    const SizedBox(height: 32),

                    // ── CTAs ──────────────────────────────────────────────
                    if (showCadastro) ...[
                      _PrimaryBtn(
                        label: 'Começar agora — é grátis',
                        icon: Icons.rocket_launch_rounded,
                        onTap: () {
                          final code = widget.sponsorCode;
                          if (code != null && code.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    RegisterScreen(sponsorCode: code),
                              ),
                            );
                          } else {
                            Navigator.pushNamed(context, '/register');
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

                    _SecondaryBtn(
                      label: 'Já tenho uma conta',
                      onTap: () => Navigator.pushNamed(context, '/login'),
                    ),

                    if (kIsWeb) ...[
                      const SizedBox(height: 12),
                      _SecondaryBtn(
                        label: 'Instalar App Android',
                        icon: Icons.android_rounded,
                        iconColor: const Color(0xFF00E5B4),
                        borderColor:
                            const Color(0xFF00E5B4).withValues(alpha: 0.45),
                        onTap: () => _handleInstall(context),
                      ),
                    ],

                    if (showCadastro) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Ao criar sua conta você concorda com nossos Termos de Uso.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.22),
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // ── Footer ────────────────────────────────────────────
                    Text(
                      '© ${DateTime.now().year} ShareWallet  •  Todos os direitos reservados',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.18),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5B4).withValues(alpha: 0.30),
            blurRadius: 32,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset(
          'assets/images/sharewallet_logo.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A2218), Color(0xFF00BCD4)],
              ),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Welcome Card ──────────────────────────────────────────────────────────────

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF00E5B4).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF00E5B4).withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF00E5B4).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.hub_rounded,
              color: Color(0xFF00E5B4),
              size: 26,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Bem-vindo à ShareWallet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF00E5B4),
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sua rede de contatos é o seu maior ativo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Gerencie, rastreie e expanda seus ganhos digitais.\nTransforme conexões em receita recorrente\ne assuma o controle da sua performance financeira.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.50),
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Feature List — vertical, sem quebras feias ────────────────────────────────

class _FeatureList extends StatelessWidget {
  const _FeatureList();

  static const _items = [
    _FeatureData(
      icon: Icons.track_changes_rounded,
      color: Color(0xFF00E5B4),
      title: 'Rastreamento em tempo real',
      desc: 'Monitore cliques, conversões e comissões instantaneamente.',
    ),
    _FeatureData(
      icon: Icons.pix_rounded,
      color: Color(0xFF00BCD4),
      title: 'Saque via PIX',
      desc: 'Receba seus ganhos direto na sua conta em segundos.',
    ),
    _FeatureData(
      icon: Icons.bar_chart_rounded,
      color: Color(0xFFFFD740),
      title: 'Dashboard completo',
      desc: 'Visualize sua performance com métricas detalhadas.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _items
          .map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _FeatureRow(feature: f),
              ))
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

class _FeatureRow extends StatelessWidget {
  final _FeatureData feature;
  const _FeatureRow({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: feature.color.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Ícone
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: feature.color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(feature.icon, color: feature.color, size: 24),
          ),
          const SizedBox(width: 14),
          // Texto
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  feature.desc,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.48),
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

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF00E5B4).withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatItem(value: '10K+', label: 'Afiliados',
              color: const Color(0xFF00E5B4)),
          Container(width: 1, height: 36,
              color: Colors.white.withValues(alpha: 0.08)),
          _StatItem(value: 'R\$ 2M+', label: 'Pagos',
              color: const Color(0xFF00BCD4)),
          Container(width: 1, height: 36,
              color: Colors.white.withValues(alpha: 0.08)),
          _StatItem(value: '99.9%', label: 'Uptime',
              color: const Color(0xFFFFD740)),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatItem({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.38),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ── Buttons ───────────────────────────────────────────────────────────────────

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _PrimaryBtn({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00E5B4),
          foregroundColor: const Color(0xFF071020),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _SecondaryBtn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? iconColor;
  final Color? borderColor;
  final VoidCallback onTap;
  const _SecondaryBtn({
    required this.label,
    required this.onTap,
    this.icon,
    this.iconColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final border = borderColor ?? Colors.white.withValues(alpha: 0.16);
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: iconColor ?? Colors.white70,
          side: BorderSide(color: border, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: iconColor ?? Colors.white70),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: iconColor ?? Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
