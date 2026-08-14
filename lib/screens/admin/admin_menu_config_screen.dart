import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_config_service.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN MENU CONFIG SCREEN
// Controla quais itens aparecem na nav bar e nos quick actions do usuário
// ─────────────────────────────────────────────────────────────────────────────
class AdminMenuConfigScreen extends StatefulWidget {
  const AdminMenuConfigScreen({super.key});

  @override
  State<AdminMenuConfigScreen> createState() => _AdminMenuConfigScreenState();
}

class _AdminMenuConfigScreenState extends State<AdminMenuConfigScreen> {
  late AppMenuConfig _draft;
  bool _saving = false;
  bool _saved  = false;

  @override
  void initState() {
    super.initState();
    final svc = context.read<AppConfigService>();
    _draft = svc.config;
    // Sempre recarrega do remoto ao abrir a tela
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await svc.load(forceRemote: true);
      if (mounted) setState(() => _draft = svc.config);
    });
  }

  Future<void> _save() async {
    setState(() { _saving = true; _saved = false; });
    final ok = await context.read<AppConfigService>().save(_draft);
    if (!mounted) return;
    setState(() { _saving = false; _saved = ok; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded,
            color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Text(ok ? 'Configuração salva com sucesso!' : 'Erro ao salvar. Tente novamente.'),
      ]),
      backgroundColor: ok ? const Color(0xFF1B5E20) : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  void _reset() {
    setState(() {
      _draft = const AppMenuConfig();
      _saved = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<AppConfigService>();

    if (svc.loading && _draft.toJson().values.every((v) => v == true)) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFC9A84C)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          _SectionHeader(
            icon: Icons.tune_rounded,
            title: 'Configuração de Menus',
            subtitle: 'Controle quais itens aparecem para os usuários do app',
          ),
          const SizedBox(height: 24),

          // ── Seção: Nav Bar ─────────────────────────────────────────────────
          _GroupCard(
            icon: Icons.tab_rounded,
            title: 'Barra de Navegação (inferior)',
            subtitle: 'Itens visíveis no rodapé do app',
            accentColor: const Color(0xFF00BFA5),
            children: [
              _MenuToggle(
                icon: Icons.home_rounded,
                label: 'Início',
                subtitle: 'Tela principal do dashboard',
                value: _draft.navInicio,
                locked: true, // Início nunca pode ser ocultado
                onChanged: null,
              ),
              _MenuToggle(
                icon: Icons.store_rounded,
                label: 'Produtos',
                subtitle: 'Catálogo de produtos para venda',
                value: _draft.navProdutos,
                onChanged: (v) => setState(() =>
                    _draft = _draft.copyWith(navProdutos: v)),
              ),
              _MenuToggle(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Carteira',
                subtitle: 'Saldo, extrato e saques',
                value: _draft.navCarteira,
                onChanged: (v) => setState(() =>
                    _draft = _draft.copyWith(navCarteira: v)),
              ),
              _MenuToggle(
                icon: Icons.people_rounded,
                label: 'Indicações',
                subtitle: 'Rede de afiliados indicados',
                value: _draft.navIndicacoes,
                onChanged: (v) => setState(() =>
                    _draft = _draft.copyWith(navIndicacoes: v)),
              ),
              _MenuToggle(
                icon: Icons.chat_bubble_rounded,
                label: 'Chat',
                subtitle: 'Mensagens entre afiliados',
                value: _draft.navChat,
                onChanged: (v) => setState(() =>
                    _draft = _draft.copyWith(navChat: v)),
              ),
              _MenuToggle(
                icon: Icons.person_rounded,
                label: 'Perfil',
                subtitle: 'Dados pessoais e configurações',
                value: _draft.navPerfil,
                onChanged: (v) => setState(() =>
                    _draft = _draft.copyWith(navPerfil: v)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Seção: Quick Actions ───────────────────────────────────────────
          _GroupCard(
            icon: Icons.grid_view_rounded,
            title: 'Atalhos Rápidos (Home)',
            subtitle: 'Botões de acesso rápido na tela inicial',
            accentColor: const Color(0xFFC9A84C),
            children: [
              _MenuToggle(
                icon: Icons.store_rounded,
                label: 'Produtos',
                subtitle: 'Atalho rápido para produtos',
                value: _draft.quickProdutos,
                onChanged: (v) => setState(() =>
                    _draft = _draft.copyWith(quickProdutos: v)),
              ),
              _MenuToggle(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Carteira',
                subtitle: 'Atalho rápido para carteira',
                value: _draft.quickCarteira,
                onChanged: (v) => setState(() =>
                    _draft = _draft.copyWith(quickCarteira: v)),
              ),
              _MenuToggle(
                icon: Icons.people_rounded,
                label: 'Indicações',
                subtitle: 'Atalho rápido para indicações',
                value: _draft.quickIndicacoes,
                onChanged: (v) => setState(() =>
                    _draft = _draft.copyWith(quickIndicacoes: v)),
              ),
              _MenuToggle(
                icon: Icons.chat_bubble_rounded,
                label: 'Chat',
                subtitle: 'Atalho rápido para chat',
                value: _draft.quickChat,
                onChanged: (v) => setState(() =>
                    _draft = _draft.copyWith(quickChat: v)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Preview ────────────────────────────────────────────────────────
          _PreviewCard(config: _draft),
          const SizedBox(height: 28),

          // ── Botões de ação ─────────────────────────────────────────────────
          Row(
            children: [
              // Reset
              OutlinedButton.icon(
                onPressed: _saving ? null : _reset,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Resetar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white54,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 12),
              // Salvar
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(
                          _saved
                              ? Icons.check_circle_rounded
                              : Icons.save_rounded,
                          size: 18),
                  label: Text(
                    _saving ? 'Salvando...' : _saved ? 'Salvo!' : 'Salvar Configuração',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _saved
                        ? const Color(0xFF1B5E20)
                        : const Color(0xFFC9A84C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Preview card — mostra como a nav bar ficará
// ─────────────────────────────────────────────────────────────────────────────
class _PreviewCard extends StatelessWidget {
  final AppMenuConfig config;
  const _PreviewCard({required this.config});

  @override
  Widget build(BuildContext context) {
    final navItems = [
      if (config.navInicio)     _PrevItem(Icons.home_rounded,                    'Início',    true),
      if (config.navProdutos)   _PrevItem(Icons.store_rounded,                   'Produtos',  false),
      if (config.navCarteira)   _PrevItem(Icons.account_balance_wallet_rounded,  'Carteira',  false),
      if (config.navIndicacoes) _PrevItem(Icons.people_rounded,                  'Indicações',false),
      if (config.navChat)       _PrevItem(Icons.chat_bubble_rounded,             'Chat',      false),
      if (config.navPerfil)     _PrevItem(Icons.person_rounded,                  'Perfil',    false),
    ];

    final quickItems = [
      if (config.quickProdutos)   _PrevItem(Icons.store_rounded,                  'Produtos',  false),
      if (config.quickCarteira)   _PrevItem(Icons.account_balance_wallet_rounded, 'Carteira',  false),
      if (config.quickIndicacoes) _PrevItem(Icons.people_rounded,                 'Indicações',false),
      if (config.quickChat)       _PrevItem(Icons.chat_bubble_rounded,            'Chat',      false),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D2518),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC9A84C).withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.preview_rounded, color: Color(0xFFC9A84C), size: 16),
            const SizedBox(width: 8),
            const Text('Preview da Navegação',
                style: TextStyle(
                    color: Color(0xFFC9A84C),
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ]),
          const SizedBox(height: 16),

          // Quick Actions preview
          const Text('Atalhos Rápidos:',
              style: TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 8),
          quickItems.isEmpty
              ? const Text('Nenhum atalho visível',
                  style: TextStyle(color: Colors.white38, fontSize: 12))
              : Wrap(
                  spacing: 8, runSpacing: 8,
                  children: quickItems.map((item) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(item.icon, color: Colors.white70, size: 14),
                      const SizedBox(width: 6),
                      Text(item.label,
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ]),
                  )).toList(),
                ),

          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),

          // Nav Bar preview
          const Text('Barra de Navegação:',
              style: TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 10),
          navItems.isEmpty
              ? const Text('Nenhum item na nav bar!',
                  style: TextStyle(color: Colors.redAccent, fontSize: 12))
              : Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF071A10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: navItems.map((item) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item.icon,
                            color: item.isActive
                                ? const Color(0xFFC9A84C)
                                : Colors.white38,
                            size: 20),
                        const SizedBox(height: 4),
                        Text(item.label,
                            style: TextStyle(
                              color: item.isActive
                                  ? const Color(0xFFC9A84C)
                                  : Colors.white38,
                              fontSize: 9,
                              fontWeight: item.isActive
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            )),
                      ],
                    )).toList(),
                  ),
                ),
        ],
      ),
    );
  }
}

class _PrevItem {
  final IconData icon;
  final String label;
  final bool isActive;
  const _PrevItem(this.icon, this.label, this.isActive);
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SectionHeader({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFC9A84C).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFFC9A84C), size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 17)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final List<Widget> children;

  const _GroupCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D2518),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header do grupo
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: accentColor, size: 16),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: accentColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: accentColor.withValues(alpha: 0.15)),
          // Items
          ...children,
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _MenuToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final bool locked;
  final ValueChanged<bool>? onChanged;

  const _MenuToggle({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    this.locked = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isOn = value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(
        children: [
          // Ícone
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: isOn
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon,
                color: isOn ? Colors.white70 : Colors.white24,
                size: 17),
          ),
          const SizedBox(width: 12),
          // Textos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(label,
                        style: TextStyle(
                          color: isOn ? Colors.white : Colors.white38,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        )),
                    if (locked) ...const [
                      SizedBox(width: 6),
                      _LockedBadge(),
                    ],
                  ],
                ),
                Text(subtitle,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          // Toggle
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: isOn,
              onChanged: locked ? null : onChanged,
              activeColor: const Color(0xFFC9A84C),
              activeTrackColor: const Color(0xFFC9A84C).withValues(alpha: 0.3),
              inactiveThumbColor: Colors.white24,
              inactiveTrackColor: Colors.white12,
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedBadge extends StatelessWidget {
  const _LockedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_rounded, color: Colors.white38, size: 9),
          SizedBox(width: 3),
          Text('fixo', style: TextStyle(color: Colors.white38, fontSize: 9)),
        ],
      ),
    );
  }
}
