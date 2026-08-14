import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../services/app_config_service.dart';
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
  void goRanking()    => goTo(3); // compatibilidade → redireciona Indicações
  void goChat()       => goTo(4);
  void goProfile()    => goTo(5);

  // Navega para a aba de chat independente do índice real (para quando
  // alguns itens estão ocultos e o índice muda)
  void goToVisibleChat(BuildContext context) {
    try {
      final cfg = context.read<AppConfigService>().config;
      // Calcula o índice real do Chat na lista filtrada
      int idx = 0;
      if (cfg.navInicio)     idx++;
      if (cfg.navProdutos)   idx++;
      if (cfg.navCarteira)   idx++;
      if (cfg.navIndicacoes) idx++;
      if (cfg.navChat) { goTo(idx); return; }
    } catch (_) {}
    goTo(4); // fallback
  }
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

  // Todas as telas (sempre presentes no IndexedStack — lazy)
  static const List<Widget> _allScreens = [
    HomeScreen(),       // 0
    ProductsScreen(),   // 1
    CarteiraScreen(),   // 2
    IndicacoesScreen(), // 3
    ChatScreen(),       // 4
    ProfileScreen(),    // 5
  ];

  // Definição completa de todos os itens possíveis (índice fixo = posição em _allScreens)
  static const List<_NavItemDef> _allNavDefs = [
    _NavItemDef(screenIndex: 0, configKey: 'navInicio',     isChatTab: false,
      icon: Icons.home_outlined,                      activeIcon: Icons.home_rounded,                     label: 'Início'),
    _NavItemDef(screenIndex: 1, configKey: 'navProdutos',   isChatTab: false,
      icon: Icons.store_outlined,                     activeIcon: Icons.store_rounded,                    label: 'Produtos'),
    _NavItemDef(screenIndex: 2, configKey: 'navCarteira',   isChatTab: false,
      icon: Icons.account_balance_wallet_outlined,    activeIcon: Icons.account_balance_wallet_rounded,   label: 'Carteira'),
    _NavItemDef(screenIndex: 3, configKey: 'navIndicacoes', isChatTab: false,
      icon: Icons.people_outline_rounded,             activeIcon: Icons.people_alt_rounded,               label: 'Indicações'),
    _NavItemDef(screenIndex: 4, configKey: 'navChat',       isChatTab: true,
      icon: Icons.chat_bubble_outline_rounded,        activeIcon: Icons.chat_bubble_rounded,              label: 'Chat'),
    _NavItemDef(screenIndex: 5, configKey: 'navPerfil',     isChatTab: false,
      icon: Icons.person_outline_rounded,             activeIcon: Icons.person_rounded,                   label: 'Perfil'),
  ];

  @override
  void initState() {
    super.initState();
    // Garante índice válido ao montar (singleton pode ter índice de sessão anterior)
    if (_ctrl.index >= _allScreens.length) {
      _ctrl.goTo(0);
    }
    _visitadas.add(_ctrl.index);
    _ctrl.addListener(_onNavChange);
    // Inicia escuta de não lidas após o primeiro frame (aguarda auth carregar)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startChatListener();
      // Carrega config de menus em background (sem bloquear UI)
      context.read<AppConfigService>().load();
    });
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
    final idx         = _ctrl.index;
    final totalUnread = context.watch<ChatService>().totalUnread;
    final menuCfg     = context.watch<AppConfigService>().config;

    // Filtra os itens visíveis baseado na config do admin
    final visibleDefs = _allNavDefs.where((d) => _isNavVisible(d, menuCfg)).toList();

    // Mapeia o índice global (screenIndex) para o índice visível
    final visibleScreenIndices = visibleDefs.map((d) => d.screenIndex).toList();
    // Índice na lista visível correspondente ao _ctrl.index atual
    int visibleIdx = visibleScreenIndices.indexOf(idx);
    if (visibleIdx < 0) visibleIdx = 0; // fallback para home se aba oculta

    return Scaffold(
      body: IndexedStack(
        // IndexedStack mantém TODAS as telas para preservar estado
        index: idx.clamp(0, _allScreens.length - 1),
        children: List.generate(_allScreens.length, (i) {
          if (!_visitadas.contains(i)) return const SizedBox.shrink();
          return _allScreens[i];
        }),
      ),
      bottomNavigationBar: _BottomNavWithBadge(
        currentIndex: visibleIdx,
        items: visibleDefs.map((d) => _NavItem(
          icon: d.icon,
          activeIcon: d.activeIcon,
          label: d.label,
        )).toList(),
        chatBadge: totalUnread,
        chatVisibleIndex: visibleDefs.indexWhere((d) => d.isChatTab),
        onTap: (visIdx) {
          final screenIdx = visibleScreenIndices[visIdx];
          _visitadas.add(screenIdx);
          _ctrl.goTo(screenIdx);
        },
      ),
    );
  }

  bool _isNavVisible(_NavItemDef def, AppMenuConfig cfg) {
    switch (def.configKey) {
      case 'navInicio':     return cfg.navInicio;     // sempre true (locked)
      case 'navProdutos':   return cfg.navProdutos;
      case 'navCarteira':   return cfg.navCarteira;
      case 'navIndicacoes': return cfg.navIndicacoes;
      case 'navChat':       return cfg.navChat;
      case 'navPerfil':     return cfg.navPerfil;
      default:              return true;
    }
  }
}

// -- Definição de item de nav (usado para filtragem dinâmica) ----------------
class _NavItemDef {
  final int screenIndex;   // índice na _allScreens
  final String configKey;  // chave em AppMenuConfig
  final bool isChatTab;    // identifica aba de chat (recebe badge)
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItemDef({
    required this.screenIndex,
    required this.configKey,
    required this.isChatTab,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

// -- Bottom Nav com badge de mensagens não lidas ------------------------------
class _BottomNavWithBadge extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final int chatBadge;          // contagem de mensagens não lidas
  final int chatVisibleIndex;   // índice visível da aba de chat (-1 se oculta)
  final void Function(int) onTap;

  const _BottomNavWithBadge({
    required this.currentIndex,
    required this.items,
    required this.chatBadge,
    required this.chatVisibleIndex,
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
              // chat (chatVisibleIndex) = azul claro, demais = primary
              final bool isChat = chatVisibleIndex >= 0 && i == chatVisibleIndex;
              final Color activeColor = isChat
                  ? const Color(0xFF29B6F6)
                  : AppColors.primary;

              // Badge de não lidas somente na aba de chat
              final bool showBadge = isChat && chatBadge > 0;

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
