import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:webview_flutter/webview_flutter.dart';


// ─────────────────────────────────────────────────────────────────────────────
// WebViewShellScreen
//
// APK shell que:
//   1. Mostra splash nativo verde-escuro enquanto verifica biometria
//   2. Se biometria habilitada → mostra tela de biometria ANTES do WebView
//   3. Carrega sharewallet.com.br/app/ em WebView de tela cheia
//   4. Intercepta cliques de foto de perfil via JS Bridge → image_picker nativo
//   5. Envia bytes da foto de volta ao site via postMessage base64
//   6. Back button navega dentro do WebView ou fecha o app
// ─────────────────────────────────────────────────────────────────────────────
class WebViewShellScreen extends StatefulWidget {
  const WebViewShellScreen({super.key});

  static const String _baseUrl = 'https://sharewallet.com.br/app/';

  @override
  State<WebViewShellScreen> createState() => _WebViewShellScreenState();
}

// ── Estados da tela ─────────────────────────────────────────────────────────
enum _ShellState {
  loading, // WebView carregando
  ready,   // WebView pronto
  error,   // sem internet
}

class _WebViewShellScreenState extends State<WebViewShellScreen> {
  // ── WebView ────────────────────────────────────────────────────────────────
  late final WebViewController _ctrl;
  int _loadProgress = 0;

  // ── Estado geral ───────────────────────────────────────────────────────────
  _ShellState _state = _ShellState.loading;

  // ── Image picker ───────────────────────────────────────────────────────────
  final _picker = ImagePicker();

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initWebView();
    _goToWebView(); // vai direto — Android gerencia biometria nativamente
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ── 2. Inicia carregamento do WebView ──────────────────────────────────────
  void _goToWebView() {
    setState(() => _state = _ShellState.loading);
    _ctrl.loadRequest(Uri.parse(WebViewShellScreen._baseUrl));
  }

  // ── 4. Inicializa WebView ──────────────────────────────────────────────────
  void _initWebView() {
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0A1628))
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 11; ShareWallet) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/120.0.0.0 Mobile Safari/537.36 '
        'ShareWalletApp/1.0',
      )
      // ── JavaScript Channel: recebe mensagens do site ─────────────────────
      ..addJavaScriptChannel(
        'ShareWalletNative',
        onMessageReceived: _onJsMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _loadProgress = p);
          },
          onPageStarted: (_) async {
            // Só mostra splash no carregamento INICIAL (checkingBiometric/loading)
            // Navegações internas após ready só atualizam o progress bar do topo
            if (mounted) setState(() => _loadProgress = 0);
            // Injeta flags IMEDIATAMENTE ao iniciar a página.
            // localStorage['sw_native']='1' é o método mais confiável:
            // persiste entre recarregamentos e independe de timing do UA.
            try {
              await _ctrl.runJavaScript(
                'try{'
                '  window.ShareWalletNativeApp=true;'
                '  document.documentElement.classList.add("sw-native-app");'
                '  localStorage.setItem("sw_native","1");'
                '}catch(e){}',
              );
            } catch (_) {
              // Ignora se o contexto JS ainda não estiver pronto
            }
          },
          onPageFinished: (url) async {
            // Injeta flags para o site detectar APK (em toda navegação)
            // localStorage['sw_native']='1' é o mais confiável — persiste entre recargas
            await _ctrl.runJavaScript(
              'try{'
              '  window.ShareWalletNativeApp=true;'
              '  document.documentElement.classList.add("sw-native-app");'
              '  localStorage.setItem("sw_native","1");'
              '}catch(e){}'
            );

            // Injeta helper JS para o site abrir câmera/galeria via native
            await _injectPhotoHelper();

            // Marca como ready (remove splash no carregamento inicial)
            // Navegações internas já estão em ready, setState é no-op
            if (mounted) {
              setState(() {
                _state        = _ShellState.ready;
                _loadProgress = 100;
              });
            }
          },
          onWebResourceError: (err) {
            if (err.isForMainFrame == true && mounted) {
              setState(() => _state = _ShellState.error);
            }
          },
          onNavigationRequest: (req) {
            final url = req.url;
            if (url.startsWith('https://sharewallet.com.br') ||
                url.startsWith('https://api.sharewallet.com.br') ||
                url.startsWith('about:') ||
                url.startsWith('blob:')) {
              return NavigationDecision.navigate;
            }
            _openExternal(url);
            return NavigationDecision.prevent;
          },
        ),
      );
      // loadRequest NÃO é chamado aqui — aguarda _goToWebView() do initState.
  }

  // ── 5. Injeta JS helper para captura de foto ──────────────────────────────
  //
  // O site usa <input type="file"> ou um bottom sheet Flutter para foto.
  // Quando está no APK WebView, interceptamos via postMessage:
  //   window.ShareWalletNative.postMessage('{"action":"pickPhoto","source":"camera"}')
  //   window.ShareWalletNative.postMessage('{"action":"pickPhoto","source":"gallery"}')
  //
  // O site deve chamar essas funções ao invés de abrir o file picker nativo.
  // Também injeta `window.openNativeCamera()` e `window.openNativeGallery()`
  // para que o site possa chamar diretamente.
  Future<void> _injectPhotoHelper() async {
    const js = r'''
(function() {
  // Funções globais que o site pode chamar
  window.openNativeCamera = function() {
    ShareWalletNative.postMessage(JSON.stringify({action:"pickPhoto",source:"camera"}));
  };
  window.openNativeGallery = function() {
    ShareWalletNative.postMessage(JSON.stringify({action:"pickPhoto",source:"gallery"}));
  };

  // Intercepta <input type="file" accept="image/*"> para redirecionar ao native
  document.addEventListener('click', function(e) {
    var el = e.target;
    if (el && el.tagName === 'INPUT' && el.type === 'file' &&
        el.accept && el.accept.indexOf('image') >= 0) {
      e.preventDefault();
      e.stopPropagation();
      ShareWalletNative.postMessage(JSON.stringify({action:"pickPhoto",source:"gallery"}));
    }
  }, true);

  // Log para confirmar injeção
  console.log('[ShareWalletNative] Photo helper injetado');
})();
''';
    await _ctrl.runJavaScript(js);
  }

  String _escapeJs(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll('\n', '');

  // ── 7. Recebe mensagens JS do site ─────────────────────────────────────────
  Future<void> _onJsMessage(JavaScriptMessage msg) async {
    try {
      final data = jsonDecode(msg.message) as Map<String, dynamic>;
      final action = data['action'] as String?;

      if (action == 'pickPhoto') {
        final sourceStr = data['source'] as String? ?? 'gallery';
        final source = sourceStr == 'camera'
            ? ImageSource.camera
            : ImageSource.gallery;
        await _pickAndSendPhoto(source);

      }
    } catch (e) {
      if (kDebugMode) debugPrint('[WebViewShell] JS message error: $e');
    }
  }

  // ── 7b. Captura foto e envia de volta ao site ───────────────────────────
  Future<void> _pickAndSendPhoto(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked == null) {
        // Usuário cancelou
        await _ctrl.runJavaScript(
          "window.dispatchEvent(new CustomEvent('sw-photo-cancelled'));",
        );
        return;
      }

      final Uint8List bytes = await picked.readAsBytes();
      final String base64 = base64Encode(bytes);

      // Determina content-type pela extensão
      final name = picked.name.toLowerCase();
      String mime = 'image/jpeg';
      if (name.endsWith('.png'))  mime = 'image/png';
      if (name.endsWith('.webp')) mime = 'image/webp';

      // Envia ao site via evento CustomEvent com dataURL
      final dataUrl = 'data:$mime;base64,$base64';

      // Injeta usando postMessage para evitar limite de tamanho de argumentos JS
      final js = '''
(function() {
  var event = new CustomEvent('sw-photo-selected', {
    detail: {
      dataUrl: ${jsonEncode(dataUrl)},
      fileName: ${jsonEncode(picked.name)},
      mimeType: ${jsonEncode(mime)}
    }
  });
  window.dispatchEvent(event);
  console.log('[ShareWalletNative] Foto enviada: ${picked.name}');
})();
''';
      await _ctrl.runJavaScript(js);
    } catch (e) {
      if (kDebugMode) debugPrint('[WebViewShell] pickPhoto error: $e');
      await _ctrl.runJavaScript(
        "window.dispatchEvent(new CustomEvent('sw-photo-error', {detail:{msg:'${_escapeJs(e.toString())}'}}));",
      );
    }
  }

  // ── URL launcher externo ───────────────────────────────────────────────────
  Future<void> _openExternal(String url) async {
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
    } catch (_) {}
  }

  // ── Back button ───────────────────────────────────────────────────────────
  Future<bool> _onBackPressed() async {
    if (await _ctrl.canGoBack()) {
      await _ctrl.goBack();
      return false;
    }
    return true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF0A1628),
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A1628),
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await _onBackPressed();
        if (shouldExit && context.mounted) SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1628),
        body: SafeArea(
          bottom: true,
          child: Stack(
            children: [
              // ── WebView ───────────────────────────────────────────────────
              // Só fica visível quando ready (splash cobre o loading)
              // maintainState=true preserva o WebView na árvore mesmo invisível
              Visibility(
                visible: _state == _ShellState.ready,
                maintainState: true,
                child: WebViewWidget(controller: _ctrl),
              ),

              // ── Barra de progresso fina no topo (só quando ready+reload) ──
              if (_state == _ShellState.loading && _loadProgress > 0 && _loadProgress < 100)
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: LinearProgressIndicator(
                    value: _loadProgress / 100,
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF00E5B4),
                    ),
                  ),
                ),

              // ── Splash enquanto carrega ───────────────────────────────────
              if (_state != _ShellState.ready && _state != _ShellState.error)
                _buildSplash(),

              // ── Tela de erro ──────────────────────────────────────────────
              if (_state == _ShellState.error)
                _buildErrorScreen(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Splash ────────────────────────────────────────────────────────────────
  Widget _buildSplash() {
    // Quando o WebView já passou de 85% → fade-out da splash para não piscar
    final isNearReady = _state == _ShellState.loading && _loadProgress >= 85;

    return AnimatedOpacity(
      opacity: isNearReady ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        color: const Color(0xFF0A1628),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _LogoWidget(),
              const SizedBox(height: 32),
              // Barra de progresso fina quando está carregando o WebView
              if (_state == _ShellState.loading && _loadProgress > 0)
                Column(
                  children: [
                    SizedBox(
                      width: 160,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _loadProgress / 100,
                          minHeight: 3,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF00E5B4),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                // Spinner enquanto verifica biometria ou aguarda início
                const SizedBox(
                  width: 24, height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5B4)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tela de erro ──────────────────────────────────────────────────────────
  Widget _buildErrorScreen() {
    return Container(
      color: const Color(0xFF0A1628),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 64, color: Color(0xFF00E5B4)),
              const SizedBox(height: 20),
              const Text('Sem conexão',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Verifique sua internet e tente novamente.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _state        = _ShellState.loading;
                    _loadProgress = 0;
                  });
                  _ctrl.reload();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5B4),
                  foregroundColor: const Color(0xFF0A1628),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Logo animada no splash / biometria ────────────────────────────────────────
class _LogoWidget extends StatelessWidget {
  const _LogoWidget();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 88, height: 88,
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
