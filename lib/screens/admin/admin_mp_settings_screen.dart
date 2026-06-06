import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/mercadopago_service.dart';
import '../../theme/app_theme.dart';

// Cor oficial do Mercado Pago
const _mpBlue = Color(0xFF009EE3);

class AdminMpSettingsScreen extends StatefulWidget {
  const AdminMpSettingsScreen({super.key});

  @override
  State<AdminMpSettingsScreen> createState() => _AdminMpSettingsScreenState();
}

class _AdminMpSettingsScreenState extends State<AdminMpSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    // Carregar config ao abrir
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MercadoPagoService>().loadConfig();
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
      body: Consumer<MercadoPagoService>(
        builder: (_, svc, __) {
          if (!svc.isConfigLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              // TabBar integrada ao body
              Container(
                color: const Color(0xFF071A10),
                child: TabBar(
                  controller: _tab,
                  labelColor: AppColors.gold,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: AppColors.gold,
                  tabs: const [
                    Tab(icon: Icon(Icons.tune_rounded), text: 'Modo & Credenciais'),
                    Tab(icon: Icon(Icons.settings_rounded), text: 'Configurações'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _ModeTab(svc: svc),
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

// ── Aba 1: Modo + Credenciais ─────────────────────────────────────────────────

class _ModeTab extends StatelessWidget {
  final MercadoPagoService svc;
  const _ModeTab({required this.svc});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Seletor de modo ───────────────────────────────────────────────
        _SectionHeader(icon: Icons.swap_horiz_rounded, title: 'Modo Ativo'),
        const SizedBox(height: 12),
        _ModeSelector(svc: svc),
        const SizedBox(height: 24),

        // ── Credenciais Sandbox ───────────────────────────────────────────
        _SectionHeader(
          icon: Icons.science_rounded,
          title: 'Credenciais Sandbox',
          badge: svc.config.mode == 'sandbox' ? 'ATIVO' : null,
          badgeColor: AppColors.success,
        ),
        const SizedBox(height: 12),
        _CredentialsCard(
          mode: 'sandbox',
          creds: svc.config.sandbox,
          isSandbox: true,
          svc: svc,
        ),
        const SizedBox(height: 24),

        // ── Credenciais Produção ──────────────────────────────────────────
        _SectionHeader(
          icon: Icons.rocket_launch_rounded,
          title: 'Credenciais Produção',
          badge: svc.config.mode == 'production' ? 'ATIVO' : null,
          badgeColor: AppColors.error,
        ),
        const SizedBox(height: 12),
        _CredentialsCard(
          mode: 'production',
          creds: svc.config.production,
          isSandbox: false,
          svc: svc,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Seletor de modo ───────────────────────────────────────────────────────────

class _ModeSelector extends StatefulWidget {
  final MercadoPagoService svc;
  const _ModeSelector({required this.svc});

  @override
  State<_ModeSelector> createState() => _ModeSelectorState();
}

class _ModeSelectorState extends State<_ModeSelector> {
  bool _switching = false;

  Future<void> _switchMode(String newMode) async {
    if (_switching) return;
    setState(() => _switching = true);

    final ok = await widget.svc.setMode(newMode);
    if (!mounted) return;
    setState(() => _switching = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(newMode == 'sandbox'
            ? '🧪 Modo Sandbox ativado'
            : '🔴 Modo Produção ativado'),
        backgroundColor: newMode == 'sandbox'
            ? AppColors.success
            : AppColors.error,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(widget.svc.lastError ?? 'Erro ao trocar modo'),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 5),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.svc.config.mode;

    return Row(
      children: [
        Expanded(
          child: _ModeOption(
            selected: current == 'sandbox',
            icon: Icons.science_rounded,
            color: const Color(0xFFE65100),
            label: 'Sandbox',
            sub: 'Pagamentos de teste',
            onTap: _switching ? null : () => _switchMode('sandbox'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ModeOption(
            selected: current == 'production',
            icon: Icons.rocket_launch_rounded,
            color: AppColors.error,
            label: 'Produção',
            sub: 'Pagamentos reais',
            onTap: _switching ? null : () => _switchMode('production'),
            locked: widget.svc.config.production.isEmpty,
          ),
        ),
      ],
    );
  }
}

class _ModeOption extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final Color color;
  final String label;
  final String sub;
  final VoidCallback? onTap;
  final bool locked;

  const _ModeOption({
    required this.selected,
    required this.icon,
    required this.color,
    required this.label,
    required this.sub,
    this.onTap,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.1)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : AppColors.cardBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Stack(
              children: [
                Icon(icon,
                    color: selected ? color : AppColors.textHint, size: 32),
                if (locked)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: AppColors.textHint,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_rounded,
                          color: Colors.white, size: 10),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: selected ? color : AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(sub,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textSecondary)),
            if (selected) ...[
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('ATIVO',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 9)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Card de credenciais ───────────────────────────────────────────────────────

class _CredentialsCard extends StatefulWidget {
  final String mode;
  final MpCredentials creds;
  final bool isSandbox;
  final MercadoPagoService svc;

  const _CredentialsCard({
    required this.mode,
    required this.creds,
    required this.isSandbox,
    required this.svc,
  });

  @override
  State<_CredentialsCard> createState() => _CredentialsCardState();
}

class _CredentialsCardState extends State<_CredentialsCard> {
  bool _editing      = false;
  bool _verifying    = false;
  bool _saving       = false;
  Map<String, dynamic>? _verifyResult;

  late final _tokenCtrl  = TextEditingController(text: widget.creds.accessToken);
  late final _pubKeyCtrl = TextEditingController(text: widget.creds.publicKey);
  late final _userCtrl   = TextEditingController(text: widget.creds.userId);

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _pubKeyCtrl.dispose();
    _userCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_tokenCtrl.text.trim().isEmpty) return;
    setState(() => _verifying = true);
    final result =
        await widget.svc.verifyCredentials(_tokenCtrl.text.trim());
    if (!mounted) return;
    setState(() {
      _verifying     = false;
      _verifyResult  = result;
      // Preencher user_id automaticamente se verificou com sucesso
      if (result['valid'] == true && _userCtrl.text.isEmpty) {
        _userCtrl.text = result['user_id'] ?? '';
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final newCreds = MpCredentials(
      accessToken: _tokenCtrl.text.trim(),
      publicKey:   _pubKeyCtrl.text.trim(),
      userId:      _userCtrl.text.trim(),
      verified:    _verifyResult?['valid'] == true,
    );

    final cfg = widget.svc.config;
    final newCfg = MpConfig(
      mode: cfg.mode,
      sandbox:    widget.mode == 'sandbox'    ? newCreds : cfg.sandbox,
      production: widget.mode == 'production' ? newCreds : cfg.production,
      comissaoPercent: cfg.comissaoPercent,
      notificationUrl: cfg.notificationUrl,
      backUrlSuccess:  cfg.backUrlSuccess,
      backUrlFailure:  cfg.backUrlFailure,
      backUrlPending:  cfg.backUrlPending,
    );

    final ok = await widget.svc.saveConfig(newCfg);
    if (!mounted) return;
    setState(() {
      _saving  = false;
      _editing = !ok;
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? '✅ Credenciais ${widget.isSandbox ? "sandbox" : "produção"} salvas!'
          : widget.svc.lastError ?? 'Erro ao salvar'),
      backgroundColor: ok ? AppColors.success : AppColors.error,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isSandbox
        ? const Color(0xFFE65100)
        : AppColors.error;
    final isEmpty = widget.creds.isEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEmpty
              ? AppColors.cardBorder
              : color.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header do card ────────────────────────────────────────────
            Row(
              children: [
                Icon(
                  widget.creds.verified
                      ? Icons.verified_rounded
                      : (isEmpty
                          ? Icons.lock_outline_rounded
                          : Icons.warning_amber_rounded),
                  color: widget.creds.verified
                      ? AppColors.success
                      : (isEmpty ? AppColors.textHint : AppColors.warning),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.isSandbox
                        ? 'Access Token Sandbox'
                        : 'Access Token Produção',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textPrimary),
                  ),
                ),
                if (!isEmpty)
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _editing       = !_editing;
                      _verifyResult  = null;
                    }),
                    icon: Icon(_editing ? Icons.close_rounded : Icons.edit_rounded,
                        size: 15),
                    label: Text(_editing ? 'Cancelar' : 'Editar',
                        style: const TextStyle(fontSize: 12)),
                  ),
              ],
            ),

            // ── Exibição resumida (não editando) ──────────────────────────
            if (!_editing && !isEmpty) ...[
              const SizedBox(height: 12),
              _TokenDisplay(
                  label: 'Access Token',
                  value: widget.creds.accessToken),
              const SizedBox(height: 6),
              _TokenDisplay(
                  label: 'Public Key',
                  value: widget.creds.publicKey),
              const SizedBox(height: 6),
              _TokenDisplay(
                  label: 'User ID',
                  value: widget.creds.userId,
                  mask: false),
              if (widget.creds.verified) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: AppColors.success, size: 14),
                      SizedBox(width: 6),
                      Text('Credenciais verificadas',
                          style: TextStyle(
                              color: AppColors.success,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ],

            // ── Estado vazio ──────────────────────────────────────────────
            if (!_editing && isEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: AppColors.textHint, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.isSandbox
                            ? 'Configure o token sandbox do Mercado Pago para testes'
                            : 'Configure o token de produção para receber pagamentos reais',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      setState(() => _editing = true),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text(
                      'Configurar credenciais ${widget.isSandbox ? "sandbox" : "produção"}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],

            // ── Formulário de edição ──────────────────────────────────────
            if (_editing) ...[
              const SizedBox(height: 16),

              // Aviso sandbox
              if (widget.isSandbox)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFE083)),
                  ),
                  child: const Text(
                    '🧪 Use credenciais de TESTE do Mercado Pago.\n'
                    'Acesse: mercadopago.com.br → Suas integrações → Credenciais de teste',
                    style: TextStyle(
                        fontSize: 11, color: Color(0xFF7B3F00)),
                  ),
                ),

              // Access Token
              _EditField(
                controller: _tokenCtrl,
                label: 'Access Token',
                hint: 'APP_USR-...',
                icon: Icons.key_rounded,
                obscure: true,
              ),
              const SizedBox(height: 10),

              // Botão verificar
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _verifying ? null : _verify,
                      icon: _verifying
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))
                          : const Icon(Icons.verified_user_rounded,
                              size: 16),
                      label: Text(
                          _verifying ? 'Verificando...' : 'Verificar Token',
                          style: const TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _mpBlue),
                        foregroundColor: _mpBlue,
                      ),
                    ),
                  ),
                ],
              ),

              // Resultado da verificação
              if (_verifyResult != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _verifyResult!['valid'] == true
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _verifyResult!['valid'] == true
                          ? AppColors.success.withValues(alpha: 0.3)
                          : AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _verifyResult!['valid'] == true
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            color: _verifyResult!['valid'] == true
                                ? AppColors.success
                                : AppColors.error,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _verifyResult!['valid'] == true
                                ? 'Token válido!'
                                : 'Token inválido',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _verifyResult!['valid'] == true
                                  ? AppColors.success
                                  : AppColors.error,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      if (_verifyResult!['valid'] == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          '📧 ${_verifyResult!['email']}\n'
                          '🆔 User ID: ${_verifyResult!['user_id']}\n'
                          '🌎 País: ${_verifyResult!['site_id']}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary),
                        ),
                      ] else
                        Text(
                          _verifyResult!['error'] ?? '',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.error),
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // Public Key
              _EditField(
                controller: _pubKeyCtrl,
                label: 'Public Key',
                hint: 'APP_USR-...',
                icon: Icons.vpn_key_rounded,
                obscure: true,
              ),
              const SizedBox(height: 10),

              // User ID
              _EditField(
                controller: _userCtrl,
                label: 'User ID (preenchido automático ao verificar)',
                hint: 'ex: 3450457834',
                icon: Icons.person_rounded,
              ),
              const SizedBox(height: 16),

              // Botão salvar
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded),
                  label: Text(_saving
                      ? 'Salvando...'
                      : 'Salvar Credenciais'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Aba 2: Configurações gerais ───────────────────────────────────────────────

class _SettingsTab extends StatefulWidget {
  final MercadoPagoService svc;
  const _SettingsTab({required this.svc});

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  late final _notifCtrl   = TextEditingController(
      text: widget.svc.config.notificationUrl);
  late final _successCtrl = TextEditingController(
      text: widget.svc.config.backUrlSuccess);
  late final _failureCtrl = TextEditingController(
      text: widget.svc.config.backUrlFailure);
  late final _pendingCtrl = TextEditingController(
      text: widget.svc.config.backUrlPending);
  late double _comissao   = widget.svc.config.comissaoPercent * 100;
  bool _saving = false;

  @override
  void dispose() {
    _notifCtrl.dispose();
    _successCtrl.dispose();
    _failureCtrl.dispose();
    _pendingCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final cfg = widget.svc.config;
    final newCfg = MpConfig(
      mode:            cfg.mode,
      sandbox:         cfg.sandbox,
      production:      cfg.production,
      comissaoPercent: _comissao / 100,
      notificationUrl: _notifCtrl.text.trim(),
      backUrlSuccess:  _successCtrl.text.trim(),
      backUrlFailure:  _failureCtrl.text.trim(),
      backUrlPending:  _pendingCtrl.text.trim(),
    );
    final ok = await widget.svc.saveConfig(newCfg);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? '✅ Configurações salvas!' : (widget.svc.lastError ?? 'Erro')),
      backgroundColor: ok ? AppColors.success : AppColors.error,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Comissão ──────────────────────────────────────────────────────
        _SectionHeader(icon: Icons.percent_rounded, title: 'Comissão dos Afiliados'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Percentual de comissão',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_comissao.toStringAsFixed(0)}%',
                      style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w800,
                          fontSize: 18),
                    ),
                  ),
                ],
              ),
              Slider(
                value: _comissao,
                min: 5,
                max: 50,
                divisions: 45,
                activeColor: AppColors.success,
                label: '${_comissao.toStringAsFixed(0)}%',
                onChanged: (v) => setState(() => _comissao = v),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('5%',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint)),
                  Text('Exemplo: venda R\$10 → afiliado ganha R\$${(10 * _comissao / 100).toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary)),
                  Text('50%',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── URLs ──────────────────────────────────────────────────────────
        _SectionHeader(
            icon: Icons.link_rounded, title: 'URLs de Retorno'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            children: [
              _EditField(
                controller: _notifCtrl,
                label: 'Webhook URL',
                icon: Icons.webhook_rounded,
                hint: 'https://...',
              ),
              const SizedBox(height: 10),
              _EditField(
                controller: _successCtrl,
                label: 'URL de Sucesso',
                icon: Icons.check_circle_outline_rounded,
                hint: 'https://...',
              ),
              const SizedBox(height: 10),
              _EditField(
                controller: _failureCtrl,
                label: 'URL de Falha',
                icon: Icons.error_outline_rounded,
                hint: 'https://...',
              ),
              const SizedBox(height: 10),
              _EditField(
                controller: _pendingCtrl,
                label: 'URL de Pendente',
                icon: Icons.pending_outlined,
                hint: 'https://...',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Status atual ──────────────────────────────────────────────────
        _SectionHeader(icon: Icons.info_outline_rounded, title: 'Status Atual'),
        const SizedBox(height: 12),
        _StatusCard(svc: widget.svc),
        const SizedBox(height: 24),

        // ── Salvar ────────────────────────────────────────────────────────
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded),
            label: Text(
                _saving ? 'Salvando...' : 'Salvar Configurações'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _mpBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Card de status ────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final MercadoPagoService svc;
  const _StatusCard({required this.svc});

  @override
  Widget build(BuildContext context) {
    final cfg   = svc.config;
    final creds = cfg.active;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          _StatusRow(
            label: 'Modo',
            value: cfg.isSandbox ? '🧪 Sandbox (Testes)' : '🔴 Produção',
            color: cfg.isSandbox ? const Color(0xFFE65100) : AppColors.error,
          ),
          const Divider(height: 16),
          _StatusRow(
            label: 'Access Token',
            value: creds.isEmpty
                ? '❌ Não configurado'
                : '✅ ${creds.accessToken.substring(0, 20)}...',
            color: creds.isEmpty ? AppColors.error : AppColors.success,
          ),
          const Divider(height: 16),
          _StatusRow(
            label: 'Verificado',
            value: creds.verified ? '✅ Sim' : '⚠️ Não verificado',
            color: creds.verified ? AppColors.success : AppColors.warning,
          ),
          const Divider(height: 16),
          _StatusRow(
            label: 'Comissão',
            value: '${(cfg.comissaoPercent * 100).toStringAsFixed(0)}%',
            color: AppColors.textPrimary,
          ),
          const Divider(height: 16),
          _StatusRow(
            label: 'Webhook',
            value: cfg.notificationUrl,
            color: _mpBlue,
            small: true,
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool small;

  const _StatusRow({
    required this.label,
    required this.value,
    required this.color,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: small ? 11 : 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? badge;
  final Color? badgeColor;

  const _SectionHeader({
    required this.icon,
    required this.title,
    this.badge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _mpBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _mpBlue, size: 16),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.textPrimary)),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (badgeColor ?? AppColors.primary).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(badge!,
                style: TextStyle(
                    color: badgeColor ?? AppColors.primary,
                    fontSize: 9,
                    fontWeight: FontWeight.w800)),
          ),
        ],
      ],
    );
  }
}

class _TokenDisplay extends StatefulWidget {
  final String label;
  final String value;
  final bool mask;

  const _TokenDisplay({
    required this.label,
    required this.value,
    this.mask = true,
  });

  @override
  State<_TokenDisplay> createState() => _TokenDisplayState();
}

class _TokenDisplayState extends State<_TokenDisplay> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final display = widget.mask && !_visible
        ? '${widget.value.substring(0, widget.value.length.clamp(0, 12))}••••••••••••'
        : widget.value;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.label,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textHint)),
              Text(display,
                  style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        if (widget.mask)
          IconButton(
            icon: Icon(
                _visible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 16,
                color: AppColors.textHint),
            onPressed: () => setState(() => _visible = !_visible),
          ),
        IconButton(
          icon: const Icon(Icons.copy_rounded, size: 14, color: AppColors.textHint),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: widget.value));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Copiado!'),
                  duration: Duration(seconds: 1)),
            );
          },
        ),
      ],
    );
  }
}

class _EditField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final bool obscure;

  const _EditField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.obscure = false,
  });

  @override
  State<_EditField> createState() => _EditFieldState();
}

class _EditFieldState extends State<_EditField> {
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: widget.obscure && !_show,
      style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: Icon(widget.icon, size: 18),
        suffixIcon: widget.obscure
            ? IconButton(
                icon: Icon(
                    _show
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 18),
                onPressed: () => setState(() => _show = !_show),
              )
            : null,
        isDense: true,
      ),
    );
  }
}
