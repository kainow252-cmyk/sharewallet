import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/wallet_service.dart';
import 'services/product_service.dart';
import 'services/subscription_service.dart';
import 'services/admin_service.dart';
import 'services/mercadopago_service.dart';
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
import 'screens/ranking/ranking_screen.dart';
import 'screens/products/products_screen.dart';
import 'screens/products/my_subscriptions_screen.dart';
import 'screens/admin/admin_login_screen.dart';
import 'screens/admin/admin_nav_screen.dart';
import 'screens/products/buy_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Inicializa Firebase (projeto: affiliate-wallet-75853) ───────────────────
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    // Loga o erro mas não bloqueia o app — UI carrega mesmo se Firebase falhar
    debugPrint('[Firebase] Erro ao inicializar: $e');
  }

  await initializeDateFormatting('pt_BR', null);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // setPreferredOrientations NÃO é suportado na web — guard obrigatório
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // ── Detecta deep link na web antes de renderizar ──────────────────────────
  // URL: https://.../#/produto/ID?ref=CODE
  // O Flutter hash routing entrega o path sem query string no onGenerateRoute.
  // Lemos Uri.base (window.location.href) aqui para extrair o ref.
  String? initialProductId;
  String? initialAffiliateCode;

  if (kIsWeb) {
    try {
      // Uri.base = URL completa do browser (multiplataforma, sem dart:html)
      // Ex: https://sharewallet-app.pages.dev/app/#/produto/p_123?ref=ABC123
      final uri = Uri.base;
      // O fragment é tudo após o # → ex: /produto/p_123?ref=ABC123
      final fragment = uri.fragment; // /produto/p_123?ref=ABC123
      if (fragment.startsWith('/produto/')) {
        final withoutPrefix = fragment.replaceFirst('/produto/', '');
        final parts = withoutPrefix.split('?');
        initialProductId = parts[0];
        if (parts.length > 1) {
          final query = Uri.splitQueryString(parts[1]);
          initialAffiliateCode = query['ref'] ?? '';
        }
      }
    } catch (_) {}
  }

  runApp(ShareWalletApp(
    initialProductId: initialProductId,
    initialAffiliateCode: initialAffiliateCode,
  ));
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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => WalletService()),
        ChangeNotifierProvider(create: (_) => ProductService()),
        ChangeNotifierProvider(create: (_) => SubscriptionService()),
        ChangeNotifierProvider(create: (_) => AdminService()),
        ChangeNotifierProvider(create: (_) => MercadoPagoService()),
      ],
      child: MaterialApp(
        title: 'ShareWallet',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        initialRoute: (initialProductId != null && initialProductId!.isNotEmpty)
            ? '/produto/$initialProductId?ref=${initialAffiliateCode ?? ""}'
            : '/',
        routes: {
          '/': (_) => const SplashScreen(),
          '/landing': (_) => const LandingScreen(),
          '/login': (_) => const LoginScreen(),
          '/register': (_) => const RegisterScreen(),
          '/home': (_) => const MainNavScreen(),
          '/products': (_) => const ProductsScreen(),
          '/carteira': (_) => const CarteiraScreen(),
          '/indicacoes': (_) => const IndicacoesScreen(),
          '/ranking': (_) => const RankingScreen(),
          '/extrato': (_) => const ExtratoScreen(),
          '/saque': (_) => const SaqueScreen(),
          '/profile': (_) => const ProfileScreen(),
          '/subscriptions': (_) => const MySubscriptionsScreen(),
          '/admin/login': (_) => const AdminLoginScreen(),
          '/admin': (_) => const AdminNavScreen(),
        },
        // Deep links dinâmicos
        onGenerateRoute: (settings) {
          final name = settings.name ?? '';

          // /ref/CODE → registro de afiliado com sponsorCode
          if (name.startsWith('/ref/')) {
            final code = name.replaceFirst('/ref/', '');
            return MaterialPageRoute(
              builder: (_) => RegisterScreen(sponsorCode: code),
            );
          }

          // /produto/PRODUCT_ID?ref=AFFILIATE_CODE → tela pública do comprador
          if (name.startsWith('/produto/')) {
            final withoutPrefix = name.replaceFirst('/produto/', '');
            final parts = withoutPrefix.split('?');
            final productId = parts[0];
            String affiliateCode = initialAffiliateCode ?? '';
            if (parts.length > 1) {
              final query = Uri.splitQueryString(parts[1]);
              final refFromRoute = query['ref'] ?? '';
              if (refFromRoute.isNotEmpty) affiliateCode = refFromRoute;
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
