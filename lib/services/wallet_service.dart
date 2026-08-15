import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/sale_model.dart';
import '../models/withdraw_model.dart';
import 'cf_api_service.dart';
import 'subscription_service.dart'; // WithdrawResult

class WalletService extends ChangeNotifier {
  List<SaleModel> _sales = [];
  List<WithdrawModel> _withdraws = [];
  bool _isLoading = false;
  int _totalIndicados = 0;
  double _saldoCarteira = 0.0;
  double _saldoPendente = 0.0;
  double _totalRecebido = 0.0;
  double _totalSacado = 0.0;
  double _saqueMinimo = 0.0; // dinâmico: vem do Worker (max entre individual e global)
  double _saqueMaximo = 0.0; // dinâmico: máximo global configurado pelo admin

  List<SaleModel> get sales => _sales;
  List<SaleModel> get salesCompleted => _sales.where((s) => s.isCompleted).toList();
  List<WithdrawModel> get withdraws => _withdraws;
  bool get isLoading => _isLoading;
  int get totalIndicados => _totalIndicados;
  int get totalVendas => salesCompleted.length;

  double get saldoCarteira => _saldoCarteira;
  double get saldoPendente => _saldoPendente;
  double get totalRecebido => _totalRecebido;
  double get totalSacado => _totalSacado;
  /// Limite mínimo de saque do afiliado (maior entre individual e global).
  double get saqueMinimo => _saqueMinimo;
  /// Limite máximo de saque global (0 = sem limite).
  double get saqueMaximo => _saqueMaximo;
  /// Retorna true se o afiliado tem saldo suficiente para sacar
  bool get podeSacar => _saqueMinimo <= 0 || _saldoCarteira >= _saqueMinimo;

  double get totalComissoes =>
      salesCompleted.fold(0.0, (sum, s) => sum + s.comissao);

  double get comissoesEsteMes {
    final agora = DateTime.now();
    return salesCompleted
        .where((s) => s.createdAt.month == agora.month && s.createdAt.year == agora.year)
        .fold(0.0, (sum, s) => sum + s.comissao);
  }

  // -- Cache local: persiste último saldo/dados entre sessões -----------------
  static const String _cacheKey = 'wallet_cache_v1';

  /// Pré-popula saldo a partir do cache local (SharedPreferences).
  /// Chamado ANTES do request ao Worker — tela aparece instantânea.
  Future<void> _prePopulateFromCache(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('${_cacheKey}_$uid');
      if (raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _saldoCarteira  = (data['saldo'] as num?)?.toDouble() ?? 0.0;
      _saldoPendente  = (data['pendente'] as num?)?.toDouble() ?? 0.0;
      _totalRecebido  = (data['recebido'] as num?)?.toDouble() ?? 0.0;
      _totalSacado    = (data['sacado'] as num?)?.toDouble() ?? 0.0;
      _totalIndicados = (data['indicados'] as num?)?.toInt() ?? 0;
      // Sales do cache
      final salesRaw = data['sales'] as List?;
      if (salesRaw != null && salesRaw.isNotEmpty) {
        _sales = salesRaw
            .map((r) => SaleModel.fromD1(r as Map<String, dynamic>))
            .toList();
      }
      notifyListeners(); // Renderiza com dados do cache IMEDIATAMENTE
      if (kDebugMode) debugPrint('[WalletService] Cache local carregado — saldo=R\$$_saldoCarteira');
    } catch (_) {}
  }

  /// Persiste dados atuais no cache local após sucesso do Worker.
  Future<void> _saveToCache(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'saldo': _saldoCarteira,
        'pendente': _saldoPendente,
        'recebido': _totalRecebido,
        'sacado': _totalSacado,
        'indicados': _totalIndicados,
        'sales': _sales.take(20).map((s) => s.toD1Map()).toList(),
      };
      await prefs.setString('${_cacheKey}_$uid', jsonEncode(data));
    } catch (_) {}
  }

  // -- Carregar dados via Cloudflare D1 --------------------------------------
  Future<void> loadData({String? userId, bool forceRefresh = false}) async {
    // Se já tem dados em memória e não é forceRefresh, não vai ao Worker
    if (!forceRefresh && (_sales.isNotEmpty || _saldoCarteira > 0)) return;

    final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // INSTANTÂNEO: carrega cache local ANTES de ir ao Worker
    // → Tela aparece com dados reais da última sessão em <50ms
    final temCache = _saldoCarteira == 0 && _sales.isEmpty;
    if (temCache) await _prePopulateFromCache(uid);

    // Agora vai buscar dados frescos no Worker (em background se tinha cache)
    _isLoading = true;
    notifyListeners();

    try {
      // Busca carteira + sales + withdrawals em paralelo
      final results = await Future.wait([
        CfApiService.getWallet(uid),
        CfApiService.getSalesByUser(uid),
        CfApiService.getWithdrawalsByUser(uid),
      ]);

      // Carteira - trata {"wallet":{...}} ou objeto direto com saldo_disponivel
      final walletRaw = results[0] as Map<String, dynamic>?;
      final wallet = (walletRaw?['wallet'] as Map<String, dynamic>?)
                  ?? (walletRaw?.containsKey('saldo_disponivel') == true ? walletRaw : null);

      if (wallet != null) {
        _saldoCarteira  = _toDouble(wallet['saldo_disponivel']);
        _saldoPendente  = _toDouble(wallet['saldo_pendente']);
        _totalRecebido  = _toDouble(wallet['total_recebido']);
        _totalSacado    = _toDouble(wallet['total_sacado']);
        _totalIndicados = _toInt(wallet['total_indicados']);
      }

      // Carrega saque_minimo e saque_maximo dinâmicos (retornados junto com a wallet pelo Worker)
      if (walletRaw != null) {
        if (walletRaw.containsKey('saque_minimo')) {
          final sm = walletRaw['saque_minimo'];
          if (sm != null) _saqueMinimo = _toDouble(sm);
        }
        if (walletRaw.containsKey('saque_maximo')) {
          final sx = walletRaw['saque_maximo'];
          if (sx != null) _saqueMaximo = _toDouble(sx);
        }
      }

      // Sales: usa walletData['sales'] se existir, senão resultado separado
      final salesList = (walletRaw?['sales'] as List?)
                     ?? (results[1] as List? ?? []);
      final wdsList   = (walletRaw?['withdrawals'] as List?)
                     ?? (results[2] as List? ?? []);

      _sales     = salesList.map((r) => SaleModel.fromD1(r as Map<String, dynamic>)).toList();
      _withdraws = wdsList.map((r) => WithdrawModel.fromD1(r as Map<String, dynamic>)).toList();

      if (kDebugMode) {
        debugPrint('[WalletService] D1  -  uid=$uid '
            'saldo=R\$$_saldoCarteira '
            'wallet=${wallet != null} '
            'sales=${_sales.length} withdrawals=${_withdraws.length}');
      }

      // Persiste no cache local para próxima abertura ser instantânea
      _saveToCache(uid).catchError((_) {});

    } catch (e) {
      if (kDebugMode) debugPrint('[WalletService] Erro loadData: $e');
      // Erro no Worker — mantém dados do cache (não limpa)
    }

    _isLoading = false;
    notifyListeners();
  }


  // -- Solicitar Saque via Mercado Pago PIX Out — endpoint unificado -----------
  // Usa POST /api/wallet/:userId/withdraw que:
  // 1. Valida saldo disponível
  // 2. Usa a chave Pix já cadastrada em affiliates.pix_key
  // 3. Chama POST /v1/payments (MP PIX Out: operation_type=money_transfer)
  // Para cadastrar/atualizar chave Pix: use salvarChavePix() abaixo.
  Future<WithdrawResult> solicitarSaque({
    required double valor,
    String? pixKey,          // se null, usa a chave cadastrada no perfil
    String? pixKeyType,
    double? saldoAtual,
    String affiliateCode = '',
    String affiliateNome = '',
  }) async {
    if ((saldoAtual ?? _saldoCarteira) < 1.0) {
      return WithdrawResult(success: false, message: 'Saldo insuficiente.');
    }
    if (valor > (saldoAtual ?? _saldoCarteira)) {
      return WithdrawResult(success: false, message: 'Valor maior que o saldo disponível.');
    }
    if (valor <= 0) {
      return WithdrawResult(success: false, message: 'Valor de saque inválido.');
    }

    _isLoading = true;
    notifyListeners();

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.isEmpty) {
        _isLoading = false;
        notifyListeners();
        return WithdrawResult(success: false, message: 'Usuário não autenticado.');
      }

      // Endpoint unificado: valida + cria withdrawal + chama Mercado Pago PIX Out
      final uri = Uri.parse('https://api.sharewallet.com.br/api/wallet/$uid/withdraw');
      final body = <String, dynamic>{'valor': valor};
      // pixKey opcional — se informado, é ignorado pelo worker (usa o cadastrado no perfil)
      // mas enviamos para log/auditoria
      if (pixKey != null && pixKey.isNotEmpty) body['pixKey'] = pixKey;

      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 35));

      final respData = jsonDecode(res.body) as Map<String, dynamic>;
      if (kDebugMode) debugPrint('[WalletService] /withdraw (${res.statusCode}): $respData');

      if (res.statusCode == 200) {
        final status      = respData['status']?.toString() ?? 'processando';
        final destAlias   = respData['destinationAlias']?.toString() ?? pixKey ?? '';
        final destType    = respData['destinationType']?.toString() ?? '';
        final msgSaque    = respData['message']?.toString() ?? 'Saque enviado!';
        final wdData      = respData['withdrawal'] as Map<String, dynamic>? ?? {};

        // Atualiza saldo local imediatamente (otimistic update)
        _saldoCarteira -= valor;
        if (status == 'aprovado') {
          _totalSacado += valor;
        } else {
          _saldoPendente += valor;
        }

        final wd = WithdrawModel.fromD1({
          'id': respData['id'] ?? wdData['id'] ?? '',
          'user_id': uid,
          'valor': valor,
          'pix_key': destAlias,
          'status': status,
          'affiliate_nome': affiliateNome,
          'affiliate_code': affiliateCode,
          'solicitado_em': DateTime.now().toIso8601String(),
          'processado_em': status == 'aprovado' ? DateTime.now().toIso8601String() : null,
          'tx_id': respData['id'] ?? '',
          'motivo': destType.isNotEmpty ? '$destType: $destAlias' : destAlias,
        });
        _withdraws.insert(0, wd);

        _isLoading = false;
        notifyListeners();
        return WithdrawResult(
          success: true,
          message: msgSaque,
          value: valor,
          pixKey: destAlias,
          status: status,
        );

      } else {
        // Erro retornado pelo worker (validação, saldo insuficiente, chave inválida, etc.)
        final errorMsg = respData['error']?.toString()
            ?? respData['message']?.toString()
            ?? 'Erro ao processar saque (${res.statusCode})';
        _isLoading = false;
        notifyListeners();
        return WithdrawResult(success: false, message: errorMsg);
      }

    } catch (e) {
      if (kDebugMode) debugPrint('[WalletService] Erro saque: $e');
      _isLoading = false;
      notifyListeners();
      return WithdrawResult(success: false, message: 'Erro de conexão. Verifique sua internet e tente novamente.');
    }
  }

  // -- Cadastrar/atualizar chave Pix do afiliado ------------------------------
  // Chama PATCH /api/wallet/:userId/pix-key
  // Retorna null se sucesso, ou mensagem de erro
  Future<String?> salvarChavePix(String pixKey) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return 'Usuário não autenticado.';
    if (pixKey.trim().isEmpty) return 'Informe a chave Pix.';

    try {
      final uri = Uri.parse('https://api.sharewallet.com.br/api/wallet/$uid/pix-key');
      final res = await http.patch(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'pixKey': pixKey.trim()}),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && data['success'] == true) {
        if (kDebugMode) debugPrint('[WalletService] Chave Pix salva: $pixKey');
        return null; // sucesso
      }
      return data['error']?.toString() ?? 'Erro ao salvar chave Pix (${res.statusCode})';
    } catch (e) {
      if (kDebugMode) debugPrint('[WalletService] Erro salvarChavePix: $e');
      return 'Erro de conexão ao salvar chave Pix.';
    }
  }

  void adicionarVenda(SaleModel sale) {
    _sales.insert(0, sale);
    notifyListeners();
  }

  List<Map<String, dynamic>> get extratoCompleto {
    final List<Map<String, dynamic>> items = [];
    for (final sale in salesCompleted) {
      items.add({
        'tipo': 'comissao',
        'descricao': 'Comissão - ${sale.productNome}',
        'valor': sale.comissao,
        'positivo': true,
        'data': sale.createdAt,
        'status': sale.status,
      });
    }
    for (final w in _withdraws) {
      items.add({
        'tipo': 'saque',
        'descricao': 'Saque PIX',
        'valor': w.valor,
        'positivo': false,
        'data': w.createdAt,
        'status': w.status,
      });
    }
    items.sort((a, b) => (b['data'] as DateTime).compareTo(a['data'] as DateTime));
    return items;
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}


