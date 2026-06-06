import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import '../models/product_model.dart';
import '../models/subscription_model.dart';
import 'cf_api_service.dart';

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
        id: _s(j['id']),
        nome: _s(j['nome']),
        email: _s(j['email']),
        cpf: _s(j['cpf']),
        telefone: _s(j['telefone']),
        affiliateCode: _s(j['affiliateCode']),
        sponsorCode: j['sponsorCode'] as String?,
        saldoDisponivel: _d(j['saldoDisponivel']),
        totalComissoes: _d(j['totalComissoes']),
        totalSacado: _d(j['totalSacado']),
        totalIndicados: _i(j['totalIndicados']),
        totalAssinaturas: _i(j['totalAssinaturas']),
        status: _s(j['status'], fb: 'ativo'),
        createdAt: _dt(j['createdAt']),
        pixKey: j['pixKey'] as String?,
      );

  static String _s(dynamic v, {String fb = ''}) => v?.toString() ?? fb;
  static double _d(dynamic v) => (v as num?)?.toDouble() ?? 0.0;
  static int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
  static DateTime _dt(dynamic v) =>
      v != null ? DateTime.tryParse(v.toString()) ?? DateTime.now() : DateTime.now();
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
        id: j['id']?.toString() ?? '',
        affiliateId: j['affiliateId']?.toString() ?? '',
        affiliateNome: j['affiliateNome']?.toString() ?? '',
        affiliateCode: j['affiliateCode']?.toString() ?? '',
        valor: (j['valor'] as num?)?.toDouble() ?? 0,
        pixKey: j['pixKey']?.toString() ?? '',
        status: j['status']?.toString() ?? 'pendente',
        solicitadoEm: j['solicitadoEm'] != null
            ? DateTime.tryParse(j['solicitadoEm'].toString()) ?? DateTime.now()
            : DateTime.now(),
        processadoEm: j['processadoEm'] != null
            ? DateTime.tryParse(j['processadoEm'].toString()) : null,
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
        receitaTotal: (j['receitaTotal'] as num?)?.toDouble() ?? 0,
        receitaMes: (j['receitaMes'] as num?)?.toDouble() ?? 0,
        comissoesTotal: (j['comissoesTotal'] as num?)?.toDouble() ?? 0,
        comissoesMes: (j['comissoesMes'] as num?)?.toDouble() ?? 0,
        totalAfiliados: (j['totalAfiliados'] as num?)?.toInt() ?? 0,
        afiliadosAtivos: (j['afiliadosAtivos'] as num?)?.toInt() ?? 0,
        totalAssinaturas: (j['totalAssinaturas'] as num?)?.toInt() ?? 0,
        assinaturasAtivas: (j['assinaturasAtivas'] as num?)?.toInt() ?? 0,
        assinaturasPendentes: (j['assinaturasPendentes'] as num?)?.toInt() ?? 0,
        mrr: (j['mrr'] as num?)?.toDouble() ?? 0,
        saquesPendentes: (j['saquesPendentes'] as num?)?.toInt() ?? 0,
        valorSaquesPendentes: (j['valorSaquesPendentes'] as num?)?.toDouble() ?? 0,
      );
}

// ── AdminService ──────────────────────────────────────────────────────────────
class AdminService extends ChangeNotifier {
  // _isLoading: usado APENAS para operações de escrita (saveProduct, adminLogin)
  // _isLoadingData: loading geral de leitura das listas (affiliates, subs, withdrawals)
  // _isLoadingProducts: loading isolado de produtos — não bloqueia tela de relatórios
  bool _isLoading = false;
  bool _isLoadingData = false;
  bool _isLoadingProducts = false;
  String? _error;
  bool _isAdmin = false;

  List<AdminAffiliate> _affiliates = [];
  List<SubscriptionModel> _subscriptions = [];
  List<AdminWithdrawal> _withdrawals = [];
  List<ProductModel> _products = [];
  AdminMetrics? _metrics;

  bool get isLoading => _isLoading;
  // isLoadingData: true enquanto affiliates/subs/withdrawals/metrics carregam
  bool get isLoadingData => _isLoadingData;
  // isLoadingProducts: true apenas durante loadProducts() — não afeta relatórios
  bool get isLoadingProducts => _isLoadingProducts;
  String? get error => _error;
  bool get isAdmin => _isAdmin;
  List<AdminAffiliate> get affiliates => _affiliates;
  List<SubscriptionModel> get subscriptions => _subscriptions;
  List<AdminWithdrawal> get withdrawals => _withdrawals;
  List<ProductModel> get products => _products;
  AdminMetrics? get metrics => _metrics;

  // Credencial admin email
  static const String _adminEmail = 'admin@affiliatewallet.com';

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

  // ── Carregar tudo via D1 (paralelo) ────────────────────────────────────────
  Future<void> loadAll() async {
    // Inicia loading geral dos dados de relatório
    _isLoadingData = true;
    notifyListeners();
    await Future.wait([
      loadMetrics(),
      loadAffiliates(),
      loadSubscriptions(),
      loadWithdrawals(),
      // loadProducts com silent=true: não seta _isLoading global
      // não bloqueia a tela de relatórios enquanto produtos carregam
      loadProducts(silent: true),
    ]);
    _isLoadingData = false;
    notifyListeners();
  }

  // ── Métricas via D1 ──────────────────────────────────────────────────────
  Future<void> loadMetrics() async {
    try {
      final data = await CfApiService.getMetrics();
      if (data != null) {
        _metrics = AdminMetrics.fromJson(Map<String, dynamic>.from(data));
        if (kDebugMode) debugPrint('[AdminService] Métricas carregadas (D1)');
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('[AdminService] Erro métricas: $e');
    }
    // Fallback vazio
    _metrics = const AdminMetrics(
      receitaTotal: 0, receitaMes: 0, comissoesTotal: 0, comissoesMes: 0,
      totalAfiliados: 0, afiliadosAtivos: 0, totalAssinaturas: 0,
      assinaturasAtivas: 0, assinaturasPendentes: 0, mrr: 0,
      saquesPendentes: 0, valorSaquesPendentes: 0,
    );
    notifyListeners();
  }

  // ── Afiliados via D1 ─────────────────────────────────────────────────────
  Future<void> loadAffiliates() async {
    try {
      final rows = await CfApiService.getAffiliates();
      _affiliates = rows.map((r) => AdminAffiliate.fromJson(_normalizeAff(r))).toList();
      _affiliates.sort((a, b) => a.nome.compareTo(b.nome));
      if (kDebugMode) debugPrint('[AdminService] ${_affiliates.length} afiliados (D1)');
    } catch (e) {
      debugPrint('[AdminService] Erro afiliados: $e');
      _affiliates = [];
    }
    notifyListeners();
  }

  static Map<String, dynamic> _normalizeAff(Map<String, dynamic> r) => {
    'id': r['id'], 'nome': r['nome'], 'email': r['email'],
    'cpf': r['cpf'], 'telefone': r['telefone'],
    'affiliateCode': r['affiliate_code'],
    'sponsorCode': r['sponsor_code'],
    'pixKey': r['pix_key'],
    'status': r['status'],
    'saldoDisponivel': r['saldo_disponivel'],
    'totalComissoes': r['total_comissoes'],
    'totalSacado': r['total_sacado'],
    'totalIndicados': r['total_indicados'],
    'totalAssinaturas': r['total_assinaturas'],
    'createdAt': r['created_at'],
  };

  Future<bool> updateAffiliateStatus(String id, String status) async {
    try {
      await CfApiService.updateAffiliate(id, {'status': status});
      await loadAffiliates();
      return true;
    } catch (e) {
      debugPrint('[AdminService] Erro updateAffiliateStatus: $e');
    }
    return false;
  }

  // ── Assinaturas via D1 ───────────────────────────────────────────────────
  Future<void> loadSubscriptions() async {
    try {
      final rows = await CfApiService.getSubscriptions();
      _subscriptions = rows.map((r) => _subFromD1(r)).toList();
      _subscriptions.sort((a, b) => b.dataInicio.compareTo(a.dataInicio));
      if (kDebugMode) debugPrint('[AdminService] ${_subscriptions.length} assinaturas (D1)');
    } catch (e) {
      debugPrint('[AdminService] Erro assinaturas: $e');
      _subscriptions = [];
    }
    notifyListeners();
  }

  Future<bool> cancelSubscription(String id, String motivo) async {
    try {
      await CfApiService.updateSubscription(id, {
        'status': 'cancelada',
        'motivo': motivo,
        'data_cancelamento': DateTime.now().toIso8601String(),
      });
      await loadSubscriptions();
      return true;
    } catch (e) {
      debugPrint('[AdminService] Erro cancelSubscription: $e');
    }
    return false;
  }

  // ── Saques via D1 ────────────────────────────────────────────────────────
  Future<void> loadWithdrawals() async {
    try {
      final rows = await CfApiService.getWithdrawals();
      _withdrawals = rows.map((r) => AdminWithdrawal.fromJson(_normalizeWd(r))).toList();
      _withdrawals.sort((a, b) => b.solicitadoEm.compareTo(a.solicitadoEm));
      if (kDebugMode) debugPrint('[AdminService] ${_withdrawals.length} saques (D1)');
    } catch (e) {
      debugPrint('[AdminService] Erro saques: $e');
      _withdrawals = [];
    }
    notifyListeners();
  }

  static Map<String, dynamic> _normalizeWd(Map<String, dynamic> r) => {
    'id': r['id'], 'affiliateId': r['user_id'],
    'affiliateNome': r['affiliate_nome'], 'affiliateCode': r['affiliate_code'],
    'valor': r['valor'], 'pixKey': r['pix_key'],
    'status': r['status'], 'solicitadoEm': r['solicitado_em'],
    'processadoEm': r['processado_em'], 'txId': r['tx_id'], 'motivo': r['motivo'],
  };

  Future<bool> approveWithdrawal(String id) async {
    try {
      final ok = await CfApiService.approveWithdrawal(id);
      if (ok) await loadWithdrawals();
      return ok;
    } catch (e) {
      debugPrint('[AdminService] Erro approveWithdrawal: $e');
      return false;
    }
  }

  Future<bool> rejectWithdrawal(String id, String motivo) async {
    try {
      final ok = await CfApiService.rejectWithdrawal(id, motivo);
      if (ok) await loadWithdrawals();
      return ok;
    } catch (e) {
      debugPrint('[AdminService] Erro rejectWithdrawal: $e');
      return false;
    }
  }

  // ── Produtos (CRUD admin) via D1 ──────────────────────────────────────────
  //
  // silent=true → não toca _isLoading nem _isLoadingProducts
  //   (usado internamente por loadAll() para não bloquear tela de relatórios)
  // silent=false (padrão) → seta _isLoadingProducts, usado pela tela de produtos
  Future<void> loadProducts({bool silent = false}) async {
    if (!silent) {
      _isLoadingProducts = true;
      notifyListeners();
    }
    try {
      final rows = await CfApiService.getProducts(all: true);
      _products = rows.map((r) => ProductModel.fromJson(_normalizeProd(r))).toList();
      _products.sort((a, b) => a.nome.compareTo(b.nome));
      if (kDebugMode) debugPrint('[AdminService] ${_products.length} produtos (D1)');
    } catch (e) {
      debugPrint('[AdminService] Erro produtos: $e');
      _error = 'Erro ao carregar produtos: $e';
      _products = [];
    }
    if (!silent) {
      _isLoadingProducts = false;
      notifyListeners();
    }
  }

  static Map<String, dynamic> _normalizeProd(Map<String, dynamic> r) => {
    'id': r['id'], 'nome': r['nome'], 'descricao': r['descricao'],
    'valor': r['valor'], 'comissao': r['comissao'], 'categoria': r['categoria'],
    'chargeType': r['charge_type'], 'periodicidade': r['periodicidade'],
    'diaCobranca': r['dia_cobranca'], 'beneficios': r['beneficios'],
    'imagem_url': r['imagem_url'],
    'ativo': r['ativo'] == 1 || r['ativo'] == true,
  };

  Future<bool> saveProduct(ProductModel product, {bool isNew = false}) async {
    // saveProduct usa _isLoading (escrita) — comportamento original preservado
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final data = product.toJson();
      final result = await CfApiService.saveProduct(data, isNew: isNew);
      if (result != null) {
        // Recarrega produtos em silent para não piscar _isLoadingProducts
        await loadProducts(silent: true);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _error = 'Erro ao salvar produto';
    } catch (e) {
      debugPrint('[AdminService] Erro saveProduct: $e');
      _error = 'Erro ao salvar: $e';
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> deleteProduct(String id) async {
    _error = null;
    try {
      final ok = await CfApiService.deleteProduct(id);
      if (ok) await loadProducts();
      return ok;
    } catch (e) {
      debugPrint('[AdminService] Erro deleteProduct: $e');
      _error = 'Erro ao excluir: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleProductStatus(String id) async {
    try {
      final ok = await CfApiService.toggleProduct(id);
      if (ok) await loadProducts();
      return ok;
    } catch (e) {
      debugPrint('[AdminService] Erro toggleProduct: $e');
      return false;
    }
  }

  // ── Converter linha D1 → SubscriptionModel ───────────────────────────────
  static SubscriptionModel _subFromD1(Map<String, dynamic> r) {
    SubscriptionStatus status;
    switch (r['status']?.toString() ?? 'ativa') {
      case 'pendente':   status = SubscriptionStatus.pendente;   break;
      case 'cancelada':  status = SubscriptionStatus.cancelada;  break;
      case 'aguardando': status = SubscriptionStatus.aguardando; break;
      default:           status = SubscriptionStatus.ativa;
    }
    ChargeType ct = r['charge_type']?.toString() == 'pixAvulso'
        ? ChargeType.pixAvulso : ChargeType.pixRecorrente;
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
      status: status, chargeType: ct,
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

  // ── Mock data (fallback — desativado, mantido para referência) ──────────────
  // ignore: unused_field
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

  // ignore: unused_field
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

  // ignore: unused_field
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
