import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN CHAT SCREEN — Gestão completa das conversas entre afiliados
// ─────────────────────────────────────────────────────────────────────────────

class AdminChatScreen extends StatefulWidget {
  const AdminChatScreen({super.key});

  @override
  State<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ── Deletar conversa inteira (+ subcoleção de mensagens) ──────────────────
  Future<void> _deleteConversation(String convId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D2518),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Excluir Conversa',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text(
          'Todas as mensagens serão apagadas permanentemente. Confirmar?',
          style: TextStyle(color: Color(0xFF7AAE90)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF7AAE90))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Excluir',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    // Deleta mensagens da subcoleção primeiro
    final msgs = await _db
        .collection('chat_conversations')
        .doc(convId)
        .collection('messages')
        .get();
    final batch = _db.batch();
    for (final doc in msgs.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_db.collection('chat_conversations').doc(convId));
    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conversa excluída com sucesso'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  // ── Deletar mensagem individual ────────────────────────────────────────────
  Future<void> _deleteMessage(String convId, String msgId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D2518),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Excluir Mensagem',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text(
          'A mensagem será removida permanentemente.',
          style: TextStyle(color: Color(0xFF7AAE90)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF7AAE90))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Excluir',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    await _db
        .collection('chat_conversations')
        .doc(convId)
        .collection('messages')
        .doc(msgId)
        .delete();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mensagem excluída'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Tab bar ─────────────────────────────────────────────────────────
        Container(
          color: const Color(0xFF071A10),
          child: TabBar(
            controller: _tab,
            indicatorColor: const Color(0xFFC9A84C),
            labelColor: const Color(0xFFC9A84C),
            unselectedLabelColor: const Color(0xFF7AAE90),
            labelStyle: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13),
            tabs: const [
              Tab(
                icon: Icon(Icons.forum_rounded, size: 18),
                text: 'Conversas',
              ),
              Tab(
                icon: Icon(Icons.bar_chart_rounded, size: 18),
                text: 'Estatísticas',
              ),
            ],
          ),
        ),

        // ── Conteúdo ─────────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _ConversationsTab(
                db: _db,
                onDeleteConv: _deleteConversation,
                onDeleteMsg: _deleteMessage,
              ),
              _StatsTab(db: _db),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ABA 1 — Lista de conversas
// ─────────────────────────────────────────────────────────────────────────────
class _ConversationsTab extends StatefulWidget {
  final FirebaseFirestore db;
  final Future<void> Function(String convId) onDeleteConv;
  final Future<void> Function(String convId, String msgId) onDeleteMsg;

  const _ConversationsTab({
    required this.db,
    required this.onDeleteConv,
    required this.onDeleteMsg,
  });

  @override
  State<_ConversationsTab> createState() => _ConversationsTabState();
}

class _ConversationsTabState extends State<_ConversationsTab> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barra de busca
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _search = v.toLowerCase().trim()),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Buscar por @usuário...',
              hintStyle: const TextStyle(color: Color(0xFF7AAE90)),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: Color(0xFF7AAE90), size: 20),
              filled: true,
              fillColor: const Color(0xFF0D2518),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF163424)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF163424)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFFC9A84C), width: 1.5),
              ),
            ),
          ),
        ),

        // Lista de conversas
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: widget.db
                .collection('chat_conversations')
                .orderBy('last_at', descending: true)
                .snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFC9A84C)));
              }
              if (snap.hasError) {
                return _AdminEmpty(
                  icon: Icons.error_outline_rounded,
                  msg: 'Erro ao carregar conversas.\n${snap.error}',
                );
              }

              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const _AdminEmpty(
                  icon: Icons.chat_bubble_outline_rounded,
                  msg: 'Nenhuma conversa ainda.',
                );
              }

              // Filtra pela busca
              final filtered = _search.isEmpty
                  ? docs
                  : docs.where((doc) {
                      final d = doc.data() as Map<String, dynamic>;
                      final usernames =
                          (d['usernames'] as Map?)?.values.join(' ').toLowerCase() ?? '';
                      return usernames.contains(_search);
                    }).toList();

              if (filtered.isEmpty) {
                return _AdminEmpty(
                  icon: Icons.search_off_rounded,
                  msg: 'Nenhuma conversa com "@$_search"',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final doc = filtered[i];
                  final d = doc.data() as Map<String, dynamic>;
                  return _ConvCard(
                    convId: doc.id,
                    data: d,
                    db: widget.db,
                    onDeleteConv: widget.onDeleteConv,
                    onDeleteMsg: widget.onDeleteMsg,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card de conversa expansível
// ─────────────────────────────────────────────────────────────────────────────
class _ConvCard extends StatefulWidget {
  final String convId;
  final Map<String, dynamic> data;
  final FirebaseFirestore db;
  final Future<void> Function(String) onDeleteConv;
  final Future<void> Function(String, String) onDeleteMsg;

  const _ConvCard({
    required this.convId,
    required this.data,
    required this.db,
    required this.onDeleteConv,
    required this.onDeleteMsg,
  });

  @override
  State<_ConvCard> createState() => _ConvCardState();
}

class _ConvCardState extends State<_ConvCard> {
  bool _expanded = false;

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '—';
    final dt = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m atrás';
    if (diff.inHours < 24) return '${diff.inHours}h atrás';
    if (diff.inDays < 7) return '${diff.inDays}d atrás';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final usernames = Map<String, dynamic>.from(widget.data['usernames'] ?? {});
    final participants =
        List<String>.from(widget.data['participants'] ?? []);
    final lastMsg = widget.data['last_message']?.toString() ?? '';
    final lastAt = widget.data['last_at'] as Timestamp?;
    final unreadMap =
        Map<String, dynamic>.from(widget.data['unread_count'] ?? {});
    final totalUnread =
        unreadMap.values.fold<int>(0, (s, v) => s + ((v as num?)?.toInt() ?? 0));

    // Monta label com os dois @usernames
    final userLabels = participants.map((uid) {
      final u = usernames[uid]?.toString() ?? uid.substring(0, 6);
      return '@$u';
    }).join('  ↔  ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2518),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF163424)),
      ),
      child: Column(
        children: [
          // ── Cabeçalho da conversa ──────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Ícone
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC9A84C).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFFC9A84C).withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.chat_rounded,
                        color: Color(0xFFC9A84C), size: 20),
                  ),
                  const SizedBox(width: 12),
                  // Usernames + preview
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                userLabels,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (totalUnread > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.error,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('$totalUnread não lida${totalUnread > 1 ? 's' : ''}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                lastMsg.isEmpty ? 'Sem mensagens' : lastMsg,
                                style: const TextStyle(
                                  color: Color(0xFF7AAE90),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDate(lastAt),
                              style: const TextStyle(
                                color: Color(0xFF7AAE90),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Ações
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Expandir/recolher mensagens
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: const Color(0xFF7AAE90),
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      // Deletar conversa
                      GestureDetector(
                        onTap: () => widget.onDeleteConv(widget.convId),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.error.withValues(alpha: 0.8),
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Mensagens expandidas ───────────────────────────────────────
          if (_expanded) ...[
            Container(
              height: 1,
              color: const Color(0xFF163424),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: widget.db
                  .collection('chat_conversations')
                  .doc(widget.convId)
                  .collection('messages')
                  .orderBy('created_at', descending: false)
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFFC9A84C), strokeWidth: 2)),
                  );
                }
                final msgs = snap.data?.docs ?? [];
                if (msgs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nenhuma mensagem nesta conversa.',
                        style: TextStyle(
                            color: Color(0xFF7AAE90), fontSize: 13)),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  itemCount: msgs.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 6),
                  itemBuilder: (ctx, i) {
                    final msgDoc = msgs[i];
                    final m =
                        msgDoc.data() as Map<String, dynamic>;
                    final sender =
                        m['sender_username']?.toString() ?? '?';
                    final text = m['text']?.toString() ?? '';
                    final ts = m['created_at'] as Timestamp?;
                    final timeStr = ts != null
                        ? '${ts.toDate().day.toString().padLeft(2, '0')}/${ts.toDate().month.toString().padLeft(2, '0')} ${ts.toDate().hour.toString().padLeft(2, '0')}:${ts.toDate().minute.toString().padLeft(2, '0')}'
                        : '—';

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF071A10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFF163424)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar inicial
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFFC9A84C)
                                  .withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                sender.isNotEmpty
                                    ? sender[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Color(0xFFC9A84C),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Conteúdo
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '@$sender',
                                      style: const TextStyle(
                                        color: Color(0xFFC9A84C),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      timeStr,
                                      style: const TextStyle(
                                        color: Color(0xFF7AAE90),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  text,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Deletar mensagem
                          GestureDetector(
                            onTap: () => widget.onDeleteMsg(
                                widget.convId, msgDoc.id),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Icon(
                                Icons.close_rounded,
                                color: AppColors.error
                                    .withValues(alpha: 0.6),
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ABA 2 — Estatísticas do chat
// ─────────────────────────────────────────────────────────────────────────────
class _StatsTab extends StatelessWidget {
  final FirebaseFirestore db;
  const _StatsTab({required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('chat_conversations').snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child:
                  CircularProgressIndicator(color: Color(0xFFC9A84C)));
        }

        final docs = snap.data?.docs ?? [];
        final totalConvs = docs.length;

        // Conta total de mensagens (soma das subcoleções — estimativa via metadados)
        int totalMsgs = 0;
        int totalUnread = 0;
        final Map<String, int> userMsgCount = {};

        for (final doc in docs) {
          final d = doc.data() as Map<String, dynamic>;
          final unreadMap =
              Map<String, dynamic>.from(d['unread_count'] ?? {});
          totalUnread += unreadMap.values
              .fold<int>(0, (s, v) => s + ((v as num?)?.toInt() ?? 0));

          // Conta participantes mais ativos pelos usernames
          final usernames =
              Map<String, dynamic>.from(d['usernames'] ?? {});
          for (final u in usernames.values) {
            final key = u.toString();
            userMsgCount[key] = (userMsgCount[key] ?? 0) + 1;
          }
        }

        // Top afiliados por conversas
        final sorted = userMsgCount.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final top5 = sorted.take(5).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Cards de resumo ─────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.forum_rounded,
                    label: 'Conversas',
                    value: '$totalConvs',
                    color: const Color(0xFFC9A84C),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.mark_unread_chat_alt_rounded,
                    label: 'Não lidas',
                    value: '$totalUnread',
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.people_rounded,
                    label: 'Afiliados ativos',
                    value: '${userMsgCount.length}',
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.chat_bubble_rounded,
                    label: 'Msgs estimadas',
                    value: totalMsgs > 0 ? '$totalMsgs' : '—',
                    color: const Color(0xFF29B6F6),
                  ),
                ),
              ],
            ),

            if (top5.isNotEmpty) ...[
              const SizedBox(height: 24),

              // ── Top afiliados ──────────────────────────────────────────
              const Text(
                'Afiliados mais ativos no chat',
                style: TextStyle(
                  color: Color(0xFFC9A84C),
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 12),
              ...top5.asMap().entries.map((e) {
                final pos = e.key + 1;
                final entry = e.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D2518),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF163424)),
                  ),
                  child: Row(
                    children: [
                      // Posição
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFC9A84C)
                              .withValues(alpha: pos == 1 ? 0.25 : 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$pos',
                            style: TextStyle(
                              color: pos == 1
                                  ? const Color(0xFFC9A84C)
                                  : const Color(0xFF7AAE90),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Username
                      Expanded(
                        child: Text(
                          '@${entry.key}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      // Conversas
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '${entry.value} conv.',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],

            // ── Aviso de moderação ─────────────────────────────────────
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF29B6F6).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF29B6F6).withValues(alpha: 0.25)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: Color(0xFF29B6F6), size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Acesse a aba "Conversas" para visualizar e moderar '
                      'mensagens individuais entre afiliados. '
                      'Conversas e mensagens podem ser excluídas permanentemente.',
                      style: TextStyle(
                        color: Color(0xFF29B6F6),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget auxiliares
// ─────────────────────────────────────────────────────────────────────────────
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2518),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF163424)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7AAE90),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminEmpty extends StatelessWidget {
  final IconData icon;
  final String msg;

  const _AdminEmpty({required this.icon, required this.msg});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: const Color(0xFF7AAE90)),
            const SizedBox(height: 16),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF7AAE90),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
