import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// APK shell — carrega o site PWA (https://sharewallet.com.br/app/)
/// dentro de um WebView de tela cheia.
///
/// Comportamento:
/// - Splash nativo verde escuro enquanto carrega
/// - Barra de status transparente sobre o gradiente do site
/// - Botão BACK do Android navega dentro do WebView (ou fecha se não houver histórico)
/// - Links externos (WhatsApp, mailto, tel) abrem no app nativo via url_launcher
/// - Cookies / sessão mantidos entre aberturas (persistência padrão do Android WebView)
class WebViewShellScreen extends StatefulWidget {
  const WebViewShellScreen({super.key});

  /// URL base do PWA
  static const String _baseUrl = 'https://sharewallet.com.br/app/';

  @override
  State<WebViewShellScreen> createState() => _WebViewShellScreenState();
}

class _WebViewShellScreenState extends State<WebViewShellScreen> {
  late final WebViewController _ctrl;
  bool _loaded = false;      // esconde splash quando true
  bool _hasError = false;    // mostra tela de erro se true
  int _loadProgress = 0;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0A1628))
      // User-Agent: mantém o site achando que é mobile (importante para PWA)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 11; ShareWallet) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _loadProgress = p);
          },
          onPageStarted: (_) {
            if (mounted) setState(() { _hasError = false; });
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loaded = true);
          },
          onWebResourceError: (err) {
            // Só mostra erro para o frame principal (não sub-recursos)
            if (err.isForMainFrame == true && mounted) {
              setState(() { _hasError = true; _loaded = true; });
            }
          },
          onNavigationRequest: (req) {
            final url = req.url;
            // Permite navegar dentro do domínio
            if (url.startsWith('https://sharewallet.com.br') ||
                url.startsWith('https://api.sharewallet.com.br') ||
                url.startsWith('about:') ||
                url.startsWith('blob:')) {
              return NavigationDecision.navigate;
            }
            // Links externos: abre no navegador via url_launcher
            _openExternal(url);
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(WebViewShellScreen._baseUrl));
  }

  Future<void> _openExternal(String url) async {
    // Usa dart:js não disponível no APK — usa url_launcher via platform channel
    // Simples: abre o Android Intent diretamente
    try {
      await const MethodChannel('flutter/url_launcher')
          .invokeMethod<void>('launch', {
        'url': url,
        'useSafariVC': false,
        'useWebView': false,
        'enableJavaScript': false,
        'enableDomStorage': false,
        'universalLinksOnly': false,
        'headers': <String, String>{},
      });
    } catch (_) {
      // Silencia — URL externa não crítica
    }
  }

  Future<bool> _onBackPressed() async {
    if (await _ctrl.canGoBack()) {
      await _ctrl.goBack();
      return false; // não sai do app
    }
    return true; // sai do app
  }

  @override
  Widget build(BuildContext context) {
    // Status bar transparente, ícones claros
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await _onBackPressed();
        if (shouldExit && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1628),
        body: Stack(
          children: [
            // ── WebView ────────────────────────────────────────────────────
            WebViewWidget(controller: _ctrl),

            // ── Barra de progresso fina no topo ───────────────────────────
            if (!_loaded && _loadProgress > 0 && _loadProgress < 100)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: LinearProgressIndicator(
                    value: _loadProgress / 100,
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF00E5B4),
                    ),
                  ),
                ),
              ),

            // ── Splash nativo — some quando carregado ─────────────────────
            if (!_loaded)
              Container(
                color: const Color(0xFF0A1628),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LogoWidget(),
                      SizedBox(height: 32),
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF00E5B4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Tela de erro (sem internet) ────────────────────────────────
            if (_hasError && _loaded)
              Container(
                color: const Color(0xFF0A1628),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.wifi_off_rounded,
                          size: 64,
                          color: Color(0xFF00E5B4),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Sem conexão',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Verifique sua internet e tente novamente.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 28),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _loaded = false;
                              _hasError = false;
                            });
                            _ctrl.reload();
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Tentar novamente'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E5B4),
                            foregroundColor: const Color(0xFF0A1628),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Logo animada no splash ────────────────────────────────────────────────────
class _LogoWidget extends StatelessWidget {
  const _LogoWidget();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5B4).withValues(alpha: 0.30),
                blurRadius: 40,
                spreadRadius: 4,
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
                  size: 44,
                ),
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
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              TextSpan(
                text: 'Wallet',
                style: TextStyle(
                  color: Color(0xFF00E5B4),
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
