import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
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

  double get totalComissoes =>
      salesCompleted.fold(0.0, (sum, s) => sum + s.comissao);

  double get comissoesEsteMes {
    final agora = DateTime.now();
    return salesCompleted
        .where((s) => s.createdAt.month == agora.month && s.createdAt.year == agora.year)
        .fold(0.0, (sum, s) => sum + s.comissao);
  }

  // -- Carregar dados via Cloudflare D1 --------------------------------------
  Future<void> loadData({String? userId, bool forceRefresh = false}) async {
    if (!forceRefresh && (_sales.isNotEmpty || _saldoCarteira > 0)) return;

    _isLoading = true;
    notifyListeners();

    try {
      final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

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
    } catch (e) {
      if (kDebugMode) debugPrint('[WalletService] Erro loadData: $e');
    }

    _isLoading = false;
    notifyListeners();
  }


  // -- Solicitar Saque via Woovi — endpoint unificado (sem subconta) -----------
  // Usa POST /api/wallet/:userId/withdraw que:
  // 1. Valida saldo disponível
  // 2. Usa a chave Pix já cadastrada em affiliates.pix_key
  // 3. Chama POST /api/v1/payment (destinationAlias) + POST /api/v1/payment/approve
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

      // Endpoint unificado: valida + cria withdrawal + chama Woovi em 1 passo
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
        final msgWoovi    = respData['message']?.toString() ?? 'Saque enviado!';
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
          message: msgWoovi,
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


