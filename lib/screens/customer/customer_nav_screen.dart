// ===========================================================================
// customer_nav_screen.dart - ShareWallet
// ---------------------------------------------------------------------------
// Tela principal do PORTAL DO CLIENTE — 4 abas via BottomNav.
// Análogo ao MainNavScreen, mas para clientes (modo comprador).
// ===========================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/customer_service.dart';
import 'customer_home_screen.dart';
import 'customer_catalog_screen.dart';
import 'customer_wallet_screen.dart';
import 'customer_profile_screen.dart';

// -- Controlador global de navegação do cliente --------------------------------
class CustomerNavController extends ChangeNotifier {
  static final CustomerNavController _instance = CustomerNavController._();
  factory CustomerNavController() => _instance;
  CustomerNavController._();

  int _index = 0;
  int get index => _index;

  void goTo(int i) {
    if (_index != i) {
      _index = i;
      notifyListeners();
    }
  }

  void goHome()     => goTo(0);
  void goCatalog()  => goTo(1);
  void goWallet()   => goTo(2);
  void goProfile()  => goTo(3);
}

class CustomerNavScreen extends StatefulWidget {
  const CustomerNavScreen({super.key});

  @override
  State<CustomerNavScreen> createState() => _CustomerNavScreenState();
}

class _CustomerNavScreenState extends State<CustomerNavScreen> {
  final _ctrl = CustomerNavController();
  final Set<int> _visitadas = {0};

  final List<Widget> _screens = const [
    CustomerHomeScreen(),
    CustomerCatalogScreen(),
    CustomerWalletScreen(),
    CustomerProfileScreen(),
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
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Perfil',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onNavChange);
    // Carrega dados do cliente ao entrar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerService>().refreshProfile();
    });
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onNavChange);
    super.dispose();
  }

  void _onNavChange() {
    setState(() => _visitadas.add(_ctrl.index));
  }

  @override
  Widget build(BuildContext context) {
    final idx = _ctrl.index;

    return Scaffold(
      body: IndexedStack(
        index: idx,
        children: List.generate(_screens.length, (i) {
          if (!_visitadas.contains(i)) return const SizedBox.shrink();
          return _screens[i];
        }),
      ),
      bottomNavigationBar: _CustomerBottomNav(
        currentIndex: idx,
        items: _navItems,
        onTap: (i) {
          _visitadas.add(i);
          _ctrl.goTo(i);
        },
      ),
    );
  }
}

// -- Bottom Nav do cliente (visual diferenciado — azul escuro ≠ verde afiliado) ---
class _CustomerBottomNav extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final void Function(int) onTap;

  const _CustomerBottomNav({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Usa o mesmo visual do afiliado — coerência de marca
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
          height: 56,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final isActive = currentIndex == i;
              // Carteira (índice 2) usa dourado; demais usam primary
              final Color activeColor = i == 2
                  ? AppColors.gold
                  : AppColors.primary;

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Badge na carteira se tiver saldo
                      i == 2
                          ? _WalletTabIcon(isActive: isActive, activeColor: activeColor, item: item)
                          : Icon(
                              isActive ? item.activeIcon : item.icon,
                              color: isActive ? activeColor : AppColors.textHint,
                              size: 22,
                            ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive ? activeColor : AppColors.textHint,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
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

// Ícone da aba Carteira com badge de saldo
class _WalletTabIcon extends StatelessWidget {
  final bool isActive;
  final Color activeColor;
  final _NavItem item;

  const _WalletTabIcon({
    required this.isActive,
    required this.activeColor,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final saldo = context.watch<CustomerService>().saldoDisponivel;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          isActive ? item.activeIcon : item.icon,
          color: isActive ? activeColor : AppColors.textHint,
          size: 22,
        ),
        if (saldo > 0)
          Positioned(
            top: -4,
            right: -6,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.gold,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 1.5),
              ),
            ),
          ),
      ],
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
