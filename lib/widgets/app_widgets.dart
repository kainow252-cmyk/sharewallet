import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

// ─── LOGO / MARCA ────────────────────────────────────────────
class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final Color? color;

  const AppLogo({super.key, this.size = 40, this.showText = true, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color ?? AppColors.gold,
            borderRadius: BorderRadius.circular(size * 0.25),
          ),
          child: Icon(
            Icons.account_balance_wallet_rounded,
            color: Colors.white,
            size: size * 0.6,
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Share',
                style: TextStyle(
                  color: color ?? Colors.white,
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Wallet',
                style: TextStyle(
                  color: (color ?? Colors.white).withValues(alpha: 0.8),
                  fontSize: size * 0.32,
                  fontWeight: FontWeight.w400,
                  height: 1.0,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─── BOTÃO PRIMÁRIO ───────────────────────────────────────────
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? color;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
                  Text(label,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                ],
              ),
      ),
    );
  }
}

// ─── CARD DE SALDO ───────────────────────────────────────────
class BalanceCard extends StatelessWidget {
  final double saldo;
  final bool isVisible;
  final VoidCallback onToggleVisibility;

  const BalanceCard({
    super.key,
    required this.saldo,
    required this.isVisible,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF083D29), Color(0xFF0D5C3D), Color(0xFF1A7A52)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              const Text('Saldo Disponível',
                  style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 0.5)),
              const Spacer(),
              GestureDetector(
                onTap: onToggleVisibility,
                child: Icon(
                  isVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          isVisible
              ? Text(
                  'R\$ ${saldo.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                )
              : Container(
                  height: 36,
                  width: 140,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.pix_rounded, color: AppColors.goldLight, size: 16),
                const SizedBox(width: 6),
                const Text('PIX via Woovi',
                    style: TextStyle(color: AppColors.goldLight, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── CARD DE ESTATÍSTICAS ───────────────────────────────────
class StatsRow extends StatelessWidget {
  final int indicados;
  final int vendas;
  final double comissoes;

  const StatsRow({
    super.key,
    required this.indicados,
    required this.vendas,
    required this.comissoes,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _StatCard(
            icon: Icons.people_rounded,
            label: 'Indicados',
            value: indicados.toString(),
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          _StatCard(
            icon: Icons.shopping_bag_rounded,
            label: 'Vendas',
            value: vendas.toString(),
            color: AppColors.gold,
          ),
          const SizedBox(width: 10),
          _StatCard(
            icon: Icons.trending_up_rounded,
            label: 'Comissões',
            value: 'R\$${comissoes.toStringAsFixed(0)}',
            color: AppColors.success,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── LINK DE AFILIADO ─────────────────────────────────────────
class AffiliateLinkCard extends StatelessWidget {
  final String link;
  final String code;

  const AffiliateLinkCard({super.key, required this.link, required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.link_rounded, color: AppColors.gold, size: 18),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Meu Link de Afiliado',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary)),
                  Text('Compartilhe e ganhe comissões',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    link,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: 'https://$link'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Link copiado! ✅'),
                        backgroundColor: AppColors.success,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.copy_rounded,
                        color: AppColors.primary, size: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionBtn(
                  icon: Icons.share_rounded,
                  label: 'Compartilhar',
                  color: AppColors.primary,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Abrindo compartilhamento...')),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionBtn(
                  icon: Icons.qr_code_rounded,
                  label: 'QR Code',
                  color: AppColors.gold,
                  onTap: () => _showQrCode(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showQrCode(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('QR Code do Afiliado',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_2_rounded, size: 120, color: AppColors.primary),
                    Text('QR Code', style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Código: $code',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.primary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─── SEÇÃO TÍTULO ─────────────────────────────────────────────
class SectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionTitle({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── LOADING SHIMMER ─────────────────────────────────────────
class LoadingShimmer extends StatelessWidget {
  final double height;
  final double? width;
  final double borderRadius;

  const LoadingShimmer({
    super.key,
    this.height = 20,
    this.width,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.cardBorder,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

// ─── STATUS BADGE ─────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case 'COMPLETED':
      case 'APPROVED':
        color = AppColors.success;
        label = status == 'COMPLETED' ? 'Pago' : 'Aprovado';
        icon = Icons.check_circle_rounded;
        break;
      case 'PENDING':
        color = AppColors.warning;
        label = 'Aguardando';
        icon = Icons.schedule_rounded;
        break;
      case 'REJECTED':
      case 'CANCELLED':
        color = AppColors.error;
        label = status == 'REJECTED' ? 'Rejeitado' : 'Cancelado';
        icon = Icons.cancel_rounded;
        break;
      default:
        color = AppColors.textHint;
        label = status;
        icon = Icons.info_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
