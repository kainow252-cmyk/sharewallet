import 'package:flutter/foundation.dart';
import '../models/subscription_model.dart';
import '../models/product_model.dart';
import 'cf_api_service.dart';

// ── Resultado da autorização de assinatura ───────────────────────────────────
class SubscribeResult {
  final bool success;
  final String? subscriptionId;
  final String? wooviSubscriptionId;
  final String? message;
  final String? authorizationUrl;

  const SubscribeResult({
    required this.success,
    this.subscriptionId,
    this.wooviSubscriptionId,
    this.message,
    this.authorizationUrl,
  });
}

// ── Resultado do saque ────────────────────────────────────────────────────────
class WithdrawResult {
  final bool success;
  final String? txId;
  final double value;
  final String? pixKey;
  final String? message;

  const WithdrawResult({
    required this.success,
    this.txId,
    this.value = 0,
    this.pixKey,
    this.message,
  });
}

class SubscriptionService extends ChangeNotifier {
  List<SubscriptionModel> _subscriptions = [];
  bool _isLoading = false;
  String? _error;

  double _saldoDisponivel = 0.0;
  double _saldoPendente = 0.0;
  double _totalSacado = 0.0;

  static const double saqueMinimo = 10.0;

  List<SubscriptionModel> get subscriptions => _subscriptions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get saldoDisponivel => _saldoDisponivel;
  double get saldoPendente => _saldoPendente;
  double get totalSacado => _totalSacado;
  bool get podeSacar => _saldoDisponivel >= saqueMinimo;

  List<SubscriptionModel> get ativas =>
      _subscriptions.where((s) => s.status == SubscriptionStatus.ativa).toList();
  List<SubscriptionModel> get pendentes =>
      _subscriptions.where((s) => s.status == SubscriptionStatus.pendente).toList();

  int get totalAtivas => ativas.length;
  int get totalPendentes => pendentes.length;

  double get comissoesMensaisRecorrentes =>
      ativas.fold(0.0, (sum, s) => sum + s.valorComissao);

  // ── Carregar assinaturas via D1 ───────────────────────────────────────────
  Future<void> loadSubscriptions(String affiliateCode) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final rows = await CfApiService.getSubscriptionsByAffiliate(affiliateCode);
      _subscriptions = rows.map((r) => _fromD1(r)).toList();
      _subscriptions.sort((a, b) => b.dataInicio.compareTo(a.dataInicio));
      if (kDebugMode) debugPrint('[SubscriptionService] ${_subscriptions.length} assinaturas (D1)');
    } catch (e) {
      debugPrint('[SubscriptionService] Erro: $e');
      _error = 'Erro ao carregar assinaturas.';
      _subscriptions = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Criar assinatura via D1 ───────────────────────────────────────────────
  Future<SubscribeResult> subscribe({
    required ProductModel product,
    required String clienteNome,
    required String clienteCpf,
    required String clienteCelular,
    required String clientePixKey,
    required String affiliateCode,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final proxima = _proximaCobranca(product.diaCobranca ?? 5);

      final result = await CfApiService.createSubscription({
        'productId': product.id,
        'productNome': product.nome,
        'valor': product.valor,
        'comissao': product.comissao,
        'affiliateCode': affiliateCode,
        'chargeType': product.chargeType.name,
        'status': 'ativa',
        'pixKey': clientePixKey,
        'diaCobranca': product.diaCobranca ?? 5,
        'dataInicio': now.toIso8601String(),
        'proximaCobranca': proxima.toIso8601String(),
      });

      if (result != null) {
        final nova = _fromD1(result);
        _subscriptions.add(nova);
        _isLoading = false;
        notifyListeners();
        return SubscribeResult(
          success: true,
          subscriptionId: result['id']?.toString(),
          message: product.isPixAutomatico
              ? 'Autorize o Pix Recorrente no seu banco para ativar'
              : 'Assinatura criada com sucesso!',
        );
      }
    } catch (e) {
      debugPrint('[SubscriptionService] Erro subscribe: $e');
    }

    _isLoading = false;
    _error = 'Erro ao criar assinatura. Tente novamente.';
    notifyListeners();
    return SubscribeResult(success: false, message: _error);
  }

  void creditarComissao(double valor) {
    _saldoDisponivel += valor;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  DateTime _proximaCobranca(int diaCobranca) {
    final now = DateTime.now();
    DateTime proxima = DateTime(now.year, now.month, diaCobranca);
    if (proxima.isBefore(now)) {
      proxima = DateTime(now.year, now.month + 1, diaCobranca);
    }
    return proxima;
  }

  static SubscriptionModel _fromD1(Map<String, dynamic> r) {
    SubscriptionStatus status;
    switch (r['status']?.toString() ?? 'ativa') {
      case 'pendente':   status = SubscriptionStatus.pendente;   break;
      case 'cancelada':  status = SubscriptionStatus.cancelada;  break;
      case 'aguardando': status = SubscriptionStatus.aguardando; break;
      default:           status = SubscriptionStatus.ativa;
    }

    ChargeType ct;
    switch (r['charge_type']?.toString() ?? 'pixRecorrente') {
      case 'pixAvulso': ct = ChargeType.pixAvulso; break;
      default:          ct = ChargeType.pixRecorrente;
    }

    DateTime parse(dynamic v) =>
        v != null ? DateTime.tryParse(v.toString()) ?? DateTime.now() : DateTime.now();

    return SubscriptionModel(
      id: r['id']?.toString() ?? '',
      productId: r['product_id']?.toString() ?? '',
      productNome: r['product_nome']?.toString() ?? '',
      valor: (r['valor'] as num? ?? 0).toDouble(),
      comissao: (r['comissao'] as num? ?? 0).toDouble(),
      affiliateCode: r['affiliate_code']?.toString() ?? '',
      affiliateNome: r['affiliate_nome']?.toString(),
      status: status,
      chargeType: ct,
      dataInicio: parse(r['data_inicio']),
      dataCancelamento: r['data_cancelamento'] != null
          ? DateTime.tryParse(r['data_cancelamento'].toString()) : null,
      proximaCobranca: parse(r['proxima_cobranca']),
      diaCobranca: (r['dia_cobranca'] as num? ?? 5).toInt(),
      pixKey: r['pix_key']?.toString(),
      wooviSubscriptionId: r['woovi_subscription_id']?.toString(),
      motivo: r['motivo']?.toString(),
      historico: [],
    );
  }
}
