import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import 'home_screen.dart';
import '../products/products_screen.dart';
import '../wallet/carteira_screen.dart';
import '../indicacoes/indicacoes_screen.dart';
import '../chat/chat_screen.dart';
import '../profile/profile_screen.dart';

// -- Controlador global de navegação ------------------------------------------
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

  void goHome()       => goTo(0);
  void goProducts()   => goTo(1);
  void goCarteira()   => goTo(2);
  void goIndicacoes() => goTo(3);
  void goRanking()    => goTo(4);
  void goChat()       => goTo(5);   // aba Chat
  void goProfile()    => goTo(6);   // aba Perfil
}

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  final _ctrl = MainNavController();
  // Rastreia quais abas já foram visitadas (lazy loading)
  final Set<int> _visitadas = {0}; // começa só com Home

  final List<Widget> _screens = const [
    HomeScreen(),       // 0
    ProductsScreen(),   // 1
    CarteiraScreen(),   // 2
    IndicacoesScreen(), // 3
    ChatScreen(),       // 4
    ProfileScreen(),    // 5
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
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
      label: 'Chat',
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
    // Inicia escuta de não lidas após o primeiro frame (aguarda auth carregar)
    WidgetsBinding.instance.addPostFrameCallback((_) => _startChatListener());
  }

  void _startChatListener() {
    if (!mounted) return;
    final auth = context.read<AuthService>();
    final uid = auth.currentUser?.id ?? '';
    if (uid.isNotEmpty) {
      context.read<ChatService>().startListeningUnread(uid);
    }
    // Escuta mudanças de auth para (re)iniciar listener quando fizer login
    auth.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    if (!mounted) return;
    final uid = context.read<AuthService>().currentUser?.id ?? '';
    context.read<ChatService>().startListeningUnread(uid);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onNavChange);
    try {
      context.read<AuthService>().removeListener(_onAuthChanged);
    } catch (_) {}
    super.dispose();
  }

  void _onNavChange() {
    // Marca aba como visitada ao navegar
    setState(() => _visitadas.add(_ctrl.index));
  }

  @override
  Widget build(BuildContext context) {
    final idx = _ctrl.index;
    final totalUnread = context.watch<ChatService>().totalUnread;

    return Scaffold(
      body: IndexedStack(
        index: idx,
        children: List.generate(_screens.length, (i) {
          if (!_visitadas.contains(i)) return const SizedBox.shrink();
          return _screens[i];
        }),
      ),
      bottomNavigationBar: _BottomNavWithBadge(
        currentIndex: idx,
        items: _navItems,
        chatBadge: totalUnread,
        onTap: (i) {
          _visitadas.add(i);
          _ctrl.goTo(i);
        },
      ),
    );
  }
}

// -- Bottom Nav com badge de mensagens não lidas ------------------------------
class _BottomNavWithBadge extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final int chatBadge;   // contagem de mensagens não lidas (índice 4)
  final void Function(int) onTap;

  const _BottomNavWithBadge({
    required this.currentIndex,
    required this.items,
    required this.chatBadge,
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
          height: 56,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final isActive = currentIndex == i;

              // Cores por aba:
              // 4 = Chat (azul claro), demais = primary
              final Color activeColor = i == 4
                  ? const Color(0xFF29B6F6)
                  : AppColors.primary;

              // Badge de não lidas somente no Chat (índice 4)
              final bool showBadge = i == 4 && chatBadge > 0;

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            isActive ? item.activeIcon : item.icon,
                            color: isActive ? activeColor : AppColors.textHint,
                            size: 22,
                          ),
                          if (showBadge)
                            Positioned(
                              right: -6,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                constraints: const BoxConstraints(
                                    minWidth: 16, minHeight: 16),
                                decoration: BoxDecoration(
                                  color: AppColors.error,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: AppColors.surface, width: 1.5),
                                ),
                                child: Text(
                                  chatBadge > 99 ? '99+' : '$chatBadge',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color:
                              isActive ? activeColor : AppColors.textHint,
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
