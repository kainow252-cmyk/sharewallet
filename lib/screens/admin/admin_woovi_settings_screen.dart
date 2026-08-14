import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/woovi_admin_service.dart';
import '../../services/mp_admin_service.dart';
import '../../theme/app_theme.dart';

// ignore_for_file: use_build_context_synchronously

// ── Cores ──────────────────────────────────────────────────────────────────
const _wooviPurple = Color(0xFF6C3CE1);
const _wooviGreen  = Color(0xFF00C851);
const _mpBlue      = Color(0xFF009EE3);

// ===========================================================================
// AdminWooviSettingsScreen (agora multi-gateway)
// ===========================================================================

class AdminWooviSettingsScreen extends StatefulWidget {
  const AdminWooviSettingsScreen({super.key});

  @override
  State<AdminWooviSettingsScreen> createState() =>
      _AdminWooviSettingsScreenState();
}

class _AdminWooviSettingsScreenState extends State<AdminWooviSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WooviAdminService>().resetAndReload();
      context.read<MpAdminService>().resetAndReload();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer2<WooviAdminService, MpAdminService>(
        builder: (_, wooviSvc, mpSvc, __) {
          final loading = !wooviSvc.isConfigLoaded || !mpSvc.isLoaded;
          if (loading) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              // ── Seletor de gateway ativo ──────────────────────────────────
              _GatewaySelectorBar(mpSvc: mpSvc),
              // ── Abas ─────────────────────────────────────────────────────
              Container(
                color: const Color(0xFF071A10),
                child: TabBar(
                  controller: _tab,
                  labelColor: AppColors.gold,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: AppColors.gold,
                  tabs: const [
                    Tab(icon: Icon(Icons.key_rounded),      text: 'Credenciais'),
                    Tab(icon: Icon(Icons.settings_rounded), text: 'Configurações'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _CredentialsTab(mpSvc: mpSvc),
                    _SettingsTab(svc: wooviSvc),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ===========================================================================
// _GatewaySelectorBar — escolher Woovi ou Mercado Pago
// ===========================================================================

class _GatewaySelectorBar extends StatefulWidget {
  final MpAdminService mpSvc;
  const _GatewaySelectorBar({required this.mpSvc});

  @override
  State<_GatewaySelectorBar> createState() => _GatewaySelectorBarState();
}

class _GatewaySelectorBarState extends State<_GatewaySelectorBar> {
  bool _switching = false;

  Future<void> _switchGateway(GatewayType gw) async {
    if (_switching) return;
    if (gw == widget.mpSvc.activeGateway) return;

    // Confirmação ao desativar
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Ativar ${gw.label}?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          gw == GatewayType.woovi
              ? 'O gateway Woovi (PIX nativo) será ativado.\nMercado Pago ficará inativo.'
              : gw == GatewayType.mercadopago
                  ? 'O Mercado Pago será ativado como gateway principal.\nWoovi ficará inativo.'
                  : 'Todos os gateways serão desativados.\nNovos pagamentos não serão processados.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: gw == GatewayType.woovi ? _wooviPurple : _mpBlue,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _switching = true);
    await widget.mpSvc.setActiveGateway(gw);
    if (mounted) {
      setState(() => _switching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gateway ativo: ${gw.label}'),
          backgroundColor: gw == GatewayType.woovi
              ? _wooviPurple
              : gw == GatewayType.mercadopago
                  ? _mpBlue
                  : AppColors.warning,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = context.watch<MpAdminService>().activeGateway;

    return Container(
      color: const Color(0xFF0A1A0F),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.swap_horiz_rounded, size: 16, color: AppColors.gold),
              const SizedBox(width: 6),
              Text(
                'Gateway de Pagamento Ativo',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              if (_switching) ...const [
                SizedBox(width: 8),
                SizedBox(
                  width: 12, height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Woovi
              Expanded(
                child: _GatewayChip(
                  label: 'Woovi / PIX',
                  icon: 'W',
                  color: _wooviPurple,
                  active: active == GatewayType.woovi,
                  onTap: () => _switchGateway(GatewayType.woovi),
                ),
              ),
              const SizedBox(width: 8),
              // Mercado Pago
              Expanded(
                child: _GatewayChip(
                  label: 'Mercado Pago',
                  icon: 'MP',
                  color: _mpBlue,
                  active: active == GatewayType.mercadopago,
                  onTap: () => _switchGateway(GatewayType.mercadopago),
                ),
              ),
              const SizedBox(width: 8),
              // Nenhum
              _GatewayChip(
                label: 'Off',
                icon: '✕',
                color: Colors.grey,
                active: active == GatewayType.none,
                compact: true,
                onTap: () => _switchGateway(GatewayType.none),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GatewayChip extends StatelessWidget {
  final String label;
  final String icon;
  final Color  color;
  final bool   active;
  final bool   compact;
  final VoidCallback onTap;

  const _GatewayChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.active,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? color : Colors.white12,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: compact
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: active ? color : Colors.white10,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                icon,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: icon.length > 1 ? 10 : 13,
                ),
              ),
            ),
            if (!compact) ...[ 
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: active ? Colors.white : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    if (active)
                      Text(
                        'ATIVO',
                        style: TextStyle(
                          color: color,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Aba 1 — Credenciais (Woovi + Mercado Pago unificado)
// ===========================================================================

class _CredentialsTab extends StatefulWidget {
  final MpAdminService mpSvc;
  const _CredentialsTab({required this.mpSvc});

  @override
  State<_CredentialsTab> createState() => _CredentialsTabState();
}

class _CredentialsTabState extends State<_CredentialsTab>
    with SingleTickerProviderStateMixin {
  late TabController _innerTab;

  @override
  void initState() {
    super.initState();
    _innerTab = TabController(length: 2, vsync: this);
    // Abre na aba do gateway ativo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.mpSvc.activeGateway == GatewayType.mercadopago) {
        _innerTab.animateTo(1);
      }
    });
  }

  @override
  void dispose() {
    _innerTab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Inner tabs
        Container(
          color: const Color(0xFF050F08),
          child: TabBar(
            controller: _innerTab,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            indicatorColor: _wooviPurple,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            tabs: const [
              Tab(text: 'Woovi / OpenPix'),
              Tab(text: 'Mercado Pago'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _innerTab,
            children: [
              const _WooviCredTab(),
              _MpCredTab(mpSvc: widget.mpSvc),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Sub-aba Woovi ────────────────────────────────────────────────────────────

class _WooviCredTab extends StatefulWidget {
  const _WooviCredTab();

  @override
  State<_WooviCredTab> createState() => _WooviCredTabState();
}

class _WooviCredTabState extends State<_WooviCredTab> {
  final _appIdCtrl  = TextEditingController();
  bool  _obscure    = true;
  bool  _saving     = false;
  String? _erro;
  String? _sucesso;
  bool  _initialized = false;

  @override
  void dispose() {
    _appIdCtrl.dispose();
    super.dispose();
  }

  void _initIfNeeded(WooviConfig cfg) {
    if (!_initialized) {
      if (cfg.appId.isNotEmpty) _appIdCtrl.text = cfg.appId;
      _initialized = true;
    }
  }

  Future<void> _salvar(WooviAdminService svc) async {
    final appId = _appIdCtrl.text.trim();
    if (appId.isEmpty) {
      setState(() => _erro = 'Informe o AppID da Woovi.');
      return;
    }
    setState(() { _saving = true; _erro = null; _sucesso = null; });
    final res = await svc.verifyAppId(appId);
    if (!mounted) return;
    if (!res.ok) {
      setState(() { _saving = false; _erro = res.error; });
      return;
    }
    final newCfg = svc.config.copyWith(
      appId: appId, verified: true, accountName: res.accountName,
    );
    final ok = await svc.saveConfig(newCfg);
    if (!mounted) return;
    setState(() {
      _saving  = false;
      _sucesso = ok ? 'AppID verificado e salvo!' : null;
      _erro    = ok ? null : 'Erro ao salvar.';
    });
  }

  Future<void> _remover(WooviAdminService svc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Remover AppID Woovi?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'A integração Woovi será desativada.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() { _saving = true; });
    await svc.saveConfig(
        svc.config.copyWith(appId: '', verified: false, accountName: ''));
    if (!mounted) return;
    _appIdCtrl.clear();
    _initialized = false;
    setState(() { _saving = false; _sucesso = 'AppID removido.'; });
  }

  @override
  Widget build(BuildContext context) {
    final svc        = context.watch<WooviAdminService>();
    final cfg        = svc.config;
    final configured = cfg.verified && cfg.appId.isNotEmpty;
    _initIfNeeded(cfg);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Banner
        _ModoBanner(
          label: configured ? 'Modo Produção Ativo' : 'Não Configurado',
          subtitle: configured
              ? 'Processando pagamentos reais via Woovi'
              : 'Configure o AppID para ativar pagamentos PIX',
          icon: 'W',
          color: _wooviPurple,
          isActive: configured,
        ),
        const SizedBox(height: 16),

        // Card AppID
        _SectionCard(
          title: 'AppID de Produção',
          badge: configured ? 'CONFIGURADO' : 'PENDENTE',
          badgeColor: configured ? _wooviGreen : AppColors.warning,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _appIdCtrl,
                obscureText: _obscure,
                maxLines: 1,
                decoration: InputDecoration(
                  labelText: 'AppID (Authorization Token)',
                  hintText: 'Q2xpZW50X0lkX...',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                      if (cfg.appId.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: cfg.appId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('AppID copiado!'),
                                  duration: Duration(seconds: 2)),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Encontre o AppID no Dashboard Woovi → API/Plugins → AppID',
                style: TextStyle(
                    fontSize: 11, color: AppColors.textHint, height: 1.4),
              ),
              if (_erro != null) ...[
                const SizedBox(height: 10),
                _AlertBox(
                    icon: Icons.error_rounded,
                    color: AppColors.error,
                    text: _erro!),
              ],
              if (_sucesso != null) ...[
                const SizedBox(height: 10),
                _AlertBox(
                    icon: Icons.check_circle_rounded,
                    color: _wooviGreen,
                    text: _sucesso!),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (_saving || svc.isVerifying)
                          ? null
                          : () => _salvar(svc),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _wooviPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: (_saving || svc.isVerifying)
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.verified_rounded, size: 18),
                      label: Text(
                        (_saving || svc.isVerifying)
                            ? 'Verificando...'
                            : 'Verificar e Salvar',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  if (configured) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : () => _remover(svc),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Remover'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Status
        _SectionCard(
          title: 'Status Atual',
          child: _WooviStatusTable(cfg: cfg),
        ),
        const SizedBox(height: 16),

        // Webhook
        _SectionCard(
          title: 'Webhook Woovi',
          child: _WebhookInfo(webhookUrl: cfg.webhookUrl),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Sub-aba Mercado Pago ─────────────────────────────────────────────────────

class _MpCredTab extends StatefulWidget {
  final MpAdminService mpSvc;
  const _MpCredTab({required this.mpSvc});

  @override
  State<_MpCredTab> createState() => _MpCredTabState();
}

class _MpCredTabState extends State<_MpCredTab> {
  final _tokenCtrl  = TextEditingController();
  final _pubKeyCtrl = TextEditingController();
  bool  _obscure    = true;
  bool  _saving     = false;
  bool  _sandbox    = false;
  String? _erro;
  String? _sucesso;
  bool  _initialized = false;

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _pubKeyCtrl.dispose();
    super.dispose();
  }

  void _initIfNeeded(MpConfig cfg) {
    if (!_initialized) {
      // token mascarado — não preenche campo por segurança
      _pubKeyCtrl.text = cfg.publicKey;
      _sandbox = cfg.sandbox;
      _initialized = true;
    }
  }

  Future<void> _salvar() async {
    final token  = _tokenCtrl.text.trim();
    if (token.isEmpty) {
      setState(() => _erro = 'Informe o Access Token do Mercado Pago.');
      return;
    }
    if (!token.startsWith('APP_USR-') && !token.startsWith('TEST-')) {
      setState(() => _erro =
          'Token inválido. Deve iniciar com APP_USR- (produção) ou TEST- (sandbox).');
      return;
    }
    setState(() { _saving = true; _erro = null; _sucesso = null; });

    final res = await widget.mpSvc.saveMpConfig(
      accessToken: token,
      publicKey:   _pubKeyCtrl.text.trim(),
      sandbox:     _sandbox,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (res.ok) {
        _sucesso = res.email.isNotEmpty
            ? 'Credenciais verificadas! Conta: ${res.email}'
            : 'Credenciais salvas!';
        _tokenCtrl.clear(); // limpa por segurança
      } else {
        _erro = res.error.isNotEmpty ? res.error : 'Erro ao salvar credenciais.';
      }
    });
  }

  Future<void> _remover() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Remover credenciais MP?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'As credenciais do Mercado Pago serão removidas.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() { _saving = true; });
    await widget.mpSvc.removeMpConfig();
    if (!mounted) return;
    _tokenCtrl.clear();
    _pubKeyCtrl.clear();
    _initialized = false;
    setState(() { _saving = false; _sucesso = 'Credenciais removidas.'; });
  }

  @override
  Widget build(BuildContext context) {
    final cfg        = context.watch<MpAdminService>().config;
    final configured = cfg.isConfigured;
    _initIfNeeded(cfg);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Banner
        _ModoBanner(
          label: configured
              ? (_sandbox ? 'Modo Sandbox (Testes)' : 'Modo Produção Ativo')
              : 'Não Configurado',
          subtitle: configured
              ? 'Conta: ${cfg.accountEmail.isNotEmpty ? cfg.accountEmail : cfg.accountId}'
              : 'Configure as credenciais para ativar o Mercado Pago',
          icon: 'MP',
          color: _mpBlue,
          isActive: configured,
        ),
        const SizedBox(height: 16),

        // Card credenciais
        _SectionCard(
          title: 'Credenciais Mercado Pago',
          badge: configured ? 'CONFIGURADO' : 'PENDENTE',
          badgeColor: configured ? _wooviGreen : AppColors.warning,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Modo sandbox
              SwitchListTile.adaptive(
                value: _sandbox,
                onChanged: (v) => setState(() => _sandbox = v),
                title: const Text('Modo Sandbox (Testes)',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: Text(
                  _sandbox
                      ? 'Usando credenciais de teste (TEST-...)'
                      : 'Usando credenciais de produção (APP_USR-...)',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
                activeColor: _mpBlue,
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(color: Colors.white12),
              const SizedBox(height: 8),

              // Access Token
              TextFormField(
                controller: _tokenCtrl,
                obscureText: _obscure,
                maxLines: 1,
                decoration: InputDecoration(
                  labelText: 'Access Token',
                  hintText: _sandbox ? 'TEST-...' : 'APP_USR-...',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (configured && cfg.accountEmail.isNotEmpty)
                _InfoRow(
                  icon: Icons.account_circle_rounded,
                  color: _mpBlue,
                  label: 'Conta atual',
                  value: cfg.accountEmail,
                ),
              const SizedBox(height: 8),

              // Public Key (opcional)
              TextFormField(
                controller: _pubKeyCtrl,
                maxLines: 1,
                decoration: InputDecoration(
                  labelText: 'Public Key (opcional)',
                  hintText: _sandbox ? 'TEST-...' : 'APP_USR-...',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Encontre as credenciais em: mercadopago.com → '
                'Seu negócio → Configurações → Credenciais da aplicação',
                style: TextStyle(
                    fontSize: 11, color: AppColors.textHint, height: 1.4),
              ),

              if (_erro != null) ...[
                const SizedBox(height: 10),
                _AlertBox(
                    icon: Icons.error_rounded,
                    color: AppColors.error,
                    text: _erro!),
              ],
              if (_sucesso != null) ...[
                const SizedBox(height: 10),
                _AlertBox(
                    icon: Icons.check_circle_rounded,
                    color: _wooviGreen,
                    text: _sucesso!),
              ],
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _salvar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _mpBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _saving
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.verified_rounded, size: 18),
                      label: Text(
                        _saving ? 'Verificando...' : 'Verificar e Salvar',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  if (configured) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _remover,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Remover'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Status
        if (configured)
          _SectionCard(
            title: 'Status Atual',
            child: Column(
              children: [
                _StatusRow(label: 'Modo',       value: _sandbox ? 'Sandbox (Testes)' : 'Produção'),
                const Divider(height: 12, color: Colors.white10),
                _StatusRow(label: 'Conta',      value: cfg.accountEmail.isNotEmpty ? cfg.accountEmail : '—'),
                const Divider(height: 12, color: Colors.white10),
                _StatusRow(label: 'ID da conta',value: cfg.accountId.isNotEmpty ? cfg.accountId : '—'),
                const Divider(height: 12, color: Colors.white10),
                _StatusRow(label: 'Gateway',    value: 'Mercado Pago'),
                const Divider(height: 12, color: Colors.white10),
                _StatusRow(label: 'Split',      value: 'Split por afiliado (% variável)'),
              ],
            ),
          ),
        const SizedBox(height: 16),

        // Info taxas MP
        _SectionCard(
          title: 'Taxas Mercado Pago',
          child: Column(
            children: [
              _TaxaRow(
                titulo: 'PIX',
                valor: '0,99% por transação',
                icon: Icons.pix_rounded,
              ),
              const Divider(height: 16),
              _TaxaRow(
                titulo: 'Cartão de crédito (parcelado)',
                valor: 'A partir de 3,49% + parcelas',
                icon: Icons.credit_card_rounded,
              ),
              const Divider(height: 16),
              _TaxaRow(
                titulo: 'Boleto',
                valor: 'R\$ 3,49 por boleto pago',
                icon: Icons.receipt_long_rounded,
              ),
              const Divider(height: 16),
              _TaxaRow(
                titulo: 'Recorrência / Assinatura',
                valor: 'A partir de 4,99% por cobrança',
                icon: Icons.autorenew_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ===========================================================================
// Aba 2 — Configurações (Woovi — mantida igual)
// ===========================================================================

class _SettingsTab extends StatefulWidget {
  final WooviAdminService svc;
  const _SettingsTab({required this.svc});

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  final _webhookCtrl  = TextEditingController();
  final _comissaoCtrl = TextEditingController();
  bool _saving = false;
  String? _erro;
  String? _sucesso;

  @override
  void initState() {
    super.initState();
    final cfg = widget.svc.config;
    _webhookCtrl.text  = cfg.webhookUrl;
    _comissaoCtrl.text = (cfg.comissaoPercent * 100).toStringAsFixed(0);
  }

  @override
  void dispose() {
    _webhookCtrl.dispose();
    _comissaoCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final webhook = _webhookCtrl.text.trim();
    final pct     = double.tryParse(_comissaoCtrl.text.trim()) ?? 20.0;
    if (webhook.isEmpty) {
      setState(() => _erro = 'URL do webhook não pode ser vazia.');
      return;
    }
    setState(() { _saving = true; _erro = null; _sucesso = null; });
    final newCfg = widget.svc.config.copyWith(
      webhookUrl:      webhook,
      comissaoPercent: pct / 100,
    );
    final ok = await widget.svc.saveConfig(newCfg);
    setState(() {
      _saving  = false;
      _sucesso = ok ? 'Configurações salvas com sucesso!' : null;
      _erro    = ok ? null : 'Erro ao salvar. Tente novamente.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Webhook
        _SectionCard(
          title: 'URL do Webhook (Woovi)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Registre esta URL no Dashboard Woovi → API/Plugins → Webhook.',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.5),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _webhookCtrl,
                decoration: InputDecoration(
                  labelText: 'URL do Webhook',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: _webhookCtrl.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('URL copiada!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Eventos registrados:',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 8),
              ...[
                'OPENPIX:CHARGE_COMPLETED — cobrança paga (Pix Avulso)',
                'OPENPIX:MOVEMENT_CONFIRMED — saque do afiliado confirmado',
                'OPENPIX:MOVEMENT_FAILED — saque do afiliado falhou',
                'PIX_AUTOMATIC_APPROVED — assinatura ativada',
                'PIX_AUTOMATIC_COBR_COMPLETED — parcela recorrente paga',
              ].map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline_rounded,
                            size: 14, color: _wooviGreen),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(e,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  height: 1.4)),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Comissão
        _SectionCard(
          title: 'Comissão Padrão dos Afiliados',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Percentual creditado na subconta do afiliado para cada venda aprovada.',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.5),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: TextFormField(
                      controller: _comissaoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                      ],
                      decoration: InputDecoration(
                        labelText: 'Comissão (%)',
                        suffixText: '%',
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _wooviPurple.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _wooviPurple.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Split — automático',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: _wooviPurple)),
                          const SizedBox(height: 2),
                          Text(
                            'A comissão é creditada automaticamente na conta do afiliado.',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Taxas Woovi
        _SectionCard(
          title: 'Taxas Woovi',
          child: Column(
            children: [
              _TaxaRow(
                titulo: 'Por cobrança Pix',
                valor: '0,80% (mín R\$ 0,50 · máx R\$ 5,00)',
                icon: Icons.pix_rounded,
              ),
              const Divider(height: 16),
              _TaxaRow(
                titulo: 'Taxa fixa alternativa',
                valor: 'R\$ 0,85 por transação',
                icon: Icons.attach_money_rounded,
              ),
              const Divider(height: 16),
              _TaxaRow(
                titulo: 'Split / Subcontas',
                valor: 'GRÁTIS',
                icon: Icons.account_tree_rounded,
                destaque: true,
              ),
              const Divider(height: 16),
              _TaxaRow(
                titulo: 'Saque do afiliado',
                valor: 'R\$ 1,00 por saque',
                icon: Icons.payments_rounded,
              ),
            ],
          ),
        ),

        if (_erro != null) ...[
          const SizedBox(height: 12),
          _AlertBox(icon: Icons.error_rounded, color: AppColors.error, text: _erro!),
        ],
        if (_sucesso != null) ...[
          const SizedBox(height: 12),
          _AlertBox(
              icon: Icons.check_circle_rounded, color: _wooviGreen, text: _sucesso!),
        ],
        const SizedBox(height: 16),

        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _salvar,
            style: ElevatedButton.styleFrom(
              backgroundColor: _wooviPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded, size: 18),
            label: Text(_saving ? 'Salvando...' : 'Salvar Configurações',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ===========================================================================
// Widgets auxiliares
// ===========================================================================

class _ModoBanner extends StatelessWidget {
  final String   label;
  final String   subtitle;
  final String   icon;
  final Color    color;
  final bool     isActive;

  const _ModoBanner({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isActive
        ? _wooviGreen.withValues(alpha: 0.08)
        : AppColors.warning.withValues(alpha: 0.08);
    final border = isActive
        ? _wooviGreen.withValues(alpha: 0.4)
        : AppColors.warning.withValues(alpha: 0.4);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              icon,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: icon.length > 1 ? 11 : 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isActive
                  ? _wooviGreen.withValues(alpha: 0.15)
                  : AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isActive ? _wooviGreen : AppColors.warning),
            ),
            child: Text(
              isActive ? 'LIVE' : 'OFF',
              style: TextStyle(
                color: isActive ? _wooviGreen : AppColors.warning,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String  title;
  final Widget  child;
  final String? badge;
  final Color?  badgeColor;

  const _SectionCard({
    required this.title,
    required this.child,
    this.badge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (badgeColor ?? Colors.grey).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: (badgeColor ?? Colors.grey).withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      badge!,
                      style: TextStyle(
                          color: badgeColor ?? Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 20),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _WooviStatusTable extends StatelessWidget {
  final WooviConfig cfg;
  const _WooviStatusTable({required this.cfg});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _StatusRow(label: 'Modo',      value: 'Produção (Pagamentos Reais)'),
        const Divider(height: 12, color: Colors.white10),
        _StatusRow(
            label: 'AppID',
            value: cfg.appId.isNotEmpty
                ? '${cfg.appId.substring(0, cfg.appId.length.clamp(0, 12))}...'
                : 'Não configurado'),
        const Divider(height: 12, color: Colors.white10),
        _StatusRow(
            label: 'Verificado',
            value: cfg.verified ? 'Sim' : 'Não',
            highlight: cfg.verified),
        const Divider(height: 12, color: Colors.white10),
        _StatusRow(label: 'Comissão', value: '${(cfg.comissaoPercent * 100).toStringAsFixed(0)}%'),
        const Divider(height: 12, color: Colors.white10),
        _StatusRow(label: 'Gateway',  value: 'Woovi / OpenPix'),
        const Divider(height: 12, color: Colors.white10),
        _StatusRow(label: 'Split',    value: 'Subconta por afiliado (GRÁTIS)'),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final bool   highlight;

  const _StatusRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: highlight ? _wooviGreen : Colors.white,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   label;
  final String   value;

  const _InfoRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text('$label: ',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _AlertBox extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   text;

  const _AlertBox({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(color: color, fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _TaxaRow extends StatelessWidget {
  final String   titulo;
  final String   valor;
  final IconData icon;
  final bool     destaque;

  const _TaxaRow({
    required this.titulo,
    required this.valor,
    required this.icon,
    this.destaque = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon,
            size: 20,
            color: destaque ? _wooviGreen : AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              Text(valor,
                  style: TextStyle(
                    fontSize: 12,
                    color: destaque ? _wooviGreen : AppColors.textSecondary,
                    fontWeight:
                        destaque ? FontWeight.w700 : FontWeight.normal,
                  )),
            ],
          ),
        ),
      ],
    );
  }
}

class _WebhookInfo extends StatelessWidget {
  final String webhookUrl;
  const _WebhookInfo({required this.webhookUrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Registre esta URL no Dashboard Woovi para receber eventos:',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  webhookUrl,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontFamily: 'monospace'),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16),
                color: AppColors.gold,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: webhookUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('URL copiada!'),
                        duration: Duration(seconds: 2)),
                  );
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
