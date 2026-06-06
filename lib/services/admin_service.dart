import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import '../models/product_model.dart';
import '../models/subscription_model.dart';
import 'firestore_service.dart';
import 'api_service.dart';

// ── Modelo Afiliado (visão admin) ─────────────────────────────────────────────
class AdminAffiliate {
  final String id;
  final String nome;
  final String email;
  final String cpf;
  final String telefone;
  final String affiliateCode;
  final String? sponsorCode;
  final double saldoDisponivel;
  final double totalComissoes;
  final double totalSacado;
  final int totalIndicados;
  final int totalAssinaturas;
  final String status; // ativo, suspenso, pendente
  final DateTime createdAt;
  final String? pixKey;

  const AdminAffiliate({
    required this.id,
    required this.nome,
    required this.email,
    required this.cpf,
    required this.telefone,
    required this.affiliateCode,
    this.sponsorCode,
    required this.saldoDisponivel,
    required this.totalComissoes,
    required this.totalSacado,
    required this.totalIndicados,
    required this.totalAssinaturas,
    required this.status,
    required this.createdAt,
    this.pixKey,
  });

  factory AdminAffiliate.fromJson(Map<String, dynamic> j) => AdminAffiliate(
        id: FirestoreService.toStr(j['id']),
        nome: FirestoreService.toStr(j['nome']),
        email: FirestoreService.toStr(j['email']),
        cpf: FirestoreService.toStr(j['cpf']),
        telefone: FirestoreService.toStr(j['telefone']),
        affiliateCode: FirestoreService.toStr(j['affiliateCode']),
        sponsorCode: j['sponsorCode'] as String?,
        saldoDisponivel: FirestoreService.toDouble(j['saldoDisponivel']),
        totalComissoes: FirestoreService.toDouble(j['totalComissoes']),
        totalSacado: FirestoreService.toDouble(j['totalSacado']),
        totalIndicados: FirestoreService.toInt(j['totalIndicados']),
        totalAssinaturas: FirestoreService.toInt(j['totalAssinaturas']),
        status: FirestoreService.toStr(j['status'], fallback: 'ativo'),
        createdAt: FirestoreService.toDateTimeOrNow(j['createdAt']),
        pixKey: j['pixKey'] as String?,
      );
}

// ── Modelo Saque (visão admin) ────────────────────────────────────────────────
class AdminWithdrawal {
  final String id;
  final String affiliateId;
  final String affiliateNome;
  final String affiliateCode;
  final double valor;
  final String pixKey;
  final String status; // pendente, aprovado, recusado, processando
  final DateTime solicitadoEm;
  final DateTime? processadoEm;
  final String? txId;
  final String? motivo;

  const AdminWithdrawal({
    required this.id,
    required this.affiliateId,
    required this.affiliateNome,
    required this.affiliateCode,
    required this.valor,
    required this.pixKey,
    required this.status,
    required this.solicitadoEm,
    this.processadoEm,
    this.txId,
    this.motivo,
  });

  factory AdminWithdrawal.fromJson(Map<String, dynamic> j) => AdminWithdrawal(
        id: FirestoreService.toStr(j['id']),
        affiliateId: FirestoreService.toStr(j['affiliateId']),
        affiliateNome: FirestoreService.toStr(j['affiliateNome']),
        affiliateCode: FirestoreService.toStr(j['affiliateCode']),
        valor: FirestoreService.toDouble(j['valor']),
        pixKey: FirestoreService.toStr(j['pixKey']),
        status: FirestoreService.toStr(j['status'], fallback: 'pendente'),
        solicitadoEm: FirestoreService.toDateTimeOrNow(j['solicitadoEm']),
        processadoEm: FirestoreService.toDateTime(j['processadoEm']),
        txId: j['txId'] as String?,
        motivo: j['motivo'] as String?,
      );

  Color get statusColor {
    switch (status) {
      case 'aprovado':
        return const Color(0xFF2E7D32);
      case 'recusado':
        return const Color(0xFFD32F2F);
      case 'processando':
        return const Color(0xFF1565C0);
      default:
        return const Color(0xFFF57C00);
    }
  }

  String get statusLabel {
    switch (status) {
      case 'aprovado':
        return 'Aprovado';
      case 'recusado':
        return 'Recusado';
      case 'processando':
        return 'Processando';
      default:
        return 'Pendente';
    }
  }
}

// ── Métricas gerais ───────────────────────────────────────────────────────────
class AdminMetrics {
  final double receitaTotal;
  final double receitaMes;
  final double comissoesTotal;
  final double comissoesMes;
  final int totalAfiliados;
  final int afiliadosAtivos;
  final int totalAssinaturas;
  final int assinaturasAtivas;
  final int assinaturasPendentes;
  final double mrr;
  final int saquesPendentes;
  final double valorSaquesPendentes;

  const AdminMetrics({
    required this.receitaTotal,
    required this.receitaMes,
    required this.comissoesTotal,
    required this.comissoesMes,
    required this.totalAfiliados,
    required this.afiliadosAtivos,
    required this.totalAssinaturas,
    required this.assinaturasAtivas,
    required this.assinaturasPendentes,
    required this.mrr,
    required this.saquesPendentes,
    required this.valorSaquesPendentes,
  });

  factory AdminMetrics.fromJson(Map<String, dynamic> j) => AdminMetrics(
        receitaTotal: FirestoreService.toDouble(j['receitaTotal']),
        receitaMes: FirestoreService.toDouble(j['receitaMes']),
        comissoesTotal: FirestoreService.toDouble(j['comissoesTotal']),
        comissoesMes: FirestoreService.toDouble(j['comissoesMes']),
        totalAfiliados: FirestoreService.toInt(j['totalAfiliados']),
        afiliadosAtivos: FirestoreService.toInt(j['afiliadosAtivos']),
        totalAssinaturas: FirestoreService.toInt(j['totalAssinaturas']),
        assinaturasAtivas: FirestoreService.toInt(j['assinaturasAtivas']),
        assinaturasPendentes: FirestoreService.toInt(j['assinaturasPendentes']),
        mrr: FirestoreService.toDouble(j['mrr']),
        saquesPendentes: FirestoreService.toInt(j['saquesPendentes']),
        valorSaquesPendentes:
            FirestoreService.toDouble(j['valorSaquesPendentes']),
      );
}

// ── AdminService ──────────────────────────────────────────────────────────────
class AdminService extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  bool _isAdmin = false;

  List<AdminAffiliate> _affiliates = [];
  List<SubscriptionModel> _subscriptions = [];
  List<AdminWithdrawal> _withdrawals = [];
  List<ProductModel> _products = [];
  AdminMetrics? _metrics;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAdmin => _isAdmin;
  List<AdminAffiliate> get affiliates => _affiliates;
  List<SubscriptionModel> get subscriptions => _subscriptions;
  List<AdminWithdrawal> get withdrawals => _withdrawals;
  List<ProductModel> get products => _products;
  AdminMetrics? get metrics => _metrics;

  // Credenciais admin demo
  static const String _adminEmail = 'admin@affiliatewallet.com';
  static const String _adminPassword = 'admin123';

  bool get _useFirestore => FirestoreService.isAvailable;

  // ── Login Admin ───────────────────────────────────────────────────────────
  Future<bool> adminLogin(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Autenticar no Firebase Auth para ter request.auth nas regras Firestore
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Verifica se é o email admin autorizado
      if (email == _adminEmail) {
        _isAdmin = true;
        await loadAll();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        // Logou mas não é admin — deslogar
        await FirebaseAuth.instance.signOut();
        _error = 'Acesso negado: não é conta admin';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('[AdminService] Erro auth: ${e.code} — ${e.message}');
    } catch (e) {
      debugPrint('[AdminService] Erro inesperado: $e');
    }

    _error = 'Credenciais inválidas';
    _isLoading = false;
    notifyListeners();
    return false;
  }

  void adminLogout() {
    _isAdmin = false;
    _affiliates = [];
    _subscriptions = [];
    _withdrawals = [];
    _metrics = null;
    notifyListeners();
  }

  // ── Carregar tudo ─────────────────────────────────────────────────────────
  Future<void> loadAll() async {
    await Future.wait([
      loadMetrics(),
      loadAffiliates(),
      loadSubscriptions(),
      loadWithdrawals(),
      loadProducts(),
    ]);
  }

  // ── Métricas ──────────────────────────────────────────────────────────────
  Future<void> loadMetrics() async {
    try {
      if (_useFirestore) {
        final snap = await FirestoreService.metrics?.doc('global').get();
        if (snap != null && snap.exists) {
          final data = snap.data()!;
          _metrics = AdminMetrics.fromJson(data);
          if (kDebugMode) debugPrint('[AdminService] Métricas carregadas do Firestore');
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      debugPrint('[AdminService] Erro ao carregar métricas: $e');
    }

    // Fallback para mock — valores do modelo financeiro ShareWallet
    _metrics = const AdminMetrics(
      receitaTotal: 450000.00,    // Receita acumulada
      receitaMes: 75000.00,       // 5.000 usuários × R$15 ticket médio
      comissoesTotal: 90000.00,   // 20% acumulado
      comissoesMes: 15000.00,     // 20% de R$75K mensal
      totalAfiliados: 1250,       // Total de afiliados cadastrados
      afiliadosAtivos: 980,       // Afiliados com assinaturas ativas
      totalAssinaturas: 5320,     // Total histórico de assinaturas
      assinaturasAtivas: 5000,    // 5.000 assinantes ativos
      assinaturasPendentes: 87,   // Aguardando pagamento
      mrr: 75000.00,              // Monthly Recurring Revenue
      saquesPendentes: 28,        // Solicitações de saque pendentes
      valorSaquesPendentes: 3200.00, // R$3.200 em saques pendentes
    );
    notifyListeners();
  }

  // ── Afiliados ─────────────────────────────────────────────────────────────
  Future<void> loadAffiliates() async {
    try {
      if (_useFirestore) {
        final snap = await FirestoreService.affiliates?.get();
        if (snap != null && snap.docs.isNotEmpty) {
          _affiliates = snap.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return AdminAffiliate.fromJson(data);
          }).toList();
          // Ordenar por nome em memória
          _affiliates.sort((a, b) => a.nome.compareTo(b.nome));
          if (kDebugMode) {
            debugPrint('[AdminService] ${_affiliates.length} afiliados carregados do Firestore');
          }
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      debugPrint('[AdminService] Erro ao carregar afiliados: $e');
    }

    // Fallback para mock APENAS em modo demo (sem Firebase)
    if (!_useFirestore) {
      _affiliates = _mockAffiliates;
    } else {
      _affiliates = []; // Firestore disponível mas vazio — lista real vazia
    }
    notifyListeners();
  }

  Future<bool> updateAffiliateStatus(String id, String status) async {
    try {
      if (_useFirestore) {
        await FirestoreService.affiliates?.doc(id).update({'status': status});
        await loadAffiliates();
        return true;
      }
    } catch (e) {
      debugPrint('[AdminService] Erro ao atualizar afiliado: $e');
    }

    // Fallback local
    final idx = _affiliates.indexWhere((a) => a.id == id);
    if (idx >= 0) {
      final a = _affiliates[idx];
      _affiliates[idx] = AdminAffiliate(
        id: a.id, nome: a.nome, email: a.email, cpf: a.cpf,
        telefone: a.telefone, affiliateCode: a.affiliateCode,
        sponsorCode: a.sponsorCode, saldoDisponivel: a.saldoDisponivel,
        totalComissoes: a.totalComissoes, totalSacado: a.totalSacado,
        totalIndicados: a.totalIndicados, totalAssinaturas: a.totalAssinaturas,
        status: status, createdAt: a.createdAt, pixKey: a.pixKey,
      );
      notifyListeners();
    }
    return true;
  }

  // ── Assinaturas ───────────────────────────────────────────────────────────
  Future<void> loadSubscriptions() async {
    try {
      if (_useFirestore) {
        final snap = await FirestoreService.subscriptions?.get();
        if (snap != null && snap.docs.isNotEmpty) {
          _subscriptions = snap.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return _subscriptionFromFirestore(data);
          }).toList();
          // Ordenar por data de início desc em memória
          _subscriptions.sort((a, b) => b.dataInicio.compareTo(a.dataInicio));
          if (kDebugMode) {
            debugPrint('[AdminService] ${_subscriptions.length} assinaturas carregadas do Firestore');
          }
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      debugPrint('[AdminService] Erro ao carregar assinaturas: $e');
    }

    // Fallback APENAS em modo demo
    if (!_useFirestore) {
      _subscriptions = _mockAllSubscriptions;
    } else {
      _subscriptions = []; // Firestore disponível mas vazio
    }
    notifyListeners();
  }

  Future<bool> cancelSubscription(String id, String motivo) async {
    try {
      if (_useFirestore) {
        await FirestoreService.subscriptions?.doc(id).update({
          'status': 'cancelada',
          'motivo': motivo,
          'dataCancelamento': DateTime.now().toIso8601String(),
        });
        await loadSubscriptions();
        return true;
      }
    } catch (e) {
      debugPrint('[AdminService] Erro ao cancelar assinatura: $e');
    }

    // Fallback local
    final idx = _subscriptions.indexWhere((s) => s.id == id);
    if (idx >= 0) {
      final s = _subscriptions[idx];
      _subscriptions[idx] = SubscriptionModel(
        id: s.id, productId: s.productId, productNome: s.productNome,
        valor: s.valor, comissao: s.comissao, affiliateCode: s.affiliateCode,
        affiliateNome: s.affiliateNome, status: SubscriptionStatus.cancelada,
        chargeType: s.chargeType, dataInicio: s.dataInicio,
        proximaCobranca: s.proximaCobranca, diaCobranca: s.diaCobranca,
        motivo: motivo, historico: s.historico,
      );
      notifyListeners();
    }
    return true;
  }

  // ── Saques ────────────────────────────────────────────────────────────────
  Future<void> loadWithdrawals() async {
    try {
      if (_useFirestore) {
        final snap = await FirestoreService.withdrawals?.get();
        if (snap != null && snap.docs.isNotEmpty) {
          _withdrawals = snap.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return AdminWithdrawal.fromJson(data);
          }).toList();
          // Ordenar por data de solicitação desc em memória
          _withdrawals.sort((a, b) => b.solicitadoEm.compareTo(a.solicitadoEm));
          if (kDebugMode) {
            debugPrint('[AdminService] ${_withdrawals.length} saques carregados do Firestore');
          }
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      debugPrint('[AdminService] Erro ao carregar saques: $e');
    }

    // Fallback APENAS em modo demo
    if (!_useFirestore) {
      _withdrawals = _mockWithdrawals;
    } else {
      _withdrawals = []; // Firestore disponível mas vazio
    }
    notifyListeners();
  }

  Future<bool> approveWithdrawal(String id) async {
    try {
      if (_useFirestore) {
        await FirestoreService.withdrawals?.doc(id).update({
          'status': 'aprovado',
          'processadoEm': DateTime.now().toIso8601String(),
        });
        await loadWithdrawals();
        return true;
      }
    } catch (e) {
      debugPrint('[AdminService] Erro ao aprovar saque: $e');
    }
    _updateWithdrawalStatus(id, 'aprovado');
    return true;
  }

  Future<bool> rejectWithdrawal(String id, String motivo) async {
    try {
      if (_useFirestore) {
        await FirestoreService.withdrawals?.doc(id).update({
          'status': 'recusado',
          'motivo': motivo,
          'processadoEm': DateTime.now().toIso8601String(),
        });
        await loadWithdrawals();
        return true;
      }
    } catch (e) {
      debugPrint('[AdminService] Erro ao recusar saque: $e');
    }
    _updateWithdrawalStatus(id, 'recusado', motivo: motivo);
    return true;
  }

  void _updateWithdrawalStatus(String id, String status, {String? motivo}) {
    final idx = _withdrawals.indexWhere((w) => w.id == id);
    if (idx >= 0) {
      final w = _withdrawals[idx];
      _withdrawals[idx] = AdminWithdrawal(
        id: w.id, affiliateId: w.affiliateId, affiliateNome: w.affiliateNome,
        affiliateCode: w.affiliateCode, valor: w.valor, pixKey: w.pixKey,
        status: status, solicitadoEm: w.solicitadoEm,
        processadoEm: DateTime.now(), txId: w.txId,
        motivo: motivo ?? w.motivo,
      );
      notifyListeners();
    }
  }

  // ── Produtos (CRUD admin) ─────────────────────────────────────────────────
  Future<void> loadProducts() async {
    // Sinaliza carregamento para a UI exibir o loading indicator
    _isLoading = true;
    notifyListeners();

    try {
      if (_useFirestore) {
        final snap = await FirestoreService.products?.get();
        if (snap != null && snap.docs.isNotEmpty) {
          _products = snap.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return ProductModel.fromJson(data);
          }).toList();
          // Ordenar por nome em memória
          _products.sort((a, b) => a.nome.compareTo(b.nome));
          debugPrint('[AdminService] ${_products.length} produtos carregados do Firestore');
          _isLoading = false;
          notifyListeners();
          return;
        } else {
          // Firestore retornou 0 docs — não usa mock, mantém lista vazia
          debugPrint('[AdminService] Firestore retornou snap vazio para products');
          _products = [];
          _isLoading = false;
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      debugPrint('[AdminService] Erro ao carregar produtos: $e');
      _error = 'Erro ao carregar produtos: $e';
    }

    // Só usa mock se o Firebase não estiver disponível (modo demo)
    if (!_useFirestore) {
      _products = ProductModel.mockProducts;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> saveProduct(ProductModel product, {bool isNew = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Verificar se há sessão Firebase Auth ativa
    final currentUser = FirebaseAuth.instance.currentUser;
    if (_useFirestore && currentUser == null) {
      _error = 'Sessão expirada. Faça login novamente.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    if (_useFirestore) {
      try {
        // Forçar refresh do token antes de escrever (resolve problemas de sessão expirada)
        final idToken = await currentUser!.getIdToken(true);
        debugPrint('[AdminService] Token refreshed — uid: ${currentUser.uid}, token: ${idToken?.substring(0, 20)}...');

        final data = product.toJson();
        data.remove('id'); // ID é o document ID, não um campo

        if (isNew) {
          await FirestoreService.products?.doc(product.id).set(data);
        } else {
          await FirestoreService.products?.doc(product.id).update(data);
        }
        await loadProducts();
        _isLoading = false;
        notifyListeners();
        return true;
      } catch (e) {
        // Expõe o erro real — sem fallback silencioso
        debugPrint('[AdminService] Erro ao salvar produto: $e');
        _error = 'Erro ao salvar: $e';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    }

    // Firestore não disponível — fallback local apenas quando Firebase não inicializado
    if (isNew) {
      _products.add(product);
    } else {
      final idx = _products.indexWhere((p) => p.id == product.id);
      if (idx >= 0) _products[idx] = product;
    }
    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> deleteProduct(String id) async {
    _error = null;

    // Verificar sessão Firebase Auth ativa
    final currentUser = FirebaseAuth.instance.currentUser;
    if (_useFirestore && currentUser == null) {
      _error = 'Sessão expirada. Faça login novamente.';
      notifyListeners();
      return false;
    }

    if (_useFirestore) {
      try {
        await FirestoreService.products?.doc(id).delete();
        await loadProducts();
        return true;
      } catch (e) {
        debugPrint('[AdminService] Erro ao deletar produto: $e');
        _error = 'Erro ao excluir produto: $e';
        notifyListeners();
        return false;
      }
    }

    // Fallback local apenas quando Firebase não inicializado
    _products.removeWhere((p) => p.id == id);
    notifyListeners();
    return true;
  }

  Future<bool> toggleProductStatus(String id) async {
    final idx = _products.indexWhere((p) => p.id == id);
    if (idx < 0) return false;
    final p = _products[idx];

    try {
      if (_useFirestore) {
        await FirestoreService.products?.doc(id).update({'ativo': !p.ativo});
        await loadProducts();
        return true;
      }
    } catch (e) {
      debugPrint('[AdminService] Erro ao toggle produto: $e');
    }

    // Fallback local
    final updated = ProductModel(
      id: p.id, nome: p.nome, valor: p.valor, comissao: p.comissao,
      descricao: p.descricao, categoria: p.categoria, imagemUrl: p.imagemUrl,
      ativo: !p.ativo, chargeType: p.chargeType, periodicidade: p.periodicidade,
      diaCobranca: p.diaCobranca, beneficios: p.beneficios,
    );
    _products[idx] = updated;
    notifyListeners();
    return true;
  }

  // ── Converter documento Firestore → SubscriptionModel ────────────────────
  SubscriptionModel _subscriptionFromFirestore(Map<String, dynamic> j) {
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

  // ── Mock data (fallback) ──────────────────────────────────────────────────
  static final List<AdminAffiliate> _mockAffiliates = [
    AdminAffiliate(
      id: 'aff_001', nome: 'João Silva', email: 'joao@email.com',
      cpf: '123.456.789-00', telefone: '(11) 99999-1111',
      affiliateCode: 'ABC123', saldoDisponivel: 125.50,
      totalComissoes: 342.00, totalSacado: 216.50,
      totalIndicados: 12, totalAssinaturas: 8,
      status: 'ativo', createdAt: DateTime(2024, 3, 10),
      pixKey: 'joao@email.com',
    ),
    AdminAffiliate(
      id: 'aff_002', nome: 'Maria Souza', email: 'maria@email.com',
      cpf: '987.654.321-00', telefone: '(11) 98888-2222',
      affiliateCode: 'XYZ789', sponsorCode: 'ABC123',
      saldoDisponivel: 87.20, totalComissoes: 187.20,
      totalSacado: 100.00, totalIndicados: 5, totalAssinaturas: 4,
      status: 'ativo', createdAt: DateTime(2024, 5, 22),
      pixKey: '98888-2222',
    ),
    AdminAffiliate(
      id: 'aff_003', nome: 'Carlos Lima', email: 'carlos@email.com',
      cpf: '111.222.333-44', telefone: '(21) 97777-3333',
      affiliateCode: 'DEF456', sponsorCode: 'ABC123',
      saldoDisponivel: 210.00, totalComissoes: 510.00,
      totalSacado: 300.00, totalIndicados: 21, totalAssinaturas: 15,
      status: 'ativo', createdAt: DateTime(2024, 1, 5),
      pixKey: 'carlos@email.com',
    ),
    AdminAffiliate(
      id: 'aff_004', nome: 'Ana Ferreira', email: 'ana@email.com',
      cpf: '444.555.666-77', telefone: '(31) 96666-4444',
      affiliateCode: 'GHI321', saldoDisponivel: 0.0,
      totalComissoes: 45.00, totalSacado: 45.00,
      totalIndicados: 2, totalAssinaturas: 1,
      status: 'suspenso', createdAt: DateTime(2024, 8, 14),
    ),
    AdminAffiliate(
      id: 'aff_005', nome: 'Pedro Rocha', email: 'pedro@email.com',
      cpf: '777.888.999-00', telefone: '(85) 95555-5555',
      affiliateCode: 'JKL654', sponsorCode: 'DEF456',
      saldoDisponivel: 340.80, totalComissoes: 780.80,
      totalSacado: 440.00, totalIndicados: 31, totalAssinaturas: 24,
      status: 'ativo', createdAt: DateTime(2023, 11, 3),
      pixKey: '777.888.999-00',
    ),
  ];

  static final List<SubscriptionModel> _mockAllSubscriptions = [
    SubscriptionModel(
      id: 'sub_001', productId: 'prod_001', productNome: 'Seguro Motoboy',
      valor: 10.00, comissao: 0.20, affiliateCode: 'ABC123',
      affiliateNome: 'Carlos Motoboy', status: SubscriptionStatus.ativa,
      chargeType: ChargeType.pixRecorrente, dataInicio: DateTime(2024, 3, 5),
      proximaCobranca: DateTime(2026, 7, 5), diaCobranca: 5,
      pixKey: 'carlos.moto@gmail.com', historico: [],
    ),
    SubscriptionModel(
      id: 'sub_002', productId: 'prod_002', productNome: 'Telesena+',
      valor: 25.00, comissao: 0.25, affiliateCode: 'ABC123',
      affiliateNome: 'Fernanda Costa', status: SubscriptionStatus.ativa,
      chargeType: ChargeType.pixRecorrente, dataInicio: DateTime(2024, 4, 5),
      proximaCobranca: DateTime(2026, 7, 5), diaCobranca: 5,
      pixKey: 'fernanda@email.com', historico: [],
    ),
    SubscriptionModel(
      id: 'sub_003', productId: 'prod_003', productNome: 'Clube de Benefícios',
      valor: 19.90, comissao: 0.30, affiliateCode: 'DEF456',
      affiliateNome: 'Roberto Alves', status: SubscriptionStatus.pendente,
      chargeType: ChargeType.pixRecorrente, dataInicio: DateTime(2024, 5, 5),
      proximaCobranca: DateTime(2026, 7, 5), diaCobranca: 5,
      motivo: 'Saldo insuficiente', pixKey: '11999990000', historico: [],
    ),
    SubscriptionModel(
      id: 'sub_004', productId: 'prod_001', productNome: 'Seguro Motoboy',
      valor: 10.00, comissao: 0.20, affiliateCode: 'XYZ789',
      affiliateNome: 'Luiz Motoboy', status: SubscriptionStatus.ativa,
      chargeType: ChargeType.pixRecorrente, dataInicio: DateTime(2024, 2, 5),
      proximaCobranca: DateTime(2026, 7, 5), diaCobranca: 5,
      pixKey: 'luiz@gmail.com', historico: [],
    ),
    SubscriptionModel(
      id: 'sub_005', productId: 'prod_004', productNome: 'Assistência Residencial',
      valor: 15.00, comissao: 0.20, affiliateCode: 'JKL654',
      affiliateNome: 'Sandra Oliveira', status: SubscriptionStatus.cancelada,
      chargeType: ChargeType.pixRecorrente, dataInicio: DateTime(2024, 1, 5),
      proximaCobranca: DateTime(2026, 8, 5), diaCobranca: 5,
      motivo: 'Cancelado pelo usuário', pixKey: 'sandra@email.com', historico: [],
    ),
  ];

  static final List<AdminWithdrawal> _mockWithdrawals = [
    AdminWithdrawal(
      id: 'wit_001', affiliateId: 'aff_001', affiliateNome: 'João Silva',
      affiliateCode: 'ABC123', valor: 125.50, pixKey: 'joao@email.com',
      status: 'pendente',
      solicitadoEm: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    AdminWithdrawal(
      id: 'wit_002', affiliateId: 'aff_005', affiliateNome: 'Pedro Rocha',
      affiliateCode: 'JKL654', valor: 200.00, pixKey: '777.888.999-00',
      status: 'pendente',
      solicitadoEm: DateTime.now().subtract(const Duration(hours: 8)),
    ),
    AdminWithdrawal(
      id: 'wit_003', affiliateId: 'aff_003', affiliateNome: 'Carlos Lima',
      affiliateCode: 'DEF456', valor: 150.00, pixKey: 'carlos@email.com',
      status: 'aprovado',
      solicitadoEm: DateTime.now().subtract(const Duration(days: 2)),
      processadoEm: DateTime.now().subtract(const Duration(days: 1)),
      txId: 'woovi_tx_abc123',
    ),
    AdminWithdrawal(
      id: 'wit_004', affiliateId: 'aff_002', affiliateNome: 'Maria Souza',
      affiliateCode: 'XYZ789', valor: 100.00, pixKey: '98888-2222',
      status: 'aprovado',
      solicitadoEm: DateTime.now().subtract(const Duration(days: 5)),
      processadoEm: DateTime.now().subtract(const Duration(days: 4)),
      txId: 'woovi_tx_def456',
    ),
    AdminWithdrawal(
      id: 'wit_005', affiliateId: 'aff_004', affiliateNome: 'Ana Ferreira',
      affiliateCode: 'GHI321', valor: 45.00, pixKey: '',
      status: 'recusado',
      solicitadoEm: DateTime.now().subtract(const Duration(days: 7)),
      processadoEm: DateTime.now().subtract(const Duration(days: 6)),
      motivo: 'Conta suspensa — aguardando verificação',
    ),
  ];
}
