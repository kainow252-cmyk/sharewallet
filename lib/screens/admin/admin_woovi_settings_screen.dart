import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/woovi_admin_service.dart';
import '../../theme/app_theme.dart';

// ignore_for_file: use_build_context_synchronously

const _wooviPurple  = Color(0xFF6C3CE1);
const _wooviDark    = Color(0xFF4A1FA8);
const _wooviGreen   = Color(0xFF00C851);

// ---------------------------------------------------------------------------
// AdminWooviSettingsScreen
// ---------------------------------------------------------------------------

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
      // resetAndReload garante dados frescos do servidor mesmo após logout/login
      context.read<WooviAdminService>().resetAndReload();
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
      body: Consumer<WooviAdminService>(
        builder: (_, svc, __) {
          if (!svc.isConfigLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              // ── Barra de abas ─────────────────────────────────────────────
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
                    const _CredentialsTab(),  // usa context.watch internamente
                    _SettingsTab(svc: svc),
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
// Aba 1 — Credenciais
// ===========================================================================

class _CredentialsTab extends StatefulWidget {
  // Não recebe mais 'svc' por parâmetro — usa context.watch para reagir a mudanças
  const _CredentialsTab();

  @override
  State<_CredentialsTab> createState() => _CredentialsTabState();
}

class _CredentialsTabState extends State<_CredentialsTab> {
  final _appIdCtrl = TextEditingController();
  bool _obscure    = true;
  bool _saving     = false;
  String? _erro;
  String? _sucesso;
  bool _initialized = false;

  @override
  void dispose() {
    _appIdCtrl.dispose();
    super.dispose();
  }

  // ── Inicializa campo uma única vez quando config carrega ───────────────────
  void _initFieldIfNeeded(WooviConfig cfg) {
    if (!_initialized && cfg.appId.isNotEmpty) {
      _appIdCtrl.text = cfg.appId;
      _initialized = true;
    } else if (!_initialized && cfg.appId.isEmpty) {
      // Config carregada mas vazia — marca como inicializado mesmo assim
      _initialized = true;
    }
  }

  // ── Verifica + Salva ──────────────────────────────────────────────────────
  Future<void> _salvar(WooviAdminService svc) async {
    final appId = _appIdCtrl.text.trim();
    if (appId.isEmpty) {
      setState(() => _erro = 'Informe o AppID da Woovi.');
      return;
    }
    setState(() { _saving = true; _erro = null; _sucesso = null; });

    // 1. Verificar AppID
    final res = await svc.verifyAppId(appId);
    if (!mounted) return;
    if (!res.ok) {
      setState(() { _saving = false; _erro = res.error; });
      return;
    }

    // 2. Salvar config verificada
    final newCfg = svc.config.copyWith(
      appId:       appId,
      verified:    true,
      accountName: res.accountName,
    );
    final ok = await svc.saveConfig(newCfg);
    if (!mounted) return;
    setState(() {
      _saving  = false;
      _sucesso = ok
          ? 'AppID verificado e salvo com sucesso!'
          : 'Verificado, mas houve erro ao salvar. Tente novamente.';
      _erro    = ok ? null : 'Erro ao persistir configuração.';
    });
  }

  // ── Remover credenciais ────────────────────────────────────────────────────
  Future<void> _remover(WooviAdminService svc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover AppID?'),
        content: const Text(
            'A integração Woovi será desativada. Pagamentos PIX deixarão de funcionar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remover', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() { _saving = true; _erro = null; _sucesso = null; });
    final newCfg = svc.config.copyWith(
      appId: '', verified: false, accountName: '',
    );
    await svc.saveConfig(newCfg);
    if (!mounted) return;
    _appIdCtrl.clear();
    _initialized = false; // reseta para inicializar novamente se necessário
    setState(() {
      _saving  = false;
      _sucesso = 'AppID removido.';
    });
  }

  @override
  Widget build(BuildContext context) {
    // ⚡ context.watch garante rebuild automático quando saveConfig chama notifyListeners()
    final svc        = context.watch<WooviAdminService>();
    final cfg        = svc.config;
    final configured = cfg.verified && cfg.appId.isNotEmpty;

    // Inicializa campo de texto com valor do servidor (só na primeira vez)
    _initFieldIfNeeded(cfg);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Modo Produção banner ────────────────────────────────────────────
        _ModoBanner(isProducao: true),
        const SizedBox(height: 16),

        // ── Seção AppID ─────────────────────────────────────────────────────
        _SectionCard(
          title: 'AppID de Produção',
          badge: configured ? 'CONFIGURADO' : 'PENDENTE',
          badgeColor: configured ? _wooviGreen : AppColors.warning,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Campo AppID
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
                        tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                      ),
                      if (cfg.appId.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: cfg.appId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('AppID copiado!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          tooltip: 'Copiar',
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Encontre o AppID no Dashboard Woovi → API/Plugins → AppID',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                    height: 1.4),
              ),

              // -- Feedback --------------------------------------------------
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

              // -- Botões ----------------------------------------------------
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
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.verified_rounded, size: 18),
                      label: Text(
                          (_saving || svc.isVerifying)
                              ? 'Verificando...'
                              : 'Verificar e Salvar',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700)),
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
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 18),
                      label: const Text('Remover'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Status Atual ───────────────────────────────────────────────────
        _SectionCard(
          title: 'Status Atual',
          child: _StatusTable(cfg: cfg),
        ),

        const SizedBox(height: 16),

        // ── Webhook URL ─────────────────────────────────────────────────────
        _SectionCard(
          title: 'Webhook Woovi',
          child: _WebhookInfo(webhookUrl: cfg.webhookUrl),
        ),
      ],
    );
  }
}

// ===========================================================================
// Aba 2 — Configurações
// ===========================================================================

class _SettingsTab extends StatefulWidget {
  final WooviAdminService svc;
  const _SettingsTab({required this.svc});

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  final _webhookCtrl    = TextEditingController();
  final _comissaoCtrl   = TextEditingController();
  bool _saving = false;
  String? _erro;
  String? _sucesso;

  @override
  void initState() {
    super.initState();
    final cfg = widget.svc.config;
    _webhookCtrl.text  = cfg.webhookUrl;
    _comissaoCtrl.text =
        (cfg.comissaoPercent * 100).toStringAsFixed(0);
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
        // ── Webhook ────────────────────────────────────────────────────────
        _SectionCard(
          title: 'URL do Webhook',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Registre esta URL no Dashboard Woovi → API/Plugins → Webhook. '
                'Ela receberá todos os eventos de pagamento.',
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

              // Eventos suportados
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
                              style: const TextStyle(fontSize: 12,
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

        // ── Comissão ───────────────────────────────────────────────────────
        _SectionCard(
          title: 'Comissão Padrão dos Afiliados',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Percentual creditado na subconta do afiliado via split Woovi '
                'para cada venda aprovada.',
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
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.]'))
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
                          const Text('Split Woovi — GRÁTIS',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: _wooviPurple)),
                          const SizedBox(height: 2),
                          Text(
                            'A comissão é creditada instantaneamente '
                            'na subconta do afiliado sem custo adicional.',
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

        // ── Preços Woovi ───────────────────────────────────────────────────
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
                valor: 'GRÁTIS — sem custo adicional',
                icon: Icons.account_tree_rounded,
                destaque: true,
              ),
              const Divider(height: 16),
              _TaxaRow(
                titulo: 'Saque do afiliado',
                valor: 'R\$ 1,00 por saque (deduzido do saldo)',
                icon: Icons.payments_rounded,
              ),
              const Divider(height: 16),
              _TaxaRow(
                titulo: 'Pix Automático (assinatura)',
                valor: 'Mesma taxa por cobrança recorrente',
                icon: Icons.autorenew_rounded,
              ),
            ],
          ),
        ),

        // ── Feedback ───────────────────────────────────────────────────────
        if (_erro != null) ...[
          const SizedBox(height: 12),
          _AlertBox(
              icon: Icons.error_rounded,
              color: AppColors.error,
              text: _erro!),
        ],
        if (_sucesso != null) ...[
          const SizedBox(height: 12),
          _AlertBox(
              icon: Icons.check_circle_rounded,
              color: _wooviGreen,
              text: _sucesso!),
        ],
        const SizedBox(height: 16),

        // ── Botão Salvar ───────────────────────────────────────────────────
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
                    width: 18,
                    height: 18,
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
  final bool isProducao;
  const _ModoBanner({required this.isProducao});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isProducao
            ? _wooviGreen.withValues(alpha: 0.08)
            : AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isProducao
                ? _wooviGreen.withValues(alpha: 0.4)
                : AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _wooviPurple,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('W',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isProducao ? 'Modo Produção Ativo' : 'Modo Sandbox Ativo',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isProducao ? _wooviGreen : AppColors.warning,
                      fontSize: 14),
                ),
                Text(
                  isProducao
                      ? 'Processando pagamentos reais via Woovi'
                      : 'Ambiente de testes — nenhum cobrança real',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:
                  isProducao ? _wooviGreen : AppColors.warning,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isProducao ? 'LIVE' : 'TEST',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final String? badge;
  final Color? badgeColor;

  const _SectionCard({
    required this.title,
    required this.child,
    this.badge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary)),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor?.withValues(alpha: 0.12) ??
                        AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: badgeColor?.withValues(alpha: 0.5) ??
                            AppColors.primary.withValues(alpha: 0.5)),
                  ),
                  child: Text(badge!,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: badgeColor ?? AppColors.primary)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _StatusTable extends StatelessWidget {
  final WooviConfig cfg;
  const _StatusTable({required this.cfg});

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: FlexColumnWidth(),
      },
      children: [
        _row('Modo', 'Produção (Pagamentos Reais)'),
        _row('AppID',
            cfg.appId.isNotEmpty ? cfg.appIdMasked : '— não configurado —'),
        if (cfg.accountName.isNotEmpty)
          _row('Conta', cfg.accountName),
        _row(
          'Verificado',
          cfg.verified ? 'Sim' : 'Não',
          valueColor: cfg.verified ? _wooviGreen : AppColors.error,
        ),
        _row(
          'Comissão',
          '${(cfg.comissaoPercent * 100).toStringAsFixed(0)}%',
        ),
        _row('Gateway', 'Woovi / OpenPix'),
        _row('Split', 'Subconta por afiliado (GRÁTIS)'),
      ],
    );
  }

  TableRow _row(String label, String value, {Color? valueColor}) =>
      TableRow(children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text('$label   ',
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(value,
              style: TextStyle(
                  color: valueColor ?? AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
      ]);
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
          'Registre esta URL no Dashboard Woovi → API/Plugins → Webhook.',
          style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.5),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  webhookUrl.isNotEmpty
                      ? webhookUrl
                      : 'https://api.sharewallet.com.br/api/webhook/woovi',
                  style: const TextStyle(
                      fontSize: 12,
                      color: _wooviPurple,
                      fontFamily: 'monospace'),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16),
                onPressed: () {
                  Clipboard.setData(ClipboardData(
                      text: webhookUrl.isNotEmpty
                          ? webhookUrl
                          : 'https://api.sharewallet.com.br/api/webhook/woovi'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('URL do webhook copiada!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                tooltip: 'Copiar',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Instruções passo a passo
        _Step(numero: '1', texto: 'Acesse dashboard.woovi.com → API/Plugins'),
        _Step(numero: '2', texto: 'Clique em "Webhook" e depois "Adicionar"'),
        _Step(numero: '3', texto: 'Cole a URL acima e selecione os 5 eventos'),
        _Step(numero: '4', texto: 'Salve — a Woovi enviará um teste de verificação'),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final String numero;
  final String texto;
  const _Step({required this.numero, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: _wooviPurple,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text(numero,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texto,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _AlertBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _AlertBox(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12, color: color, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _TaxaRow extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icon;
  final bool destaque;

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
            size: 18,
            color: destaque ? _wooviGreen : AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(titulo,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
        ),
        Text(valor,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: destaque ? _wooviGreen : AppColors.textPrimary)),
      ],
    );
  }
}
