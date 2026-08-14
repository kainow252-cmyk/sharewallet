import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// Modelos
// ---------------------------------------------------------------------------

class MpConfig {
  final String accessToken;       // APP-... (mascarado ao retornar do servidor)
  final String publicKey;         // TEST-... ou APP-...
  final bool   verified;
  final String accountEmail;
  final String accountId;
  final bool   sandbox;

  const MpConfig({
    required this.accessToken,
    required this.publicKey,
    required this.verified,
    required this.accountEmail,
    required this.accountId,
    required this.sandbox,
  });

  bool get isEmpty => accessToken.isEmpty;
  bool get isConfigured => verified && accessToken.isNotEmpty;

  factory MpConfig.defaultConfig() => const MpConfig(
        accessToken:   '',
        publicKey:     '',
        verified:      false,
        accountEmail:  '',
        accountId:     '',
        sandbox:       false,
      );

  factory MpConfig.fromMap(Map<String, dynamic> m) => MpConfig(
        accessToken:   m['access_token']   as String? ?? '',
        publicKey:     m['public_key']     as String? ?? '',
        verified:      m['verified']       as bool?   ?? false,
        accountEmail:  m['account_email']  as String? ?? '',
        accountId:     m['account_id']     as String? ?? '',
        sandbox:       m['sandbox']        as bool?   ?? false,
      );

  Map<String, dynamic> toMap() => {
        'access_token':  accessToken,
        'public_key':    publicKey,
        'verified':      verified,
        'account_email': accountEmail,
        'account_id':    accountId,
        'sandbox':       sandbox,
      };

  MpConfig copyWith({
    String? accessToken,
    String? publicKey,
    bool?   verified,
    String? accountEmail,
    String? accountId,
    bool?   sandbox,
  }) =>
      MpConfig(
        accessToken:   accessToken   ?? this.accessToken,
        publicKey:     publicKey     ?? this.publicKey,
        verified:      verified      ?? this.verified,
        accountEmail:  accountEmail  ?? this.accountEmail,
        accountId:     accountId     ?? this.accountId,
        sandbox:       sandbox       ?? this.sandbox,
      );
}

// ---------------------------------------------------------------------------
// GatewayType
// ---------------------------------------------------------------------------

enum GatewayType { woovi, mercadopago, none }

extension GatewayTypeX on GatewayType {
  String get key {
    switch (this) {
      case GatewayType.woovi:        return 'woovi';
      case GatewayType.mercadopago:  return 'mercadopago';
      case GatewayType.none:         return 'none';
    }
  }

  String get label {
    switch (this) {
      case GatewayType.woovi:        return 'Woovi / OpenPix';
      case GatewayType.mercadopago:  return 'Mercado Pago';
      case GatewayType.none:         return 'Nenhum';
    }
  }

  static GatewayType fromKey(String key) {
    switch (key) {
      case 'mercadopago': return GatewayType.mercadopago;
      case 'none':        return GatewayType.none;
      default:            return GatewayType.woovi;
    }
  }
}

// ---------------------------------------------------------------------------
// MpAdminService — ChangeNotifier (Provider)
// ---------------------------------------------------------------------------

class MpAdminService extends ChangeNotifier {
  static const String _base = 'https://api.sharewallet.com.br';

  MpConfig    _config       = MpConfig.defaultConfig();
  GatewayType _activeGateway = GatewayType.woovi;
  bool        _isLoading    = false;
  bool        _isLoaded     = false;
  String?     _lastError;

  MpConfig    get config        => _config;
  GatewayType get activeGateway => _activeGateway;
  bool        get isLoading     => _isLoading;
  bool        get isLoaded      => _isLoaded;
  String?     get lastError     => _lastError;

  // ---------------------------------------------------------------------------
  // resetAndReload
  // ---------------------------------------------------------------------------
  Future<void> resetAndReload() async {
    _config        = MpConfig.defaultConfig();
    _activeGateway = GatewayType.woovi;
    _isLoaded      = false;
    _isLoading     = false;
    notifyListeners();
    await loadAll();
  }

  // ---------------------------------------------------------------------------
  // loadAll — carrega gateway ativo + config MP em paralelo
  // ---------------------------------------------------------------------------
  Future<void> loadAll() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _fetchGatewayConfig(),
        _fetchMpConfig(),
      ]);
      _activeGateway = results[0] as GatewayType;
      _config        = results[1] as MpConfig;
    } catch (e) {
      _lastError = e.toString();
    }

    _isLoaded  = true;
    _isLoading = false;
    notifyListeners();
  }

  Future<GatewayType> _fetchGatewayConfig() async {
    try {
      final resp = await http
          .get(Uri.parse('$_base/api/admin/gateway-config'))
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final data = (body['result'] as Map<String, dynamic>?) ?? body;
        return GatewayTypeX.fromKey(data['active_gateway'] as String? ?? 'woovi');
      }
    } catch (_) {}
    return GatewayType.woovi;
  }

  Future<MpConfig> _fetchMpConfig() async {
    try {
      final resp = await http
          .get(Uri.parse('$_base/api/admin/mp-config'))
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final data = (body['result'] as Map<String, dynamic>?) ?? body;
        return MpConfig.fromMap(data);
      }
    } catch (_) {}
    return MpConfig.defaultConfig();
  }

  // ---------------------------------------------------------------------------
  // setActiveGateway
  // ---------------------------------------------------------------------------
  Future<bool> setActiveGateway(GatewayType gw) async {
    _isLoading = true;
    notifyListeners();

    bool ok = false;
    try {
      final resp = await http
          .post(
            Uri.parse('$_base/api/admin/gateway-config'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'active_gateway': gw.key}),
          )
          .timeout(const Duration(seconds: 8));
      ok = resp.statusCode >= 200 && resp.statusCode < 300;
      if (ok) _activeGateway = gw;
    } catch (e) {
      _lastError = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return ok;
  }

  // ---------------------------------------------------------------------------
  // saveMpConfig — salva + verifica token automaticamente no Worker
  // ---------------------------------------------------------------------------
  Future<({bool ok, String email, String id, String error})> saveMpConfig({
    required String accessToken,
    required String publicKey,
    bool sandbox = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final resp = await http
          .post(
            Uri.parse('$_base/api/admin/mp-config'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'access_token': accessToken,
              'public_key':   publicKey,
              'sandbox':      sandbox,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final result = (body['result'] as Map<String, dynamic>?) ?? body;

      if (resp.statusCode >= 200 && resp.statusCode < 300 &&
          (result['success'] == true || result['verified'] == true)) {
        final email = result['account_email'] as String? ?? '';
        final id    = result['account_id']    as String? ?? '';
        // Atualizar estado local
        _config = _config.copyWith(
          accessToken:  accessToken.substring(0, accessToken.length.clamp(0, 16)) + '...',
          publicKey:    publicKey,
          verified:     true,
          accountEmail: email,
          accountId:    id,
          sandbox:      sandbox,
        );
        _isLoading = false;
        notifyListeners();
        return (ok: true, email: email, id: id, error: '');
      }

      final errMsg = result['error'] as String? ?? 'Erro ao salvar credenciais';
      _isLoading = false;
      notifyListeners();
      return (ok: false, email: '', id: '', error: errMsg);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return (ok: false, email: '', id: '', error: e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // removeMpConfig
  // ---------------------------------------------------------------------------
  Future<bool> removeMpConfig() async {
    _isLoading = true;
    notifyListeners();

    bool ok = false;
    try {
      final resp = await http
          .delete(Uri.parse('$_base/api/admin/mp-config'))
          .timeout(const Duration(seconds: 8));
      ok = resp.statusCode >= 200 && resp.statusCode < 300;
      if (ok) _config = MpConfig.defaultConfig();
    } catch (e) {
      _lastError = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return ok;
  }
}
