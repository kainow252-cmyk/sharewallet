import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../services/app_config_service.dart';
import '../../utils/web_utils.dart';
import 'register_screen.dart';

// Endpoint do Worker: adiciona email como testador interno na Play Store
const _joinBetaUrl = 'https://payment.sharewallet.com.br/app/join-beta';

/// Landing Page — cabe tudo numa tela, sem scroll.
/// LayoutBuilder escala proporcionalmente a partir de 680px de altura útil.
/// Cards de feature em linha horizontal com ícone menor + texto curto.
class LandingScreen extends StatefulWidget {
  final String? sponsorCode;
  const LandingScreen({super.key, this.sponsorCode});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  // Detecta APK WebView — reavaliado após o primeiro frame (UA pode chegar depois)
  bool _isNative = false;

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
        vsync: this, duration: const Duration(milliseconds: 600));
    _heroFade  = CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut);
    _heroSlide = Tween<Offset>(
      begin: const Offset(0, -0.10),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut));

    _cardsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _cardsFade  = CurvedAnimation(parent: _cardsCtrl, curve: Curves.easeOut);
    _cardsSlide = Tween<Offset>(
      begin: const Offset(0, 0.14),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _cardsCtrl, curve: Curves.easeOut));

    _ctaCtrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _ctaScale = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(parent: _ctaCtrl, curve: Curves.elasticOut),
    );

    _runSequence();

    // ── Detecta APK WebView — polling multi-tentativa até 3s ────────────────
    // O UA 'ShareWalletApp/1.0' já vem no primeiro request, mas o WebView
    // pode demorar para disponibilizar navigator.userAgent para o Dart.
    // Polling em 5 pontos cobre todos os cenários de timing.
    if (kIsWeb) {
      _startNativeDetectionPolling();
    }

    // ── Remove o HTML splash quando a LandingScreen estiver visível ──────────
    // Aguarda 700ms após o 1º frame: cobre a animação hero (600ms) + margem.
    // NÃO chama no SplashScreen nem no main.dart — a LandingScreen é a tela
    // real que o usuário vai ver, então só removemos quando ELA estiver pronta.
    // Isso elimina o flash de tela azul entre o HTML splash e o conteúdo verde.
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 700), notifyFlutterReady);
      });
    }
  }

  // Polling de detecção nativa: verifica em 0ms, 300ms, 800ms, 1500ms e 3000ms.
  // Necessário porque o WebView injeta o UA antes da navegação, mas o Dart
  // pode não ter acesso a navigator.userAgent imediatamente no initState.
  void _startNativeDetectionPolling() {
    const delays = [0, 300, 800, 1500, 3000];
    for (final ms in delays) {
      Future.delayed(Duration(milliseconds: ms), () {
        if (!mounted) return;
        final native = isNativeApp();
        if (native != _isNative) {
          setState(() => _isNative = native);
        }
      });
    }
  }

  Future<void> _runSequence() async {
    await _heroCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 60));
    _cardsCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 160));
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
              // Escala proporcional — referência 680px, clamp 0.68..1.05
              final s = (h / 680).clamp(0.68, 1.05);

              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 20 * s),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [

                    // ── Hero ──────────────────────────────────────────────
                    SlideTransition(
                      position: _heroSlide,
                      child: FadeTransition(
                        opacity: _heroFade,
                        child: _HeroSection(s: s),
                      ),
                    ),

                    // ── Welcome card ──────────────────────────────────────
                    FadeTransition(
                      opacity: _cardsFade,
                      child: _WelcomeCard(s: s),
                    ),

                    // ── Feature cards (3 colunas) ─────────────────────────
                    SlideTransition(
                      position: _cardsSlide,
                      child: FadeTransition(
                        opacity: _cardsFade,
                        child: _FeatureCards(s: s),
                      ),
                    ),

                    // ── Stats ─────────────────────────────────────────────
                    FadeTransition(
                      opacity: _cardsFade,
                      child: _StatsRow(s: s),
                    ),

                    // ── CTAs ──────────────────────────────────────────────
                    ScaleTransition(
                      scale: _ctaScale,
                      child: _CtaSection(
                        s: s,
                        isNative: _isNative,
                        showCadastro: context
                            .watch<AppConfigService>()
                            .loginConfig
                            .loginCadastroPublico,
                        onCadastro: () {
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
                        onLogin: () =>
                            Navigator.pushNamed(context, '/login'),
                      ),
                    ),

                    // ── Footer ────────────────────────────────────────────
                    FadeTransition(
                      opacity: _heroFade,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 4 * s),
                        child: Text(
                          '© ${DateTime.now().year} ShareWallet  •  Todos os direitos reservados',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            color: Colors.white.withValues(alpha: 0.18),
                            fontSize: 9 * s,
                          ),
                        ),
                      ),
                    ),
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

// ── Hero ──────────────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final double s;
  const _HeroSection({required this.s});

  @override
  Widget build(BuildContext context) {
    final logo = 62.0 * s;
    return Column(
      children: [
        SizedBox(height: 12 * s),
        // Logo
        Container(
          width: logo, height: logo,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(logo * 0.28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5B4).withValues(alpha: 0.25),
                blurRadius: 24, spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(logo * 0.28),
            child: Image.asset(
              'assets/images/sharewallet_logo.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A237E), Color(0xFF00BCD4)],
                  ),
                ),
                child: Icon(Icons.account_balance_wallet_rounded,
                    color: Colors.white, size: logo * 0.54),
              ),
            ),
          ),
        ),
        SizedBox(height: 10 * s),
        // Brand
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(children: [
            TextSpan(
              text: 'Share',
              style: TextStyle(
                fontFamily: 'Roboto',
                color: Colors.white,
                fontSize: 28 * s,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            TextSpan(
              text: 'Wallet',
              style: TextStyle(
                fontFamily: 'Roboto',
                color: const Color(0xFF00E5B4),
                fontSize: 28 * s,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ]),
        ),
        SizedBox(height: 5 * s),
        Text(
          'Transforme conexões em receita recorrente.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Roboto',
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 12 * s,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

// ── Welcome Card ──────────────────────────────────────────────────────────────

class _WelcomeCard extends StatelessWidget {
  final double s;
  const _WelcomeCard({required this.s});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          vertical: 14 * s, horizontal: 16 * s),
      decoration: BoxDecoration(
        color: const Color(0xFF00E5B4).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00E5B4).withValues(alpha: 0.20),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Ícone
          Container(
            width: 40 * s, height: 40 * s,
            decoration: BoxDecoration(
              color: const Color(0xFF00E5B4).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(Icons.hub_rounded,
                color: const Color(0xFF00E5B4), size: 22 * s),
          ),
          SizedBox(width: 12 * s),
          // Texto
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bem-vindo à ShareWallet',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: const Color(0xFF00E5B4),
                    fontSize: 13 * s,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3 * s),
                Text(
                  'Sua rede de contatos é o seu maior ativo. Gerencie e expanda seus ganhos digitais com inteligência.',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11 * s,
                    height: 1.45,
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

// ── Feature Cards — 3 colunas compactas ──────────────────────────────────────

class _FeatureCards extends StatelessWidget {
  final double s;
  const _FeatureCards({required this.s});

  static const _features = [
    _FeatureData(
      icon: Icons.track_changes_rounded,
      color: Color(0xFF00E5B4),
      title: 'Rastreamento',
      desc: 'Cliques e comissões em tempo real.',
    ),
    _FeatureData(
      icon: Icons.pix_rounded,
      color: Color(0xFF00BCD4),
      title: 'Saque PIX',
      desc: 'Receba na sua conta em segundos.',
    ),
    _FeatureData(
      icon: Icons.bar_chart_rounded,
      color: Color(0xFFFFD740),
      title: 'Dashboard',
      desc: 'Métricas detalhadas de performance.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _features
            .map((f) => Expanded(
                  child: _FeatureCard(feature: f, s: s),
                ))
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
  final double s;
  const _FeatureCard({required this.feature, required this.s});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: EdgeInsets.symmetric(
          vertical: 12 * s, horizontal: 6 * s),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: feature.color.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 38 * s, height: 38 * s,
            decoration: BoxDecoration(
              color: feature.color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(feature.icon,
                color: feature.color, size: 18 * s),
          ),
          SizedBox(height: 8 * s),
          Text(
            feature.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: Colors.white,
              fontSize: 11 * s,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          SizedBox(height: 4 * s),
          Text(
            feature.desc,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: Colors.white.withValues(alpha: 0.42),
              fontSize: 9.5 * s,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final double s;
  const _StatsRow({required this.s});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          vertical: 10 * s, horizontal: 12 * s),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: const Color(0xFF00E5B4).withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(value: '10K+', label: 'Afiliados',
              color: const Color(0xFF00E5B4), s: s),
          Container(width: 1, height: 28 * s,
              color: Colors.white.withValues(alpha: 0.10)),
          _StatItem(value: 'R\$ 2M+', label: 'Pagos',
              color: const Color(0xFF00BCD4), s: s),
          Container(width: 1, height: 28 * s,
              color: Colors.white.withValues(alpha: 0.10)),
          _StatItem(value: '99.9%', label: 'Uptime',
              color: const Color(0xFFFFD740), s: s),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final double s;
  const _StatItem({
    required this.value,
    required this.label,
    required this.color,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Roboto',
            color: color,
            fontSize: 14 * s,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        SizedBox(height: 2 * s),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Roboto',
            color: Colors.white.withValues(alpha: 0.38),
            fontSize: 9.5 * s,
          ),
        ),
      ],
    );
  }
}

// ── CTA Section ───────────────────────────────────────────────────────────────

class _CtaSection extends StatefulWidget {
  final VoidCallback onCadastro;
  final VoidCallback onLogin;
  final double s;
  final bool showCadastro;
  final bool isNative;

  const _CtaSection({
    required this.onCadastro,
    required this.onLogin,
    required this.s,
    this.showCadastro = true,
    this.isNative = false,
  });

  @override
  State<_CtaSection> createState() => _CtaSectionState();
}

class _CtaSectionState extends State<_CtaSection>
    with SingleTickerProviderStateMixin {

  // ── estado do fluxo beta ───────────────────────────────────────────────────
  // false  → mostra botão "Instalar App Android"
  // true   → mostra campo de email
  bool _showEmailField = false;

  // 'idle' | 'loading' | 'success' | 'error'
  String _status = 'idle';
  String _errorMsg = '';

  final _emailCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  late final AnimationController _fieldAnim;
  late final Animation<double> _fieldFade;
  late final Animation<double> _fieldScale;

  @override
  void initState() {
    super.initState();
    _fieldAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fieldFade  = CurvedAnimation(parent: _fieldAnim, curve: Curves.easeOut);
    _fieldScale = Tween<double>(begin: 0.92, end: 1.0)
        .animate(CurvedAnimation(parent: _fieldAnim, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _emailFocus.dispose();
    _fieldAnim.dispose();
    super.dispose();
  }

  // ── abre o campo de email com animação ────────────────────────────────────
  void _openEmailField() {
    setState(() => _showEmailField = true);
    _fieldAnim.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 100),
        () => _emailFocus.requestFocus());
  }

  // ── envia email para o Worker → Play Store ────────────────────────────────
  Future<void> _submitEmail() async {
    final email = _emailCtrl.text.trim();
    final emailRx = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRx.hasMatch(email)) {
      setState(() { _status = 'error'; _errorMsg = 'Email inválido'; });
      return;
    }

    setState(() { _status = 'loading'; _errorMsg = ''; });

    try {
      final resp = await http.post(
        Uri.parse(_joinBetaUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ).timeout(const Duration(seconds: 20));

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        setState(() => _status = 'success');
      } else {
        final body = jsonDecode(resp.body);
        setState(() {
          _status = 'error';
          _errorMsg = body['error'] ?? 'Tente novamente.';
        });
      }
    } catch (_) {
      setState(() {
        _status = 'error';
        _errorMsg = 'Sem conexão. Tente novamente.';
      });
    }
  }

  // ── volta ao estado inicial ───────────────────────────────────────────────
  void _resetEmailField() {
    _fieldAnim.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _showEmailField = false;
        _status = 'idle';
        _errorMsg = '';
        _emailCtrl.clear();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;

    return Column(
      children: [
        // ── Botão primário "Começar agora" ────────────────────────────────
        if (widget.showCadastro)
          SizedBox(
            width: double.infinity,
            height: 48 * s,
            child: ElevatedButton.icon(
              onPressed: widget.onCadastro,
              icon: Icon(Icons.rocket_launch_rounded, size: 17 * s),
              label: Text(
                'Começar agora — é grátis',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14 * s,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.1,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5B4),
                foregroundColor: const Color(0xFF0A1628),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.zero,
              ),
            ),
          ),

        if (widget.showCadastro) SizedBox(height: 8 * s),

        // ── Botão login ───────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 42 * s,
          child: OutlinedButton(
            onPressed: widget.onLogin,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.18), width: 1),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Já tenho uma conta',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 13 * s,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),

        // ── Bloco Android — só no site web, fora do APK WebView ──────────
        if (kIsWeb && !widget.isNative) ...[
          SizedBox(height: 8 * s),

          // Estado: sucesso — email enviado, convite a caminho
          if (_status == 'success')
            _BetaSuccessBox(s: s, onReset: _resetEmailField)

          // Estado: campo de email expandido
          else if (_showEmailField)
            ScaleTransition(
              scale: _fieldScale,
              child: FadeTransition(
                opacity: _fieldFade,
                child: _EmailInputRow(
                  s: s,
                  controller: _emailCtrl,
                  focusNode: _emailFocus,
                  isLoading: _status == 'loading',
                  errorMsg: _errorMsg,
                  onSubmit: _submitEmail,
                  onCancel: _resetEmailField,
                ),
              ),
            )

          // Estado: botão inicial "Baixar para Android"
          else
            SizedBox(
              width: double.infinity,
              height: 42 * s,
              child: OutlinedButton.icon(
                onPressed: _openEmailField,
                icon: Icon(Icons.android_rounded,
                    size: 17 * s, color: const Color(0xFF00E5B4)),
                label: Text(
                  'Baixar para Android',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 13 * s,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF00E5B4),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  side: BorderSide(
                      color: const Color(0xFF00E5B4).withValues(alpha: 0.40),
                      width: 1.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],

        if (widget.showCadastro) ...[
          SizedBox(height: 6 * s),
          Text(
            'Ao criar sua conta você concorda com nossos Termos de Uso.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: Colors.white.withValues(alpha: 0.22),
              fontSize: 9 * s,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Campo email + botão enviar ────────────────────────────────────────────────

class _EmailInputRow extends StatelessWidget {
  final double s;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final String errorMsg;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  const _EmailInputRow({
    required this.s,
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.errorMsg,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Campo email
            Expanded(
              child: SizedBox(
                height: 42 * s,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onSubmit(),
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.white,
                    fontSize: 13 * s,
                  ),
                  decoration: InputDecoration(
                    hintText: 'seu@email.com',
                    hintStyle: TextStyle(
                      fontFamily: 'Roboto',
                      color: Colors.white.withValues(alpha: 0.30),
                      fontSize: 13 * s,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 14 * s, vertical: 0),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: const Color(0xFF00E5B4).withValues(alpha: 0.35),
                          width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: const Color(0xFF00E5B4).withValues(alpha: 0.35),
                          width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: Color(0xFF00E5B4), width: 1.4),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: Color(0xFFFF5252), width: 1),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8 * s),

            // Botão enviar
            SizedBox(
              height: 42 * s,
              child: ElevatedButton(
                onPressed: isLoading ? null : onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5B4),
                  foregroundColor: const Color(0xFF0A1628),
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: 14 * s),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: isLoading
                    ? SizedBox(
                        width: 16 * s,
                        height: 16 * s,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF0A1628),
                        ),
                      )
                    : Text(
                        'Enviar',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 13 * s,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),

            // Botão cancelar (X)
            SizedBox(width: 4 * s),
            GestureDetector(
              onTap: onCancel,
              child: Padding(
                padding: EdgeInsets.all(6 * s),
                child: Icon(
                  Icons.close_rounded,
                  color: Colors.white.withValues(alpha: 0.35),
                  size: 18 * s,
                ),
              ),
            ),
          ],
        ),

        // Mensagem de erro (se houver)
        if (errorMsg.isNotEmpty) ...[
          SizedBox(height: 5 * s),
          Row(
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 12 * s, color: const Color(0xFFFF5252)),
              SizedBox(width: 4 * s),
              Text(
                errorMsg,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: const Color(0xFFFF5252),
                  fontSize: 10.5 * s,
                ),
              ),
            ],
          ),
        ],

        // Dica sutil
        if (errorMsg.isEmpty) ...[
          SizedBox(height: 5 * s),
          Text(
            'Você receberá o convite no seu Gmail.',
            style: TextStyle(
              fontFamily: 'Roboto',
              color: Colors.white.withValues(alpha: 0.28),
              fontSize: 10 * s,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Box de sucesso ────────────────────────────────────────────────────────────

class _BetaSuccessBox extends StatelessWidget {
  final double s;
  final VoidCallback onReset;
  const _BetaSuccessBox({required this.s, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 12 * s, horizontal: 14 * s),
      decoration: BoxDecoration(
        color: const Color(0xFF00E5B4).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00E5B4).withValues(alpha: 0.30),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.mark_email_read_rounded,
              color: const Color(0xFF00E5B4), size: 22 * s),
          SizedBox(width: 10 * s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Convite enviado!',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: const Color(0xFF00E5B4),
                    fontSize: 13 * s,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2 * s),
                Text(
                  'Verifique seu Gmail em instantes.',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.white.withValues(alpha: 0.50),
                    fontSize: 10.5 * s,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onReset,
            child: Icon(Icons.close_rounded,
                color: Colors.white.withValues(alpha: 0.25), size: 16 * s),
          ),
        ],
      ),
    );
  }
}
