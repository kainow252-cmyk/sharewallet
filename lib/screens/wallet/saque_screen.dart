import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/wallet_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';

class SaqueScreen extends StatefulWidget {
  const SaqueScreen({super.key});

  @override
  State<SaqueScreen> createState() => _SaqueScreenState();
}

class _SaqueScreenState extends State<SaqueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _valorController = TextEditingController();
  final _pixKeyController = TextEditingController();
  String _pixKeyType = 'CPF';
  bool _isLoading = false;

  final List<Map<String, dynamic>> _pixTypes = [
    {'value': 'CPF', 'label': 'CPF', 'icon': Icons.badge_rounded},
    {'value': 'EMAIL', 'label': 'E-mail', 'icon': Icons.email_outlined},
    {'value': 'PHONE', 'label': 'Telefone', 'icon': Icons.phone_rounded},
    {'value': 'ALEATORIA', 'label': 'Chave Aleatória', 'icon': Icons.vpn_key_rounded},
  ];

  @override
  void dispose() {
    _valorController.dispose();
    _pixKeyController.dispose();
    super.dispose();
  }

  Future<void> _solicitarSaque() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthService>();
    final wallet = context.read<WalletService>();
    final valor = double.tryParse(
          _valorController.text.replaceAll(',', '.'),
        ) ??
        0;

    if (valor < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Valor mínimo para saque é R\$ 10,00'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (valor > (auth.currentUser?.saldo ?? 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saldo insuficiente'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await wallet.solicitarSaque(
      valor: valor,
      pixKey: _pixKeyController.text.trim(),
      pixKeyType: _pixKeyType,
      saldoAtual: auth.currentUser?.saldo ?? 0,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      auth.updateSaldo((auth.currentUser?.saldo ?? 0) - valor);
      _showSuccessDialog(valor);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showSuccessDialog(double valor) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pix_rounded,
                  color: AppColors.success, size: 56),
            ),
            const SizedBox(height: 16),
            const Text('Saque Solicitado!',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}',
              style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Seu PIX será processado em até 1 hora útil via Woovi.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.schedule_rounded,
                      color: AppColors.textSecondary, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Processamento: até 1 hora útil',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PrimaryButton(
            label: 'Voltar ao Painel',
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final saldo = auth.currentUser?.saldo ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Solicitar Saque PIX')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card de saldo
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF083D29), Color(0xFF0D5C3D)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Saldo Disponível',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 6),
                      Text(
                        'R\$ ${saldo.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.pix_rounded,
                              color: AppColors.goldLight, size: 16),
                          const SizedBox(width: 6),
                          const Text('PIX via Woovi/OpenPix',
                              style: TextStyle(
                                  color: AppColors.goldLight, fontSize: 12)),
                          const Spacer(),
                          const Text('Mín: R\$ 10,00',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Valor do saque
                const Text('Valor do Saque',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _valorController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary),
                  decoration: const InputDecoration(
                    prefixText: 'R\$ ',
                    prefixStyle: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary),
                    hintText: '0,00',
                    hintStyle: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w300,
                        color: AppColors.textHint),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Informe o valor';
                    final val =
                        double.tryParse(v.replaceAll(',', '.')) ?? 0;
                    if (val < 10) return 'Mínimo R\$ 10,00';
                    if (val > saldo) return 'Saldo insuficiente';
                    return null;
                  },
                ),

                // Atalhos de valor
                const SizedBox(height: 12),
                Row(
                  children: [50.0, 100.0, 200.0].map((v) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          if (v <= saldo) {
                            _valorController.text =
                                v.toStringAsFixed(2).replaceAll('.', ',');
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Text(
                            'R\$ ${v.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                // Tipo de chave PIX
                const Text('Tipo de Chave PIX',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 3.5,
                  children: _pixTypes.map((t) {
                    final isSelected = _pixKeyType == t['value'];
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _pixKeyType = t['value']),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.08)
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.cardBorder,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(t['icon'] as IconData,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textHint,
                                size: 18),
                            const SizedBox(width: 8),
                            Text(t['label'] as String,
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _pixKeyController,
                  decoration: InputDecoration(
                    labelText: 'Sua chave PIX ($_pixKeyType)',
                    prefixIcon: const Icon(Icons.pix_rounded,
                        color: AppColors.primary),
                    hintText: _pixKeyType == 'CPF'
                        ? '000.000.000-00'
                        : _pixKeyType == 'EMAIL'
                            ? 'seu@email.com'
                            : _pixKeyType == 'PHONE'
                                ? '(11) 99999-9999'
                                : 'Chave aleatória',
                  ),
                  validator: (v) =>
                      v!.isEmpty ? 'Informe sua chave PIX' : null,
                ),

                const SizedBox(height: 24),

                // Aviso
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.3)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: AppColors.info, size: 18),
                          SizedBox(width: 8),
                          Text('Informações do Saque',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.info,
                                  fontSize: 14)),
                        ],
                      ),
                      SizedBox(height: 10),
                      _InfoRow(text: 'Processado via Woovi/OpenPix'),
                      _InfoRow(text: 'PIX creditado em até 1 hora útil'),
                      _InfoRow(text: 'Valor mínimo: R\$ 10,00'),
                      _InfoRow(text: 'Sem taxas para o afiliado'),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                PrimaryButton(
                  label: 'Solicitar Saque via PIX',
                  onPressed: _solicitarSaque,
                  isLoading: _isLoading,
                  icon: Icons.pix_rounded,
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String text;
  const _InfoRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_rounded, color: AppColors.success, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
