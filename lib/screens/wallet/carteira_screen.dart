import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/wallet_service.dart';
import '../../services/auth_service.dart';
import '../../services/cf_api_service.dart';
import '../../theme/app_theme.dart';

/// Tela completa de Carteira ShareWallet — dados via Cloudflare D1
class CarteiraScreen extends StatefulWidget {
  const CarteiraScreen({super.key});

  @override
  State<CarteiraScreen> createState() => _CarteiraScreenState();
}

class _CarteiraScreenState extends State<CarteiraScreen>
    with SingleTickerProviderStateMixin {
  final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  bool _saldoVisible = true;
  static const double _saqueMinimo = 100.0;

  // Abas: 0 = Carteira, 1 = Indicados
  late TabController _tabController;

  // Dados de indicados
  bool _loadingIndicados = false;
  List<Map<String, dynamic>> _compradores = [];
  List<Map<String, dynamic>> _naoCompraram = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWallet();
      _loadIndicados();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadWallet({bool forceRefresh = false}) async {
    // Usa o uid do AuthService (já validado após Firebase.initializeApp)
    // evita "No Firebase App '[DEFAULT]'" quando FirebaseAuth.instance é
    // acessado antes da inicialização estar completa.
    final auth = context.read<AuthService>();
    final uid = auth.currentUser?.id ?? auth.currentUser?.email;
    if (uid == null || uid.isEmpty) return;
    await context.read<WalletService>().loadData(
          userId: auth.currentUser!.id,
          forceRefresh: forceRefresh,
        );
  }

  Future<void> _loadIndicados() async {
    setState(() => _loadingIndicados = true);
    try {
      final auth = context.read<AuthService>();
      final email = auth.currentUser?.email ?? '';
      final affiliateData = await CfApiService.getAffiliateByEmail(email);
      if (affiliateData == null) return;

      final code = affiliateData['affiliate_code']?.toString() ?? '';
      if (code.isEmpty) return;

      final subs = await CfApiService.getSubscriptionsByAffiliate(code);

      // Quem comprou (ativos/pagos)
      final compradores = subs.where((s) {
        final st = s['status']?.toString().toLowerCase() ?? '';
        return st == 'ativa' || st == 'ativo' || st == 'pago' || st == 'approved' || st == 'active';
      }).map((s) {
        final valor    = (s['valor'] as num?)?.toDouble() ?? 0.0;
        final pctCom   = (s['comissao'] as num?)?.toDouble() ?? 0.20;
        final comissao = (s['comissao_valor'] as num?)?.toDouble() ?? (valor * pctCom);
        return {
          'nome':     s['nome_cliente'] ?? s['affiliate_nome'] ?? 'Cliente',
          'email':    s['email_cliente'] ?? s['email'] ?? '',
          'produto':  s['product_nome'] ?? s['produto_nome'] ?? 'Produto',
          'valor':    valor,
          'comissao': comissao,
          'status':   s['status']?.toString() ?? 'ativa',
          'data':     s['created_at']?.toString() ?? '',
          'tipo':     s['tipo'] ?? 'recorrente',
        };
      }).toList();

      // Quem não concluiu
      final naoCompraram = subs.where((s) {
        final st = s['status']?.toString().toLowerCase() ?? '';
        return st == 'cancelada' || st == 'inativa' || st == 'pendente' ||
               st == 'cancelado' || st == 'inativo';
      }).map((s) => {
        'nome':    s['nome_cliente'] ?? s['affiliate_nome'] ?? 'Cliente',
        'email':   s['email_cliente'] ?? s['email'] ?? '',
        'produto': s['product_nome'] ?? s['produto_nome'] ?? 'Produto',
        'status':  s['status']?.toString() ?? 'inativa',
        'data':    s['created_at']?.toString() ?? '',
      }).toList();

      setState(() {
        _compradores   = List<Map<String, dynamic>>.from(compradores);
        _naoCompraram  = List<Map<String, dynamic>>.from(naoCompraram);
      });
    } catch (e) {
      debugPrint('[CarteiraScreen] indicados err: $e');
    } finally {
      setState(() => _loadingIndicados = false);
    }
  }

  // Exportar extrato CSV para clipboard
  void _exportarExtrato(WalletService wallet) {
    final sb = StringBuffer();
    sb.writeln('Tipo,Descrição,Valor,Data,Status');
    for (final tx in wallet.extratoCompleto) {
      final tipo   = tx['tipo'] as String? ?? '';
      final desc   = (tx['descricao'] as String? ?? '').replaceAll('"', '""');
      final valor  = (tx['valor'] as num?)?.toDouble() ?? 0.0;
      final data   = tx['data'] as DateTime?;
      final status = tx['status'] as String? ?? '';
      final dataStr = data != null
          ? DateFormat('dd/MM/yyyy HH:mm').format(data) : '';
      sb.writeln('$tipo,"$desc",${valor.toStringAsFixed(2)},$dataStr,$status');
    }
    Clipboard.setData(ClipboardData(text: sb.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Extrato copiado! Cole numa planilha para visualizar.'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 4),
      ),
    );
  }

  Future<void> _solicitarSaque() async {
    final wallet = context.read<WalletService>();
    if (wallet.saldoCarteira < _saqueMinimo) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saldo mínimo para saque: ${_fmt.format(_saqueMinimo)}. '
            'Você tem ${_fmt.format(wallet.saldoCarteira)}.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    final auth = context.read<AuthService>();
    final user = auth.currentUser;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SaqueModal(
        saldoDisponivel: wallet.saldoCarteira,
        pixKey: user?.email ?? '',
        onConfirm: (valor, pixKey, pixType) async {
          Navigator.pop(context);
          final result = await context.read<WalletService>().solicitarSaque(
                valor: valor,
                pixKey: pixKey,
                pixKeyType: pixType,
              );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.success
                    ? 'Solicitação de saque de ${_fmt.format(valor)} enviada! ✅'
                    : result.message ?? 'Erro ao solicitar saque'),
                backgroundColor:
                    result.success ? AppColors.success : AppColors.error,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletService>(
      builder: (context, wallet, _) {
        final saldo        = wallet.saldoCarteira;
        final pendente     = wallet.saldoPendente;
        final totalRecebido = wallet.totalRecebido;
        final transacoes   = wallet.extratoCompleto;
        final metaPct      = (saldo / _saqueMinimo).clamp(0.0, 1.0);
        final faltam       = (_saqueMinimo - saldo).clamp(0.0, _saqueMinimo);
        final podesSacar   = saldo >= _saqueMinimo;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: NestedScrollView(
            headerSliverBuilder: (_, __) => [
              SliverAppBar(
                expandedHeight: 190,
                pinned: true,
                automaticallyImplyLeading: false,
                backgroundColor: const Color(0xFF0A1628),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0A1628), Color(0xFF0D3B2E)],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 52),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('Minha Carteira',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800)),
                                const Spacer(),
                                // Exportar extrato
                                IconButton(
                                  onPressed: () => _exportarExtrato(wallet),
                                  icon: const Icon(Icons.download_rounded,
                                      color: Colors.white70, size: 20),
                                  tooltip: 'Exportar extrato CSV',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 36, minHeight: 36),
                                ),
                                IconButton(
                                  onPressed: () => setState(
                                      () => _saldoVisible = !_saldoVisible),
                                  icon: Icon(
                                    _saldoVisible
                                        ? Icons.visibility_rounded
                                        : Icons.visibility_off_rounded,
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 36, minHeight: 36),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text('Saldo Disponível',
                                style: TextStyle(
                                    color: Colors.white60, fontSize: 12)),
                            const SizedBox(height: 2),
                            wallet.isLoading
                                ? const SizedBox(
                                    width: 22, height: 22,
                                    child: CircularProgressIndicator(
                                        color: Color(0xFF00E5B4),
                                        strokeWidth: 2))
                                : Text(
                                    _saldoVisible
                                        ? _fmt.format(saldo)
                                        : 'R\$ ••••••',
                                    style: const TextStyle(
                                        color: Color(0xFF00E5B4),
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _MiniStat(
                                    label: 'Pendente',
                                    value: _saldoVisible
                                        ? _fmt.format(pendente)
                                        : 'R\$ ••'),
                                const SizedBox(width: 16),
                                _MiniStat(
                                    label: 'Total recebido',
                                    value: _saldoVisible
                                        ? _fmt.format(totalRecebido)
                                        : 'R\$ ••••'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // TabBar na bottom da AppBar
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(46),
                  child: Container(
                    color: const Color(0xFF0D1F14),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF00E5B4),
                      unselectedLabelColor: Colors.white54,
                      indicatorColor: const Color(0xFF00E5B4),
                      indicatorSize: TabBarIndicatorSize.label,
                      labelStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                      tabs: [
                        const Tab(
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.account_balance_wallet_rounded, size: 15),
                            SizedBox(width: 6),
                            Text('Carteira'),
                          ]),
                        ),
                        Tab(
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.people_alt_rounded, size: 15),
                            const SizedBox(width: 6),
                            const Text('Indicados'),
                            if (_compradores.isNotEmpty || _naoCompraram.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${_compradores.length + _naoCompraram.length}',
                                  style: const TextStyle(
                                      fontSize: 9,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                // ── ABA 1: CARTEIRA ────────────────────────────────────────
                RefreshIndicator(
                  onRefresh: () => _loadWallet(forceRefresh: true),
                  color: const Color(0xFF00E5B4),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    child: Column(
                      children: [
                        // Meta de saque
                        Container(
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
                                  const Icon(Icons.flag_rounded,
                                      color: AppColors.primary, size: 18),
                                  const SizedBox(width: 8),
                                  const Text('Meta para saque',
                                      style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500)),
                                  const Spacer(),
                                  Text(
                                    '${(metaPct * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: metaPct,
                                  backgroundColor: AppColors.cardBorder,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                    Color(0xFF00E5B4),
                                  ),
                                  minHeight: 10,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                podesSacar
                                    ? '✅ Você já pode solicitar seu saque!'
                                    : 'Faltam ${_fmt.format(faltam)} para o mínimo de ${_fmt.format(_saqueMinimo)}',
                                style: TextStyle(
                                    color: podesSacar
                                        ? AppColors.success
                                        : AppColors.textSecondary,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Botões de ação
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: _solicitarSaque,
                                icon: const Icon(Icons.pix_rounded, size: 18),
                                label: const Text('Solicitar Saque PIX',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: podesSacar
                                      ? const Color(0xFF00E5B4)
                                      : AppColors.textHint,
                                  foregroundColor: podesSacar
                                      ? const Color(0xFF0A1628)
                                      : Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Exportar comissões
                            OutlinedButton.icon(
                              onPressed: () => _exportarExtrato(wallet),
                              icon: const Icon(Icons.download_rounded,
                                  size: 16, color: AppColors.primary),
                              label: const Text('Extrato',
                                  style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14, horizontal: 14),
                                side: const BorderSide(
                                    color: AppColors.primary),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Mínimo: ${_fmt.format(_saqueMinimo)} • Processamento em até 24h',
                          style: const TextStyle(
                              color: AppColors.textHint, fontSize: 11),
                        ),

                        const SizedBox(height: 24),

                        // Histórico
                        Row(
                          children: [
                            const Text('Histórico',
                                style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800)),
                            const Spacer(),
                            Text('${transacoes.length} transações',
                                style: const TextStyle(
                                    color: AppColors.textHint, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (wallet.isLoading)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                                child: CircularProgressIndicator()))
                        else if (transacoes.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: AppColors.cardBorder),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.receipt_long_outlined,
                                    color: AppColors.textHint, size: 40),
                                SizedBox(height: 12),
                                Text('Nenhuma transação ainda',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w500)),
                                Text('Suas comissões aparecerão aqui',
                                    style: TextStyle(
                                        color: AppColors.textHint,
                                        fontSize: 12)),
                              ],
                            ),
                          )
                        else
                          ...transacoes
                              .take(30)
                              .map((tx) =>
                                  _TransacaoTile(tx: tx, fmt: _fmt)),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),

                // ── ABA 2: INDICADOS ──────────────────────────────────────
                RefreshIndicator(
                  onRefresh: _loadIndicados,
                  color: AppColors.primary,
                  child: _loadingIndicados
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Resumo
                              Row(
                                children: [
                                  Expanded(
                                    child: _SaldoCard(
                                      label: 'Compraram',
                                      valor: '${_compradores.length}',
                                      icon: Icons.check_circle_rounded,
                                      color: AppColors.success,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _SaldoCard(
                                      label: 'Não concluíram',
                                      valor: '${_naoCompraram.length}',
                                      icon: Icons.cancel_rounded,
                                      color: AppColors.error,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _SaldoCard(
                                      label: 'Comissões',
                                      valor: _fmt.format(_compradores.fold<double>(
                                          0.0,
                                          (s, c) => s + ((c['comissao'] as num?)?.toDouble() ?? 0.0))),
                                      icon: Icons.monetization_on_rounded,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 24),

                              // COMPRADORES
                              if (_compradores.isNotEmpty) ...[
                                _IndicadosSectionHeader(
                                  label: 'Compraram',
                                  count: _compradores.length,
                                  color: AppColors.success,
                                  icon: Icons.check_circle_rounded,
                                ),
                                const SizedBox(height: 10),
                                ..._compradores.map((c) => _IndicadoTile(
                                      nome: c['nome']?.toString() ?? '',
                                      email: c['email']?.toString() ?? '',
                                      produto: c['produto']?.toString() ?? '',
                                      comissao: (c['comissao'] as num?)?.toDouble() ?? 0.0,
                                      status: c['status']?.toString() ?? 'ativa',
                                      data: c['data']?.toString() ?? '',
                                      tipo: c['tipo']?.toString() ?? '',
                                      comprou: true,
                                      fmt: _fmt,
                                    )),
                              ],

                              // NÃO COMPRARAM
                              if (_naoCompraram.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                _IndicadosSectionHeader(
                                  label: 'Não concluíram',
                                  count: _naoCompraram.length,
                                  color: AppColors.error,
                                  icon: Icons.cancel_rounded,
                                ),
                                const SizedBox(height: 10),
                                ..._naoCompraram.map((c) => _IndicadoTile(
                                      nome: c['nome']?.toString() ?? '',
                                      email: c['email']?.toString() ?? '',
                                      produto: c['produto']?.toString() ?? '',
                                      comissao: 0.0,
                                      status: c['status']?.toString() ?? 'cancelada',
                                      data: c['data']?.toString() ?? '',
                                      tipo: '',
                                      comprou: false,
                                      fmt: _fmt,
                                    )),
                              ],

                              if (_compradores.isEmpty &&
                                  _naoCompraram.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(32),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius:
                                        BorderRadius.circular(16),
                                    border: Border.all(
                                        color: AppColors.cardBorder),
                                  ),
                                  child: const Column(
                                    children: [
                                      Icon(Icons.people_outline_rounded,
                                          color: AppColors.textHint,
                                          size: 40),
                                      SizedBox(height: 12),
                                      Text('Nenhum indicado ainda',
                                          style: TextStyle(
                                              color:
                                                  AppColors.textSecondary,
                                              fontWeight: FontWeight.w500)),
                                      Text(
                                          'Compartilhe seu link e comece a ganhar!',
                                          style: TextStyle(
                                              color: AppColors.textHint,
                                              fontSize: 12)),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Mini stat na AppBar ───────────────────────────────────────────────────────
class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
        Text(value,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── Widget: Card de saldo ─────────────────────────────────────────────────────
class _SaldoCard extends StatelessWidget {
  final String label;
  final String valor;
  final IconData icon;
  final Color color;

  const _SaldoCard(
      {required this.label,
      required this.valor,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textHint, fontSize: 10)),
          const SizedBox(height: 1),
          Text(valor,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ── Header de seção de indicados ──────────────────────────────────────────────
class _IndicadosSectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _IndicadosSectionHeader({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppColors.textPrimary)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$count',
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ),
      ],
    );
  }
}

// ── Tile de indicado ──────────────────────────────────────────────────────────
class _IndicadoTile extends StatelessWidget {
  final String nome;
  final String email;
  final String produto;
  final double comissao;
  final String status;
  final String data;
  final String tipo;
  final bool comprou;
  final NumberFormat fmt;

  const _IndicadoTile({
    required this.nome,
    required this.email,
    required this.produto,
    required this.comissao,
    required this.status,
    required this.data,
    required this.tipo,
    required this.comprou,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final color = comprou ? AppColors.success : AppColors.error;
    final inicial = nome.isNotEmpty ? nome[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(inicial,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome.isNotEmpty ? nome : 'Cliente',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textPrimary)),
                if (produto.isNotEmpty)
                  Text(produto,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                Row(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        comprou ? status.toUpperCase() : 'NÃO COMPROU',
                        style: TextStyle(
                            color: color,
                            fontSize: 9,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (tipo == 'recorrente' && comprou) ...[
                      const SizedBox(width: 5),
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text('MENSAL',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 9,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Comissão (só se comprou)
          if (comprou && comissao > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(fmt.format(comissao),
                    style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
                const Text('comissão',
                    style: TextStyle(
                        color: AppColors.textHint, fontSize: 10)),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Widget: Tile de transação ─────────────────────────────────────────────────
class _TransacaoTile extends StatelessWidget {
  final Map<String, dynamic> tx;
  final NumberFormat fmt;

  const _TransacaoTile({required this.tx, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final tipo      = (tx['tipo'] as String? ?? 'comissao').toUpperCase();
    final valor     = (tx['valor'] as num?)?.toDouble() ?? 0.0;
    final desc      = tx['descricao'] as String? ?? 'Comissão';
    final date      = tx['data'] as DateTime?;
    final isComissao = tipo == 'COMISSAO';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isComissao ? AppColors.success : AppColors.warning)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isComissao
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: isComissao ? AppColors.success : AppColors.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(desc,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textPrimary)),
                if (date != null)
                  Text(
                    DateFormat('dd/MM/yyyy', 'pt_BR').format(date),
                    style: const TextStyle(
                        color: AppColors.textHint, fontSize: 11),
                  ),
              ],
            ),
          ),
          Text(
            '${isComissao ? '+' : '-'}${fmt.format(valor)}',
            style: TextStyle(
              color: isComissao ? AppColors.success : AppColors.warning,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Modal de solicitação de saque ─────────────────────────────────────────────
class _SaqueModal extends StatefulWidget {
  final double saldoDisponivel;
  final String pixKey;
  final void Function(double valor, String pixKey, String pixType) onConfirm;

  const _SaqueModal({
    required this.saldoDisponivel,
    required this.pixKey,
    required this.onConfirm,
  });

  @override
  State<_SaqueModal> createState() => _SaqueModalState();
}

class _SaqueModalState extends State<_SaqueModal> {
  final _pixController = TextEditingController();
  final _valorController = TextEditingController();
  String _pixType = 'EMAIL';
  final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    _pixController.text = widget.pixKey;
    _valorController.text = widget.saldoDisponivel.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _pixController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Solicitar Saque',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(
            'Saldo disponível: ${_fmt.format(widget.saldoDisponivel)}',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          const Text('Valor do saque',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _valorController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              prefixText: 'R\$ ',
              hintText: '100,00',
            ),
          ),
          const SizedBox(height: 16),
          const Text('Tipo da chave PIX',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _pixType,
            decoration: const InputDecoration(),
            items: const [
              DropdownMenuItem(value: 'EMAIL', child: Text('E-mail')),
              DropdownMenuItem(value: 'CPF', child: Text('CPF')),
              DropdownMenuItem(value: 'TELEFONE', child: Text('Telefone')),
              DropdownMenuItem(
                  value: 'ALEATORIA', child: Text('Chave aleatória')),
            ],
            onChanged: (v) => setState(() => _pixType = v ?? 'EMAIL'),
          ),
          const SizedBox(height: 16),
          const Text('Chave PIX',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _pixController,
            decoration: const InputDecoration(
              hintText: 'Digite sua chave PIX',
              prefixIcon:
                  Icon(Icons.pix_rounded, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final valor = double.tryParse(
                        _valorController.text.replaceAll(',', '.')) ??
                    0;
                if (valor <= 0 || _pixController.text.isEmpty) return;
                widget.onConfirm(valor, _pixController.text, _pixType);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5B4),
                foregroundColor: const Color(0xFF0A1628),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Confirmar Saque',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}
