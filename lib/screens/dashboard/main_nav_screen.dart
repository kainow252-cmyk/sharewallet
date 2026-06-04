import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'home_screen.dart';
import '../products/products_screen.dart';
import '../wallet/carteira_screen.dart';
import '../indicacoes/indicacoes_screen.dart';
import '../ranking/ranking_screen.dart';
import '../profile/profile_screen.dart';

// ── Controlador global de navegação ──────────────────────────────────────────
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

  void goHome() => goTo(0);
  void goProducts() => goTo(1);
  void goCarteira() => goTo(2);
  void goIndicacoes() => goTo(3);
  void goRanking() => goTo(4);
  void goProfile() => goTo(5); // Perfil é o índice 5
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
    CarteiraScreen(),
    IndicacoesScreen(),
    RankingScreen(),
    ProfileScreen(),
  ];

  final List<_NavItem> _navItems = const [
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Início',
    ),
    _NavItem(
      icon: Icons.store_outlined,
      activeIcon: Icons.store_rounded,
      label: 'Produtos',
    ),
    _NavItem(
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet_rounded,
      label: 'Carteira',
    ),
    _NavItem(
      icon: Icons.people_outline_rounded,
      activeIcon: Icons.people_alt_rounded,
      label: 'Indicações',
    ),
    _NavItem(
      icon: Icons.emoji_events_outlined,
      activeIcon: Icons.emoji_events_rounded,
      label: 'Ranking',
    ),
    _NavItem(
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

  void _onNavChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final idx = _ctrl.index;

    return Scaffold(
      body: IndexedStack(
        index: idx,
        children: _screens,
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: idx,
        items: _navItems,
        onTap: _ctrl.goTo,
      ),
    );
  }
}

// ── Bottom Nav personalizado ──────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final void Function(int) onTap;

  const _BottomNav({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          height: 64,
          child: Row(
            children: items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final isActive = currentIndex == i;

              // Carteira (índice 2) tem destaque especial
              if (i == 2) {
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: isActive
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF0A1628),
                                      Color(0xFF0D3B2E)
                                    ],
                                  )
                                : LinearGradient(
                                    colors: [
                                      AppColors.textHint.withValues(alpha: 0.3),
                                      AppColors.textHint.withValues(alpha: 0.3),
                                    ],
                                  ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF00E5B4)
                                          .withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Icon(
                            isActive ? item.activeIcon : item.icon,
                            color: isActive
                                ? const Color(0xFF00E5B4)
                                : AppColors.textHint,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isActive
                                ? const Color(0xFF00E5B4)
                                : AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isActive)
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: i == 4
                                  ? const Color(0xFFFFD740)
                                  : i == 5
                                      ? AppColors.primary
                                      : AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          )
                        else
                          const SizedBox(height: 4),
                        const SizedBox(height: 2),
                        Icon(
                          isActive ? item.activeIcon : item.icon,
                          color: isActive
                              ? (i == 4
                                  ? const Color(0xFFFFD740)
                                  : AppColors.primary)
                              : AppColors.textHint,
                          size: 24,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isActive
                                ? (i == 4
                                    ? const Color(0xFFFFD740)
                                    : AppColors.primary)
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
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

// Manter compatibilidade
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
