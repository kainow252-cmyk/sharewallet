import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  // ── Carregar dados via Cloudflare D1 ──────────────────────────────────────
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

      // Carteira
      final walletData = results[0] as Map<String, dynamic>?;
      if (walletData != null) {
        final wallet = walletData['wallet'] as Map<String, dynamic>?;
        if (wallet != null) {
          _saldoCarteira  = _toDouble(wallet['saldo_disponivel']);
          _saldoPendente  = _toDouble(wallet['saldo_pendente']);
          _totalRecebido  = _toDouble(wallet['total_recebido']);
          _totalSacado    = _toDouble(wallet['total_sacado']);
          _totalIndicados = _toInt(wallet['total_indicados']);
        }
        // Sales e withdrawals já vêm no walletData também
        final salesRaw = walletData['sales'] as List? ?? [];
        final wdsRaw   = walletData['withdrawals'] as List? ?? [];
        _sales    = salesRaw.map((r) => SaleModel.fromD1(r as Map<String, dynamic>)).toList();
        _withdraws = wdsRaw.map((r) => WithdrawModel.fromD1(r as Map<String, dynamic>)).toList();
      } else {
        // Fallback: usa os resultados separados
        final salesRaw = results[1] as List<Map<String, dynamic>>;
        final wdsRaw   = results[2] as List<Map<String, dynamic>>;
        _sales    = salesRaw.map((r) => SaleModel.fromD1(r)).toList();
        _withdraws = wdsRaw.map((r) => WithdrawModel.fromD1(r)).toList();
      }

      if (kDebugMode) {
        debugPrint('[WalletService] D1 — saldo=R\$$_saldoCarteira '
            'sales=${_sales.length} withdrawals=${_withdraws.length}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[WalletService] Erro: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Solicitar Saque via D1 ────────────────────────────────────────────────
  Future<WithdrawResult> solicitarSaque({
    required double valor,
    required String pixKey,
    String? pixKeyType,
    double? saldoAtual,
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
      final result = await CfApiService.createWithdrawal({
        'userId': uid,
        'valor': valor,
        'pixKey': pixKey,
        'affiliateCode': '',
        'affiliateNome': '',
      });

      if (result != null) {
        // Atualiza saldo local
        _saldoCarteira -= valor;
        _saldoPendente += valor;
        final wd = WithdrawModel.fromD1(result);
        _withdraws.insert(0, wd);
        _isLoading = false;
        notifyListeners();
        return WithdrawResult(success: true, message: 'Saque solicitado!', value: valor, pixKey: pixKey);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[WalletService] Erro saque: $e');
    }

    _isLoading = false;
    notifyListeners();
    return WithdrawResult(success: false, message: 'Erro ao solicitar saque. Tente novamente.');
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
