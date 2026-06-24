import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// Modelos
// ---------------------------------------------------------------------------

class WooviConfig {
  final String appId;           // AppID completo (base64)
  final String webhookUrl;      // URL registrada no Dashboard Woovi
  final double comissaoPercent; // 0.20 = 20%
  final bool   verified;        // true se API Woovi respondeu OK
  final String accountName;     // nome da conta retornado pela API

  const WooviConfig({
    required this.appId,
    required this.webhookUrl,
    required this.comissaoPercent,
    required this.verified,
    required this.accountName,
  });

  bool get isEmpty => appId.isEmpty;

  String get appIdMasked {
    if (appId.isEmpty) return '';
    if (appId.length <= 12) return appId;
    return '${appId.substring(0, 12)}...';
  }

  factory WooviConfig.defaultConfig() => const WooviConfig(
        appId:           '',
        webhookUrl:      'https://api.sharewallet.com.br/api/webhook/woovi',
        comissaoPercent: 0.20,
        verified:        false,
        accountName:     '',
      );

  factory WooviConfig.fromMap(Map<String, dynamic> m) => WooviConfig(
        appId:           m['app_id']            as String? ?? '',
        webhookUrl:      m['webhook_url']        as String?
            ?? 'https://api.sharewallet.com.br/api/webhook/woovi',
        comissaoPercent: (m['comissao_percent'] as num?)?.toDouble() ?? 0.20,
        verified:        m['verified']           as bool?   ?? false,
        accountName:     m['account_name']       as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'app_id':           appId,
        'webhook_url':      webhookUrl,
        'comissao_percent': comissaoPercent,
        'verified':         verified,
        'account_name':     accountName,
      };

  WooviConfig copyWith({
    String? appId,
    String? webhookUrl,
    double? comissaoPercent,
    bool?   verified,
    String? accountName,
  }) =>
      WooviConfig(
        appId:           appId           ?? this.appId,
        webhookUrl:      webhookUrl      ?? this.webhookUrl,
        comissaoPercent: comissaoPercent ?? this.comissaoPercent,
        verified:        verified        ?? this.verified,
        accountName:     accountName     ?? this.accountName,
      );
}

// ---------------------------------------------------------------------------
// WooviAdminService — ChangeNotifier (Provider)
// ---------------------------------------------------------------------------

class WooviAdminService extends ChangeNotifier {
  static const String _configDocPath = 'config/woovi';
  static const String _databaseId    = 'affiliatewalletwallet';

  static FirebaseFirestore? _dbInst;
  static FirebaseFirestore? get _db {
    if (_dbInst != null) return _dbInst;
    try {
      _dbInst = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: _databaseId,
      );
      if (kIsWeb) {
        _dbInst!.settings = const Settings(persistenceEnabled: false);
      } else {
        _dbInst!.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
      }
    } catch (_) {}
    return _dbInst;
  }

  WooviConfig _config = WooviConfig.defaultConfig();
  bool _isLoading      = false;
  bool _isConfigLoaded = false;
  String? _lastError;
  bool _isVerifying    = false;

  WooviConfig get config       => _config;
  bool get isLoading           => _isLoading;
  bool get isConfigLoaded      => _isConfigLoaded;
  String? get lastError        => _lastError;
  bool get isVerifying         => _isVerifying;

  // ---------------------------------------------------------------------------
  // loadConfig
  // ---------------------------------------------------------------------------
  Future<void> loadConfig() async {
    if (_isLoading) return;
    _isLoading = true;

    // Web: busca via Worker (evita WebChannel Firestore)
    if (kIsWeb) {
      try {
        final resp = await http.get(
          Uri.parse('https://api.sharewallet.com.br/api/admin/woovi-config'),
        ).timeout(const Duration(seconds: 5));
        if (resp.statusCode == 200) {
          final j = jsonDecode(resp.body) as Map<String, dynamic>?;
          if (j != null) _config = WooviConfig.fromMap(j);
        }
      } catch (_) {/* mantém default */}
      _isConfigLoaded = true;
      _isLoading = false;
      notifyListeners();
      return;
    }

    // Mobile: Firestore cache → server → fallback
    try {
      final db = _db;
      if (db == null) throw Exception('Firestore indisponível');
      final parts = _configDocPath.split('/');
      DocumentSnapshot<Map<String, dynamic>>? snap;

      // cache local
      try {
        snap = await db
            .collection(parts[0])
            .doc(parts[1])
            .get(const GetOptions(source: Source.cache));
        if (snap.exists && snap.data() != null) {
          _config = WooviConfig.fromMap(snap.data()!);
        }
      } catch (_) {}

      // servidor
      try {
        snap = await db
            .collection(parts[0])
            .doc(parts[1])
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 8));
        if (snap.exists && snap.data() != null) {
          _config = WooviConfig.fromMap(snap.data()!);
        }
      } catch (_) {}
    } catch (e) {
      _lastError = e.toString();
    }

    _isConfigLoaded = true;
    _isLoading = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // saveConfig
  // ---------------------------------------------------------------------------
  Future<bool> saveConfig(WooviConfig cfg) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    bool ok = false;

    // Salva via Worker (web + mobile)
    try {
      final resp = await http.post(
        Uri.parse('https://api.sharewallet.com.br/api/admin/woovi-config'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(cfg.toMap()),
      ).timeout(const Duration(seconds: 10));
      ok = resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (e) {
      _lastError = e.toString();
    }

    // Também persiste no Firestore (mobile)
    if (!kIsWeb) {
      try {
        final parts = _configDocPath.split('/');
        await _db
            ?.collection(parts[0])
            .doc(parts[1])
            .set(cfg.toMap(), SetOptions(merge: true));
        ok = true;
      } catch (e) {
        _lastError = e.toString();
      }
    }

    if (ok) _config = cfg;
    _isLoading = false;
    notifyListeners();
    return ok;
  }

  // ---------------------------------------------------------------------------
  // verifyAppId — testa via Worker proxy (AppID nunca sai do servidor)
  // ---------------------------------------------------------------------------
  Future<({bool ok, String accountName, String error})> verifyAppId(
      String appId) async {
    _isVerifying = true;
    notifyListeners();

    try {
      final resp = await http.post(
        Uri.parse('https://api.sharewallet.com.br/api/admin/woovi-verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'appId': appId}),
      ).timeout(const Duration(seconds: 10));

      final j = jsonDecode(resp.body) as Map<String, dynamic>?;
      if (resp.statusCode == 200 && j != null) {
        final name = (j['name'] ?? j['account_name'] ?? '') as String;
        _isVerifying = false;
        notifyListeners();
        return (ok: true, accountName: name, error: '');
      }
      final msg = (j?['error'] ?? j?['message'] ?? 'Falha na verificação') as String;
      _isVerifying = false;
      notifyListeners();
      return (ok: false, accountName: '', error: msg);
    } catch (e) {
      _isVerifying = false;
      notifyListeners();
      return (ok: false, accountName: '', error: e.toString());
    }
  }
}
