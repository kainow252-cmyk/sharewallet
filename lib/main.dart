import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

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

  // ── Firebase ────────────────────────────────────────────────────────────────
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    // Web: desabilita persistência para evitar o IndexedDB lock loop
    // Com persistenceEnabled:true no Web, múltiplas abas / reloads causam
    // falhas repetidas no GET Listen/channel → backoff exponencial ~50s de login.
    // Referência: https://firebase.google.com/docs/firestore/manage-data/enable-offline
    if (kIsWeb) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
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

  // ── Deep link: lê o fragment gravado pelo JS no index.html ─────────────────
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
      final fragment =
          html.window.sessionStorage['flutter_initial_route'];

      if (fragment != null && fragment.startsWith('/produto/')) {
        final withoutPrefix = fragment.replaceFirst('/produto/', '');
        final parts = withoutPrefix.split('?');
        initialProductId = parts[0].isNotEmpty ? parts[0] : null;
        if (parts.length > 1) {
          final query = Uri.splitQueryString(parts[1]);
          initialAffiliateCode = query['ref'] ?? '';
        }
        // Limpa após ler para não reutilizar em reloads futuros
        html.window.sessionStorage
            .remove('flutter_initial_route');
      }
    } catch (e) {
      debugPrint('[DeepLink] Erro ao ler sessionStorage: $e');
    }
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
      ],
      child: MaterialApp(
        title: 'ShareWallet',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        // Se veio pelo link de produto, a rota inicial é a tela do comprador
        initialRoute: hasProduto
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
        onGenerateRoute: (settings) {
          final name = settings.name ?? '';

          // /ref/CODE → registro de afiliado
          if (name.startsWith('/ref/')) {
            final code = name.replaceFirst('/ref/', '');
            return MaterialPageRoute(
              builder: (_) => RegisterScreen(sponsorCode: code),
            );
          }

          // /produto/ID?ref=CODE → tela pública do comprador (sem login)
          if (name.startsWith('/produto/')) {
            final withoutPrefix = name.replaceFirst('/produto/', '');
            final parts = withoutPrefix.split('?');
            final productId = parts[0];
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
