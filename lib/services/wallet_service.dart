import 'package:flutter/foundation.dart';
import '../models/sale_model.dart';
import '../models/withdraw_model.dart';
import 'api_service.dart';
import 'woovi_service.dart';
import 'firestore_service.dart';

class WalletService extends ChangeNotifier {
  List<SaleModel> _sales = [];
  List<WithdrawModel> _withdraws = [];
  bool _isLoading = false;
  int _totalIndicados = 0;
  double _balanceFromServer = 0; // ignore: unused_field

  List<SaleModel> get sales => _sales;
  List<SaleModel> get salesCompleted => _sales.where((s) => s.isCompleted).toList();
  List<WithdrawModel> get withdraws => _withdraws;
  bool get isLoading => _isLoading;
  int get totalIndicados => _totalIndicados;
  int get totalVendas => salesCompleted.length;

  double get totalComissoes =>
      salesCompleted.fold(0.0, (sum, s) => sum + s.comissao);

  double get comissoesEsteMes {
    final agora = DateTime.now();
    return salesCompleted
        .where((s) =>
            s.createdAt.month == agora.month &&
            s.createdAt.year == agora.year)
        .fold(0.0, (sum, s) => sum + s.comissao);
  }

  // ── Carregar dados ────────────────────────────────────────────────────────

  Future<void> loadData({String? userId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (ApiService.hasToken) {
        // Modo real via API NestJS
        await Future.wait([_loadSales(), _loadWithdrawals(), _loadDashboard()]);
      } else if (userId != null && FirestoreService.isAvailable) {
        // Modo Firestore direto — busca vendas e saques do usuário
        await Future.wait([
          _loadSalesFromFirestore(userId),
          _loadWithdrawalsFromFirestore(userId),
          _loadAffiliateDataFromFirestore(userId),
        ]);
      } else {
        // Modo demo
        await Future.delayed(const Duration(milliseconds: 800));
        _sales = SaleModel.mockSales;
        _withdraws = WithdrawModel.mockWithdraws;
        _totalIndicados = 53;
      }
    } catch (e) {
      _sales = SaleModel.mockSales;
      _withdraws = WithdrawModel.mockWithdraws;
      _totalIndicados = 53;
      if (kDebugMode) debugPrint('WalletService erro: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadSalesFromFirestore(String userId) async {
    try {
      final col = FirestoreService.collection('sales');
      if (col == null) return;
      final snap = await col.where('user_id', isEqualTo: userId).get();
      final all = snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] = d.id;
        return SaleModel.fromJson(data);
      }).toList();
      // Ordenar por data em memória
      all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _sales = all;
    } catch (e) {
      if (kDebugMode) debugPrint('[WalletService] Erro sales Firestore: $e');
    }
  }

  Future<void> _loadWithdrawalsFromFirestore(String userId) async {
    try {
      final col = FirestoreService.withdrawals;
      if (col == null) return;
      final snap = await col.where('user_id', isEqualTo: userId).get();
      final all = snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] = d.id;
        return WithdrawModel.fromJson(data);
      }).toList();
      all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _withdraws = all;
    } catch (e) {
      if (kDebugMode) debugPrint('[WalletService] Erro withdrawals Firestore: $e');
    }
  }

  Future<void> _loadAffiliateDataFromFirestore(String userId) async {
    try {
      final col = FirestoreService.affiliates;
      if (col == null) return;
      final snap = await col
          .where('firebase_uid', isEqualTo: userId)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        _totalIndicados = FirestoreService.toInt(data['total_referrals']);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[WalletService] Erro affiliate Firestore: $e');
    }
  }

  Future<void> _loadSales() async {
    final response = await ApiService.get('/sales/my?page=1&limit=50');
    if (response.success && response.data != null) {
      final List<dynamic> salesData = response.data['data'] ?? [];
      _sales = salesData.map((json) => SaleModel.fromApiJson(json)).toList();
    }
  }

  Future<void> _loadWithdrawals() async {
    final response = await ApiService.get('/withdrawals/history?page=1&limit=50');
    if (response.success && response.data != null) {
      final List<dynamic> withdrawsData = response.data['data'] ?? [];
      _withdraws =
          withdrawsData.map((json) => WithdrawModel.fromApiJson(json)).toList();
    }
  }

  Future<void> _loadDashboard() async {
    final dashboard = await WooviService.getDashboard();
    if (dashboard != null) {
      _totalIndicados = dashboard['totalReferrals'] as int? ?? 0;
      _balanceFromServer =
          (dashboard['balanceInReais'] as num?)?.toDouble() ?? 0;
    }
  }

  // ── Solicitar Saque ───────────────────────────────────────────────────────

  Future<WithdrawResult> solicitarSaque({
    double? valor,
    String? pixKey,
    String? pixKeyType,
    double? saldoAtual,
  }) async {
    // Validações básicas (frontend)
    if (saldoAtual != null && saldoAtual < 10.0) {
      return WithdrawResult(
        success: false,
        message: 'Saldo insuficiente. Mínimo R\$10,00',
      );
    }

    _isLoading = true;
    notifyListeners();

    // Chama o backend → que chama a Woovi
    final result = await WooviService.requestWithdraw();

    if (result.success) {
      // Registra localmente o saque enquanto aguarda webhook
      final novoSaque = WithdrawModel(
        id: 'w_${DateTime.now().millisecondsSinceEpoch}',
        userId: 'current',
        valor: result.value,
        pixKey: result.pixKey ?? pixKey ?? '',
        pixKeyType: pixKeyType ?? 'EMAIL',
        status: 'PROCESSING',
        createdAt: DateTime.now(),
      );
      _withdraws.insert(0, novoSaque);
    }

    _isLoading = false;
    notifyListeners();

    return result;
  }

  // ── Adicionar venda recebida via WebSocket/Push ───────────────────────────

  void adicionarVenda(SaleModel sale) {
    _sales.insert(0, sale);
    notifyListeners();
  }

  // ── Extrato completo (vendas + saques) ────────────────────────────────────

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

    items.sort(
        (a, b) => (b['data'] as DateTime).compareTo(a['data'] as DateTime));
    return items;
  }
}
