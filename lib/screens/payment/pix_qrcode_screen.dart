import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/woovi_service.dart';
import '../../theme/app_theme.dart';

/// Tela exibida após criar uma cobrança PIX.
/// Mostra o QR Code + copia-e-cola + countdown de expiração.
/// Faz polling a cada 3s para detectar o pagamento automaticamente.
class PixQrCodeScreen extends StatefulWidget {
  final ChargeResult charge;

  const PixQrCodeScreen({super.key, required this.charge});

  @override
  State<PixQrCodeScreen> createState() => _PixQrCodeScreenState();
}

class _PixQrCodeScreenState extends State<PixQrCodeScreen>
    with TickerProviderStateMixin {
  Timer? _pollingTimer;
  Timer? _countdownTimer;
  String _status = 'PENDING';
  int _secondsLeft = 3600;
  bool _paid = false;

  late AnimationController _successController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Calcular tempo restante
    final diff = widget.charge.expiresAtDate.difference(DateTime.now());
    _secondsLeft = diff.inSeconds.clamp(0, 3600);

    // Animação de sucesso
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Animação de pulso no QR Code (aguardando pagamento)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Iniciar polling e countdown
    _startPolling();
    _startCountdown();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    _successController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Polling de status ─────────────────────────────────────────────────────

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_paid || _secondsLeft <= 0) {
        _pollingTimer?.cancel();
        return;
      }

      final status = await WooviService.getSaleStatus(widget.charge.saleId);
      if (mounted && status != _status) {
        setState(() => _status = status);

        if (status == 'PAID') {
          _onPaymentConfirmed();
        } else if (status == 'EXPIRED') {
          _pollingTimer?.cancel();
        }
      }
    });
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) _secondsLeft--;
      });
    });
  }

  void _onPaymentConfirmed() {
    _paid = true;
    _pollingTimer?.cancel();
    _pulseController.stop();
    _successController.forward();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PaymentSuccessDialog(
        commissionValue: widget.charge.commissionInReais,
        productName: widget.charge.productName,
        onClose: () {
          Navigator.of(context).pop(); // fecha dialog
          Navigator.of(context).pop(); // volta para tela anterior
        },
      ),
    );
  }

  // ── Formatar tempo restante ───────────────────────────────────────────────

  String get _timeLeft {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pagar com PIX'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => _confirmClose(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // ── Produto + Valor ─────────────────────────────────────────
              _ProductHeader(charge: widget.charge),
              const SizedBox(height: 24),

              // ── QR Code ─────────────────────────────────────────────────
              if (_secondsLeft > 0 && !_paid)
                _QrCodeCard(
                  brCode: widget.charge.brCode,
                  pulseAnimation: _pulseAnimation,
                )
              else if (_secondsLeft <= 0)
                _ExpiredCard()
              else
                _PaidCard(),

              const SizedBox(height: 20),

              // ── Countdown ───────────────────────────────────────────────
              if (_secondsLeft > 0 && !_paid)
                _CountdownBar(
                  timeLeft: _timeLeft,
                  secondsLeft: _secondsLeft,
                ),

              const SizedBox(height: 20),

              // ── Copia-e-cola ─────────────────────────────────────────────
              if (!_paid && widget.charge.brCode.isNotEmpty)
                _CopyPasteSection(brCode: widget.charge.brCode),

              const SizedBox(height: 20),

              // ── Comissão a receber ───────────────────────────────────────
              _CommissionPreview(charge: widget.charge),

              const SizedBox(height: 16),

              // ── Status indicator ─────────────────────────────────────────
              _StatusIndicator(status: _status),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmClose() {
    if (_paid) {
      Navigator.of(context).pop();
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancelar pagamento?'),
        content: const Text(
            'O link de pagamento continuará ativo por mais tempo. Deseja voltar assim mesmo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Não'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // fecha dialog
              Navigator.pop(context); // fecha tela
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sim, voltar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─── Widgets internos ─────────────────────────────────────────────────────────

class _ProductHeader extends StatelessWidget {
  final ChargeResult charge;
  const _ProductHeader({required this.charge});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.greenGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.pix_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  charge.productName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'R\$ ${charge.totalValueInReais.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 28),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QrCodeCard extends StatelessWidget {
  final String brCode;
  final Animation<double> pulseAnimation;

  const _QrCodeCard({required this.brCode, required this.pulseAnimation});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Escaneie o QR Code',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Abra seu banco e aponte para o código',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          ScaleTransition(
            scale: pulseAnimation,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 2),
              ),
              child: brCode.isNotEmpty
                  ? QrImageView(
                      data: brCode,
                      version: QrVersions.auto,
                      size: 220,
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                    )
                  : const SizedBox(
                      width: 220,
                      height: 220,
                      child: Center(child: CircularProgressIndicator()),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownBar extends StatelessWidget {
  final String timeLeft;
  final int secondsLeft;

  const _CountdownBar({required this.timeLeft, required this.secondsLeft});

  @override
  Widget build(BuildContext context) {
    final progress = secondsLeft / 3600;
    final isUrgent = secondsLeft < 300; // últimos 5 min

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUrgent
            ? AppColors.error.withValues(alpha: 0.05)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUrgent
              ? AppColors.error.withValues(alpha: 0.3)
              : AppColors.cardBorder,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.timer_rounded,
                size: 16,
                color: isUrgent ? AppColors.error : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Expira em $timeLeft',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isUrgent ? AppColors.error : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation(
                isUrgent ? AppColors.error : AppColors.primary,
              ),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyPasteSection extends StatelessWidget {
  final String brCode;
  const _CopyPasteSection({required this.brCode});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PIX Copia e Cola',
          style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${brCode.substring(0, brCode.length.clamp(0, 40))}...',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: brCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Código PIX copiado! ✅'),
                      backgroundColor: AppColors.success,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 14),
                label: const Text('Copiar',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommissionPreview extends StatelessWidget {
  final ChargeResult charge;
  const _CommissionPreview({required this.charge});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sua comissão ao pagar:',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(
                  'R\$ ${charge.commissionInReais.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.goldDark,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Aguardando',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final String status;
  const _StatusIndicator({required this.status});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (status == 'PENDING') ...[
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(width: 8),
          const Text('Aguardando pagamento...',
              style: TextStyle(fontSize: 12, color: AppColors.textHint)),
        ] else if (status == 'PAID') ...[
          const Icon(Icons.check_circle_rounded,
              color: AppColors.success, size: 16),
          const SizedBox(width: 6),
          const Text('Pagamento confirmado!',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.success,
                  fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }
}

class _ExpiredCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: const Column(
        children: [
          Icon(Icons.timer_off_rounded, size: 64, color: AppColors.error),
          SizedBox(height: 12),
          Text('QR Code Expirado',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppColors.textPrimary)),
          SizedBox(height: 6),
          Text('Volte e gere um novo link de pagamento',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _PaidCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: const Column(
        children: [
          Icon(Icons.check_circle_rounded, size: 64, color: AppColors.success),
          SizedBox(height: 12),
          Text('Pagamento Confirmado!',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppColors.success)),
        ],
      ),
    );
  }
}

class _PaymentSuccessDialog extends StatelessWidget {
  final double commissionValue;
  final String productName;
  final VoidCallback onClose;

  const _PaymentSuccessDialog({
    required this.commissionValue,
    required this.productName,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: EdgeInsets.zero,
      content: Container(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.greenGradient,
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.check_rounded, color: Colors.white, size: 44),
            ),
            const SizedBox(height: 20),
            const Text('PIX Recebido! 🎉',
                style:
                    TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
            const SizedBox(height: 8),
            Text(
              productName,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  const Text('💰 Comissão creditada',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    'R\$ ${commissionValue.toStringAsFixed(2).replaceAll('.', ',')}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 32),
                  ),
                  const Text('adicionado à sua carteira',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onClose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Ver minha carteira',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
