import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/cf_api_service.dart';
import '../../theme/app_theme.dart';

/// Tela exibida após pagamento PIX confirmado.
/// Mostra detalhes do produto comprado, comissão creditada e envia e-mail.
class PaymentConfirmedScreen extends StatefulWidget {
  final String paymentId;
  final String productName;
  final String productDescricao;
  final double valor;
  final double comissao;
  final String affiliateCode;
  final String clienteNome;
  final String clienteEmail;
  final VoidCallback? onGoToWallet;

  const PaymentConfirmedScreen({
    super.key,
    required this.paymentId,
    required this.productName,
    required this.productDescricao,
    required this.valor,
    required this.comissao,
    required this.affiliateCode,
    required this.clienteNome,
    required this.clienteEmail,
    this.onGoToWallet,
  });

  @override
  State<PaymentConfirmedScreen> createState() => _PaymentConfirmedScreenState();
}

class _PaymentConfirmedScreenState extends State<PaymentConfirmedScreen>
    with TickerProviderStateMixin {
  late AnimationController _checkController;
  late AnimationController _cardController;
  late Animation<double> _checkScale;
  late Animation<double> _cardSlide;

  bool _emailSent = false;
  bool _emailLoading = true;

  @override
  void initState() {
    super.initState();

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _checkScale = CurvedAnimation(
      parent: _checkController,
      curve: Curves.elasticOut,
    );
    _cardSlide = CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOutCubic,
    );

    // Sequência de animações
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _checkController.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _cardController.forward();
    });

    // Enviar e-mail de confirmação
    _sendEmail();
  }

  @override
  void dispose() {
    _checkController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  Future<void> _sendEmail() async {
    if (widget.clienteEmail.isEmpty || !widget.clienteEmail.contains('@')) {
      setState(() => _emailLoading = false);
      return;
    }
    try {
      await CfApiService.sendConfirmationEmail(
        toEmail:          widget.clienteEmail,
        toName:           widget.clienteNome,
        productName:      widget.productName,
        productDescricao: widget.productDescricao,
        valor:            widget.valor,
        comissao:         widget.comissao,
        affiliateCode:    widget.affiliateCode,
        paymentId:        widget.paymentId,
      );
      if (mounted) setState(() { _emailSent = true; _emailLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _emailLoading = false);
    }
  }

  String _fmtValor(double v) =>
      'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),

              // ── Ícone de sucesso ──────────────────────────────────────────
              ScaleTransition(
                scale: _checkScale,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: AppColors.greenGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 54,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Pagamento Confirmado!',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Sua assinatura está ativa',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 28),

              // ── Card produto comprado ─────────────────────────────────────
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(_cardSlide),
                child: FadeTransition(
                  opacity: _cardSlide,
                  child: _buildProductCard(),
                ),
              ),

              const SizedBox(height: 16),

              // ── Card comissão creditada ───────────────────────────────────
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.4),
                  end: Offset.zero,
                ).animate(_cardSlide),
                child: FadeTransition(
                  opacity: _cardSlide,
                  child: _buildCommissionCard(),
                ),
              ),

              const SizedBox(height: 16),

              // ── Card detalhes pagamento ───────────────────────────────────
              _buildPaymentDetailsCard(),

              const SizedBox(height: 16),

              // ── Status do e-mail ──────────────────────────────────────────
              if (widget.clienteEmail.isNotEmpty) _buildEmailStatus(),

              const SizedBox(height: 28),

              // ── Botões de ação ────────────────────────────────────────────
              _buildActions(),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Produto Contratado',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textHint,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.productName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '✅ ATIVO',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          if (widget.productDescricao.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Text(
              widget.productDescricao,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              _detailChip(
                Icons.pix_rounded,
                'Pix Recorrente',
                const Color(0xFF32BCAD),
              ),
              const SizedBox(width: 8),
              _detailChip(
                Icons.calendar_month_rounded,
                'Renovação em 30 dias',
                AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Valor mensal',
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
              Text(
                '${_fmtValor(widget.valor)}/mês',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommissionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.greenGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Comissão Creditada na Carteira',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _fmtValor(widget.comissao),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'por mês enquanto a assinatura estiver ativa',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          _detailRow(Icons.receipt_long_rounded, 'Nº Pagamento',
              widget.paymentId.length > 14
                  ? '...${widget.paymentId.substring(widget.paymentId.length - 12)}'
                  : widget.paymentId),
          const Divider(height: 20),
          _detailRow(Icons.person_rounded, 'Cliente',
              widget.clienteNome.isNotEmpty ? widget.clienteNome : '—'),
          const Divider(height: 20),
          _detailRow(Icons.tag_rounded, 'Código afiliado',
              widget.affiliateCode),
          const Divider(height: 20),
          _detailRow(Icons.payments_rounded, 'Valor pago',
              _fmtValor(widget.valor)),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textHint),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
              fontSize: 13, color: AppColors.textSecondary),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailStatus() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: _emailLoading
          ? Container(
              key: const ValueKey('loading'),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Enviando confirmação para ${widget.clienteEmail}...',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          : Container(
              key: const ValueKey('done'),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _emailSent
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _emailSent
                      ? AppColors.success.withValues(alpha: 0.3)
                      : AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _emailSent
                        ? Icons.mark_email_read_rounded
                        : Icons.email_outlined,
                    size: 16,
                    color: _emailSent ? AppColors.success : AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _emailSent
                          ? 'Confirmação enviada para ${widget.clienteEmail}'
                          : 'Não foi possível enviar o e-mail de confirmação',
                      style: TextStyle(
                        fontSize: 12,
                        color: _emailSent
                            ? AppColors.success
                            : AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        // Botão principal: Ver carteira
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () {
              if (widget.onGoToWallet != null) {
                widget.onGoToWallet!();
              } else {
                Navigator.of(context).popUntil((r) => r.isFirst);
              }
            },
            icon: const Icon(Icons.account_balance_wallet_rounded,
                size: 20),
            label: const Text(
              'Ver minha carteira',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 4,
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Botão secundário: compartilhar comprovante
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: _compartilharComprovante,
            icon: const Icon(Icons.share_rounded, size: 18),
            label: const Text(
              'Compartilhar comprovante',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  void _compartilharComprovante() {
    final texto = '''✅ Pagamento PIX Confirmado!

📦 Produto: ${widget.productName}
💰 Valor: ${_fmtValor(widget.valor)}/mês
💎 Comissão creditada: ${_fmtValor(widget.comissao)}/mês
🔑 Código afiliado: ${widget.affiliateCode}
🔖 Pagamento: ${widget.paymentId}

Assinatura ativa — renovação automática todo mês via Pix.
''';
    Clipboard.setData(ClipboardData(text: texto));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            '📋 Comprovante copiado! Cole para compartilhar.'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 3),
      ),
    );
  }
}
