import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/wallet_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

/// Tela completa de Carteira ShareWallet — dados via Cloudflare D1
class CarteiraScreen extends StatefulWidget {
  const CarteiraScreen({super.key});

  @override
  State<CarteiraScreen> createState() => _CarteiraScreenState();
}

class _CarteiraScreenState extends State<CarteiraScreen> {
  final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  bool _saldoVisible = true;
  static const double _saqueMinimo = 100.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWallet());
  }

  Future<void> _loadWallet({bool forceRefresh = false}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await context.read<WalletService>().loadData(
          userId: uid,
          forceRefresh: forceRefresh,
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
        final saldo = wallet.saldoCarteira;
        final pendente = wallet.saldoPendente;
        final totalRecebido = wallet.totalRecebido;
        final transacoes = wallet.extratoCompleto;
        final metaPct = (saldo / _saqueMinimo).clamp(0.0, 1.0);
        final faltam = (_saqueMinimo - saldo).clamp(0.0, _saqueMinimo);
        final podesSacar = saldo >= _saqueMinimo;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: RefreshIndicator(
            onRefresh: () => _loadWallet(forceRefresh: true),
            color: const Color(0xFF00E5B4),
            child: CustomScrollView(
              slivers: [
                // ── AppBar ──────────────────────────────────────────────────
                SliverAppBar(
                  expandedHeight: 200,
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
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Minha Carteira',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    onPressed: () => setState(
                                        () => _saldoVisible = !_saldoVisible),
                                    icon: Icon(
                                      _saldoVisible
                                          ? Icons.visibility_rounded
                                          : Icons.visibility_off_rounded,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text('Saldo Disponível',
                                  style: TextStyle(
                                      color: Colors.white60, fontSize: 13)),
                              const SizedBox(height: 4),
                              wallet.isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                          color: Color(0xFF00E5B4),
                                          strokeWidth: 2),
                                    )
                                  : Text(
                                      _saldoVisible
                                          ? _fmt.format(saldo)
                                          : 'R\$ ••••••',
                                      style: const TextStyle(
                                        color: Color(0xFF00E5B4),
                                        fontSize: 34,
                                        fontWeight: FontWeight.w900,
                                      ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),

                        // ── Cards de saldo ──────────────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: _SaldoCard(
                                label: 'Saldo Pendente',
                                valor: _saldoVisible
                                    ? _fmt.format(pendente)
                                    : 'R\$ ••',
                                icon: Icons.hourglass_empty_rounded,
                                color: AppColors.warning,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SaldoCard(
                                label: 'Total Recebido',
                                valor: _saldoVisible
                                    ? _fmt.format(totalRecebido)
                                    : 'R\$ ••••',
                                icon: Icons.trending_up_rounded,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ── Card meta de saque ──────────────────────────────
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
                                  const Text(
                                    'Meta para saque',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${(metaPct * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
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
                                    : 'Faltam ${_fmt.format(faltam)} para atingir o mínimo de ${_fmt.format(_saqueMinimo)}',
                                style: TextStyle(
                                  color: podesSacar
                                      ? AppColors.success
                                      : AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Botão Solicitar Saque ────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _solicitarSaque,
                            icon: const Icon(Icons.pix_rounded, size: 20),
                            label: const Text('Solicitar Saque via PIX',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: podesSacar
                                  ? const Color(0xFF00E5B4)
                                  : AppColors.textHint,
                              foregroundColor: podesSacar
                                  ? const Color(0xFF0A1628)
                                  : Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),
                        Text(
                          'Mínimo: ${_fmt.format(_saqueMinimo)} • Processamento em até 24h',
                          style: const TextStyle(
                              color: AppColors.textHint, fontSize: 11),
                        ),

                        const SizedBox(height: 24),

                        // ── Histórico de transações ──────────────────────────
                        Row(
                          children: [
                            const Text(
                              'Histórico',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${transacoes.length} transações',
                              style: const TextStyle(
                                  color: AppColors.textHint, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (wallet.isLoading)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (transacoes.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.cardBorder),
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
                              .take(20)
                              .map((tx) => _TransacaoTile(tx: tx, fmt: _fmt)),

                        const SizedBox(height: 32),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          Text(label,
              style:
                  const TextStyle(color: AppColors.textHint, fontSize: 11)),
          const SizedBox(height: 2),
          Text(valor,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              )),
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
    final tipo = (tx['tipo'] as String? ?? 'comissao').toUpperCase();
    final valor = (tx['valor'] as num?)?.toDouble() ?? 0.0;
    final desc = tx['descricao'] as String? ?? 'Comissão';
    final date = tx['data'] as DateTime?;
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
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
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
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Valor
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

          // Tipo chave PIX
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

          // Chave PIX
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
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}
