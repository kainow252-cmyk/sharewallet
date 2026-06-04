import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _ranking = [];
  final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRanking());
  }

  Future<void> _loadRanking() async {
    setState(() => _loading = true);
    try {
      final snap =
          await FirestoreService.collection('ranking')?.get();
      if (snap != null && snap.docs.isNotEmpty) {
        final list = snap.docs.map((d) {
          final data = Map<String, dynamic>.from(d.data());
          data['id'] = d.id;
          return data;
        }).toList();
        list.sort((a, b) => FirestoreService.toInt(a['position'])
            .compareTo(FirestoreService.toInt(b['position'])));
        setState(() => _ranking = list);
      }
    } catch (e) {
      debugPrint('[RankingScreen] Erro: $e');
      // Dados demo
      setState(() {
        _ranking = [
          {'nome': 'João Silva', 'assinaturas': 145, 'comissao_total': 1740.0, 'nivel': 'Diamante', 'position': 1},
          {'nome': 'Carlos Melo', 'assinaturas': 120, 'comissao_total': 1440.0, 'nivel': 'Ouro', 'position': 2},
          {'nome': 'Pedro Costa', 'assinaturas': 98, 'comissao_total': 1176.0, 'nivel': 'Ouro', 'position': 3},
          {'nome': 'Ana Lima', 'assinaturas': 87, 'comissao_total': 1044.0, 'nivel': 'Ouro', 'position': 4},
          {'nome': 'Lucas Souza', 'assinaturas': 72, 'comissao_total': 864.0, 'nivel': 'Prata', 'position': 5},
          {'nome': 'Mariana Reis', 'assinaturas': 65, 'comissao_total': 780.0, 'nivel': 'Prata', 'position': 6},
          {'nome': 'Felipe Nunes', 'assinaturas': 54, 'comissao_total': 648.0, 'nivel': 'Prata', 'position': 7},
          {'nome': 'Juliana Pinto', 'assinaturas': 41, 'comissao_total': 492.0, 'nivel': 'Prata', 'position': 8},
          {'nome': 'Roberto Alves', 'assinaturas': 33, 'comissao_total': 396.0, 'nivel': 'Prata', 'position': 9},
          {'nome': 'Camila Borges', 'assinaturas': 27, 'comissao_total': 324.0, 'nivel': 'Bronze', 'position': 10},
        ];
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Color _nivelColor(String nivel) {
    switch (nivel) {
      case 'Diamante': return const Color(0xFF00BCD4);
      case 'Ouro': return const Color(0xFFFFD740);
      case 'Prata': return const Color(0xFFBDBDBD);
      default: return const Color(0xFFCD7F32);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top3 = _ranking.take(3).toList();
    final resto = _ranking.skip(3).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadRanking,
        color: const Color(0xFFFFD740),
        child: CustomScrollView(
          slivers: [
            // ── AppBar ─────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 120,
              pinned: true,
              automaticallyImplyLeading: false,
              backgroundColor: const Color(0xFF0A1628),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0A1628), Color(0xFF1A237E)],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          const Icon(Icons.emoji_events_rounded,
                              color: Color(0xFFFFD740), size: 32),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Ranking',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800)),
                              Text('Top 10 Afiliados do Mês',
                                  style: TextStyle(
                                      color: Colors.white60, fontSize: 13)),
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
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(60),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),

                          // ── Pódio Top 3 ─────────────────────────────
                          if (top3.length >= 3) _Podium(top3: top3, fmt: _fmt),

                          const SizedBox(height: 24),

                          // ── Posições 4–10 ───────────────────────────
                          ...resto.asMap().entries.map((entry) {
                            final pos = entry.key + 4;
                            final item = entry.value;
                            return _RankingTile(
                              position: pos,
                              nome: FirestoreService.toStr(item['nome']),
                              assinaturas:
                                  FirestoreService.toInt(item['assinaturas']),
                              comissaoTotal: FirestoreService.toDouble(
                                  item['comissao_total']),
                              nivel:
                                  FirestoreService.toStr(item['nivel']),
                              nivelColor: _nivelColor(
                                  FirestoreService.toStr(item['nivel'])),
                              fmt: _fmt,
                            );
                          }),

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

// ── Pódio ─────────────────────────────────────────────────────────────────────
class _Podium extends StatelessWidget {
  final List<Map<String, dynamic>> top3;
  final NumberFormat fmt;

  const _Podium({required this.top3, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A1628), Color(0xFF1A237E)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text('🏆 Top 3 do Mês',
              style: TextStyle(
                  color: Color(0xFFFFD740),
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 2º lugar
              Expanded(
                child: _PodiumItem(
                  position: 2,
                  nome: FirestoreService.toStr(top3[1]['nome']),
                  assinaturas: FirestoreService.toInt(top3[1]['assinaturas']),
                  height: 90,
                  medalColor: const Color(0xFFBDBDBD),
                  emoji: '🥈',
                ),
              ),
              // 1º lugar (maior)
              Expanded(
                child: _PodiumItem(
                  position: 1,
                  nome: FirestoreService.toStr(top3[0]['nome']),
                  assinaturas: FirestoreService.toInt(top3[0]['assinaturas']),
                  height: 120,
                  medalColor: const Color(0xFFFFD740),
                  emoji: '🥇',
                ),
              ),
              // 3º lugar
              Expanded(
                child: _PodiumItem(
                  position: 3,
                  nome: FirestoreService.toStr(top3[2]['nome']),
                  assinaturas: FirestoreService.toInt(top3[2]['assinaturas']),
                  height: 70,
                  medalColor: const Color(0xFFCD7F32),
                  emoji: '🥉',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PodiumItem extends StatelessWidget {
  final int position;
  final String nome;
  final int assinaturas;
  final double height;
  final Color medalColor;
  final String emoji;

  const _PodiumItem({
    required this.position,
    required this.nome,
    required this.assinaturas,
    required this.height,
    required this.medalColor,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    final firstName = nome.split(' ').first;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          firstName,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
        ),
        Text(
          '$assinaturas ass.',
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
        const SizedBox(height: 8),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: medalColor.withValues(alpha: 0.2),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(
                color: medalColor.withValues(alpha: 0.5), width: 1.5),
          ),
          child: Center(
            child: Text(
              '$position°',
              style: TextStyle(
                color: medalColor,
                fontWeight: FontWeight.w900,
                fontSize: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tile de ranking (pos 4–10) ────────────────────────────────────────────────
class _RankingTile extends StatelessWidget {
  final int position;
  final String nome;
  final int assinaturas;
  final double comissaoTotal;
  final String nivel;
  final Color nivelColor;
  final NumberFormat fmt;

  const _RankingTile({
    required this.position,
    required this.nome,
    required this.assinaturas,
    required this.comissaoTotal,
    required this.nivel,
    required this.nivelColor,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          // Posição
          SizedBox(
            width: 32,
            child: Text(
              '$position°',
              style: const TextStyle(
                  color: AppColors.textHint,
                  fontWeight: FontWeight.w700,
                  fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: nivelColor.withValues(alpha: 0.15),
            child: Text(
              nome.isNotEmpty ? nome[0].toUpperCase() : '?',
              style: TextStyle(
                  color: nivelColor, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          // Nome e nível
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textPrimary)),
                Row(
                  children: [
                    Icon(Icons.military_tech_rounded,
                        color: nivelColor, size: 13),
                    const SizedBox(width: 3),
                    Text(nivel,
                        style: TextStyle(
                            color: nivelColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          // Assinaturas
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$assinaturas',
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: AppColors.textPrimary),
              ),
              const Text('assinaturas',
                  style: TextStyle(
                      color: AppColors.textHint, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}
