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


  // -- Solicitar Saque via Woovi (subconta → Pix para chave do afiliado) -----
  Future<WithdrawResult> solicitarSaque({
    required double valor,
    required String pixKey,
    String? pixKeyType,
    double? saldoAtual,
    String affiliateCode = '',
    String affiliateNome = '',
  }) async {
    if ((saldoAtual ?? _saldoCarteira) < 10.0) {
      return WithdrawResult(success: false, message: 'Saldo insuficiente. Mínimo R\$10,00');
    }
    if (valor > (saldoAtual ?? _saldoCarteira)) {
      return WithdrawResult(success: false, message: 'Valor maior que o saldo disponível');
    }

    _isLoading = true;
    notifyListeners();

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

      // 1. Registra o saque no D1 com status 'pendente'
      final result = await CfApiService.createWithdrawal({
        'userId': uid,
        'valor': valor,
        'pixKey': pixKey,
        'pixKeyType': pixKeyType ?? 'EMAIL',
        'affiliateCode': affiliateCode,
        'affiliateNome': affiliateNome,
      });

      if (result == null) {
        _isLoading = false;
        notifyListeners();
        return WithdrawResult(success: false, message: 'Erro ao registrar saque. Tente novamente.');
      }

      final withdrawalId = result['id']?.toString() ?? '';

      // 2. Dispara Pix Out via Woovi (Worker chama /api/v1/subaccount/{pixKey}/withdraw)
      final wooviResult = await _enviarPixWoovi(withdrawalId: withdrawalId, valor: valor);

      if (wooviResult.success) {
        _saldoCarteira -= valor;
        _totalSacado += valor;
        final wd = WithdrawModel.fromD1({
          ...result,
          'status': wooviResult.status == 'processando' ? 'processando' : 'aprovado',
          'tx_id': wooviResult.txId,
        });
        _withdraws.insert(0, wd);
        _isLoading = false;
        notifyListeners();
        return WithdrawResult(
          success: true,
          message: 'PIX enviado! Em instantes o valor chegará na sua conta.',
          value: valor,
          pixKey: pixKey,
        );
      } else {
        // Woovi falhou: saque fica pendente, admin pode reprocessar
        _saldoCarteira -= valor;
        _saldoPendente += valor;
        final wd = WithdrawModel.fromD1(result);
        _withdraws.insert(0, wd);
        _isLoading = false;
        notifyListeners();
        if (kDebugMode) debugPrint('[WalletService] Woovi saque falhou: ${wooviResult.error}');
        return WithdrawResult(
          success: true,
          message: 'Saque solicitado! Será processado em até 1 hora útil.',
          value: valor,
          pixKey: pixKey,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[WalletService] Erro saque: $e');
    }

    _isLoading = false;
    notifyListeners();
    return WithdrawResult(success: false, message: 'Erro ao solicitar saque. Tente novamente.');
  }

  // -- Chama o Worker que processa o Pix Out via Woovi ----------------------
  Future<_WooviPixResult> _enviarPixWoovi({
    required String withdrawalId,
    required double valor,
  }) async {
    try {
      final uri = Uri.parse(
          'https://api.sharewallet.com.br/api/withdrawals/$withdrawalId/pay');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({}), // Worker usa apenas o withdrawalId — pixKey vem do D1
      ).timeout(const Duration(seconds: 30));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (kDebugMode) debugPrint('[WalletService] Woovi /pay (${res.statusCode}): $body');

      if (res.statusCode == 200 && body['status'] != null) {
        return _WooviPixResult(
          success: true,
          status: body['status'] as String? ?? 'aprovado',
          txId: body['id']?.toString() ?? withdrawalId,
        );
      }

      return _WooviPixResult(
        success: false,
        error: body['error']?.toString() ?? 'Erro Woovi (${res.statusCode})',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[WalletService] Erro Woovi /pay: $e');
      return _WooviPixResult(success: false, error: e.toString());
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

// -- Resultado interno do Pix Woovi ------------------------------------------
class _WooviPixResult {
  final bool success;
  final String status;  // 'aprovado' | 'processando'
  final String? txId;
  final String? error;
  const _WooviPixResult({
    required this.success,
    this.status = 'aprovado',
    this.txId,
    this.error,
  });
}

