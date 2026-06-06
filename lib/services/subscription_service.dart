import 'package:flutter/foundation.dart';
import '../models/subscription_model.dart';
import '../models/product_model.dart';
import 'firestore_service.dart';

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
  final double? valor;
  final String? message;

  const WithdrawResult({
    required this.success,
    this.txId,
    this.valor,
    this.message,
  });
}

class SubscriptionService extends ChangeNotifier {
  // ── Estado ────────────────────────────────────────────────────────────────
  List<SubscriptionModel> _subscriptions = [];
  bool _isLoading = false;
  String? _error;

  // Carteira interna
  double _saldoDisponivel = 0.0;
  // ignore: prefer_final_fields
  double _saldoPendente = 0.0;
  double _totalSacado = 0.0;

  static const double saqueMinimo = 100.0;

  // Getters
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

  bool get _useFirestore => FirestoreService.isAvailable;

  // ── Carregar assinaturas ──────────────────────────────────────────────────
  Future<void> loadSubscriptions(String affiliateCode) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_useFirestore) {
        // Query simples por affiliateCode (sem orderBy para evitar composite index)
        final snap = await FirestoreService.subscriptions
            ?.where('affiliateCode', isEqualTo: affiliateCode)
            .get();

        if (snap != null) {
          final all = snap.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return _fromFirestore(data);
          }).toList();

          // Ordenar em memória por data de início desc
          all.sort((a, b) => b.dataInicio.compareTo(a.dataInicio));
          _subscriptions = all;
          _calcularSaldo();

          if (kDebugMode) {
            debugPrint('[SubscriptionService] ${_subscriptions.length} assinaturas para $affiliateCode');
          }
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

      // Fallback para mock APENAS em modo demo (sem Firebase)
      if (!_useFirestore) {
        _subscriptions = SubscriptionModel.mockSubscriptions
            .where((s) => s.affiliateCode == affiliateCode)
            .toList();
        _calcularSaldo();
      } else {
        // Firestore disponivel mas sem assinaturas: lista vazia é o correto
        _subscriptions = [];
        _calcularSaldo();
      }
    } catch (e) {
      debugPrint('[SubscriptionService] Erro ao carregar assinaturas: $e');
      _error = 'Erro ao carregar assinaturas. Tente novamente.';
      // Fallback para mock APENAS em modo demo
      if (!_useFirestore) {
        _subscriptions = SubscriptionModel.mockSubscriptions
            .where((s) => s.affiliateCode == affiliateCode)
            .toList();
        _calcularSaldo();
      } else {
        _subscriptions = [];
        _calcularSaldo();
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Autorizar nova assinatura ─────────────────────────────────────────────
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
      if (_useFirestore) {
        // Criar documento de assinatura no Firestore
        final subId = 'sub_${DateTime.now().millisecondsSinceEpoch}';
        final now = DateTime.now();

        final subData = {
          'productId': product.id,
          'productNome': product.nome,
          'valor': product.valor,
          'comissao': product.comissao,
          'affiliateCode': affiliateCode,
          'affiliateNome': null,
          'status': 'ativa',
          'chargeType': product.chargeType.name,
          'dataInicio': now.toIso8601String(),
          'proximaCobranca': _proximaCobranca(product.diaCobranca ?? 5).toIso8601String(),
          'diaCobranca': product.diaCobranca ?? 5,
          'pixKey': clientePixKey,
          'clienteNome': clienteNome,
          'clienteCpf': clienteCpf,
          'clienteCelular': clienteCelular,
          'createdAt': now.toIso8601String(),
        };

        await FirestoreService.subscriptions?.doc(subId).set(subData);

        final nova = SubscriptionModel(
          id: subId,
          productId: product.id,
          productNome: product.nome,
          valor: product.valor,
          comissao: product.comissao,
          affiliateCode: affiliateCode,
          status: SubscriptionStatus.ativa,
          chargeType: product.chargeType,
          dataInicio: now,
          proximaCobranca: _proximaCobranca(product.diaCobranca ?? 5),
          diaCobranca: product.diaCobranca ?? 5,
          pixKey: clientePixKey,
          historico: [],
        );

        _subscriptions.add(nova);
        _calcularSaldo();
        _isLoading = false;
        notifyListeners();

        return SubscribeResult(
          success: true,
          subscriptionId: subId,
          message: product.isPixAutomatico
              ? 'Autorize o Pix Recorrente no seu banco para ativar'
              : 'Assinatura criada com sucesso!',
        );
      }

      // Modo demo sem Firestore
      final nova = SubscriptionModel(
        id: 'sub_demo_${DateTime.now().millisecondsSinceEpoch}',
        productId: product.id,
        productNome: product.nome,
        valor: product.valor,
        comissao: product.comissao,
        affiliateCode: affiliateCode,
        status: SubscriptionStatus.ativa,
        chargeType: product.chargeType,
        dataInicio: DateTime.now(),
        proximaCobranca: _proximaCobranca(product.diaCobranca ?? 5),
        diaCobranca: product.diaCobranca ?? 5,
        pixKey: clientePixKey,
        historico: [],
      );

      _subscriptions.add(nova);
      _calcularSaldo();
      _isLoading = false;
      notifyListeners();

      return const SubscribeResult(
        success: true,
        message: 'Assinatura ativada (modo demonstração)',
        authorizationUrl: null,
      );
    } catch (e) {
      _isLoading = false;
      _error = 'Erro ao criar assinatura. Tente novamente.';
      notifyListeners();
      return SubscribeResult(success: false, message: _error);
    }
  }

  // ── Saque ─────────────────────────────────────────────────────────────────
  Future<WithdrawResult> requestWithdraw({
    required String affiliateCode,
    required String pixKey,
  }) async {
    if (!podeSacar) {
      return WithdrawResult(
        success: false,
        message:
            'Saldo insuficiente. Mínimo para saque: R\$ ${saqueMinimo.toStringAsFixed(2).replaceAll('.', ',')}',
      );
    }

    _isLoading = true;
    notifyListeners();

    try {
      if (_useFirestore) {
        // Registrar saque no Firestore
        final witId = 'wit_${DateTime.now().millisecondsSinceEpoch}';
        final valorSacado = _saldoDisponivel;

        await FirestoreService.withdrawals?.doc(witId).set({
          'affiliateCode': affiliateCode,
          'valor': valorSacado,
          'pixKey': pixKey,
          'status': 'pendente',
          'solicitadoEm': DateTime.now().toIso8601String(),
        });

        _totalSacado += valorSacado;
        _saldoDisponivel = 0.0;
        _isLoading = false;
        notifyListeners();

        return WithdrawResult(
          success: true,
          valor: valorSacado,
          message:
              'Saque de R\$ ${valorSacado.toStringAsFixed(2).replaceAll('.', ',')} solicitado! Aguardando aprovação.',
        );
      }

      // Modo demo
      final valorSacado = _saldoDisponivel;
      _totalSacado += valorSacado;
      _saldoDisponivel = 0.0;
      _isLoading = false;
      notifyListeners();
      return WithdrawResult(
        success: true,
        valor: valorSacado,
        message:
            'Saque de R\$ ${valorSacado.toStringAsFixed(2).replaceAll('.', ',')} enviado via PIX!',
      );
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return const WithdrawResult(
          success: false, message: 'Erro de conexão. Tente novamente.');
    }
  }

  // ── Creditar comissão ─────────────────────────────────────────────────────
  void creditarComissao(double valor) {
    _saldoDisponivel += valor;
    notifyListeners();
  }

  // ── Helpers privados ──────────────────────────────────────────────────────
  void _calcularSaldo() {
    double saldo = 0.0;
    for (final sub in _subscriptions) {
      for (final pay in sub.historico) {
        if (pay.status == PaymentStatus.pago) {
          saldo += sub.valorComissao;
        }
      }
    }
    _saldoDisponivel = saldo;
  }

  DateTime _proximaCobranca(int diaCobranca) {
    final now = DateTime.now();
    DateTime proxima = DateTime(now.year, now.month, diaCobranca);
    if (proxima.isBefore(now)) {
      proxima = DateTime(now.year, now.month + 1, diaCobranca);
    }
    return proxima;
  }

  /// Converte um documento Firestore em SubscriptionModel
  SubscriptionModel _fromFirestore(Map<String, dynamic> j) {
    SubscriptionStatus status;
    switch (j['status'] as String? ?? 'ativa') {
      case 'pendente':
        status = SubscriptionStatus.pendente;
        break;
      case 'cancelada':
        status = SubscriptionStatus.cancelada;
        break;
      case 'aguardando':
        status = SubscriptionStatus.aguardando;
        break;
      default:
        status = SubscriptionStatus.ativa;
    }

    ChargeType ct;
    switch (j['chargeType'] as String? ?? 'pixRecorrente') {
      case 'pixAvulso':
        ct = ChargeType.pixAvulso;
        break;
      case 'unico':
        ct = ChargeType.pixAvulso;
        break;
      default:
        ct = ChargeType.pixRecorrente;
    }

    return SubscriptionModel(
      id: FirestoreService.toStr(j['id']),
      productId: FirestoreService.toStr(j['productId']),
      productNome: FirestoreService.toStr(j['productNome']),
      valor: FirestoreService.toDouble(j['valor']),
      comissao: FirestoreService.toDouble(j['comissao']),
      affiliateCode: FirestoreService.toStr(j['affiliateCode']),
      affiliateNome: j['affiliateNome'] as String?,
      status: status,
      chargeType: ct,
      dataInicio: FirestoreService.toDateTimeOrNow(j['dataInicio']),
      dataCancelamento: FirestoreService.toDateTime(j['dataCancelamento']),
      proximaCobranca: FirestoreService.toDateTimeOrNow(j['proximaCobranca']),
      diaCobranca: FirestoreService.toInt(j['diaCobranca'], fallback: 5),
      pixKey: j['pixKey'] as String?,
      wooviSubscriptionId: j['wooviSubscriptionId'] as String?,
      motivo: j['motivo'] as String?,
      historico: [],
    );
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
