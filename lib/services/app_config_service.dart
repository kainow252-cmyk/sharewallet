import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppLoginConfig — configuração de visibilidade dos métodos de login
// ─────────────────────────────────────────────────────────────────────────────
class AppLoginConfig {
  final bool loginGoogle;
  final bool loginFacebook;
  final bool loginCadastroPublico;

  const AppLoginConfig({
    this.loginGoogle          = true,
    this.loginFacebook        = true,
    this.loginCadastroPublico = true,
  });

  factory AppLoginConfig.fromJson(Map<String, dynamic> j) => AppLoginConfig(
    loginGoogle:          j['login_google']           as bool? ?? true,
    loginFacebook:        j['login_facebook']         as bool? ?? true,
    loginCadastroPublico: j['login_cadastro_publico'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'login_google':           loginGoogle,
    'login_facebook':         loginFacebook,
    'login_cadastro_publico': loginCadastroPublico,
  };

  AppLoginConfig copyWith({
    bool? loginGoogle,
    bool? loginFacebook,
    bool? loginCadastroPublico,
  }) => AppLoginConfig(
    loginGoogle:          loginGoogle          ?? this.loginGoogle,
    loginFacebook:        loginFacebook        ?? this.loginFacebook,
    loginCadastroPublico: loginCadastroPublico ?? this.loginCadastroPublico,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// AppMenuConfig — configuração de visibilidade dos menus
// ─────────────────────────────────────────────────────────────────────────────
class AppMenuConfig {
  // Nav bar bottom (itens visíveis)
  final bool navInicio;
  final bool navProdutos;
  final bool navCarteira;
  final bool navIndicacoes;
  final bool navChat;
  final bool navPerfil;

  // Quick actions na home
  final bool quickProdutos;
  final bool quickCarteira;
  final bool quickIndicacoes;
  final bool quickChat;

  const AppMenuConfig({
    this.navInicio     = true,
    this.navProdutos   = true,
    this.navCarteira   = true,
    this.navIndicacoes = true,
    this.navChat       = true,
    this.navPerfil     = true,
    this.quickProdutos   = true,
    this.quickCarteira   = true,
    this.quickIndicacoes = true,
    this.quickChat       = true,
  });

  factory AppMenuConfig.fromJson(Map<String, dynamic> j) => AppMenuConfig(
    navInicio:       j['nav_inicio']     as bool? ?? true,
    navProdutos:     j['nav_produtos']   as bool? ?? true,
    navCarteira:     j['nav_carteira']   as bool? ?? true,
    navIndicacoes:   j['nav_indicacoes'] as bool? ?? true,
    navChat:         j['nav_chat']       as bool? ?? true,
    navPerfil:       j['nav_perfil']     as bool? ?? true,
    quickProdutos:   j['quick_produtos']   as bool? ?? true,
    quickCarteira:   j['quick_carteira']   as bool? ?? true,
    quickIndicacoes: j['quick_indicacoes'] as bool? ?? true,
    quickChat:       j['quick_chat']       as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'nav_inicio':     navInicio,
    'nav_produtos':   navProdutos,
    'nav_carteira':   navCarteira,
    'nav_indicacoes': navIndicacoes,
    'nav_chat':       navChat,
    'nav_perfil':     navPerfil,
    'quick_produtos':   quickProdutos,
    'quick_carteira':   quickCarteira,
    'quick_indicacoes': quickIndicacoes,
    'quick_chat':       quickChat,
  };

  AppMenuConfig copyWith({
    bool? navInicio, bool? navProdutos, bool? navCarteira,
    bool? navIndicacoes, bool? navChat, bool? navPerfil,
    bool? quickProdutos, bool? quickCarteira,
    bool? quickIndicacoes, bool? quickChat,
  }) => AppMenuConfig(
    navInicio:       navInicio       ?? this.navInicio,
    navProdutos:     navProdutos     ?? this.navProdutos,
    navCarteira:     navCarteira     ?? this.navCarteira,
    navIndicacoes:   navIndicacoes   ?? this.navIndicacoes,
    navChat:         navChat         ?? this.navChat,
    navPerfil:       navPerfil       ?? this.navPerfil,
    quickProdutos:   quickProdutos   ?? this.quickProdutos,
    quickCarteira:   quickCarteira   ?? this.quickCarteira,
    quickIndicacoes: quickIndicacoes ?? this.quickIndicacoes,
    quickChat:       quickChat       ?? this.quickChat,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// AppConfigService — ChangeNotifier que mantém a config de menus em memória,
// persiste localmente (SharedPreferences) e sincroniza com o worker remoto.
// ─────────────────────────────────────────────────────────────────────────────
class AppConfigService extends ChangeNotifier {
  static const String _baseUrl       = 'https://api.sharewallet.com.br';
  static const String _cacheKey      = 'app_menu_config_v1';
  static const String _loginCacheKey = 'app_login_config_v1';

  AppMenuConfig  _config      = const AppMenuConfig();
  AppLoginConfig _loginConfig = const AppLoginConfig();
  bool    _loading = false;
  String? _error;

  AppMenuConfig  get config      => _config;
  AppLoginConfig get loginConfig => _loginConfig;
  bool           get loading     => _loading;
  String?        get error       => _error;

  // ── Carrega ambas as configs (cache local → remoto em paralelo) ───────────
  Future<void> load({bool forceRemote = false}) async {
    if (!forceRemote) {
      await Future.wait([_loadMenuFromCache(), _loadLoginFromCache()]);
    }

    _loading = true;
    _error   = null;
    notifyListeners();

    try {
      // Busca as duas configs em paralelo
      final results = await Future.wait([
        http.get(Uri.parse('$_baseUrl/api/admin/menu-config'))
            .timeout(const Duration(seconds: 8)),
        http.get(Uri.parse('$_baseUrl/api/admin/login-config'))
            .timeout(const Duration(seconds: 8)),
      ]);

      final menuRes  = results[0];
      final loginRes = results[1];

      if (menuRes.statusCode == 200) {
        final body = json.decode(menuRes.body) as Map<String, dynamic>;
        final data = (body['result'] ?? body) as Map<String, dynamic>;
        _config = AppMenuConfig.fromJson(data);
        await _saveMenuToCache(_config);
      }
      if (loginRes.statusCode == 200) {
        final body = json.decode(loginRes.body) as Map<String, dynamic>;
        final data = (body['result'] ?? body) as Map<String, dynamic>;
        _loginConfig = AppLoginConfig.fromJson(data);
        await _saveLoginToCache(_loginConfig);
      }
    } catch (e) {
      _error = 'Falha ao carregar configurações';
      if (kDebugMode) debugPrint('[AppConfigService] load error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Salva config de menus ─────────────────────────────────────────────────
  Future<bool> save(AppMenuConfig newConfig) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/admin/menu-config'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(newConfig.toJson()),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        _config = newConfig;
        await _saveMenuToCache(newConfig);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('[AppConfigService] save error: $e');
      return false;
    }
  }

  // ── Salva config de login ─────────────────────────────────────────────────
  Future<bool> saveLoginConfig(AppLoginConfig newConfig) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/admin/login-config'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(newConfig.toJson()),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        _loginConfig = newConfig;
        await _saveLoginToCache(newConfig);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('[AppConfigService] saveLogin error: $e');
      return false;
    }
  }

  // ── Cache local — menus ───────────────────────────────────────────────────
  Future<void> _loadMenuFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_cacheKey);
      if (raw != null) {
        _config = AppMenuConfig.fromJson(json.decode(raw) as Map<String, dynamic>);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveMenuToCache(AppMenuConfig cfg) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, json.encode(cfg.toJson()));
    } catch (_) {}
  }

  // ── Cache local — login ───────────────────────────────────────────────────
  Future<void> _loadLoginFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_loginCacheKey);
      if (raw != null) {
        _loginConfig = AppLoginConfig.fromJson(json.decode(raw) as Map<String, dynamic>);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveLoginToCache(AppLoginConfig cfg) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_loginCacheKey, json.encode(cfg.toJson()));
    } catch (_) {}
  }
}
