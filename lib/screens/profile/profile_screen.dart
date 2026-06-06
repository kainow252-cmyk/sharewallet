import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.darkGreenGradient,
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor:
                                AppColors.gold.withValues(alpha: 0.3),
                            child: Text(
                              user?.primeiroNome.substring(0, 1) ?? 'A',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.gold,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.verified_rounded,
                                  color: Colors.white, size: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user?.nome ?? 'Afiliado',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.pix_rounded,
                              color: AppColors.goldLight, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            user?.affiliateCode ?? 'ABC123',
                            style: const TextStyle(
                                color: AppColors.goldLight,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 16),

                // Cards de info
                _InfoSection(
                  title: 'Minha Conta',
                  items: [
                    _InfoItem(
                      icon: Icons.person_rounded,
                      label: 'Nome',
                      value: user?.nome ?? '',
                    ),
                    _InfoItem(
                      icon: Icons.email_outlined,
                      label: 'E-mail',
                      value: user?.email ?? '',
                    ),
                    _InfoItem(
                      icon: Icons.phone_rounded,
                      label: 'Telefone',
                      value: user?.telefone ?? '',
                    ),
                    _InfoItem(
                      icon: Icons.badge_rounded,
                      label: 'CPF',
                      value: user?.cpf ?? '',
                      isProtected: true,
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Chave PIX para recebimento
                _InfoSection(
                  title: 'Recebimento PIX',
                  items: [
                    _InfoItem(
                      icon: Icons.pix_rounded,
                      label: 'Chave PIX',
                      value: user?.email ?? 'Não configurada',
                    ),
                    _InfoItem(
                      icon: Icons.account_balance_rounded,
                      label: 'Status',
                      value: 'Ativa ✅',
                      valueColor: AppColors.success,
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Código de Afiliado
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.badge_rounded,
                                color: AppColors.primary, size: 20),
                            SizedBox(width: 8),
                            Text('Meu Código de Afiliado',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: AppColors.textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Compartilhe produtos pela aba Produtos',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  user?.affiliateCode ?? '—',
                                  style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 20,
                                      letterSpacing: 3),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded,
                                    color: AppColors.primary, size: 18),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(
                                      text: user?.affiliateCode ?? ''));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Código copiado! ✅'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Ações
                _InfoSection(
                  title: 'Configurações',
                  items: [
                    _ActionItem(
                      icon: Icons.notifications_rounded,
                      label: 'Notificações',
                      onTap: () {},
                    ),
                    _ActionItem(
                      icon: Icons.lock_rounded,
                      label: 'Alterar Senha',
                      onTap: () {},
                    ),
                    _ActionItem(
                      icon: Icons.description_rounded,
                      label: 'Termos de Uso',
                      onTap: () {},
                    ),
                    _ActionItem(
                      icon: Icons.help_rounded,
                      label: 'Suporte',
                      onTap: () {},
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Logout
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmLogout(context, auth),
                    icon: const Icon(Icons.logout_rounded,
                        color: AppColors.error),
                    label: const Text('Sair da Conta',
                        style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, AuthService auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sair da conta?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Você precisará fazer login novamente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await auth.logout();
              if (context.mounted) {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/login', (_) => false);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            child: const Text('Sair',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final List<Widget> items;

  const _InfoSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHint,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...items.asMap().entries.map((e) {
              return Column(
                children: [
                  if (e.key > 0)
                    const Divider(
                        height: 1, indent: 52, endIndent: 0),
                  e.value,
                ],
              );
            }),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isProtected;
  final Color? valueColor;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    this.isProtected = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textHint)),
                const SizedBox(height: 2),
                Text(
                  isProtected
                      ? '${value.substring(0, value.length.clamp(0, 4))}••••••'
                      : value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? AppColors.textPrimary,
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

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textHint, size: 20),
          ],
        ),
      ),
    );
  }
}
