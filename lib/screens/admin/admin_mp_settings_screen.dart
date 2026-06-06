import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/mercadopago_service.dart';
import '../../theme/app_theme.dart';

const _mpBlue  = Color(0xFF009EE3);
const _mpGreen = Color(0xFF00C851);

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
              Container(
                color: const Color(0xFF071A10),
                child: TabBar(
                  controller: _tab,
                  labelColor: AppColors.gold,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: AppColors.gold,
                  tabs: const [
                    Tab(icon: Icon(Icons.key_rounded), text: 'Credenciais'),
                    Tab(icon: Icon(Icons.settings_rounded), text: 'Configurações'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _CredenciaisTab(svc: svc),
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

// ── Aba 1: Credenciais de Produção ────────────────────────────────────────────

class _CredenciaisTab extends StatelessWidget {
  final MercadoPagoService svc;
  const _CredenciaisTab({required this.svc});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [

        // ── Banner de modo fixo ───────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _mpGreen.withValues(alpha: 0.15),
                _mpBlue.withValues(alpha: 0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _mpGreen.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _mpGreen.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.rocket_launch_rounded,
                    color: _mpGreen, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Modo Produção Ativo',
                      style: TextStyle(
                        color: _mpGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Pagamentos reais via PIX — MercadoPago',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _mpGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('LIVE',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 1)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Card de credenciais ───────────────────────────────────────────
        _SectionHeader(
          icon: Icons.key_rounded,
          title: 'Access Token de Produção',
          badge: svc.config.production.isEmpty ? null : 'CONFIGURADO',
          badgeColor: _mpGreen,
        ),
        const SizedBox(height: 12),
        _CredenciaisCard(svc: svc),
        const SizedBox(height: 24),

        // ── Status ────────────────────────────────────────────────────────
        _SectionHeader(icon: Icons.info_outline_rounded, title: 'Status Atual'),
        const SizedBox(height: 12),
        _StatusCard(svc: svc),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Card de credenciais de produção ──────────────────────────────────────────

class _CredenciaisCard extends StatefulWidget {
  final MercadoPagoService svc;
  const _CredenciaisCard({required this.svc});

  @override
  State<_CredenciaisCard> createState() => _CredenciaisCardState();
}

class _CredenciaisCardState extends State<_CredenciaisCard> {
  bool _editing     = false;
  bool _verifying   = false;
  bool _saving      = false;
  Map<String, dynamic>? _verifyResult;

  late final _tokenCtrl =
      TextEditingController(text: widget.svc.config.production.accessToken);
  late final _userCtrl  =
      TextEditingController(text: widget.svc.config.production.userId);

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _userCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_tokenCtrl.text.trim().isEmpty) return;
    setState(() => _verifying = true);
    final result = await widget.svc.verifyCredentials(_tokenCtrl.text.trim());
    if (!mounted) return;
    setState(() {
      _verifying    = false;
      _verifyResult = result;
      if (result['valid'] == true && _userCtrl.text.isEmpty) {
        _userCtrl.text = result['user_id'] ?? '';
      }
    });
  }

  Future<void> _save() async {
    if (_tokenCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Informe o Access Token de produção'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    setState(() => _saving = true);

    final newCreds = MpCredentials(
      accessToken: _tokenCtrl.text.trim(),
      publicKey:   '',   // public_key não é necessário para PIX
      userId:      _userCtrl.text.trim(),
      verified:    _verifyResult?['valid'] == true,
    );

    final cfg = widget.svc.config;
    final newCfg = MpConfig(
      mode:            'production',   // sempre produção
      sandbox:         MpCredentials.empty(),
      production:      newCreds,
      comissaoPercent: cfg.comissaoPercent,
      notificationUrl: cfg.notificationUrl,
      backUrlSuccess:  cfg.backUrlSuccess,
      backUrlFailure:  cfg.backUrlFailure,
      backUrlPending:  cfg.backUrlPending,
      clientId:        cfg.clientId,
      clientSecret:    cfg.clientSecret,
    );

    final ok = await widget.svc.saveConfig(newCfg);
    if (!mounted) return;
    setState(() {
      _saving  = false;
      _editing = !ok;
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? '✅ Credenciais de produção salvas!'
          : widget.svc.lastError ?? 'Erro ao salvar'),
      backgroundColor: ok ? _mpGreen : AppColors.error,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = widget.svc.config.production.isEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEmpty
              ? AppColors.cardBorder
              : _mpGreen.withValues(alpha: 0.35),
          width: isEmpty ? 1 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Header ────────────────────────────────────────────────────
            Row(
              children: [
                Icon(
                  widget.svc.config.production.verified
                      ? Icons.verified_rounded
                      : (isEmpty
                          ? Icons.lock_outline_rounded
                          : Icons.warning_amber_rounded),
                  color: widget.svc.config.production.verified
                      ? _mpGreen
                      : (isEmpty ? AppColors.textHint : AppColors.warning),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Access Token (APP_USR-...)',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textPrimary),
                  ),
                ),
                if (!isEmpty)
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _editing      = !_editing;
                      _verifyResult = null;
                    }),
                    icon: Icon(
                        _editing ? Icons.close_rounded : Icons.edit_rounded,
                        size: 15),
                    label: Text(_editing ? 'Cancelar' : 'Editar',
                        style: const TextStyle(fontSize: 12)),
                  ),
              ],
            ),

            // ── Exibição resumida ─────────────────────────────────────────
            if (!_editing && !isEmpty) ...[
              const SizedBox(height: 12),
              _TokenDisplay(
                  label: 'Access Token',
                  value: widget.svc.config.production.accessToken),
              const SizedBox(height: 6),
              _TokenDisplay(
                  label: 'User ID',
                  value: widget.svc.config.production.userId,
                  mask: false),
              if (widget.svc.config.production.verified) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _mpGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: _mpGreen, size: 14),
                      SizedBox(width: 6),
                      Text('Credenciais verificadas',
                          style: TextStyle(
                              color: _mpGreen,
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
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: AppColors.textHint, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Configure o Access Token de produção para receber pagamentos via PIX',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _editing = true),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Configurar credenciais de produção'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _mpGreen,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],

            // ── Formulário de edição ──────────────────────────────────────
            if (_editing) ...[
              const SizedBox(height: 16),

              // Guia visual
              _GuiaProducao(),

              // Access Token
              _EditField(
                controller: _tokenCtrl,
                label: 'Access Token de Produção',
                hint: 'APP_USR-...',
                icon: Icons.key_rounded,
                obscure: true,
              ),
              const SizedBox(height: 12),

              // Botão verificar
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _verifying ? null : _verify,
                  icon: _verifying
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.verified_user_rounded, size: 16),
                  label: Text(
                      _verifying ? 'Verificando...' : 'Verificar Token',
                      style: const TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _mpBlue),
                    foregroundColor: _mpBlue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              // Resultado da verificação
              if (_verifyResult != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _verifyResult!['valid'] == true
                        ? _mpGreen.withValues(alpha: 0.08)
                        : AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _verifyResult!['valid'] == true
                          ? _mpGreen.withValues(alpha: 0.3)
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
                                ? _mpGreen
                                : AppColors.error,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _verifyResult!['valid'] == true
                                ? 'Token válido!'
                                : 'Token inválido',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _verifyResult!['valid'] == true
                                  ? _mpGreen
                                  : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                      if (_verifyResult!['valid'] == true) ...[
                        const SizedBox(height: 6),
                        Text(
                          '📧 ${_verifyResult!['email']}\n'
                          '🆔 User ID: ${_verifyResult!['user_id']}\n'
                          '🌎 País: ${_verifyResult!['site_id']}',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                        ),
                      ] else
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _verifyResult!['error'] ?? '',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.error),
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // User ID (preenchido automaticamente)
              _EditField(
                controller: _userCtrl,
                label: 'User ID (preenchido ao verificar)',
                hint: 'ex: 3235638414',
                icon: Icons.person_rounded,
              ),
              const SizedBox(height: 20),

              // Botão salvar
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'Salvando...' : 'Salvar Credenciais',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _mpGreen,
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
  late final _notifCtrl   =
      TextEditingController(text: widget.svc.config.notificationUrl);
  late final _successCtrl =
      TextEditingController(text: widget.svc.config.backUrlSuccess);
  late final _failureCtrl =
      TextEditingController(text: widget.svc.config.backUrlFailure);
  late final _pendingCtrl =
      TextEditingController(text: widget.svc.config.backUrlPending);
  late double _comissao = widget.svc.config.comissaoPercent * 100;
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
      mode:            'production',
      sandbox:         MpCredentials.empty(),
      production:      cfg.production,
      comissaoPercent: _comissao / 100,
      notificationUrl: _notifCtrl.text.trim(),
      backUrlSuccess:  _successCtrl.text.trim(),
      backUrlFailure:  _failureCtrl.text.trim(),
      backUrlPending:  _pendingCtrl.text.trim(),
      clientId:        cfg.clientId,
      clientSecret:    cfg.clientSecret,
    );
    final ok = await widget.svc.saveConfig(newCfg);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          ok ? '✅ Configurações salvas!' : (widget.svc.lastError ?? 'Erro')),
      backgroundColor: ok ? _mpGreen : AppColors.error,
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
                  const Text('5%',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textHint)),
                  Text(
                    'Venda R\$10 → afiliado ganha R\$${(10 * _comissao / 100).toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const Text('50%',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textHint)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── URLs ──────────────────────────────────────────────────────────
        _SectionHeader(icon: Icons.link_rounded, title: 'URLs de Retorno'),
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
                label: 'Webhook URL (notificações MP)',
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

        // ── Status ────────────────────────────────────────────────────────
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
            label: Text(_saving ? 'Salvando...' : 'Salvar Configurações'),
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
    final creds = cfg.production;

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
            value: '🚀 Produção (Pagamentos Reais)',
            color: _mpGreen,
          ),
          const Divider(height: 16),
          _StatusRow(
            label: 'Access Token',
            value: creds.isEmpty
                ? '❌ Não configurado'
                : '✅ ${creds.accessToken.substring(0, creds.accessToken.length.clamp(0, 20))}...',
            color: creds.isEmpty ? AppColors.error : _mpGreen,
          ),
          const Divider(height: 16),
          _StatusRow(
            label: 'User ID',
            value: creds.userId.isEmpty ? '—' : creds.userId,
            color: AppColors.textPrimary,
          ),
          const Divider(height: 16),
          _StatusRow(
            label: 'Verificado',
            value: creds.verified ? '✅ Sim' : '⚠️ Não verificado',
            color: creds.verified ? _mpGreen : AppColors.warning,
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

// ── Guia de onde encontrar o Access Token ─────────────────────────────────────

class _GuiaProducao extends StatelessWidget {
  const _GuiaProducao();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4CAF50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFC8E6C9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                Text('🔑', style: TextStyle(fontSize: 16)),
                SizedBox(width: 8),
                Text(
                  'Onde encontrar o Access Token',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Color(0xFF1B5E20),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Passo(n: '1', texto: 'Acesse mercadopago.com.br e faça login'),
                _Passo(
                    n: '2',
                    texto:
                        'Seu perfil → Seu negócio → Configurações → Gestão e administração → Credenciais'),
                _Passo(n: '3', texto: 'Clique na aba "Credenciais de produção"'),
                _Passo(
                    n: '4',
                    texto:
                        'Copie o Access Token (começa com APP_USR-...)'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '⚠️ "Chave secreta" e "ID do aplicativo" que aparecem no\n'
                    'painel de Desenvolvedores NÃO são o Access Token!\n'
                    'O Access Token correto fica em:\n'
                    'Configurações → Credenciais de produção.',
                    style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF1B5E20),
                        fontWeight: FontWeight.w600,
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                _visible
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 16,
                color: AppColors.textHint),
            onPressed: () => setState(() => _visible = !_visible),
          ),
        IconButton(
          icon: const Icon(Icons.copy_rounded,
              size: 14, color: AppColors.textHint),
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

class _Passo extends StatelessWidget {
  final String n;
  final String texto;
  const _Passo({required this.n, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _mpBlue,
              shape: BoxShape.circle,
            ),
            child: Text(n,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.4)),
          ),
        ],
      ),
    );
  }
}
