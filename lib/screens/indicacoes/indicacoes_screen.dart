import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/cf_api_service.dart';
import '../../services/extrato_export_service.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enum de filtro de período
// ─────────────────────────────────────────────────────────────────────────────
enum _PeriodoFiltro { todos, sete, trinta, noventa, custom }

extension _PeriodoLabel on _PeriodoFiltro {
  String get label {
    switch (this) {
      case _PeriodoFiltro.todos:
        return 'Todos';
      case _PeriodoFiltro.sete:
        return '7d';
      case _PeriodoFiltro.trinta:
        return '30d';
      case _PeriodoFiltro.noventa:
        return '90d';
      case _PeriodoFiltro.custom:
        return 'Custom';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Enum de filtro de status
// ─────────────────────────────────────────────────────────────────────────────
enum _StatusFiltro { todos, compraram, naoCompraram }

// ─────────────────────────────────────────────────────────────────────────────
// IndicacoesScreen
// ─────────────────────────────────────────────────────────────────────────────
class IndicacoesScreen extends StatefulWidget {
  const IndicacoesScreen({super.key});

  @override
  State<IndicacoesScreen> createState() => _IndicacoesScreenState();
}

class _IndicacoesScreenState extends State<IndicacoesScreen>
    with SingleTickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  bool _loading = true;
  int _totalAssinaturas = 0;
  double _comissaoMensal = 0;
  List<Map<String, dynamic>> _referrals = [];
  String _nomeAfiliado = '';

  // Filtros
  _StatusFiltro _statusFiltro = _StatusFiltro.todos;
  _PeriodoFiltro _periodoFiltro = _PeriodoFiltro.todos;
  DateTimeRange? _customRange;

  late final TabController _tabController;
  final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _fmtDate = DateFormat('dd/MM/yyyy');

  // ── Níveis ─────────────────────────────────────────────────────────────────
  static const _niveis = [
    _Nivel('Bronze', 0, 20, Color(0xFFCD7F32), Icons.military_tech_rounded),
    _Nivel('Prata', 21, 100, Color(0xFFBDBDBD), Icons.military_tech_rounded),
    _Nivel('Ouro', 101, 500, Color(0xFFFFD740), Icons.military_tech_rounded),
    _Nivel('Diamante', 501, 999999, Color(0xFF00BCD4), Icons.diamond_rounded),
  ];

  // ── Init ───────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          switch (_tabController.index) {
            case 0:
              _statusFiltro = _StatusFiltro.todos;
              break;
            case 1:
              _statusFiltro = _StatusFiltro.compraram;
              break;
            case 2:
              _statusFiltro = _StatusFiltro.naoCompraram;
              break;
          }
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReferrals());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Carga de dados ─────────────────────────────────────────────────────────
  Future<void> _loadReferrals({bool forceRefresh = false}) async {
    if (_referrals.isNotEmpty && !forceRefresh) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _clearData();
        return;
      }

      final affiliateData = await CfApiService.getAffiliateByEmail(
          FirebaseAuth.instance.currentUser?.email ?? '');
      if (affiliateData == null) {
        _clearData();
        return;
      }

      _nomeAfiliado = affiliateData['nome']?.toString() ??
          FirebaseAuth.instance.currentUser?.displayName ??
          '';

      final code = affiliateData['affiliate_code']?.toString() ?? '';
      if (code.isEmpty) {
        _clearData();
        return;
      }

      final subs = await CfApiService.getSubscriptionsByAffiliate(code);

      final ativos = subs
          .where((s) => (s['status']?.toString() ?? 'ativa') == 'ativa')
          .toList();
      final comissao = ativos.fold<double>(
          0, (s, r) => s + ((r['comissao'] as num?)?.toDouble() ?? 0));

      final list = subs.map((s) {
        final clienteNome = (s['cliente_nome']?.toString() ?? '').trim();
        final productNome = (s['product_nome']?.toString() ?? '').trim();
        final hasNome = clienteNome.isNotEmpty;
        final statusRaw = (s['status']?.toString() ?? 'ativa');
        final isAtivo = statusRaw == 'ativa';

        // Parseia data_inicio se existir
        DateTime? dataInicio;
        final dataStr = s['data_inicio']?.toString() ?? '';
        if (dataStr.isNotEmpty) {
          try {
            dataInicio = DateTime.tryParse(dataStr);
          } catch (_) {}
        }

        return {
          'id': s['id'],
          'referred_id': hasNome ? clienteNome : 'Comprador',
          'product_nome': productNome,
          'nome_desconhecido': !hasNome,
          'status': isAtivo ? 'ATIVO' : 'INATIVO',
          'comissao_mensal': (s['comissao'] as num?)?.toDouble() ?? 0,
          'meses_ativos': 1,
          'data_inicio': dataInicio,
          'cliente_email': s['cliente_email']?.toString() ?? '',
        };
      }).toList();

      setState(() {
        _referrals = list.cast<Map<String, dynamic>>();
        _totalAssinaturas = ativos.length;
        _comissaoMensal = comissao;
      });
    } catch (e) {
      debugPrint('[IndicacoesScreen] Erro: $e');
      _clearData();
    } finally {
      setState(() => _loading = false);
    }
  }

  void _clearData() {
    setState(() {
      _referrals = [];
      _totalAssinaturas = 0;
      _comissaoMensal = 0;
    });
  }

  // ── Filtros aplicados ──────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _referralsFiltrados {
    var lista = _referrals.toList();

    // Filtro por status
    if (_statusFiltro == _StatusFiltro.compraram) {
      lista = lista.where((r) => r['status'] == 'ATIVO').toList();
    } else if (_statusFiltro == _StatusFiltro.naoCompraram) {
      lista = lista.where((r) => r['status'] != 'ATIVO').toList();
    }

    // Filtro por período
    final now = DateTime.now();
    DateTime? from;
    DateTime? to;

    switch (_periodoFiltro) {
      case _PeriodoFiltro.sete:
        from = now.subtract(const Duration(days: 7));
        break;
      case _PeriodoFiltro.trinta:
        from = now.subtract(const Duration(days: 30));
        break;
      case _PeriodoFiltro.noventa:
        from = now.subtract(const Duration(days: 90));
        break;
      case _PeriodoFiltro.custom:
        from = _customRange?.start;
        to = _customRange?.end;
        break;
      case _PeriodoFiltro.todos:
        break;
    }

    if (from != null) {
      lista = lista.where((r) {
        final dt = r['data_inicio'] as DateTime?;
        if (dt == null) return true; // sem data → inclui
        final afterFrom = dt.isAfter(from!.subtract(const Duration(days: 1)));
        final beforeTo = to == null || dt.isBefore(to.add(const Duration(days: 1)));
        return afterFrom && beforeTo;
      }).toList();
    }

    return lista;
  }

  // Contagens por aba
  int get _countTodos => _aplicarPeriodo(_referrals).length;
  int get _countCompraram =>
      _aplicarPeriodo(_referrals.where((r) => r['status'] == 'ATIVO').toList())
          .length;
  int get _countNaoCompraram =>
      _aplicarPeriodo(_referrals.where((r) => r['status'] != 'ATIVO').toList())
          .length;

  List<Map<String, dynamic>> _aplicarPeriodo(List<Map<String, dynamic>> lista) {
    final now = DateTime.now();
    DateTime? from;
    DateTime? to;

    switch (_periodoFiltro) {
      case _PeriodoFiltro.sete:
        from = now.subtract(const Duration(days: 7));
        break;
      case _PeriodoFiltro.trinta:
        from = now.subtract(const Duration(days: 30));
        break;
      case _PeriodoFiltro.noventa:
        from = now.subtract(const Duration(days: 90));
        break;
      case _PeriodoFiltro.custom:
        from = _customRange?.start;
        to = _customRange?.end;
        break;
      case _PeriodoFiltro.todos:
        return lista;
    }

    return lista.where((r) {
      final dt = r['data_inicio'] as DateTime?;
      if (dt == null) return true;
      final afterFrom = dt.isAfter(from!.subtract(const Duration(days: 1)));
      final beforeTo = to == null || dt.isBefore(to.add(const Duration(days: 1)));
      return afterFrom && beforeTo;
    }).toList();
  }

  // Comissão da lista filtrada
  double _comissaoLista(List<Map<String, dynamic>> lista) =>
      lista.fold(0, (s, r) => s + ((r['comissao_mensal'] as num?)?.toDouble() ?? 0));

  // ── Selecionar período custom ──────────────────────────────────────────────
  Future<void> _selecionarCustomRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: _customRange,
      locale: const Locale('pt', 'BR'),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (range != null) {
      setState(() {
        _customRange = range;
        _periodoFiltro = _PeriodoFiltro.custom;
      });
    }
  }

  // ── Modal de exportação ────────────────────────────────────────────────────
  void _showExportModal() {
    final lista = _referralsFiltrados;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ExportModal(
        referrals: lista,
        nomeAfiliado: _nomeAfiliado,
        periodoLabel: _periodoFiltro == _PeriodoFiltro.custom && _customRange != null
            ? '${_fmtDate.format(_customRange!.start)} – ${_fmtDate.format(_customRange!.end)}'
            : _periodoFiltro.label,
        statusLabel: _statusFiltro == _StatusFiltro.compraram
            ? 'Compraram'
            : _statusFiltro == _StatusFiltro.naoCompraram
                ? 'Não Compraram'
                : 'Todos',
        fmt: _fmt,
        fmtDate: _fmtDate,
      ),
    );
  }

  // ── Níveis ─────────────────────────────────────────────────────────────────
  _Nivel get _nivelAtual {
    for (final n in _niveis.reversed) {
      if (_totalAssinaturas >= n.min) return n;
    }
    return _niveis.first;
  }

  _Nivel? get _proximoNivel {
    final idx = _niveis.indexOf(_nivelAtual);
    if (idx < _niveis.length - 1) return _niveis[idx + 1];
    return null;
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final nivel = _nivelAtual;
    final proximo = _proximoNivel;
    final progressoNivel = proximo != null
        ? ((_totalAssinaturas - nivel.min) / (proximo.min - nivel.min))
            .clamp(0.0, 1.0)
        : 1.0;
    final filtrados = _referralsFiltrados;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () => _loadReferrals(forceRefresh: true),
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            // ── AppBar ──────────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 210,
              pinned: true,
              automaticallyImplyLeading: false,
              backgroundColor: AppColors.primary,
              actions: [
                IconButton(
                  tooltip: 'Exportar indicações',
                  icon: const Icon(Icons.download_rounded, color: Colors.white),
                  onPressed: _showExportModal,
                ),
                const SizedBox(width: 4),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.darkGreenGradient,
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 44),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Minhas Indicações',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800)),
                              const Spacer(),
                              // Botão exportar no header expandido
                              GestureDetector(
                                onTap: _showExportModal,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color:
                                            Colors.white.withValues(alpha: 0.3)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.file_download_outlined,
                                          color: Colors.white, size: 15),
                                      SizedBox(width: 4),
                                      Text('Exportar',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _StatBubble(
                                label: 'Assinaturas ativas',
                                value: '$_totalAssinaturas',
                                icon: Icons.people_alt_rounded,
                              ),
                              const SizedBox(width: 12),
                              _StatBubble(
                                label: 'Comissão/mês',
                                value: _fmt.format(_comissaoMensal),
                                icon: Icons.attach_money_rounded,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(0),
                child: Container(
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F7F5),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                ),
              ),
            ),

            // ── Conteúdo ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // -- Card de nível atual ----------------------------------
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            nivel.cor.withValues(alpha: 0.15),
                            nivel.cor.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: nivel.cor.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(nivel.icone, color: nivel.cor, size: 32),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Seu nível atual',
                                      style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12)),
                                  Text(nivel.nome,
                                      style: TextStyle(
                                        color: nivel.cor,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                      )),
                                ],
                              ),
                            ],
                          ),
                          if (proximo != null) ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('$_totalAssinaturas assinaturas',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12)),
                                Text(
                                    'Próximo: ${proximo.nome} (${proximo.min})',
                                    style: TextStyle(
                                        color: proximo.cor, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progressoNivel,
                                backgroundColor:
                                    nivel.cor.withValues(alpha: 0.15),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(nivel.cor),
                                minHeight: 8,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                                'Faltam ${proximo.min - _totalAssinaturas} indicações para ${proximo.nome}',
                                style: const TextStyle(
                                    color: AppColors.textHint, fontSize: 11)),
                          ] else ...[
                            const SizedBox(height: 8),
                            const Text('Nível máximo atingido!',
                                style: TextStyle(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // -- Progressão de Níveis ---------------------------------
                    const Text('Progressão de Níveis',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    Row(
                      children: _niveis
                          .map((n) => Expanded(
                                child: _NivelChip(
                                  nivel: n,
                                  isAtual: n.nome == nivel.nome,
                                  atingido: _totalAssinaturas >= n.min,
                                ),
                              ))
                          .toList(),
                    ),

                    const SizedBox(height: 24),

                    // -- Header: Meus Indicados + filtro período ---------------
                    Row(
                      children: [
                        const Text('Meus Indicados',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                color: AppColors.textPrimary)),
                        const Spacer(),
                        // Badge com total filtrado
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${filtrados.length}',
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // -- Filtros de período ------------------------------------
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ..._PeriodoFiltro.values
                              .where((p) => p != _PeriodoFiltro.custom)
                              .map((p) => _PeriodoChip(
                                    label: p.label,
                                    selected: _periodoFiltro == p,
                                    onTap: () =>
                                        setState(() => _periodoFiltro = p),
                                  )),
                          _PeriodoChip(
                            label: _periodoFiltro == _PeriodoFiltro.custom &&
                                    _customRange != null
                                ? '${_fmtDate.format(_customRange!.start)}–${_fmtDate.format(_customRange!.end)}'
                                : 'Período',
                            selected: _periodoFiltro == _PeriodoFiltro.custom,
                            icon: Icons.date_range_rounded,
                            onTap: _selecionarCustomRange,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // -- Tabs: Todos / Compraram / Não Compraram ---------------
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicatorPadding: const EdgeInsets.all(4),
                        labelColor: Colors.white,
                        unselectedLabelColor: AppColors.textSecondary,
                        labelStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700),
                        unselectedLabelStyle:
                            const TextStyle(fontSize: 12),
                        dividerColor: Colors.transparent,
                        tabs: [
                          Tab(text: 'Todos ($_countTodos)'),  
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    size: 13),
                                const SizedBox(width: 4),
                                Text('Compraram ($_countCompraram)'),  
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.hourglass_empty_rounded,
                                    size: 13),
                                const SizedBox(width: 4),
                                Text('Pendentes ($_countNaoCompraram)'),  
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // -- Resumo da aba filtrada --------------------------------
                    if (!_loading && filtrados.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.summarize_rounded,
                                color: AppColors.primary, size: 15),
                            const SizedBox(width: 6),
                            Text(
                              '${filtrados.length} indicados  •  comissão: ${_fmt.format(_comissaoLista(filtrados))}/mês',
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // -- Lista ------------------------------------------------
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (filtrados.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.person_add_outlined,
                                color: AppColors.textHint, size: 40),
                            const SizedBox(height: 12),
                            Text(
                              _statusFiltro == _StatusFiltro.compraram
                                  ? 'Nenhum indicado comprou ainda'
                                  : _statusFiltro == _StatusFiltro.naoCompraram
                                      ? 'Todos os indicados já compraram!'
                                      : 'Você ainda não tem indicados',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                                'Compartilhe seu link e comece a ganhar!',
                                style: TextStyle(
                                    color: AppColors.textHint, fontSize: 12)),
                          ],
                        ),
                      )
                    else
                      ...filtrados.map((r) => _ReferralTile(
                            referral: r,
                            fmt: _fmt,
                            fmtDate: _fmtDate,
                          )),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Modal de Exportação de Indicações
// ─────────────────────────────────────────────────────────────────────────────
class _ExportModal extends StatelessWidget {
  final List<Map<String, dynamic>> referrals;
  final String nomeAfiliado;
  final String periodoLabel;
  final String statusLabel;
  final NumberFormat fmt;
  final DateFormat fmtDate;

  const _ExportModal({
    required this.referrals,
    required this.nomeAfiliado,
    required this.periodoLabel,
    required this.statusLabel,
    required this.fmt,
    required this.fmtDate,
  });

  Future<void> _exportPdf(BuildContext ctx) async {
    // Constrói lista compatível com ExtratoExportService.openPdf
    final extratoCompat = referrals
        .map((r) => {
              'data': r['data_inicio'] ?? DateTime.now(),
              'tipo': 'comissao',
              'descricao': '${r['referred_id'] ?? 'Comprador'} — ${r['product_nome'] ?? ''}',
              'valor': (r['comissao_mensal'] as num?)?.toDouble() ?? 0.0,
              'positivo': true,
              'status': r['status'] == 'ATIVO' ? 'Ativo' : 'Pendente',
            })
        .toList();
    final totalComissao = referrals.fold<double>(
        0, (s, r) => s + ((r['comissao_mensal'] as num?)?.toDouble() ?? 0));
    await ExtratoExportService.openPdf(
      extrato: extratoCompat,
      totalComissoes: totalComissao,
      totalSaques: 0,
      nomeAfiliado: nomeAfiliado,
    );
    if (ctx.mounted) Navigator.pop(ctx);
  }

  Future<void> _exportCsv(BuildContext ctx) async {
    await ExtratoExportService.downloadCsv(
      extrato: referrals
          .map((r) => {
                'data': r['data_inicio'] ?? DateTime.now(),
                'tipo': 'indicacao',
                'descricao': '${r['referred_id'] ?? 'Comprador'} — ${r['product_nome'] ?? ''}',
                'valor': (r['comissao_mensal'] as num?)?.toDouble() ?? 0.0,
                'positivo': true,
                'status': r['status'] == 'ATIVO' ? 'Ativo' : 'Pendente',
              })
          .toList(),
      nomeAfiliado: nomeAfiliado,
    );
    if (ctx.mounted) Navigator.pop(ctx);
  }

  Future<void> _copiarTexto(BuildContext ctx) async {
    final buffer = StringBuffer();
    buffer.writeln('📋 Relatório de Indicações — ShareWallet');
    buffer.writeln('Período: $periodoLabel  |  Filtro: $statusLabel');
    buffer.writeln('---');
    for (final r in referrals) {
      final nome = r['referred_id']?.toString() ?? 'Comprador';
      final status = r['status'] == 'ATIVO' ? '✅ Ativo' : '⏳ Pendente';
      final comissao = fmt.format(
          (r['comissao_mensal'] as num?)?.toDouble() ?? 0);
      final dt = r['data_inicio'] as DateTime?;
      final data = dt != null ? fmtDate.format(dt) : '-';
      buffer.writeln('$nome | $status | $comissao/mês | $data');
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (ctx.mounted) {
      Navigator.pop(ctx);
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Lista copiada para a área de transferência!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Título
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.download_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Exportar Indicações',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppColors.textPrimary)),
                  Text('$periodoLabel  •  $statusLabel  •  ${referrals.length} indicados',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Opções
          _ExportOption(
            icon: Icons.picture_as_pdf_rounded,
            iconColor: const Color(0xFFE53935),
            title: 'PDF / Imprimir',
            subtitle: 'Abre relatório formatado para imprimir ou salvar como PDF',
            onTap: () => _exportPdf(context),
          ),
          const SizedBox(height: 10),
          _ExportOption(
            icon: Icons.table_chart_rounded,
            iconColor: const Color(0xFF1B8A4A),
            title: 'Exportar CSV',
            subtitle: 'Baixa planilha compatível com Excel, Sheets',
            onTap: () => _exportCsv(context),
          ),
          const SizedBox(height: 10),
          _ExportOption(
            icon: Icons.copy_rounded,
            iconColor: const Color(0xFF2563EB),
            title: 'Copiar Lista',
            subtitle: 'Copia texto formatado para colar em qualquer lugar',
            onTap: () => _copiarTexto(context),
          ),
        ],
      ),
    );
  }
}



// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares
// ─────────────────────────────────────────────────────────────────────────────

class _ExportOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ExportOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: iconColor.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.textHint, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Chip de período ────────────────────────────────────────────────────────
class _PeriodoChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const _PeriodoChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.cardBorder,
          ),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 13,
                  color: selected ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Modelo de nível ────────────────────────────────────────────────────────
class _Nivel {
  final String nome;
  final int min;
  final int max;
  final Color cor;
  final IconData icone;

  const _Nivel(this.nome, this.min, this.max, this.cor, this.icone);
}

// ── Bolha de estatística ───────────────────────────────────────────────────
class _StatBubble extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatBubble(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18)),
            Text(label,
                style: const TextStyle(
                    color: Colors.white60, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ── Chip de nível ──────────────────────────────────────────────────────────
class _NivelChip extends StatelessWidget {
  final _Nivel nivel;
  final bool isAtual;
  final bool atingido;

  const _NivelChip(
      {required this.nivel, required this.isAtual, required this.atingido});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: isAtual
            ? nivel.cor.withValues(alpha: 0.15)
            : atingido
                ? nivel.cor.withValues(alpha: 0.06)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAtual
              ? nivel.cor
              : atingido
                  ? nivel.cor.withValues(alpha: 0.3)
                  : AppColors.cardBorder,
          width: isAtual ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Icon(nivel.icone,
              color: atingido ? nivel.cor : AppColors.textHint, size: 20),
          const SizedBox(height: 4),
          Text(nivel.nome,
              style: TextStyle(
                color: atingido ? nivel.cor : AppColors.textHint,
                fontSize: 10,
                fontWeight: isAtual ? FontWeight.w800 : FontWeight.w500,
              )),
          Text('${nivel.min}+',
              style:
                  const TextStyle(color: AppColors.textHint, fontSize: 9)),
        ],
      ),
    );
  }
}

// ── Tile de referral ───────────────────────────────────────────────────────
class _ReferralTile extends StatelessWidget {
  final Map<String, dynamic> referral;
  final NumberFormat fmt;
  final DateFormat fmtDate;

  const _ReferralTile(
      {required this.referral, required this.fmt, required this.fmtDate});

  @override
  Widget build(BuildContext context) {
    final status = referral['status']?.toString() ?? '';
    final isAtivo = status == 'ATIVO';
    final comissao = (referral['comissao_mensal'] as num?)?.toDouble() ?? 0;
    final referred = referral['referred_id']?.toString() ?? 'Usuário';
    final nomeDesconhecido = referral['nome_desconhecido'] == true;
    final productNome = referral['product_nome']?.toString() ?? '';
    final dt = referral['data_inicio'] as DateTime?;

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
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: (isAtivo ? AppColors.primary : AppColors.textHint)
                .withValues(alpha: 0.1),
            child: Text(
              nomeDesconhecido
                  ? '?'
                  : (referred.isNotEmpty ? referred[0].toUpperCase() : 'U'),
              style: TextStyle(
                  color: isAtivo ? AppColors.primary : AppColors.textHint,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nomeDesconhecido ? 'Comprador' : referred,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: nomeDesconhecido
                          ? AppColors.textHint
                          : AppColors.textPrimary),
                ),
                if (productNome.isNotEmpty)
                  Text(
                    productNome,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontStyle: FontStyle.italic),
                    overflow: TextOverflow.ellipsis,
                  ),
                if (dt != null)
                  Text(
                    'Desde ${fmtDate.format(dt)}',
                    style: const TextStyle(
                        color: AppColors.textHint, fontSize: 11),
                  ),
              ],
            ),
          ),

          // Status + comissão
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${fmt.format(comissao)}/mês',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: isAtivo ? AppColors.success : AppColors.textHint),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isAtivo ? AppColors.success : AppColors.error)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isAtivo ? 'Ativo' : 'Pendente',
                  style: TextStyle(
                    color: isAtivo ? AppColors.success : AppColors.error,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
