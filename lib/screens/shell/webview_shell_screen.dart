import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../services/biometric_service.dart';

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
  checkingBiometric, // verificando se biometria está habilitada
  biometricPrompt,   // mostrando prompt de biometria
  loading,           // WebView carregando
  ready,             // WebView pronto
  error,             // sem internet
}

class _WebViewShellScreenState extends State<WebViewShellScreen>
    with SingleTickerProviderStateMixin {
  // ── WebView ────────────────────────────────────────────────────────────────
  late final WebViewController _ctrl;
  int _loadProgress = 0;

  // ── Estado geral ───────────────────────────────────────────────────────────
  _ShellState _state = _ShellState.checkingBiometric;

  // ── Biometria ──────────────────────────────────────────────────────────────
  bool _biometricAvailable = false; // ignore: unused_field
  bool _biometricEnabled   = false;  // ignore: unused_field
  bool _bioLoading         = false;
  String? _bioError;

  // ── Animação de pulso no botão de biometria ───────────────────────────────
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  // ── Image picker ───────────────────────────────────────────────────────────
  final _picker = ImagePicker();

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    // Animação de pulso para o botão de biometria
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _initWebView();
    _checkBiometric();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── 1. Verifica biometria ─────────────────────────────────────────────────
  Future<void> _checkBiometric() async {
    final available = await BiometricService.isAvailable();
    final enabled   = await BiometricService.isEnabled();

    if (!mounted) return;

    setState(() {
      _biometricAvailable = available;
      _biometricEnabled   = enabled;
    });

    if (enabled && available) {
      // Tem biometria habilitada → mostra tela de biometria
      setState(() => _state = _ShellState.biometricPrompt);
      // Dispara automaticamente após 600ms (UX mais suave)
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && _state == _ShellState.biometricPrompt) {
          _loginWithBiometric(silent: true);
        }
      });
    } else {
      // Sem biometria → vai direto para WebView
      _goToWebView();
    }
  }

  // ── 2. Login via biometria ────────────────────────────────────────────────
  Future<void> _loginWithBiometric({bool silent = false}) async {
    if (_bioLoading) return;
    setState(() { _bioLoading = true; _bioError = null; });

    try {
      final ok = await BiometricService.authenticate();
      if (!mounted) return;

      if (ok) {
        // Autenticado → injeta credenciais no WebView após carregar
        final creds = await BiometricService.loadCredentials();
        if (mounted) {
          _goToWebView(credenciais: creds);
        }
      } else {
        setState(() {
          _bioLoading = false;
          _bioError   = silent ? null : 'Biometria não reconhecida. Tente novamente.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bioLoading = false;
        _bioError   = 'Erro ao usar biometria.';
      });
    }
  }

  // ── 3. Pular biometria → inicia carregamento do WebView ────────────────────
  void _goToWebView({({String email, String password})? credenciais}) {
    // Salva credenciais pendentes ANTES de mudar estado
    if (credenciais != null) {
      _pendingBiometricCredentials = credenciais;
    }

    setState(() {
      _state      = _ShellState.loading;
      _bioLoading = false;
    });

    // Só agora inicia o carregamento do WebView (evita tela preta inicial)
    _ctrl.loadRequest(Uri.parse(WebViewShellScreen._baseUrl));
  }

  // Credenciais pendentes para injetar via JS após o WebView carregar
  ({String email, String password})? _pendingBiometricCredentials;

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
            // Injeta flag IMEDIATAMENTE ao iniciar a página — antes do onPageFinished.
            // Isso garante que isNativeApp() retorne true nos primeiros frames do Flutter Web.
            try {
              await _ctrl.runJavaScript(
                'window.ShareWalletNativeApp = true;'
                'document.documentElement.classList.add("sw-native-app");',
              );
            } catch (_) {
              // Ignora se o contexto JS ainda não estiver pronto
            }
          },
          onPageFinished: (url) async {
            // Injeta flag JS para o site detectar APK (em toda navegação)
            await _ctrl.runJavaScript(
              'window.ShareWalletNativeApp = true;'
              'document.documentElement.classList.add("sw-native-app");'
            );

            // Injeta helper JS para o site abrir câmera/galeria via native
            await _injectPhotoHelper();

            // Injeta listener para pedidos de biometria vindos do site
            // (botão de digital na LoginScreen web dispara sw-request-biometric)
            await _injectBiometricRequestListener();

            // Se tem credenciais de biometria → faz login automático
            if (_pendingBiometricCredentials != null) {
              await _injectBiometricLogin(_pendingBiometricCredentials!);
              _pendingBiometricCredentials = null;
            }

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
      // loadRequest NÃO é chamado aqui — aguarda _goToWebView() ser chamado
      // após verificação de biometria, evitando tela preta / splash dupla.
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

  // ── 5b. Injeta listener de 'sw-request-biometric' no site ────────────────
  // O site (LoginScreen web) dispara este evento quando o usuário toca no botão
  // de digital. O shell escuta, autentica com biometria nativa e devolve
  // as credenciais via 'sw-biometric-login'.
  Future<void> _injectBiometricRequestListener() async {
    const js = '''
(function() {
  if (window._swBiometricRequestRegistered) return;
  window._swBiometricRequestRegistered = true;
  window.addEventListener('sw-request-biometric', function() {
    // Pede ao shell Flutter para iniciar biometria
    ShareWalletNative.postMessage(JSON.stringify({action: 'requestBiometric'}));
    console.log('[ShareWalletNative] Biometric request recebido do site');
  });
  console.log('[ShareWalletNative] sw-request-biometric listener registrado');
})();
''';
    await _ctrl.runJavaScript(js);
  }

  // ── 6. Injeta login automático via biometria ──────────────────────────────
  Future<void> _injectBiometricLogin(
      ({String email, String password}) creds) async {
    // Aguarda o React/Flutter Web inicializar (máx 3s)
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final emailEsc = _escapeJs(creds.email);
    final passEsc  = _escapeJs(creds.password);

    // Dispara evento customizado que o site escuta para fazer login silencioso
    final js = '''
(function() {
  var event = new CustomEvent('sw-biometric-login', {
    detail: { email: '$emailEsc', password: '$passEsc' }
  });
  window.dispatchEvent(event);
  console.log('[ShareWalletNative] Biometric login event disparado');
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

      } else if (action == 'requestBiometric') {
        // Site pediu biometria via botão na LoginScreen
        await _handleBiometricRequest();

      } else if (action == 'saveBiometric') {
        // Site pediu para salvar credenciais no Keystore nativo
        final email    = data['email']    as String? ?? '';
        final password = data['password'] as String? ?? '';
        await _handleSaveBiometric(email, password);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[WebViewShell] JS message error: $e');
    }
  }

  /// Lida com pedido de biometria disparado pelo site.
  /// Autentica com digital/Face ID e devolve credenciais ao site.
  Future<void> _handleBiometricRequest() async {
    if (!_biometricEnabled) {
      // Biometria não configurada — informa o site
      await _ctrl.runJavaScript(
        "window.dispatchEvent(new CustomEvent('sw-biometric-error', "
        "{detail:{msg:'Biometria não configurada. Faça login com e-mail e senha primeiro.'}}));",
      );
      return;
    }
    try {
      final creds = await BiometricService.loginWithBiometric();
      if (creds != null) {
        await _injectBiometricLogin(
            (email: creds.email, password: creds.password));
      } else {
        await _ctrl.runJavaScript(
          "window.dispatchEvent(new CustomEvent('sw-biometric-error', "
          "{detail:{msg:'Autenticação biométrica falhou.'}}));",
        );
      }
    } catch (e) {
      await _ctrl.runJavaScript(
        "window.dispatchEvent(new CustomEvent('sw-biometric-error', "
        "{detail:{msg:'Erro na biometria.'}}));",
      );
    }
  }

  // ── 7b. Salva credenciais no Keystore e ativa biometria ───────────────────
  /// Chamado quando o usuário toca "Ativar" no dialog de biometria da LoginScreen.
  /// Salva email+senha no Keystore Android e confirma ao site via evento JS.
  Future<void> _handleSaveBiometric(String email, String password) async {
    if (email.isEmpty || password.isEmpty) return;
    try {
      await BiometricService.saveCredentials(email, password);
      // Atualiza flag local para que o shell saiba que biometria está ativa
      if (mounted) setState(() => _biometricEnabled = true);
      // Confirma ao site que a biometria foi ativada com sucesso
      await _ctrl.runJavaScript(
        "window.dispatchEvent(new CustomEvent('sw-biometric-saved'));"
      );
      if (kDebugMode) debugPrint('[WebViewShell] Biometria salva para $email');
    } catch (e) {
      if (kDebugMode) debugPrint('[WebViewShell] saveBiometric error: $e');
    }
  }

  // ── 8. Captura foto e envia de volta ao site ──────────────────────────────
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
    if (_state == _ShellState.biometricPrompt) return true; // fecha app
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

              // ── Splash / verificando biometria / carregando ───────────────
              // Mostra splash em TODOS os estados exceto ready e error
              if (_state != _ShellState.ready &&
                  _state != _ShellState.error &&
                  _state != _ShellState.biometricPrompt)
                _buildSplash(),

              // ── Tela de biometria ─────────────────────────────────────────
              if (_state == _ShellState.biometricPrompt)
                _buildBiometricScreen(),

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

  // ── Tela de biometria ─────────────────────────────────────────────────────
  Widget _buildBiometricScreen() {
    return Container(
      color: const Color(0xFF0A1628),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            const _LogoWidget(),
            const SizedBox(height: 52),

            // Ícone de biometria com animação de pulso
            ScaleTransition(
              scale: _pulseAnim,
              child: GestureDetector(
                onTap: _bioLoading ? null : () => _loginWithBiometric(),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00E5B4).withValues(alpha: 0.12),
                    border: Border.all(
                      color: const Color(0xFF00E5B4).withValues(alpha: 0.4),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5B4).withValues(alpha: 0.20),
                        blurRadius: 32,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: _bioLoading
                      ? const Center(
                          child: SizedBox(
                            width: 32, height: 32,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF00E5B4)),
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.fingerprint_rounded,
                          size: 52,
                          color: Color(0xFF00E5B4),
                        ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Título
            const Text(
              'Acesso biométrico',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use sua digital ou reconhecimento\nfacial para entrar no ShareWallet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
                height: 1.5,
              ),
            ),

            // Erro de biometria
            if (_bioError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _bioError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),
            ],

            const SizedBox(height: 36),

            // Botão principal: Usar Biometria
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _bioLoading ? null : () => _loginWithBiometric(),
                icon: const Icon(Icons.fingerprint_rounded),
                label: const Text('Usar Digital / Face ID'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5B4),
                  foregroundColor: const Color(0xFF0A1628),
                  disabledBackgroundColor:
                      const Color(0xFF00E5B4).withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Botão secundário: Entrar com e-mail
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _bioLoading ? null : _goToWebView,
                icon: const Icon(Icons.email_outlined, size: 18),
                label: const Text('Entrar com e-mail'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.2)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
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
