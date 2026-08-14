import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';
import 'admin_dashboard_screen.dart';
import 'admin_products_screen.dart';
import 'admin_affiliates_screen.dart';
import 'admin_subscriptions_screen.dart';
import 'admin_withdrawals_screen.dart';
import '../../services/woovi_admin_service.dart';
import 'admin_woovi_settings_screen.dart';
import 'admin_sales_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_reset_screen.dart';
import 'admin_chat_screen.dart';
import 'admin_menu_config_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Cores do tema admin (verde escuro profissional)
// ─────────────────────────────────────────────────────────────────────────────
class _AdminColors {
  static const bg        = Color(0xFF071A10);  // fundo sidebar
  static const border    = Color(0xFF163424);  // divisores
  static const accent    = Color(0xFFC9A84C);  // dourado ativo
  static const accentBg  = Color(0x22C9A84C);  // fundo item ativo
  static const textOn    = Colors.white;
  static const textOff   = Color(0xFF7AAE90);  // verde-acinzentado inativo
  static const resetRed  = Color(0xFFFF5252);
}

// ─────────────────────────────────────────────────────────────────────────────
class AdminNavScreen extends StatefulWidget {
  const AdminNavScreen({super.key});
  @override
  State<AdminNavScreen> createState() => _AdminNavScreenState();
}

class _AdminNavScreenState extends State<AdminNavScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ⚡ WooviAdminService criado UMA ÚNICA VEZ no State — não recria a cada rebuild
  // Antes estava no getter _screens (List<Widget> get _screens => [...]) o que
  // causava recriação da instância toda vez que setState() era chamado,
  // perdendo os dados carregados e mostrando AppID vazio após login.
  final WooviAdminService _wooviService = WooviAdminService();

  @override
  void initState() {
    super.initState();
    // Se o admin chegou aqui via login de afiliado (email-based redirect),
    // o AdminService ainda não foi inicializado — fazemos isso agora.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminService>().initFromExistingSession();
    });
  }

  @override
  void dispose() {
    _wooviService.dispose();
    super.dispose();
  }

  static const List<_NavItem> _items = [
    _NavItem(icon: Icons.dashboard_rounded,               label: 'Dashboard'),
    _NavItem(icon: Icons.inventory_2_rounded,             label: 'Produtos'),
    _NavItem(icon: Icons.people_rounded,                  label: 'Afiliados'),
    _NavItem(icon: Icons.repeat_rounded,                  label: 'Assinaturas'),
    _NavItem(icon: Icons.account_balance_wallet_rounded,  label: 'Saques'),
    _NavItem(icon: Icons.receipt_long_rounded,            label: 'Vendas'),
    _NavItem(icon: Icons.payment_rounded,                 label: 'Pagamentos'),
    _NavItem(icon: Icons.assessment_rounded,              label: 'Relatórios'),
    _NavItem(icon: Icons.chat_bubble_rounded,             label: 'Chat'),
    _NavItem(icon: Icons.tune_rounded,                    label: 'Menus'),
    _NavItem(icon: Icons.delete_sweep_rounded,            label: 'Reset', isReset: true),
  ];

  // ⚡ _screens é uma lista FIXA (late final) — construída uma única vez
  // Garante que o WooviAdminService (e outros stateful providers) nunca
  // sejam recriados quando setState() é chamado na navegação.
  late final List<Widget> _screens = [
    AdminDashboardScreen(onNavigateTo: _onDestinationSelected),
    const AdminProductsScreen(),
    const AdminAffiliatesScreen(),
    const AdminSubscriptionsScreen(),
    const AdminWithdrawalsScreen(),
    const AdminSalesScreen(),
    ChangeNotifierProvider.value(
      value: _wooviService,          // reutiliza a instância fixa
      child: const AdminWooviSettingsScreen(),
    ),
    const AdminReportsScreen(),
    const AdminChatScreen(),
    const AdminMenuConfigScreen(),
    const AdminResetScreen(),
  ];

  void _onDestinationSelected(int idx) {
    setState(() => _selectedIndex = idx);
    // Fecha o drawer se estiver aberto (mobile)
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  void _refresh() {
    final s = context.read<AdminService>();
    switch (_selectedIndex) {
      case 1: s.loadProducts(); break;
      case 2: s.loadAffiliates(); break;
      case 3: s.loadSubscriptions(); break;
      case 4: s.loadWithdrawals(); break;
      case 5: s.loadSales(); break;
      case 8: break; // Chat — sem refresh do AdminService
      case 9: break; // Menus — sem refresh do AdminService
      case 10: break; // Reset
      default: s.loadAll(); break;
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(  // já é async ✓
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D2518),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sair do Painel',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text('Tem certeza que deseja sair?',
            style: TextStyle(color: _AdminColors.textOff)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar',
                style: TextStyle(color: _AdminColors.textOff)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Sair',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      // Aguarda signOut do Firebase antes de navegar — evita loop de redirecionamento
      await context.read<AdminService>().adminLogout();
      if (!mounted) return;
      // Vai para /admin/login (não /landing, que redireciona de volta para /admin se logado)
      Navigator.pushReplacementNamed(context, '/admin/login');
    }
  }

  // ── Drawer / Sidebar (compartilhado entre mobile e desktop) ─────────────
  Widget _buildSidebar({bool isDrawer = false}) {
    final pending = context.watch<AdminService>()
        .withdrawals
        .where((w) => w.status == 'pendente')
        .length;

    return Container(
      width: 240,
      color: _AdminColors.bg,
      child: Column(
        children: [
          // ── Cabeçalho ─────────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      gradient: AppColors.greenGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 12, offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.admin_panel_settings_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Admin Panel',
                          style: TextStyle(
                              color: _AdminColors.textOn,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              letterSpacing: 0.3)),
                      Text('ShareWallet',
                          style: TextStyle(
                              color: _AdminColors.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  if (isDrawer) ...[
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: _AdminColors.textOff, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Linha divisória dourada fina
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                _AdminColors.accent.withValues(alpha: 0.5),
                Colors.transparent,
              ]),
            ),
          ),

          // ── Itens de navegação ────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              children: [
                ..._items.asMap().entries.map((e) {
                  final i    = e.key;
                  final item = e.value;
                  return _SidebarItem(
                    icon: item.icon,
                    label: item.label,
                    isSelected: _selectedIndex == i,
                    isReset: item.isReset,
                    badge: i == 4 && pending > 0 ? pending : null,
                    onTap: () => _onDestinationSelected(i),
                  );
                }),
              ],
            ),
          ),

          // ── Rodapé: Sair ──────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            height: 1,
            color: _AdminColors.border,
          ),
          const SizedBox(height: 4),
          _SidebarItem(
            icon: Icons.logout_rounded,
            label: 'Sair',
            isSelected: false,
            isReset: true,
            onTap: _logout,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── AppBar compartilhada ─────────────────────────────────────────────────
  AppBar _buildAppBar({required bool isMobile}) {
    return AppBar(
      backgroundColor: _AdminColors.bg,
      elevation: 0,
      automaticallyImplyLeading: false,

      // Hambúrguer apenas no mobile
      leading: isMobile
          ? IconButton(
              icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              tooltip: 'Menu',
            )
          : null,

      title: Row(
        children: [
          if (!isMobile) ...[
            const Icon(Icons.admin_panel_settings_rounded,
                color: _AdminColors.accent, size: 20),
            const SizedBox(width: 8),
          ],
          Text(
            _selectedIndex < _items.length ? _items[_selectedIndex].label : '',
            style: const TextStyle(
                color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
          ),
          if (_items[_selectedIndex].isReset) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.4)),
              ),
              child: const Text('PERIGO',
                  style: TextStyle(
                      color: AppColors.error,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1)),
            ),
          ],
        ],
      ),

      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
          tooltip: 'Atualizar',
          onPressed: _refresh,
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white70),
          tooltip: 'Sair',
          onPressed: _logout,
        ),
        const SizedBox(width: 4),
      ],

      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _AdminColors.border),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    final content = IndexedStack(index: _selectedIndex, children: _screens);

    // ── Desktop: sidebar fixa à esquerda ────────────────────────────────────
    if (isWide) {
      return Scaffold(
        appBar: _buildAppBar(isMobile: false),
        body: Row(
          children: [
            _buildSidebar(isDrawer: false),
            Container(width: 1, color: _AdminColors.border),
            Expanded(child: content),
          ],
        ),
      );
    }

    // ── Mobile: hambúrguer → Drawer (igual ao sidebar web) ──────────────────
    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildAppBar(isMobile: true),
      drawer: Drawer(
        width: 240,
        backgroundColor: _AdminColors.bg,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: _buildSidebar(isDrawer: true),
      ),
      body: content,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget item da sidebar
// ─────────────────────────────────────────────────────────────────────────────
class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isReset;
  final int? badge;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isReset = false,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final color = isReset
        ? (isSelected ? _AdminColors.resetRed : _AdminColors.resetRed.withValues(alpha: 0.6))
        : (isSelected ? _AdminColors.accent : _AdminColors.textOff);

    final bgColor = isSelected
        ? (isReset
            ? AppColors.error.withValues(alpha: 0.12)
            : _AdminColors.accentBg)
        : Colors.transparent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: isSelected
            ? Border.all(
                color: isReset
                    ? AppColors.error.withValues(alpha: 0.3)
                    : _AdminColors.accent.withValues(alpha: 0.35),
                width: 1,
              )
            : null,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: _AdminColors.accent.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              // Ícone com badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, color: color, size: 19),
                  if (badge != null)
                    Positioned(
                      right: -8, top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('$badge',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              // Label
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 13.5,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w400,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              // Indicador ativo
              if (isSelected)
                Container(
                  width: 4, height: 4,
                  decoration: BoxDecoration(
                    color: isReset ? _AdminColors.resetRed : _AdminColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final String label;
  final bool isReset;
  const _NavItem(
      {required this.icon, required this.label, this.isReset = false});
}
