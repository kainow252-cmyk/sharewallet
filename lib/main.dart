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

  runApp(const ShareWalletApp());
}

class ShareWalletApp extends StatelessWidget {
  const ShareWalletApp({super.key});

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
        initialRoute: '/',
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
        // Deep link: /ref/CODE → RegisterScreen com sponsorCode
        onGenerateRoute: (settings) {
          if (settings.name != null &&
              settings.name!.startsWith('/ref/')) {
            final code = settings.name!.replaceFirst('/ref/', '');
            return MaterialPageRoute(
              builder: (_) => RegisterScreen(sponsorCode: code),
            );
          }
          return null;
        },
      ),
    );
  }
}
