import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Página pública de download do APK.
/// Rota: /apk  (acessível sem login)
/// URL:  https://sharewallet.com.br/app/#/apk
class ApkDownloadScreen extends StatelessWidget {
  const ApkDownloadScreen({super.key});

  // APK hospedado no GitHub Releases — link permanente
  static const _apkUrl =
      'https://github.com/kainow252-cmyk/sharewallet/releases/download/v1.0.1/ShareWallet.apk';

  Future<void> _download() async {
    final uri = Uri.parse(_apkUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              _buildHero(context),
              _buildSteps(),
              _buildDownloadBtn(),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header com logo ────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF00E5B4).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Color(0xFF00E5B4),
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'Share',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextSpan(
                  text: 'Wallet',
                  style: TextStyle(
                    color: Color(0xFF00E5B4),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Badge versão
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5B4).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF00E5B4).withValues(alpha: 0.3),
              ),
            ),
            child: const Text(
              'v1.0.1',
              style: TextStyle(
                color: Color(0xFF00E5B4),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero: ícone + título ───────────────────────────────────────────────────
  Widget _buildHero(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        children: [
          // Ícone glow
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5B4).withValues(alpha: 0.35),
                  blurRadius: 50,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Image.asset(
                'assets/images/sharewallet_logo.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1A237E), Color(0xFF00BCD4)],
                    ),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 56,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'ShareWallet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sua carteira de afiliados com\npagamentos via Pix instantâneo',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white60,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          // Info chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: const [
              _InfoChip(icon: Icons.android_rounded, label: 'Android'),
              _InfoChip(icon: Icons.lock_rounded, label: 'Seguro'),
              _InfoChip(icon: Icons.pix_rounded, label: 'Pix Woovi'),
              _InfoChip(icon: Icons.bolt_rounded, label: 'Grátis'),
            ],
          ),
        ],
      ),
    );
  }

  // ── Passos de instalação ───────────────────────────────────────────────────
  Widget _buildSteps() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Como instalar',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _StepCard(
            number: '1',
            title: 'Baixe o APK',
            description:
                'Toque no botão abaixo para baixar o arquivo ShareWallet.apk para o seu celular.',
            icon: Icons.download_rounded,
          ),
          const SizedBox(height: 10),
          _StepCard(
            number: '2',
            title: 'Permita fontes desconhecidas',
            description:
                'No Android: Configurações → Segurança → Instalar apps desconhecidos → habilite para seu navegador.',
            icon: Icons.security_rounded,
          ),
          const SizedBox(height: 10),
          _StepCard(
            number: '3',
            title: 'Instale o app',
            description:
                'Abra o arquivo baixado e toque em "Instalar". Pronto — o ícone ShareWallet aparecerá na sua tela.',
            icon: Icons.install_mobile_rounded,
          ),
          const SizedBox(height: 10),
          _StepCard(
            number: '4',
            title: 'Atualizações automáticas',
            description:
                'O app verifica atualizações automaticamente ao abrir. Quando houver nova versão, um aviso aparecerá na tela.',
            icon: Icons.system_update_rounded,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Botão de download ──────────────────────────────────────────────────────
  Widget _buildDownloadBtn() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _download,
              icon: const Icon(Icons.download_rounded, size: 24),
              label: const Text(
                'Baixar ShareWallet.apk',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5B4),
                foregroundColor: const Color(0xFF0A1628),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Tamanho e info do APK
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 14, color: Colors.white38),
              const SizedBox(width: 4),
              const Text(
                'APK · Android 6.0+ · ~25 MB',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Column(
        children: [
          const Text(
            '© 2025 ShareWallet — Todos os direitos reservados',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white30, fontSize: 11),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => launchUrl(
              Uri.parse('mailto:suporte@sharewallet.com.br'),
            ),
            child: const Text(
              'suporte@sharewallet.com.br',
              style: TextStyle(
                color: Color(0xFF00E5B4),
                fontSize: 12,
                decoration: TextDecoration.underline,
                decorationColor: Color(0xFF00E5B4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chip de info ──────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white60),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Card de passo ─────────────────────────────────────────────────────────────
class _StepCard extends StatelessWidget {
  final String number;
  final String title;
  final String description;
  final IconData icon;

  const _StepCard({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Número
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF00E5B4).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Color(0xFF00E5B4),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: const Color(0xFF00E5B4)),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    height: 1.4,
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
