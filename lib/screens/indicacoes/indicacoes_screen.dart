import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/cf_api_service.dart';
import '../../theme/app_theme.dart';

class IndicacoesScreen extends StatefulWidget {
  const IndicacoesScreen({super.key});

  @override
  State<IndicacoesScreen> createState() => _IndicacoesScreenState();
}

class _IndicacoesScreenState extends State<IndicacoesScreen> {
  bool _loading = true;
  int _totalAssinaturas = 0;
  double _comissaoMensal = 0;
  List<Map<String, dynamic>> _referrals = [];
  final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  // Sistema de níveis
  static const _niveis = [
    _Nivel('Bronze', 0, 20, Color(0xFFCD7F32), Icons.military_tech_rounded),
    _Nivel('Prata', 21, 100, Color(0xFFBDBDBD), Icons.military_tech_rounded),
    _Nivel('Ouro', 101, 500, Color(0xFFFFD740), Icons.military_tech_rounded),
    _Nivel('Diamante', 501, 999999, Color(0xFF00BCD4), Icons.diamond_rounded),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReferrals());
  }

  Future<void> _loadReferrals() async {
    // Cache: não recarrega se já tem dados
    if (_referrals.isNotEmpty) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() {
          _referrals = [];
          _totalAssinaturas = 0;
          _comissaoMensal = 0;
        });
        return;
      }

      // Busca assinaturas pelo affiliate code via D1
      // O "indicados" mapeamos das assinaturas do afiliado
      final affiliateData = await CfApiService.getAffiliateByEmail(
          FirebaseAuth.instance.currentUser?.email ?? '');
      if (affiliateData == null) {
        setState(() {
          _referrals = [];
          _totalAssinaturas = 0;
          _comissaoMensal = 0;
        });
        return;
      }

      final code = affiliateData['affiliate_code']?.toString() ?? '';
      if (code.isEmpty) {
        setState(() {
          _referrals = [];
          _totalAssinaturas = 0;
          _comissaoMensal = 0;
        });
        return;
      }

      final subs = await CfApiService.getSubscriptionsByAffiliate(code);

      final ativos = subs.where((s) =>
          (s['status']?.toString() ?? 'ativa') == 'ativa').toList();
      // CORREÇÃO: 'comissao' no D1 já é o valor em R$ (ex: 0.50),
      // NÃO é percentual. Não multiplicar por 'valor'.
      final comissao = ativos.fold<double>(
          0,
          (s, r) => s + ((r['comissao'] as num?)?.toDouble() ?? 0));

      // Adapta ao formato esperado pelo widget _ReferralTile
      final list = subs.map((s) => {
            'id': s['id'],
            'referred_id': s['affiliate_nome'] ?? 'Cliente',
            'status': (s['status']?.toString() ?? 'ativa') == 'ativa'
                ? 'ATIVO'
                : 'INATIVO',
            // CORREÇÃO: comissao no D1 já é R$ — usar diretamente
            'comissao_mensal': (s['comissao'] as num?)?.toDouble() ?? 0,
            'meses_ativos': 1,
          }).toList();

      setState(() {
        _referrals = list.cast<Map<String, dynamic>>();
        _totalAssinaturas = ativos.length;
        _comissaoMensal = comissao;
      });
    } catch (e) {
      debugPrint('[IndicacoesScreen] Erro: $e');
      setState(() {
        _referrals = [];
        _totalAssinaturas = 0;
        _comissaoMensal = 0;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final nivel = _nivelAtual;
    final proximo = _proximoNivel;
    final progressoNivel = proximo != null
        ? ((_totalAssinaturas - nivel.min) /
                (proximo.min - nivel.min))
            .clamp(0.0, 1.0)
        : 1.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadReferrals,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            // ── AppBar ───────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              automaticallyImplyLeading: false,
              backgroundColor: AppColors.primary,
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
                          const Text('Minhas Indicações',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800)),
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

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Card de nível atual ──────────────────────────────
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
                        border: Border.all(
                            color: nivel.cor.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(nivel.icone,
                                  color: nivel.cor, size: 32),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Seu nível atual',
                                      style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12)),
                                  Text(
                                    nivel.nome,
                                    style: TextStyle(
                                      color: nivel.cor,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (proximo != null) ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${_totalAssinaturas} assinaturas',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12),
                                ),
                                Text(
                                  'Próximo: ${proximo.nome} (${proximo.min})',
                                  style: TextStyle(
                                      color: proximo.cor, fontSize: 12),
                                ),
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
                                  color: AppColors.textHint, fontSize: 11),
                            ),
                          ] else ...[
                            const SizedBox(height: 8),
                            const Text('🏆 Nível máximo atingido!',
                                style: TextStyle(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Todos os níveis ──────────────────────────────────
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

                    // ── Lista de indicados ───────────────────────────────
                    Row(
                      children: [
                        const Text('Meus indicados',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                color: AppColors.textPrimary)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_referrals.length}',
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_loading)
                      const Center(child: CircularProgressIndicator())
                    else if (_referrals.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.person_add_outlined,
                                color: AppColors.textHint, size: 40),
                            SizedBox(height: 12),
                            Text('Você ainda não tem indicados',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500)),
                            Text('Compartilhe seu link e comece a ganhar!',
                                style: TextStyle(
                                    color: AppColors.textHint, fontSize: 12)),
                          ],
                        ),
                      )
                    else
                      ..._referrals.take(20).map((r) => _ReferralTile(
                            referral: r,
                            fmt: _fmt,
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

// ── Modelo de nível ───────────────────────────────────────────────────────────
class _Nivel {
  final String nome;
  final int min;
  final int max;
  final Color cor;
  final IconData icone;

  const _Nivel(this.nome, this.min, this.max, this.cor, this.icone);
}

// ── Widget: Bolha de estatística ──────────────────────────────────────────────
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
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
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
                style:
                    const TextStyle(color: Colors.white60, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ── Widget: Chip de nível ─────────────────────────────────────────────────────
class _NivelChip extends StatelessWidget {
  final _Nivel nivel;
  final bool isAtual;
  final bool atingido;

  const _NivelChip(
      {required this.nivel,
      required this.isAtual,
      required this.atingido});

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
              color: atingido ? nivel.cor : AppColors.textHint,
              size: 20),
          const SizedBox(height: 4),
          Text(
            nivel.nome,
            style: TextStyle(
              color: atingido ? nivel.cor : AppColors.textHint,
              fontSize: 10,
              fontWeight:
                  isAtual ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
          Text(
            '${nivel.min}+',
            style: const TextStyle(
                color: AppColors.textHint, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

// ── Widget: Tile de referral ──────────────────────────────────────────────────
class _ReferralTile extends StatelessWidget {
  final Map<String, dynamic> referral;
  final NumberFormat fmt;

  const _ReferralTile({required this.referral, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final status = referral['status']?.toString() ?? '';
    final isAtivo = status == 'ATIVO';
    final comissao = (referral['comissao_mensal'] as num?)?.toDouble() ?? 0;
    final meses = (referral['meses_ativos'] as num?)?.toInt() ?? 0;
    final referred = referral['referred_id']?.toString() ?? 'Usuário';

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
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              referred.isNotEmpty ? referred[0].toUpperCase() : 'U',
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(referred,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textPrimary)),
                Text('$meses ${ meses == 1 ? 'mês' : 'meses'} ativo',
                    style: const TextStyle(
                        color: AppColors.textHint, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${fmt.format(comissao)}/mês',
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: AppColors.success),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isAtivo ? AppColors.success : AppColors.error)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isAtivo ? 'Ativo' : 'Inativo',
                  style: TextStyle(
                    color:
                        isAtivo ? AppColors.success : AppColors.error,
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
