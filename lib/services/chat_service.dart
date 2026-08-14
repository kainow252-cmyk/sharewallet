import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

// ---------------------------------------------------------------------------
// Modelos
// ---------------------------------------------------------------------------

class ChatMessage {
  final String id;
  final String senderId;      // uid do remetente
  final String senderUsername; // @usuario do remetente
  final String text;
  final DateTime createdAt;
  final bool read;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderUsername,
    required this.text,
    required this.createdAt,
    this.read = false,
  });

  factory ChatMessage.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      senderId: d['sender_id'] as String? ?? '',
      senderUsername: d['sender_username'] as String? ?? '?',
      text: d['text'] as String? ?? '',
      createdAt: (d['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: d['read'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'sender_id': senderId,
    'sender_username': senderUsername,
    'text': text,
    'created_at': FieldValue.serverTimestamp(),
    'read': read,
  };
}

class ChatConversation {
  final String id;          // conversationId = uid menor + '_' + uid maior
  final String otherUid;
  final String otherUsername;
  final String lastMessage;
  final DateTime lastAt;
  final int unreadCount;    // não lidas PARA o usuário atual

  const ChatConversation({
    required this.id,
    required this.otherUid,
    required this.otherUsername,
    required this.lastMessage,
    required this.lastAt,
    this.unreadCount = 0,
  });
}

// ---------------------------------------------------------------------------
// ChatService
// ---------------------------------------------------------------------------

class ChatService extends ChangeNotifier {
  final FirebaseFirestore _db;

  // Mesmo banco usado em firebase_user_service.dart
  static const String _databaseId = 'affiliatewalletwallet';
  static FirebaseFirestore? _dbInstance;

  static FirebaseFirestore _getDb() {
    if (_dbInstance != null) return _dbInstance!;
    try {
      _dbInstance = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: _databaseId,
      );
      if (kIsWeb) {
        _dbInstance!.settings = const Settings(
          persistenceEnabled: false,
          webExperimentalForceLongPolling: true,
        );
      } else {
        _dbInstance!.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
      }
    } catch (e) {
      // fallback para instância padrão caso Firebase não inicializado ainda
      _dbInstance = FirebaseFirestore.instance;
      if (kDebugMode) debugPrint('[ChatService] _getDb fallback: $e');
    }
    return _dbInstance!;
  }

  ChatService() : _db = _getDb();

  // Total de não lidas (para badge na nav bar)
  int _totalUnread = 0;
  int get totalUnread => _totalUnread;
  StreamSubscription<QuerySnapshot>? _unreadSub;

  // ── ID canônico da conversa (uid menor primeiro, evita duplicatas) ─────────
  static String conversationId(String uidA, String uidB) =>
      uidA.compareTo(uidB) < 0 ? '${uidA}_$uidB' : '${uidB}_$uidA';

  // ── Inicia escuta de mensagens não lidas para badge ───────────────────────
  void startListeningUnread(String myUid) {
    _unreadSub?.cancel();
    if (myUid.isEmpty) return;
    _unreadSub = _db
        .collection('chat_conversations')
        .where('participants', arrayContains: myUid)
        .snapshots()
        .listen((snap) {
      int total = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        final unreadMap = data['unread_count'] as Map<String, dynamic>? ?? {};
        total += (unreadMap[myUid] as num?)?.toInt() ?? 0;
      }
      if (total != _totalUnread) {
        _totalUnread = total;
        notifyListeners();
      }
    }, onError: (e) {
      // Silencia erros de Firestore (ex: regras, índice) — badge fica em 0
      if (kDebugMode) debugPrint('[ChatService] unread error: $e');
    });
  }

  void stopListeningUnread() {
    _unreadSub?.cancel();
    _unreadSub = null;
  }

  // ── Stream de conversas do usuário ────────────────────────────────────────
  Stream<List<ChatConversation>> conversationsStream(String myUid) {
    if (myUid.isEmpty) return const Stream.empty();
    // Sem orderBy para evitar índice composto no Firestore — ordena em memória
    return _db
        .collection('chat_conversations')
        .where('participants', arrayContains: myUid)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((doc) {
            final d = doc.data();
            final participants = List<String>.from(d['participants'] ?? []);
            final otherUid =
                participants.firstWhere((u) => u != myUid, orElse: () => '');
            final usernames = Map<String, dynamic>.from(d['usernames'] ?? {});
            final unreadMap = Map<String, dynamic>.from(d['unread_count'] ?? {});
            return ChatConversation(
              id: doc.id,
              otherUid: otherUid,
              otherUsername: usernames[otherUid]?.toString() ?? '@?',
              lastMessage: d['last_message']?.toString() ?? '',
              lastAt: (d['last_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
              unreadCount: (unreadMap[myUid] as num?)?.toInt() ?? 0,
            );
          }).toList();
          // Ordena por mais recente primeiro (sem índice composto)
          list.sort((a, b) => b.lastAt.compareTo(a.lastAt));
          return list;
        });
  }

  // ── Stream de mensagens de uma conversa ───────────────────────────────────
  Stream<List<ChatMessage>> messagesStream(String convId) {
    return _db
        .collection('chat_conversations')
        .doc(convId)
        .collection('messages')
        .orderBy('created_at', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => ChatMessage.fromDoc(doc)).toList());
  }

  // ── Abrir ou criar conversa ───────────────────────────────────────────────
  Future<String> openConversation({
    required String myUid,
    required String myUsername,
    required String otherUid,
    required String otherUsername,
  }) async {
    final convId = conversationId(myUid, otherUid);
    final ref = _db.collection('chat_conversations').doc(convId);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'participants': [myUid, otherUid],
        'usernames': {myUid: myUsername, otherUid: otherUsername},
        'last_message': '',
        'last_at': FieldValue.serverTimestamp(),
        'unread_count': {myUid: 0, otherUid: 0},
        'created_at': FieldValue.serverTimestamp(),
      });
    } else {
      // Atualiza username se mudou
      await ref.update({
        'usernames.$myUid': myUsername,
        'usernames.$otherUid': otherUsername,
      });
    }
    return convId;
  }

  // ── Enviar mensagem ───────────────────────────────────────────────────────
  Future<void> sendMessage({
    required String convId,
    required String myUid,
    required String myUsername,
    required String otherUid,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;
    final convRef = _db.collection('chat_conversations').doc(convId);
    final batch = _db.batch();

    // Adiciona mensagem na subcoleção
    final msgRef = convRef.collection('messages').doc();
    batch.set(msgRef, {
      'sender_id': myUid,
      'sender_username': myUsername,
      'text': text.trim(),
      'created_at': FieldValue.serverTimestamp(),
      'read': false,
    });

    // Atualiza metadados da conversa
    batch.update(convRef, {
      'last_message': text.trim(),
      'last_at': FieldValue.serverTimestamp(),
      'unread_count.$otherUid': FieldValue.increment(1),
    });

    await batch.commit();
  }

  // ── Marcar mensagens como lidas ───────────────────────────────────────────
  Future<void> markAsRead(String convId, String myUid) async {
    try {
      await _db
          .collection('chat_conversations')
          .doc(convId)
          .update({'unread_count.$myUid': 0});
    } catch (_) {}
  }

  // ── Buscar afiliado por @username ─────────────────────────────────────────
  // Estratégia em cascata:
  //  1. Busca exata por username no Firestore (banco correto)
  //  2. Busca por nome (case-insensitive) no Firestore como fallback
  //  3. Busca por affiliate_code (maiúsculo) como último recurso
  Future<Map<String, String>?> findByUsername(String username) async {
    final limpo = username.toLowerCase().replaceFirst('@', '').trim();
    if (limpo.isEmpty) return null;
    try {
      // 1. Busca exata por username
      final snapUser = await _db
          .collection('affiliates')
          .where('username', isEqualTo: limpo)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));

      if (snapUser.docs.isNotEmpty) {
        final d = snapUser.docs.first.data();
        return {
          'uid': snapUser.docs.first.id,
          'username': d['username']?.toString() ?? limpo,
          'nome': d['nome']?.toString() ?? limpo,
        };
      }

      // 2. Fallback: busca por nome (ex: "saulo" bate em nome="Saulo")
      //    Busca case-insensitive usando range query
      final nomeCapit = limpo[0].toUpperCase() + limpo.substring(1);
      final snapNome = await _db
          .collection('affiliates')
          .where('nome', isGreaterThanOrEqualTo: nomeCapit)
          .where('nome', isLessThanOrEqualTo: '$nomeCapit\uf8ff')
          .limit(5)
          .get()
          .timeout(const Duration(seconds: 5));

      if (snapNome.docs.isNotEmpty) {
        // Pega o primeiro que tenha nome começando com o termo buscado
        final doc = snapNome.docs.first;
        final d = doc.data();
        final usernameExistente = d['username']?.toString() ?? '';
        return {
          'uid': doc.id,
          'username': usernameExistente.isNotEmpty ? usernameExistente : limpo,
          'nome': d['nome']?.toString() ?? limpo,
        };
      }

      // 3. Último recurso: busca por affiliate_code (ex: "LA1Z9K")
      final codigoUpper = limpo.toUpperCase();
      final snapCode = await _db
          .collection('affiliates')
          .where('affiliate_code', isEqualTo: codigoUpper)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));

      if (snapCode.docs.isNotEmpty) {
        final d = snapCode.docs.first.data();
        final usernameExistente = d['username']?.toString() ?? '';
        return {
          'uid': snapCode.docs.first.id,
          'username': usernameExistente.isNotEmpty ? usernameExistente : limpo,
          'nome': d['nome']?.toString() ?? limpo,
        };
      }

      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[ChatService] findByUsername error: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _unreadSub?.cancel();
    super.dispose();
  }
}
