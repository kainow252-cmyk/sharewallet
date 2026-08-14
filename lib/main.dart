import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'utils/web_utils.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/wallet_service.dart';
import 'services/product_service.dart';
import 'services/subscription_service.dart';
import 'services/admin_service.dart';
import 'services/mercadopago_service.dart';
import 'services/chat_service.dart';
import 'services/app_config_service.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/landing_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/dashboard/main_nav_screen.dart';
import 'screens/wallet/carteira_screen.dart';
import 'screens/wallet/extrato_screen.dart';
import 'screens/wallet/saque_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/indicacoes/indicacoes_screen.dart';
import 'screens/products/products_screen.dart';
import 'screens/products/my_subscriptions_screen.dart';
import 'screens/admin/admin_login_screen.dart';
import 'screens/admin/admin_nav_screen.dart';
import 'screens/products/buy_screen.dart';
import 'screens/download/apk_download_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // -- NotoColorEmoji: pre-carrega como fallback global ----------------------
  // Evita o warning "Could not find a set of Noto fonts" para dados dinamicos
  // (strings da API / Firestore com chars especiais).
  // O FontLoader registra a fonte no FontCollection do CanvasKit ANTES de
  // qualquer paragraph ser renderizado, tornando-a disponivel como fallback.
  if (kIsWeb) {
    try {
      final loader = FontLoader('NotoColorEmoji')
        ..addFont(
          rootBundle.load('assets/fonts/NotoColorEmoji.ttf'),
        );
      await loader.load();
    } catch (e) {
      debugPrint('[Fonts] NotoColorEmoji nao carregado: $e');
    }
  }

  // -- Firebase ----------------------------------------------------------------
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    if (kIsWeb) {
      // PERSISTÊNCIA DE SESSÃO: LOCAL → salva no IndexedDB do navegador.
      // Padrão do Firebase Auth Web é SESSION (perde ao fechar o tab).
      // Com LOCAL: usuário fica logado ao fechar e reabrir o app/browser.
      // Deve ser chamado ANTES de qualquer operação de auth.
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);

      // Firestore banco default com long-polling para evitar WebChannel instável.
      // NÃO inicializa 'affiliatewalletwallet' aqui: seria antes do login →
      // Firestore Rules rejeitaria (auth == null) → "Backend didn't respond".
      // O banco customizado é inicializado lazily nos serviços (após login).
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
        webExperimentalForceLongPolling: true,
      );
    }
  } catch (e) {
    debugPrint('[Firebase] Erro ao inicializar: $e');
  }

  await initializeDateFormatting('pt_BR', null);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // -- Deep link: lê o fragment gravado pelo JS no index.html -----------------
  // O index.html grava window.location.hash no sessionStorage ANTES do Flutter
  // carregar. Aqui lemos via dart:js e extraímos productId + affiliateCode.
  //
  // URL do afiliado: /app/#/produto/p_xxx?ref=ABC123
  // hash lido pelo JS: #/produto/p_xxx?ref=ABC123
  // fragment gravado: /produto/p_xxx?ref=ABC123
  String? initialProductId;
  String? initialAffiliateCode;

  if (kIsWeb) {
    try {
      // Lê do sessionStorage o valor gravado pelo script no index.html
      final fragment = getSessionStorageValue('flutter_initial_route');

      if (fragment != null && fragment.startsWith('/produto/')) {
        final withoutPrefix = fragment.replaceFirst('/produto/', '');
        final parts = withoutPrefix.split('?');
        initialProductId = parts[0].isNotEmpty ? parts[0] : null;
        if (parts.length > 1) {
          final query = Uri.splitQueryString(parts[1]);
          initialAffiliateCode = query['ref'] ?? '';
        }
        // Limpa após ler para não reutilizar em reloads futuros
        removeSessionStorageValue('flutter_initial_route');
      }
    } catch (e) {
      debugPrint('[DeepLink] Erro ao ler sessionStorage: $e');
    }
  }

  runApp(ShareWalletApp(
    initialProductId: initialProductId,
    initialAffiliateCode: initialAffiliateCode,
  ));

  // ── Remove o HTML splash nativo assim que o PRIMEIRO frame for pintado ────
  // Funciona independente da rota inicial (SplashScreen, HomeScreen, etc.)
  // Resolve o bug de F5 na /home que deixava o splash travado na tela.
  if (kIsWeb) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyFlutterReady();
    });
  }
}

class ShareWalletApp extends StatelessWidget {
  final String? initialProductId;
  final String? initialAffiliateCode;

  const ShareWalletApp({
    super.key,
    this.initialProductId,
    this.initialAffiliateCode,
  });

  @override
  Widget build(BuildContext context) {
    final hasProduto =
        initialProductId != null && initialProductId!.isNotEmpty;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => WalletService()),
        ChangeNotifierProvider(create: (_) => ProductService()),
        ChangeNotifierProvider(create: (_) => SubscriptionService()),
        ChangeNotifierProvider(create: (_) => AdminService()),
        ChangeNotifierProvider(create: (_) => MercadoPagoService()),
        ChangeNotifierProvider(create: (_) => ChatService()),
        ChangeNotifierProvider(create: (_) => AppConfigService()),
      ],
      child: MaterialApp(
        title: 'ShareWallet',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        // Deep link de produto: usa `home:` com BuyScreen diretamente.
        // Motivo: MaterialApp.initialRoute com querystring ('/produto/ID?ref=CODE')
        // não é processado corretamente quando há `routes:` registradas —
        // o Navigator faz lookup exato e não encontra '/produto/ID?ref=CODE',
        // caindo no fallback '/' (SplashScreen) que redireciona para login.
        // Com `home:` a BuyScreen é exibida diretamente, sem passar pelo router.
        home: hasProduto
            ? BuyScreen(
                productId: initialProductId!,
                affiliateCode: initialAffiliateCode ?? '',
              )
            : null,
        initialRoute: hasProduto ? null : '/',
        routes: {
          '/': (_) => const SplashScreen(),
          '/landing': (_) => const LandingScreen(),
          '/login': (_) => const LoginScreen(),
          '/register': (_) => const RegisterScreen(),
          '/home': (_) => const MainNavScreen(),
          '/products': (_) => const ProductsScreen(),
          '/carteira': (_) => const CarteiraScreen(),
          '/indicacoes': (_) => const IndicacoesScreen(),
          '/extrato': (_) => const ExtratoScreen(),
          '/saque': (_) => const SaqueScreen(),
          '/profile': (_) => const ProfileScreen(),
          '/subscriptions': (_) => const MySubscriptionsScreen(),
          '/admin/login': (_) => const AdminLoginScreen(),
          '/admin': (_) => const AdminNavScreen(),
          '/apk':   (_) => const ApkDownloadScreen(),
        },
        onGenerateRoute: (settings) {
          final name = settings.name ?? '';

          // /ref/CODE -> registro de afiliado
          if (name.startsWith('/ref/')) {
            final code = name.replaceFirst('/ref/', '');
            return MaterialPageRoute(
              builder: (_) => RegisterScreen(sponsorCode: code),
            );
          }

          // /produto/ID?ref=CODE -> tela pública do comprador (sem login).
          // Também captura navegação interna via pushNamed('/produto/...').
          if (name.startsWith('/produto/')) {
            final withoutPrefix = name.replaceFirst('/produto/', '');
            final parts = withoutPrefix.split('?');
            final productId = parts[0];
            // Prioridade: ref da URL > ref do deep link original
            String affiliateCode = initialAffiliateCode ?? '';
            if (parts.length > 1) {
              final query = Uri.splitQueryString(parts[1]);
              final ref = query['ref'] ?? '';
              if (ref.isNotEmpty) affiliateCode = ref;
            }
            return MaterialPageRoute(
              builder: (_) => BuyScreen(
                productId: productId,
                affiliateCode: affiliateCode,
              ),
            );
          }

          return null;
        },
      ),
    );
  }
}
