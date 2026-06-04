import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'home_screen.dart';
import '../products/products_screen.dart';
import '../wallet/extrato_screen.dart';
import '../wallet/saque_screen.dart';
import '../profile/profile_screen.dart';

// ── Controlador global de navegação do MainNavScreen ─────────────────────────
// Permite que qualquer tela filha (ex: HomeScreen) troque a aba ativa
// sem usar Navigator.pushNamed (que abre nova aba na web).
class MainNavController extends ChangeNotifier {
  static final MainNavController _instance = MainNavController._();
  factory MainNavController() => _instance;
  MainNavController._();

  int _index = 0;
  int get index => _index;

  void goTo(int i) {
    if (_index != i) {
      _index = i;
      notifyListeners();
    }
  }

  // Atalhos semânticos
  void goHome() => goTo(0);
  void goProducts() => goTo(1);
  void goExtrato() => goTo(2);
  void goSaque() => goTo(3);
  void goProfile() => goTo(4);
}

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  final _ctrl = MainNavController();

  final List<Widget> _screens = const [
    HomeScreen(),
    ProductsScreen(),
    ExtratoScreen(),
    SaqueScreen(),
    ProfileScreen(),
  ];

  final List<NavigationItem> _navItems = const [
    NavigationItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Início',
    ),
    NavigationItem(
      icon: Icons.store_outlined,
      activeIcon: Icons.store_rounded,
      label: 'Produtos',
    ),
    NavigationItem(
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
      label: 'Extrato',
    ),
    NavigationItem(
      icon: Icons.pix_outlined,
      activeIcon: Icons.pix_rounded,
      label: 'Saque',
    ),
    NavigationItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Perfil',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onNavChange);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onNavChange);
    super.dispose();
  }

  void _onNavChange() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _ctrl.index;

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 62,
            child: Row(
              children: _navItems.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                final isActive = currentIndex == i;

                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _ctrl.goTo(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Indicador ativo (bolinha)
                          if (isActive)
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            )
                          else
                            const SizedBox(height: 4),
                          const SizedBox(height: 4),
                          // Ícone especial para Saque (PIX)
                          i == 3
                              ? _PixButton(isActive: isActive)
                              : Icon(
                                  isActive ? item.activeIcon : item.icon,
                                  color: isActive
                                      ? AppColors.primary
                                      : AppColors.textHint,
                                  size: 24,
                                ),
                          const SizedBox(height: 4),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isActive
                                  ? AppColors.primary
                                  : AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _PixButton extends StatelessWidget {
  final bool isActive;
  const _PixButton({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: isActive
            ? AppColors.greenGradient
            : const LinearGradient(
                colors: [AppColors.textHint, AppColors.textHint]),
        borderRadius: BorderRadius.circular(10),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: const Icon(Icons.pix_rounded, color: Colors.white, size: 20),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
