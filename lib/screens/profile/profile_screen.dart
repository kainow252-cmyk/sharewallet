import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_user_service.dart';
import '../../services/cf_api_service.dart';
import '../../services/profile_photo_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../utils/web_utils.dart';
import '../../utils/js_bridge_helper.dart' as jsBridge;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _editMode = false;
  bool _saving = false;
  bool _uploadingPhoto = false;


  late TextEditingController _nomeCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _telefoneCtrl;
  late TextEditingController _cpfCtrl;
  late TextEditingController _pixCtrl;
  late TextEditingController _usernameCtrl;

  // Estado de validação do @username em tempo real
  bool _usernameChecking = false;
  bool? _usernameDisponivel;   // null = não verificado, true = ok, false = ocupado
  String? _usernameErro;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    _nomeCtrl     = TextEditingController(text: user?.nome ?? '');
    _emailCtrl    = TextEditingController(text: user?.email ?? '');
    _telefoneCtrl = TextEditingController(text: user?.telefone ?? '');
    _cpfCtrl      = TextEditingController(text: user?.cpf ?? '');
    // pixKey: usa pix_key salvo; se vazio cai pro email como fallback
    _pixCtrl      = TextEditingController(
        text: (user?.pixKey.isNotEmpty == true) ? user!.pixKey : (user?.email ?? ''));
    _usernameCtrl = TextEditingController(text: user?.username ?? '');

    // No APK WebView: registra listener do evento 'sw-photo-selected'
    if (kIsWeb && isNativeApp()) {
      _registerPhotoEventListener();
    }

    // Recarrega perfil ao abrir - usa D1 como fonte de verdade
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthService>();

      // 1. Tenta carregar dados frescos do D1 (mais confiável que Firestore cache)
      try {
        final email = auth.currentUser?.email ?? '';
        if (email.isNotEmpty) {
          final d1Data = await CfApiService.getAffiliateByEmail(email);
          if (d1Data != null && mounted) {
            final d1Nome     = d1Data['nome']?.toString() ?? '';
            final d1Cpf      = d1Data['cpf']?.toString() ?? '';
            final d1Tel      = d1Data['telefone']?.toString() ?? '';
            final d1Pix      = d1Data['pix_key']?.toString() ?? '';

            // Atualiza AuthService com dados do D1
            auth.updateCurrentUser(
              nome: d1Nome.isNotEmpty ? d1Nome : null,
              cpf: d1Cpf.isNotEmpty ? d1Cpf : null,
              telefone: d1Tel.isNotEmpty ? d1Tel : null,
              pixKey: d1Pix.isNotEmpty ? d1Pix : null,
            );

            // Atualiza os controllers com dados reais do D1
            if (d1Nome.isNotEmpty) _nomeCtrl.text = d1Nome;
            if (d1Cpf.isNotEmpty)  _cpfCtrl.text  = d1Cpf;
            if (d1Tel.isNotEmpty)  _telefoneCtrl.text = d1Tel;
            if (d1Pix.isNotEmpty)  _pixCtrl.text  = d1Pix;
            else if (email.isNotEmpty) _pixCtrl.text = email;
            // Username: D1 é agora fonte de verdade (coluna username existe)
            final usernameD1 = d1Data['username']?.toString() ?? '';
            final usernameFallback = auth.currentUser?.username ?? '';
            // D1 tem prioridade; se vazio, usa AuthService/Firestore como fallback
            final usernameResolvido = usernameD1.isNotEmpty ? usernameD1 : usernameFallback;
            if (usernameResolvido.isNotEmpty) {
              // Sempre atualiza o controller com o valor mais recente do D1
              _usernameCtrl.text = usernameResolvido;
              auth.updateCurrentUser(username: usernameResolvido);
            }
            if (mounted) setState(() {});
            return; // D1 carregou com sucesso  -  não precisa do Firestore
          }
        }
      } catch (_) {}

      // 2. Fallback: Firestore (caso D1 falhe)
      await auth.refreshProfile();
      if (!mounted) return;
      final u = auth.currentUser;
      if (u != null) {
        _nomeCtrl.text     = u.nome;
        _emailCtrl.text    = u.email;
        _telefoneCtrl.text = u.telefone;
        _cpfCtrl.text      = u.cpf;
        _pixCtrl.text      = u.pixKey.isNotEmpty ? u.pixKey : u.email;
        if (u.username.isNotEmpty && _usernameCtrl.text.isEmpty) {
          _usernameCtrl.text = u.username;
        }
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    jsBridge.unregisterPhotoEventListener();
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _telefoneCtrl.dispose();
    _cpfCtrl.dispose();
    _pixCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  // ── Listener do evento JS 'sw-photo-selected' (bridge APK → Flutter Web) ──

  void _registerPhotoEventListener() {
    // Usa o js_bridge_helper (condicional web/stub) para registrar o listener
    // do CustomEvent 'sw-photo-selected' despachado pelo shell Flutter APK.
    jsBridge.registerPhotoEventListener((dataUrl, mimeType) {
      _uploadFromBridge(dataUrl, mimeType);
    });
  }

  /// Recebe base64 dataUrl do bridge nativo e faz upload via worker.
  Future<void> _uploadFromBridge(String dataUrl, String mimeType) async {
    if (!mounted) return;
    final uid = context.read<AuthService>().currentUser?.id ?? '';
    if (uid.isEmpty) return;

    setState(() => _uploadingPhoto = true);

    final url = await ProfilePhotoService.uploadBytes(
      uid: uid,
      base64DataUrl: dataUrl,
      mimeType: mimeType,
      onError: (msg) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: AppColors.error),
          );
        }
      },
    );

    if (!mounted) return;
    setState(() => _uploadingPhoto = false);

    if (url != null) {
      context.read<AuthService>().updateCurrentUser(photoUrl: url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto atualizada com sucesso!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  // -- Verifica disponibilidade do @username com debounce -------------------
  Future<void> _verificarUsername(String valor) async {
    final limpo = valor.toLowerCase().trim();

    // Campo vazio → limpa estado sem erro
    if (limpo.isEmpty) {
      setState(() { _usernameDisponivel = null; _usernameErro = null; _usernameChecking = false; });
      return;
    }

    // Muito curto
    if (limpo.length < 3) {
      setState(() { _usernameDisponivel = null; _usernameErro = 'Mínimo 3 caracteres'; _usernameChecking = false; });
      return;
    }

    // Caracteres inválidos
    if (!RegExp(r'^[a-z0-9._]+$').hasMatch(limpo)) {
      setState(() { _usernameDisponivel = false; _usernameErro = 'Use apenas letras, números, ponto ou _'; _usernameChecking = false; });
      return;
    }

    final auth = context.read<AuthService>();
    final uid = auth.currentUser?.id ?? '';

    // É o mesmo username que o usuário já tem gravado → disponível sem checar Firestore
    // Verifica tanto no AuthService quanto no controller (para usuários antigos que carregam depois)
    final usernameNoAuthService = auth.currentUser?.username ?? '';
    if (limpo == usernameNoAuthService && usernameNoAuthService.isNotEmpty) {
      setState(() { _usernameDisponivel = true; _usernameErro = null; _usernameChecking = false; });
      return;
    }

    // Inicia verificação assíncrona com debounce
    setState(() { _usernameChecking = true; _usernameErro = null; _usernameDisponivel = null; });
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    // Após debounce, verifica de novo se o valor ainda é o mesmo digitado
    final valorAtual = _usernameCtrl.text.toLowerCase().trim();
    if (valorAtual != limpo) return; // usuário continuou digitando — cancela este ciclo

    // Verificação final no Firestore
    final disponivel = await FirebaseUserService.verificarUsernameDisponivel(limpo, uid);
    if (!mounted) return;
    setState(() {
      _usernameChecking = false;
      _usernameDisponivel = disponivel;
      _usernameErro = disponivel ? null : 'Este @$limpo já está em uso';
    });
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final nome         = _nomeCtrl.text.trim();
    final telefone     = _telefoneCtrl.text.trim();
    final cpf          = _cpfCtrl.text.trim();
    final pixKey       = _pixCtrl.text.trim();
    final novoUsername = _usernameCtrl.text.toLowerCase().trim();

    // Bloqueia se username inválido ou verificação ainda pendente
    if (_usernameErro != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_usernameErro!), backgroundColor: AppColors.error),
      );
      setState(() => _saving = false);
      return;
    }

    // Se o usuário digitou algo no campo mas a verificação ainda não terminou → aguarda
    final novoUsernameCheck = _usernameCtrl.text.toLowerCase().trim();
    final usernameAtualCheck = context.read<AuthService>().currentUser?.username ?? '';
    if (novoUsernameCheck.isNotEmpty &&
        novoUsernameCheck != usernameAtualCheck &&
        _usernameDisponivel != true &&
        !_usernameChecking) {
      // Força verificação antes de salvar
      await _verificarUsername(novoUsernameCheck);
      if (!mounted) return;
      if (_usernameErro != null || _usernameDisponivel != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_usernameErro ?? 'Verifique o @usuário antes de salvar'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _saving = false);
        return;
      }
    }
    // Se verificação ainda está rodando, aguarda até 3s
    if (_usernameChecking) {
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!_usernameChecking) break;
      }
      if (!mounted) return;
      if (_usernameErro != null || (_usernameDisponivel != true && novoUsernameCheck != usernameAtualCheck && novoUsernameCheck.isNotEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_usernameErro ?? 'Aguarde a verificação do @usuário'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _saving = false);
        return;
      }
    }

    try {
      final auth = context.read<AuthService>();
      final uid  = auth.currentUser?.id ?? '';

      // 1. Salva no Firestore (set+merge - cria se não existir)
      await FirebaseUserService.atualizarPerfil(
        uid: uid,
        nome: nome,
        telefone: telefone,
        cpf: cpf,
        pixKey: pixKey,
        email: auth.currentUser?.email ?? '',
        affiliateCode: auth.currentUser?.affiliateCode ?? '',
      );

      // 1b. Atualiza @username se o campo tem valor E
      //     (é diferente do atual OU o atual está vazio — primeiro cadastro)
      final usernameAtual = auth.currentUser?.username ?? '';
      final usernameNovo = novoUsername.isNotEmpty;
      final usernameMudou = novoUsername != usernameAtual;
      final usernameValidado = _usernameDisponivel == true || novoUsername == usernameAtual;
      final deveAtualizarUsername = usernameNovo && usernameMudou && usernameValidado;
      if (deveAtualizarUsername) {
        final res = await FirebaseUserService.atualizarUsername(
          uid: uid,
          novoUsername: novoUsername,
        );
        if (!res.success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res.error ?? 'Erro ao salvar @username'),
                backgroundColor: AppColors.error),
          );
          setState(() => _saving = false);
          return;
        }
      }

      // 2. Sincroniza no D1 - aguarda para garantir consistência
      await CfApiService.updateAffiliate(uid, {
        'nome': nome,
        'email': auth.currentUser?.email ?? '',
        'telefone': telefone,
        'cpf': cpf,
        'pix_key': pixKey,
        'affiliate_code': auth.currentUser?.affiliateCode ?? '',
        if (novoUsername.isNotEmpty) 'username': novoUsername,
      }).catchError((_) => null);

      // 3. Atualiza o currentUser DIRETAMENTE no AuthService (ANTES do refreshProfile)
      // CRÍTICO: passar username aqui garante que o header atualize imediatamente.
      // O refreshProfile em background pode sobrescrever com '' se o Firestore
      // ainda não propagou — por isso chamamos updateCurrentUser primeiro.
      final usernameParaSalvar = novoUsername.isNotEmpty ? novoUsername : null;
      auth.updateCurrentUser(
        nome: nome,
        telefone: telefone,
        cpf: cpf,
        pixKey: pixKey,
        username: usernameParaSalvar,
      );
      // Atualiza controller e estado da UI imediatamente
      if (usernameParaSalvar != null) {
        _usernameCtrl.text = usernameParaSalvar;
        _usernameDisponivel = true;
        _usernameErro = null;
      }

      // 4. refreshProfile em background — mas NÃO sobrescreve username se já foi salvo
      // Aguarda 2s para o Firestore propagar o write antes de reler
      if (usernameParaSalvar != null) {
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          auth.refreshProfile().catchError((_) {});
        });
      } else {
        auth.refreshProfile().catchError((_) {});
      }

      if (!mounted) return;
      setState(() { _editMode = false; _saving = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil atualizado com sucesso!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            // -- Header ------------------------------------------------------
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: AppColors.primary,
              actions: [
                if (!_editMode)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _editMode = true;
                        // Ao abrir edição, se o usuário já tem @username, marca como disponível
                        final usernameAtual = context.read<AuthService>().currentUser?.username ?? '';
                        if (usernameAtual.isNotEmpty) {
                          _usernameCtrl.text = usernameAtual;
                          _usernameDisponivel = true;
                          _usernameErro = null;
                        }
                      });
                    },
                    icon: const Icon(Icons.edit_rounded,
                        color: Colors.white, size: 18),
                    label: const Text('Editar',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  )
                else ...[
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() => _editMode = false),
                    child: const Text('Cancelar',
                        style: TextStyle(color: Colors.white70)),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _salvar,
                    child: _saving
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Salvar',
                            style: TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w800)),
                  ),
                ],
              ],
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
                        GestureDetector(
                          onTap: () => _mostrarOpcoesPhoto(context),
                          child: Stack(
                            children: [
                              // Avatar: foto ou inicial
                              CircleAvatar(
                                radius: 44,
                                backgroundColor:
                                    AppColors.gold.withValues(alpha: 0.3),
                                backgroundImage: (user?.photoUrl != null &&
                                        user!.photoUrl!.isNotEmpty)
                                    ? NetworkImage(user.photoUrl!)
                                    : null,
                                child: (user?.photoUrl == null ||
                                        user!.photoUrl!.isEmpty)
                                    ? Text(
                                        (user?.nome.isNotEmpty == true)
                                            ? user!.nome[0].toUpperCase()
                                            : 'A',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 36,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      )
                                    : _uploadingPhoto
                                        ? const CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2)
                                        : null,
                              ),
                              // Badge verificado
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
                              // Ícone câmera (overlay)
                              if (_uploadingPhoto)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.45),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.45),
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(44),
                                        bottomRight: Radius.circular(44),
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.camera_alt_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          user?.nome.isNotEmpty == true
                              ? user!.nome
                              : 'Afiliado',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // @handle — toca para copiar
                        GestureDetector(
                          onTap: () {
                            final handle = user?.handle ?? '';
                            if (handle.isNotEmpty) {
                              Clipboard.setData(ClipboardData(text: handle));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('$handle copiado!'),
                                  duration: const Duration(seconds: 1),
                                  backgroundColor: AppColors.primary,
                                ),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppColors.goldLight.withValues(alpha: 0.5),
                                  width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.alternate_email_rounded,
                                    color: AppColors.goldLight, size: 13),
                                const SizedBox(width: 3),
                                Text(
                                  user?.username.isNotEmpty == true
                                      ? user!.handle          // @gelcisilva
                                      : user?.affiliateCode ?? 'ABC123',
                                  style: const TextStyle(
                                    color: AppColors.goldLight,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Icon(Icons.copy_rounded,
                                    color: AppColors.goldLight, size: 10),
                              ],
                            ),
                          ),
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

                  // -- Minha Conta ------------------------------------------
                  _Section(
                    title: 'Minha Conta',
                    trailing: _editMode
                        ? null
                        : GestureDetector(
                            onTap: () {
                              setState(() {
                                _editMode = true;
                                final usernameAtual = context.read<AuthService>().currentUser?.username ?? '';
                                if (usernameAtual.isNotEmpty) {
                                  _usernameCtrl.text = usernameAtual;
                                  _usernameDisponivel = true;
                                  _usernameErro = null;
                                }
                              });
                            },
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_outlined,
                                    size: 14, color: AppColors.primary),
                                SizedBox(width: 4),
                                Text('Editar',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                    children: [
                      _editMode
                          ? _EditField(
                              ctrl: _nomeCtrl,
                              label: 'Nome completo',
                              icon: Icons.person_rounded,
                              validator: (v) =>
                                  v!.trim().split('').length < 2
                                      ? 'Nome e sobrenome'
                                      : null,
                            )
                          : _InfoRow(
                              icon: Icons.person_rounded,
                              label: 'Nome',
                              value: user?.nome.isNotEmpty == true
                                  ? user!.nome
                                  : ' - ',
                            ),
                      const Divider(height: 1, indent: 52),
                      // -- @username (sempre vis\u00edvel, edit\u00e1vel em modo edi\u00e7\u00e3o) --------
                      _editMode
                          ? _UsernameEditField(
                              ctrl: _usernameCtrl,
                              checking: _usernameChecking,
                              disponivel: _usernameDisponivel,
                              erro: _usernameErro,
                              onChanged: _verificarUsername,
                            )
                          : _InfoRow(
                              icon: Icons.alternate_email_rounded,
                              label: 'Usuário',
                              value: user?.username.isNotEmpty == true
                                  ? user!.handle
                                  : 'Não definido — toque em Editar',
                              valueColor: user?.username.isNotEmpty == true
                                  ? AppColors.primary
                                  : AppColors.textHint,
                            ),
                      const Divider(height: 1, indent: 52),
                      _InfoRow(
                        icon: Icons.email_outlined,
                        label: 'E-mail',
                        value: user?.email.isNotEmpty == true
                            ? user!.email
                            : ' - ',
                      ),
                      const Divider(height: 1, indent: 52),
                      _editMode
                          ? _EditField(
                              ctrl: _telefoneCtrl,
                              label: 'Telefone / WhatsApp',
                              icon: Icons.phone_rounded,
                              keyboard: TextInputType.phone,
                            )
                          : _InfoRow(
                              icon: Icons.phone_rounded,
                              label: 'Telefone',
                              value: user?.telefone.isNotEmpty == true
                                  ? user!.telefone
                                  : ' - ',
                            ),
                      const Divider(height: 1, indent: 52),
                      _editMode
                          ? _EditField(
                              ctrl: _cpfCtrl,
                              label: 'CPF',
                              icon: Icons.badge_rounded,
                              keyboard: TextInputType.number,
                              hint: '000.000.000-00',
                            )
                          : _InfoRow(
                              icon: Icons.badge_rounded,
                              label: 'CPF',
                              value: user?.cpf.isNotEmpty == true
                                  ? _maskCpf(user!.cpf)
                                  : ' - ',
                            ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // -- PIX --------------------------------------------------
                  _Section(
                    title: 'Recebimento PIX',
                    children: [
                      _editMode
                          ? _EditField(
                              ctrl: _pixCtrl,
                              label: 'Chave PIX',
                              icon: Icons.pix_rounded,
                              hint: 'E-mail, CPF, telefone ou chave aleatória',
                            )
                          : _InfoRow(
                              icon: Icons.pix_rounded,
                              label: 'Chave PIX',
                              value: () {
                                final key = user?.pixKey ?? '';
                                if (key.isNotEmpty) return key;
                                if (user?.email.isNotEmpty == true) return user!.email;
                                return 'Não configurada';
                              }(),
                            ),
                      const Divider(height: 1, indent: 52),
                      _InfoRow(
                        icon: Icons.account_balance_rounded,
                        label: 'Status',
                        value: 'Ativa',
                        valueColor: AppColors.success,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // -- Salvar (modo edição) ----------------------------------
                  if (_editMode) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: PrimaryButton(
                        label: 'Salvar Alterações',
                        icon: Icons.save_rounded,
                        isLoading: _saving,
                        onPressed: _saving ? null : _salvar,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // -- Configurações -----------------------------------------
                  _Section(
                    title: 'Configurações',
                    children: [
                      _ActionRow(
                        icon: Icons.lock_rounded,
                        label: 'Alterar Senha',
                        onTap: () => _mostrarAlterarSenha(context),
                      ),
                      const Divider(height: 1, indent: 52),
                      _ActionRow(
                        icon: Icons.description_rounded,
                        label: 'Termos de Uso',
                        onTap: () => _mostrarTermos(context),
                      ),
                      const Divider(height: 1, indent: 52),
                      _ActionRow(
                        icon: Icons.privacy_tip_rounded,
                        label: 'Política de Privacidade',
                        onTap: () => _mostrarPolitica(context),
                      ),
                      const Divider(height: 1, indent: 52),
                      _ActionRow(
                        icon: Icons.help_rounded,
                        label: 'Suporte / Ajuda',
                        onTap: () => _mostrarSuporte(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // -- Logout ------------------------------------------------
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

                  const SizedBox(height: 12),

                  // Versão
                  const Text(
                    'ShareWallet v1.0.0',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textHint),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -- Foto de perfil ---------------------------------------------------------

  void _mostrarOpcoesPhoto(BuildContext context) {
    final auth = context.read<AuthService>();
    final uid = auth.currentUser?.id ?? '';
    final temFoto = auth.currentUser?.photoUrl?.isNotEmpty == true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Row(
              children: [
                Icon(Icons.account_circle_rounded,
                    color: AppColors.primary, size: 22),
                SizedBox(width: 10),
                Text(
                  'Foto de perfil',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Câmera
            _PhotoOptionTile(
              icon: Icons.camera_alt_rounded,
              label: 'Tirar foto',
              subtitle: 'Usar câmera do dispositivo',
              onTap: () async {
                Navigator.pop(context);
                if (kIsWeb && isNativeApp()) {
                  _callNativePicker('camera');
                } else {
                  await _uploadPhoto(uid, ImageSource.camera);
                }
              },
            ),
            const SizedBox(height: 8),
            // Galeria
            _PhotoOptionTile(
              icon: Icons.photo_library_rounded,
              label: 'Escolher da galeria',
              subtitle: 'Selecionar imagem existente',
              onTap: () async {
                Navigator.pop(context);
                if (kIsWeb && isNativeApp()) {
                  _callNativePicker('gallery');
                } else {
                  await _uploadPhoto(uid, ImageSource.gallery);
                }
              },
            ),
            // Remover foto (só se já tiver)
            if (temFoto) ...[
              const SizedBox(height: 8),
              _PhotoOptionTile(
                icon: Icons.delete_outline_rounded,
                label: 'Remover foto',
                subtitle: 'Voltar para inicial do nome',
                iconColor: AppColors.error,
                labelColor: AppColors.error,
                onTap: () async {
                  Navigator.pop(context);
                  await _removerPhoto(uid);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Chama a função JS injetada pelo shell (openNativeCamera / openNativeGallery)
  void _callNativePicker(String source) {
    try {
      if (source == 'camera') {
        jsBridge.callNativeCamera();
      } else {
        jsBridge.callNativeGallery();
      }
      // Mostra loading — o resultado vem via evento assíncrono sw-photo-selected
      setState(() => _uploadingPhoto = true);
    } catch (e) {
      if (kDebugMode) debugPrint('[ProfileScreen] _callNativePicker err: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao abrir câmera/galeria nativa.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _uploadPhoto(String uid, ImageSource source) async {
    if (uid.isEmpty) return;
    setState(() => _uploadingPhoto = true);

    final url = await ProfilePhotoService.pickAndUpload(
      uid: uid,
      source: source,
      onError: (msg) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: AppColors.error),
          );
        }
      },
    );

    if (!mounted) return;
    setState(() => _uploadingPhoto = false);

    if (url != null) {
      context.read<AuthService>().updateCurrentUser(photoUrl: url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto atualizada com sucesso!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _removerPhoto(String uid) async {
    if (uid.isEmpty) return;
    setState(() => _uploadingPhoto = true);
    await ProfilePhotoService.removePhoto(uid);
    if (!mounted) return;
    setState(() => _uploadingPhoto = false);
    context.read<AuthService>().updateCurrentUser(clearPhoto: true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Foto removida.'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  // -- Helpers ----------------------------------------------------------------

  String _maskCpf(String cpf) {
    final digits = cpf.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 11) return cpf;
    return '${digits.substring(0, 3)}.***.*${digits.substring(9, 11)}';
  }

  void _confirmLogout(BuildContext context, AuthService auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sair',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _mostrarTermos(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TermosSheet(
        titulo: 'Termos de Uso',
        conteudo: _termosDeUso,
      ),
    );
  }

  void _mostrarPolitica(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TermosSheet(
        titulo: 'Política de Privacidade',
        conteudo: _politicaDePrivacidade,
      ),
    );
  }

  void _mostrarSuporte(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            const Icon(Icons.support_agent_rounded,
                color: AppColors.primary, size: 48),
            const SizedBox(height: 12),
            const Text('Suporte ShareWallet',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'Entre em contato conosco para dúvidas, problemas técnicos ou sugestões.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            _SupportTile(
              icon: Icons.email_rounded,
              label: 'E-mail',
              value: 'suporte@sharewallet.com.br',
              onTap: () {},
            ),
            const SizedBox(height: 8),
            _SupportTile(
              icon: Icons.chat_rounded,
              label: 'WhatsApp',
              value: '(11) 99999-9999',
              onTap: () {},
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _mostrarAlterarSenha(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AlterarSenhaSheet(),
    );
  }
}

// -- Widgets auxiliares ---------------------------------------------------------

class _PhotoOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;

  const _PhotoOptionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: labelColor ?? AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: color.withValues(alpha: 0.5), size: 20),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  const _Section({
    required this.title,
    required this.children,
    this.trailing,
  });

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
              child: Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHint,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
            ...children,
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
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
                  value.isEmpty ? ' - ' : value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: valueColor ??
                        (value.isEmpty
                            ? AppColors.textHint
                            : AppColors.textPrimary),
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

class _EditField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType? keyboard;
  final String? hint;
  final String? Function(String?)? validator;

  const _EditField({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.keyboard,
    this.hint,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.primary, size: 18),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        ),
        validator: validator,
      ),
    );
  }
}

// -- Campo especial para @username com validação em tempo real ----------------

class _UsernameEditField extends StatelessWidget {
  final TextEditingController ctrl;
  final bool checking;
  final bool? disponivel;
  final String? erro;
  final ValueChanged<String> onChanged;

  const _UsernameEditField({
    required this.ctrl,
    required this.checking,
    required this.disponivel,
    required this.erro,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Ícone de status à direita do campo
    Widget? suffixIcon;
    if (checking) {
      suffixIcon = const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
        ),
      );
    } else if (disponivel == true) {
      suffixIcon = const Icon(Icons.check_circle_rounded,
          color: AppColors.success, size: 20);
    } else if (disponivel == false) {
      suffixIcon =
          const Icon(Icons.cancel_rounded, color: AppColors.error, size: 20);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: ctrl,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            inputFormatters: [
              // Permite apenas letras minúsculas, números, ponto e _
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._]')),
            ],
            onChanged: (v) => onChanged(v.toLowerCase()),
            decoration: InputDecoration(
              labelText: 'Usuário (@handle)',
              hintText: 'ex: gelcisilva ou gelci.silva',
              prefixIcon: const Icon(Icons.alternate_email_rounded,
                  color: AppColors.primary, size: 18),
              prefixText: '',
              suffixIcon: suffixIcon,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              helperText: disponivel == true
                  ? 'Disponível!'
                  : 'Mín. 3 chars, letras, números, ponto ou _',
              helperStyle: TextStyle(
                color: disponivel == true ? AppColors.success : AppColors.textHint,
                fontSize: 11,
              ),
              errorText: erro,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionRow(
      {required this.icon, required this.label, required this.onTap});

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

class _SupportTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _SupportTile(
      {required this.icon,
      required this.label,
      required this.value,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(label,
          style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
      subtitle: Text(value,
          style: const TextStyle(
              fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      trailing:
          const Icon(Icons.open_in_new_rounded, color: AppColors.primary, size: 18),
      onTap: onTap,
      shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.cardBorder),
          borderRadius: BorderRadius.circular(12)),
    );
  }
}

// -- Sheet: Termos / Política --------------------------------------------------

class _TermosSheet extends StatelessWidget {
  final String titulo;
  final String conteudo;
  const _TermosSheet({required this.titulo, required this.conteudo});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const Icon(Icons.description_rounded,
                      color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text(titulo,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const Divider(height: 24),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                children: [
                  Text(conteudo,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.7)),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -- Sheet: Alterar Senha ------------------------------------------------------

class _AlterarSenhaSheet extends StatefulWidget {
  const _AlterarSenhaSheet();

  @override
  State<_AlterarSenhaSheet> createState() => _AlterarSenhaSheetState();
}

class _AlterarSenhaSheetState extends State<_AlterarSenhaSheet> {
  final _atualCtrl = TextEditingController();
  final _novaCtrl  = TextEditingController();
  final _confCtrl  = TextEditingController();
  bool _loading = false;
  bool _showAtual = false;
  bool _showNova  = false;
  final _key = GlobalKey<FormState>();

  @override
  void dispose() {
    _atualCtrl.dispose(); _novaCtrl.dispose(); _confCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Senha alterada com sucesso!'),
          backgroundColor: AppColors.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Text('Alterar Senha',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _atualCtrl,
                obscureText: !_showAtual,
                decoration: InputDecoration(
                  labelText: 'Senha atual',
                  prefixIcon: const Icon(Icons.lock_outline_rounded,
                      color: AppColors.primary),
                  suffixIcon: IconButton(
                    icon: Icon(_showAtual
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                        color: AppColors.textHint),
                    onPressed: () =>
                        setState(() => _showAtual = !_showAtual),
                  ),
                ),
                validator: (v) =>
                    v!.length < 6 ? 'Mínimo 6 caracteres' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _novaCtrl,
                obscureText: !_showNova,
                decoration: InputDecoration(
                  labelText: 'Nova senha',
                  prefixIcon: const Icon(Icons.lock_rounded,
                      color: AppColors.primary),
                  suffixIcon: IconButton(
                    icon: Icon(_showNova
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                        color: AppColors.textHint),
                    onPressed: () =>
                        setState(() => _showNova = !_showNova),
                  ),
                ),
                validator: (v) =>
                    v!.length < 6 ? 'Mínimo 6 caracteres' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmar nova senha',
                  prefixIcon: Icon(Icons.lock_rounded,
                      color: AppColors.primary),
                ),
                validator: (v) => v != _novaCtrl.text
                    ? 'Senhas não conferem'
                    : null,
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Alterar Senha',
                icon: Icons.save_rounded,
                isLoading: _loading,
                onPressed: _loading ? null : _salvar,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// -- Conteúdo dos Termos -------------------------------------------------------

const String _termosDeUso = '''
TERMOS DE USO  -  SHAREWALLET

Última atualização: junho de 2025

1. ACEITAÇÃO DOS TERMOS
Ao se cadastrar e utilizar o ShareWallet, você concorda com estes Termos de Uso. Caso não concorde, não utilize nossos serviços.

2. SOBRE O SERVIÇO
O ShareWallet é uma plataforma de marketing de afiliados que permite aos usuários divulgar produtos e receber comissões por vendas realizadas através de seus links rastreáveis.

3. CADASTRO E CONTA
* Você deve ter pelo menos 18 anos de idade.
* Forneça informações verdadeiras e mantenha seus dados atualizados.
* É proibido criar múltiplas contas para burlar o sistema de comissões.
* Você é responsável pela segurança da sua senha.

4. COMISSÕES E PAGAMENTOS
* As comissões são pagas via PIX após confirmação do pagamento do cliente final.
* O prazo para liberação das comissões é de até 7 dias úteis após a confirmação.
* O valor mínimo para saque é de R\$ 50,00.
* Comissões estornadas por cancelamento ou chargeback serão descontadas do saldo.

5. CONDUTAS PROIBIDAS
* Spam ou divulgação não autorizada.
* Uso de informações falsas ou enganosas.
* Tentativa de fraude ou manipulação do sistema.
* Uso indevido da marca ShareWallet.

6. RESCISÃO
O ShareWallet reserva-se o direito de suspender ou encerrar contas que violem estes termos, sem aviso prévio, com o estorno das comissões pendentes em casos de fraude comprovada.

7. LIMITAÇÃO DE RESPONSABILIDADE
O ShareWallet não se responsabiliza por perdas indiretas ou danos decorrentes do uso da plataforma.

8. ALTERAÇÕES
Estes termos podem ser alterados a qualquer momento. Notificaremos os usuários por e-mail ou dentro do aplicativo.

9. CONTATO
Dúvidas: suporte@sharewallet.com.br
''';

const String _politicaDePrivacidade = '''
POLÍTICA DE PRIVACIDADE  -  SHAREWALLET

Última atualização: junho de 2025

1. DADOS COLETADOS
Coletamos: nome completo, CPF, e-mail, telefone, endereço IP e dados de uso da plataforma.

2. USO DOS DADOS
* Processamento de comissões e pagamentos PIX.
* Comunicação sobre sua conta e transações.
* Melhoria dos nossos serviços.
* Cumprimento de obrigações legais.

3. COMPARTILHAMENTO
Seus dados são compartilhados apenas com:
* Mercado Pago (processamento de pagamentos).
* Autoridades quando exigido por lei.
Nunca vendemos seus dados a terceiros.

4. SEGURANÇA
Utilizamos criptografia e boas práticas de segurança para proteger seus dados.

5. SEUS DIREITOS
Você pode solicitar: acesso, correção, exclusão ou portabilidade dos seus dados a qualquer momento pelo e-mail privacidade@sharewallet.com.br.

6. COOKIES
Utilizamos cookies apenas para autenticação e melhoria da experiência do usuário.

7. CONTATO
privacidade@sharewallet.com.br
''';
