import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/sale_model.dart';
import '../models/withdraw_model.dart';
import 'cf_api_service.dart';
import 'mercadopago_service.dart';
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
        _sales     = salesRaw.map((r) => SaleModel.fromD1(r as Map<String, dynamic>)).toList();
        _withdraws = wdsRaw.map((r) => WithdrawModel.fromD1(r as Map<String, dynamic>)).toList();
      } else {
        // Fallback: usa os resultados separados
        final salesRaw = results[1] as List<Map<String, dynamic>>;
        final wdsRaw   = results[2] as List<Map<String, dynamic>>;
        _sales     = salesRaw.map((r) => SaleModel.fromD1(r)).toList();
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

  // ── Solicitar Saque via D1 + MercadoPago automático ───────────────────────
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

      // 1️⃣ Registra o saque no D1 com status 'pendente'
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

      // 2️⃣ Dispara PIX via MercadoPago automaticamente
      final mpResult = await _enviarPixMercadoPago(
        withdrawalId: withdrawalId,
        valor: valor,
        pixKey: pixKey,
        pixKeyType: pixKeyType ?? 'EMAIL',
        affiliateNome: affiliateNome,
      );

      if (mpResult.success) {
        // MP processou: marca como 'aprovado' no D1
        await CfApiService.approveWithdrawal(withdrawalId, txId: mpResult.txId);
        // Atualiza saldo local
        _saldoCarteira -= valor;
        final wd = WithdrawModel.fromD1({
          ...result,
          'status': 'aprovado',
          'tx_id': mpResult.txId,
        });
        _withdraws.insert(0, wd);
        _isLoading = false;
        notifyListeners();
        return WithdrawResult(
          success: true,
          message: 'PIX enviado com sucesso! 🎉',
          value: valor,
          pixKey: pixKey,
        );
      } else {
        // MP falhou: saque fica pendente para admin processar
        _saldoCarteira -= valor;
        _saldoPendente += valor;
        final wd = WithdrawModel.fromD1(result);
        _withdraws.insert(0, wd);
        _isLoading = false;
        notifyListeners();
        if (kDebugMode) debugPrint('[WalletService] MP falhou, saque pendente: ${mpResult.error}');
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

  // ── Enviar PIX via MercadoPago (delega ao Worker para evitar CORS) ────────
  Future<_MpPixResult> _enviarPixMercadoPago({
    required String withdrawalId,
    required double valor,
    required String pixKey,
    required String pixKeyType,
    required String affiliateNome,
  }) async {
    try {
      final mpService = MercadoPagoService();
      await mpService.loadConfig();
      final creds = mpService.config.active;

      if (creds.isEmpty) {
        return _MpPixResult(success: false, error: 'Credenciais MP não configuradas');
      }

      // Mapeia tipo para formato MP
      String mpKeyType;
      switch (pixKeyType.toUpperCase()) {
        case 'CPF':       mpKeyType = 'cpf';        break;
        case 'EMAIL':     mpKeyType = 'email';       break;
        case 'PHONE':     mpKeyType = 'phone';       break;
        case 'ALEATORIA': mpKeyType = 'random_key';  break;
        default:          mpKeyType = 'email';       break;
      }

      return await _enviarPixViaWorker(
        withdrawalId: withdrawalId,
        valor: valor,
        pixKey: pixKey,
        pixKeyType: mpKeyType,
        affiliateNome: affiliateNome,
        accessToken: creds.accessToken,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[WalletService] Erro MP PIX: $e');
      return _MpPixResult(success: false, error: e.toString());
    }
  }

  // ── Chama o Worker que processa o PIX server-side ─────────────────────────
  Future<_MpPixResult> _enviarPixViaWorker({
    required String withdrawalId,
    required double valor,
    required String pixKey,
    required String pixKeyType,
    required String affiliateNome,
    required String accessToken,
  }) async {
    try {
      final uri = Uri.parse(
          'https://sharewallet-api.kainow252.workers.dev/api/withdrawals/$withdrawalId/pay');
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'X-MP-Token': accessToken,
        },
        body: jsonEncode({
          'valor': valor,
          'pixKey': pixKey,
          'pixKeyType': pixKeyType,
          'affiliateNome': affiliateNome,
        }),
      ).timeout(const Duration(seconds: 30));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (kDebugMode) debugPrint('[WalletService] Worker /pay response: $body');

      if (body['success'] == true) {
        final txId = body['result']?['id']?.toString()
            ?? body['result']?['tx_id']?.toString()
            ?? withdrawalId;
        return _MpPixResult(success: true, txId: txId);
      } else {
        return _MpPixResult(
          success: false,
          error: body['error']?.toString() ?? 'Erro no Worker',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[WalletService] Erro Worker /pay: $e');
      return _MpPixResult(success: false, error: e.toString());
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

// ── Resultado interno do PIX MercadoPago ─────────────────────────────────────
class _MpPixResult {
  final bool success;
  final String? txId;
  final String? error;
  const _MpPixResult({required this.success, this.txId, this.error});
}
