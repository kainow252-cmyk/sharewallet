import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';
import 'admin_dashboard_screen.dart';
import 'admin_products_screen.dart';
import 'admin_affiliates_screen.dart';
import 'admin_subscriptions_screen.dart';
import 'admin_withdrawals_screen.dart';

class AdminNavScreen extends StatefulWidget {
  const AdminNavScreen({super.key});

  @override
  State<AdminNavScreen> createState() => _AdminNavScreenState();
}

class _AdminNavScreenState extends State<AdminNavScreen> {
  int _selectedIndex = 0;

  static const List<_NavItem> _items = [
    _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard'),
    _NavItem(icon: Icons.inventory_2_rounded, label: 'Produtos'),
    _NavItem(icon: Icons.people_rounded, label: 'Afiliados'),
    _NavItem(icon: Icons.repeat_rounded, label: 'Assinaturas'),
    _NavItem(icon: Icons.account_balance_wallet_rounded, label: 'Saques'),
  ];

  final List<Widget> _screens = const [
    AdminDashboardScreen(),
    AdminProductsScreen(),
    AdminAffiliatesScreen(),
    AdminSubscriptionsScreen(),
    AdminWithdrawalsScreen(),
  ];

  void _onDestinationSelected(int idx) {
    setState(() => _selectedIndex = idx);
  }

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sair do Painel Admin'),
        content: const Text('Tem certeza que deseja sair?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      context.read<AdminService>().adminLogout();
      Navigator.pushReplacementNamed(context, '/admin/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<AdminService>();
    final pending = svc.withdrawals.where((w) => w.status == 'pendente').length;
    final isWide = MediaQuery.of(context).size.width >= 800;

    // ── Layout Desktop (NavigationRail) ──────────────────────────────────────
    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            // Sidebar
            Container(
              width: 220,
              color: const Color(0xFF071A10),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // Logo
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: AppColors.greenGradient,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.admin_panel_settings_rounded,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Admin',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16)),
                            Text('Affiliate Wallet',
                                style: TextStyle(
                                    color: Color(0xFF6DBF9A), fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Nav items
                  ..._items.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    final isSelected = _selectedIndex == i;
                    // Badge de saques pendentes
                    final showBadge = i == 4 && pending > 0;
                    return _SidebarItem(
                      icon: item.icon,
                      label: item.label,
                      isSelected: isSelected,
                      badge: showBadge ? pending : null,
                      onTap: () => _onDestinationSelected(i),
                    );
                  }),

                  const Spacer(),
                  const Divider(color: Color(0xFF1A3A28), height: 1),
                  const SizedBox(height: 8),
                  _SidebarItem(
                    icon: Icons.logout_rounded,
                    label: 'Sair',
                    isSelected: false,
                    onTap: () => _logout(context),
                    isLogout: true,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Conteúdo
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: _screens,
              ),
            ),
          ],
        ),
      );
    }

    // ── Layout Mobile (BottomNavigationBar) ──────────────────────────────────
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF071A10),
        title: Row(
          children: [
            const Icon(Icons.admin_panel_settings_rounded,
                color: AppColors.gold, size: 22),
            const SizedBox(width: 8),
            Text(
              _items[_selectedIndex].label,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            tooltip: 'Sair',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF071A10),
          border: Border(
              top: BorderSide(color: Color(0xFF1A3A28), width: 1)),
        ),
        child: SafeArea(
          child: Row(
            children: _items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final isSelected = _selectedIndex == i;
              final showBadge = i == 4 && pending > 0;
              return Expanded(
                child: InkWell(
                  onTap: () => _onDestinationSelected(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              item.icon,
                              color: isSelected
                                  ? AppColors.gold
                                  : Colors.white30,
                              size: 22,
                            ),
                            if (showBadge)
                              Positioned(
                                right: -6,
                                top: -4,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '$pending',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.gold
                                : Colors.white30,
                            fontSize: 9,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
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

// ── Sidebar item ──────────────────────────────────────────────────────────────
class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int? badge;
  final bool isLogout;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badge,
    this.isLogout = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isLogout
        ? Colors.red[300]!
        : isSelected
            ? AppColors.gold
            : Colors.white54;

    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.gold.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 20),
                if (badge != null)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$badge',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
