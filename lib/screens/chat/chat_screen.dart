import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../dashboard/main_nav_screen.dart';

// ============================================================================
// TELA PRINCIPAL DE CHAT (lista de conversas)
// ============================================================================
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final chat = context.watch<ChatService>();

    // ── Uid: prioridade ao AuthService (Firestore profile), fallback ao
    // FirebaseAuth direto para evitar tela de "Faça login" durante hidratação
    // assíncrona do AuthService na PWA/Web.
    final fbUser = FirebaseAuth.instance.currentUser;
    final myUid = auth.currentUser?.id.isNotEmpty == true
        ? auth.currentUser!.id
        : (fbUser?.uid ?? '');
    final myUsername = auth.currentUser?.username.isNotEmpty == true
        ? auth.currentUser!.username
        : (fbUser?.displayName ?? fbUser?.email?.split('@').first ?? '');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) MainNavController().goHome();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: AppColors.primaryDark,
          title: const Row(
            children: [
              Icon(Icons.chat_bubble_rounded, color: Colors.white70, size: 20),
              SizedBox(width: 10),
              Text('Chat Afiliados',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18)),
            ],
          ),
          actions: [
            // Botão de nova conversa por @usuario
            IconButton(
              icon: const Icon(Icons.person_search_rounded, color: Colors.white),
              tooltip: 'Buscar @usuário',
              onPressed: () => _showNewChatSheet(context, myUid, myUsername, chat),
            ),
          ],
        ),
        body: myUid.isEmpty
            ? const _EmptyState(
                icon: Icons.lock_outline_rounded,
                msg: 'Faça login para acessar o chat')
            : StreamBuilder<List<ChatConversation>>(
                stream: chat.conversationsStream(myUid),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary));
                  }
                  final convs = snap.data ?? [];
                  if (convs.isEmpty) {
                    return _EmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      msg: 'Nenhuma conversa ainda.\nToque em  para buscar um @usuário.',
                      action: TextButton.icon(
                        onPressed: () => _showNewChatSheet(
                            context, myUid, myUsername, chat),
                        icon: const Icon(Icons.person_search_rounded,
                            color: AppColors.primary),
                        label: const Text('Buscar @usuário',
                            style: TextStyle(color: AppColors.primary)),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: convs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) =>
                        _ConversationTile(
                          conv: convs[i],
                          myUid: myUid,
                          myUsername: myUsername,
                        ),
                  );
                },
              ),
      ),
    );
  }

  // -- Bottom sheet: buscar @usuario para iniciar conversa -------------------
  void _showNewChatSheet(
      BuildContext context, String myUid, String myUsername, ChatService chat) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewChatSheet(
        myUid: myUid,
        myUsername: myUsername,
        chat: chat,
      ),
    );
  }
}

// ============================================================================
// Tile de conversa na lista
// ============================================================================
class _ConversationTile extends StatelessWidget {
  final ChatConversation conv;
  final String myUid;
  final String myUsername;

  const _ConversationTile({
    required this.conv,
    required this.myUid,
    required this.myUsername,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = conv.unreadCount > 0;
    final ago = _timeAgo(conv.lastAt);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          convId: conv.id,
          myUid: myUid,
          myUsername: myUsername,
          otherUid: conv.otherUid,
          otherUsername: conv.otherUsername,
        ),
      )),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasUnread
                ? AppColors.primary.withValues(alpha: 0.35)
                : AppColors.cardBorder,
            width: hasUnread ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            _Avatar(username: conv.otherUsername, size: 46),
            const SizedBox(width: 12),
            // Textos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '@${conv.otherUsername}',
                          style: TextStyle(
                            fontWeight: hasUnread
                                ? FontWeight.w800
                                : FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        ago,
                        style: TextStyle(
                          fontSize: 11,
                          color: hasUnread
                              ? AppColors.primary
                              : AppColors.textHint,
                          fontWeight: hasUnread
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    conv.lastMessage.isEmpty
                        ? 'Conversa iniciada'
                        : conv.lastMessage,
                    style: TextStyle(
                      fontSize: 12,
                      color: hasUnread
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: hasUnread
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Badge de não lidas
            if (hasUnread) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${conv.unreadCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }
}

// ============================================================================
// Sheet para iniciar nova conversa por @usuario
// ============================================================================
class _NewChatSheet extends StatefulWidget {
  final String myUid;
  final String myUsername;
  final ChatService chat;
  const _NewChatSheet(
      {required this.myUid, required this.myUsername, required this.chat});

  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet> {
  final _ctrl = TextEditingController();
  bool _searching = false;
  String? _error;
  Map<String, String>? _found;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
      _found = null;
    });
    final result = await widget.chat.findByUsername(q);
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _error = 'Usuário @${q.replaceFirst('@', '')} não encontrado';
        _searching = false;
      });
    } else if (result['uid'] == widget.myUid) {
      setState(() {
        _error = 'Você não pode conversar com você mesmo 😄';
        _searching = false;
      });
    } else {
      setState(() {
        _found = result;
        _searching = false;
      });
    }
  }

  Future<void> _startChat() async {
    if (_found == null) return;
    final convId = await widget.chat.openConversation(
      myUid: widget.myUid,
      myUsername: widget.myUsername,
      otherUid: _found!['uid']!,
      otherUsername: _found!['username']!,
    );
    if (!mounted) return;
    Navigator.pop(context);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatRoomScreen(
        convId: convId,
        myUid: widget.myUid,
        myUsername: widget.myUsername,
        otherUid: _found!['uid']!,
        otherUsername: _found!['username']!,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Título
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_search_rounded,
                      color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nova Conversa',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: AppColors.textPrimary)),
                    Text('Busque pelo @usuário do afiliado',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Campo de busca
            TextField(
              controller: _ctrl,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              style: const TextStyle(
                  fontSize: 15, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: '@usuario...',
                hintStyle: const TextStyle(color: AppColors.textHint),
                prefixIcon: const Icon(Icons.alternate_email_rounded,
                    color: AppColors.primary, size: 20),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.search_rounded,
                            color: AppColors.primary),
                        onPressed: _search,
                      ),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
            // Erro
            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.error, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              color: AppColors.error, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
            // Resultado encontrado
            if (_found != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    _Avatar(
                        username: _found!['username'] ?? '?',
                        size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '@${_found!['username']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if ((_found!['nome'] ?? '').isNotEmpty)
                            Text(
                              _found!['nome']!,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary),
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.success, size: 22),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startChat,
                  icon: const Icon(Icons.chat_bubble_rounded,
                      color: Colors.white, size: 18),
                  label: Text(
                    'Iniciar conversa com @${_found!['username']}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TELA DE CHAT (mensagens)
// ============================================================================
class ChatRoomScreen extends StatefulWidget {
  final String convId;
  final String myUid;
  final String myUsername;
  final String otherUid;
  final String otherUsername;

  const ChatRoomScreen({
    super.key,
    required this.convId,
    required this.myUid,
    required this.myUsername,
    required this.otherUid,
    required this.otherUsername,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _msgCtrl = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Marca como lido ao abrir
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatService>().markAsRead(widget.convId, widget.myUid);
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _msgCtrl.clear();
    try {
      await context.read<ChatService>().sendMessage(
            convId: widget.convId,
            myUid: widget.myUid,
            myUsername: widget.myUsername,
            otherUid: widget.otherUid,
            text: text,
          );
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToBottom());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.read<ChatService>();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F3),
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            _Avatar(username: widget.otherUsername, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '@${widget.otherUsername}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text('Online',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Lista de mensagens
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: chat.messagesStream(widget.convId),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary));
                }
                final msgs = snap.data ?? [];
                if (msgs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.waving_hand_rounded,
                            size: 48,
                            color: AppColors.textHint),
                        SizedBox(height: 12),
                        Text('Diga olá! 👋',
                            style: TextStyle(
                                color: AppColors.textHint,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        SizedBox(height: 4),
                        Text('Comece a conversa abaixo',
                            style: TextStyle(
                                color: AppColors.textHint,
                                fontSize: 13)),
                      ],
                    ),
                  );
                }
                // Scroll automático quando chegam mensagens novas
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                  itemCount: msgs.length,
                  itemBuilder: (ctx, i) {
                    final msg = msgs[i];
                    final isMe = msg.senderId == widget.myUid;
                    // Mostrar data separadora
                    final showDate = i == 0 ||
                        !_sameDay(
                            msgs[i - 1].createdAt, msg.createdAt);
                    return Column(
                      children: [
                        if (showDate) _DateDivider(dt: msg.createdAt),
                        _MessageBubble(msg: msg, isMe: isMe),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Barra de input
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(
              12,
              10,
              12,
              10 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SafeArea(
              top: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Campo de texto
                  Expanded(
                    child: Container(
                      constraints:
                          const BoxConstraints(minHeight: 44, maxHeight: 120),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(22),
                        border:
                            Border.all(color: AppColors.cardBorder),
                      ),
                      child: TextField(
                        controller: _msgCtrl,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Mensagem...',
                          hintStyle:
                              TextStyle(color: AppColors.textHint, fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botão enviar
                  GestureDetector(
                    onTap: _sending ? null : _send,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _sending
                            ? AppColors.textHint
                            : AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary
                                .withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ============================================================================
// Widgets auxiliares
// ============================================================================

class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final bool isMe;

  const _MessageBubble({required this.msg, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final time =
        '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 3,
          bottom: 3,
          left: isMe ? 60 : 0,
          right: isMe ? 0 : 60,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '@${msg.senderUsername}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            Text(
              msg.text,
              style: TextStyle(
                fontSize: 14,
                color: isMe ? Colors.white : AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              time,
              style: TextStyle(
                fontSize: 10,
                color: isMe
                    ? Colors.white.withValues(alpha: 0.65)
                    : AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  final DateTime dt;
  const _DateDivider({required this.dt});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String label;
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      label = 'Hoje';
    } else if (dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day - 1) {
      label = 'Ontem';
    } else {
      label = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(
              child: Divider(color: Color(0xFFDDE4E0))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFDDE4E0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                label,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const Expanded(
              child: Divider(color: Color(0xFFDDE4E0))),
        ],
      ),
    );
  }
}

// Avatar gerado por inicial do @usuario
class _Avatar extends StatelessWidget {
  final String username;
  final double size;
  const _Avatar({required this.username, required this.size});

  static Color _colorForUsername(String u) {
    final colors = [
      const Color(0xFF1565C0),
      const Color(0xFF6A1B9A),
      const Color(0xFF00695C),
      const Color(0xFFE65100),
      const Color(0xFF2E7D32),
      const Color(0xFFAD1457),
      const Color(0xFF00838F),
      const Color(0xFF4527A0),
    ];
    if (u.isEmpty) return colors[0];
    return colors[u.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final initial = username.isEmpty
        ? '?'
        : username.replaceFirst('@', '')[0].toUpperCase();
    final color = _colorForUsername(username);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.30),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.4,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String msg;
  final Widget? action;
  const _EmptyState({required this.icon, required this.msg, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 60, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
