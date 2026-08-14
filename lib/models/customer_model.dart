// ===========================================================================
// customer_model.dart - ShareWallet
// ---------------------------------------------------------------------------
// Modelo do CLIENTE (quem compra via link de afiliado).
// Diferente do AfiliAdo (UserModel), o cliente:
//   • Compra produtos (não vende/indica)
//   • Tem carteira própria para saldo/pagamentos
//   • Está permanentemente vinculado ao afiliado que o indicou
//   • Pode se tornar afiliado futuramente (upgrade)
// ===========================================================================

class CustomerModel {
  final String id;               // Firebase UID
  final String nome;
  final String email;
  final String telefone;
  final String cpf;
  final String avatarUrl;        // foto do Google/Facebook

  // Vínculo permanente com o afiliado indicador
  final String sponsorAffiliateId;    // UID do afiliado
  final String sponsorUsername;       // @gelcisilva
  final String sponsorAffiliateCode;  // 9ESQ3K (fallback)
  final String sponsorNome;           // "Gelci Silva"

  // Carteira do cliente
  final double saldoDisponivel;
  final double saldoPendente;
  final double totalGasto;       // total pago em produtos

  // Métricas
  final int totalProdutos;       // qtd de produtos ativos
  final String status;           // 'ativo' | 'inativo' | 'suspenso'
  final DateTime createdAt;
  final DateTime? lastLogin;

  // Chave PIX para eventual reembolso
  final String pixKey;
  final String pixKeyType;

  const CustomerModel({
    required this.id,
    required this.nome,
    required this.email,
    this.telefone = '',
    this.cpf = '',
    this.avatarUrl = '',
    this.sponsorAffiliateId = '',
    this.sponsorUsername = '',
    this.sponsorAffiliateCode = '',
    this.sponsorNome = '',
    this.saldoDisponivel = 0.0,
    this.saldoPendente = 0.0,
    this.totalGasto = 0.0,
    this.totalProdutos = 0,
    this.status = 'ativo',
    required this.createdAt,
    this.lastLogin,
    this.pixKey = '',
    this.pixKeyType = 'EMAIL',
  });

  String get primeiroNome => nome.split(' ').first;

  /// Handle do afiliado indicador para exibição
  String get sponsorHandle {
    if (sponsorUsername.isNotEmpty) return '@$sponsorUsername';
    if (sponsorAffiliateCode.isNotEmpty) return sponsorAffiliateCode;
    return 'ShareWallet';
  }

  bool get hasSponsor => sponsorAffiliateId.isNotEmpty;
  bool get isAtivo => status == 'ativo';

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id']?.toString() ?? '',
      nome: json['nome']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      telefone: json['telefone']?.toString() ?? '',
      cpf: json['cpf']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString() ?? '',
      sponsorAffiliateId: json['sponsor_affiliate_id']?.toString() ?? '',
      sponsorUsername: json['sponsor_username']?.toString() ?? '',
      sponsorAffiliateCode: json['sponsor_affiliate_code']?.toString() ?? '',
      sponsorNome: json['sponsor_nome']?.toString() ?? '',
      saldoDisponivel: _toDouble(json['saldo_disponivel']),
      saldoPendente: _toDouble(json['saldo_pendente']),
      totalGasto: _toDouble(json['total_gasto']),
      totalProdutos: (json['total_produtos'] ?? 0) as int,
      status: json['status']?.toString() ?? 'ativo',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      pixKey: json['pix_key']?.toString() ?? '',
      pixKeyType: json['pix_key_type']?.toString() ?? 'EMAIL',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'email': email,
        'telefone': telefone,
        'cpf': cpf,
        'avatar_url': avatarUrl,
        'sponsor_affiliate_id': sponsorAffiliateId,
        'sponsor_username': sponsorUsername,
        'sponsor_affiliate_code': sponsorAffiliateCode,
        'sponsor_nome': sponsorNome,
        'saldo_disponivel': saldoDisponivel,
        'saldo_pendente': saldoPendente,
        'total_gasto': totalGasto,
        'total_produtos': totalProdutos,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'pix_key': pixKey,
        'pix_key_type': pixKeyType,
      };

  CustomerModel copyWith({
    String? id,
    String? nome,
    String? email,
    String? telefone,
    String? cpf,
    String? avatarUrl,
    String? sponsorAffiliateId,
    String? sponsorUsername,
    String? sponsorAffiliateCode,
    String? sponsorNome,
    double? saldoDisponivel,
    double? saldoPendente,
    double? totalGasto,
    int? totalProdutos,
    String? status,
    DateTime? createdAt,
    String? pixKey,
    String? pixKeyType,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      email: email ?? this.email,
      telefone: telefone ?? this.telefone,
      cpf: cpf ?? this.cpf,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      sponsorAffiliateId: sponsorAffiliateId ?? this.sponsorAffiliateId,
      sponsorUsername: sponsorUsername ?? this.sponsorUsername,
      sponsorAffiliateCode: sponsorAffiliateCode ?? this.sponsorAffiliateCode,
      sponsorNome: sponsorNome ?? this.sponsorNome,
      saldoDisponivel: saldoDisponivel ?? this.saldoDisponivel,
      saldoPendente: saldoPendente ?? this.saldoPendente,
      totalGasto: totalGasto ?? this.totalGasto,
      totalProdutos: totalProdutos ?? this.totalProdutos,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      pixKey: pixKey ?? this.pixKey,
      pixKeyType: pixKeyType ?? this.pixKeyType,
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}

// ---------------------------------------------------------------------------
// CustomerProductModel — produto comprado por um cliente
// ---------------------------------------------------------------------------

class CustomerProductModel {
  final String id;               // doc ID no Firestore
  final String customerId;
  final String affiliateId;      // quem recebe comissão
  final String productId;
  final String productNome;
  final String productDescricao;
  final String productCategoria;
  final double productValor;
  final double comissaoValor;
  final double comissaoPercent;
  final String chargeType;       // 'recorrente' | 'avulso'
  final String status;           // 'ativo' | 'cancelado' | 'pendente' | 'suspenso'
  final String wooviSubscriptionId;
  final DateTime dataInicio;
  final DateTime? proximaCobranca;
  final DateTime? dataCancelamento;
  final int comissoesGeradas;    // quantas comissões já foram pagas

  const CustomerProductModel({
    required this.id,
    required this.customerId,
    required this.affiliateId,
    required this.productId,
    required this.productNome,
    this.productDescricao = '',
    this.productCategoria = '',
    required this.productValor,
    this.comissaoValor = 0.0,
    this.comissaoPercent = 20.0,
    this.chargeType = 'recorrente',
    this.status = 'ativo',
    this.wooviSubscriptionId = '',
    required this.dataInicio,
    this.proximaCobranca,
    this.dataCancelamento,
    this.comissoesGeradas = 0,
  });

  bool get isAtivo => status == 'ativo';
  bool get isRecorrente => chargeType == 'recorrente';
  bool get isPendente => status == 'pendente';

  String get statusLabel {
    switch (status) {
      case 'ativo':      return 'Ativo';
      case 'pendente':   return 'Aguardando pagamento';
      case 'cancelado':  return 'Cancelado';
      case 'suspenso':   return 'Suspenso';
      default:           return status;
    }
  }

  String get valorFormatado {
    return 'R\$ ${productValor.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  factory CustomerProductModel.fromJson(Map<String, dynamic> json) {
    return CustomerProductModel(
      id: json['id']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      affiliateId: json['affiliate_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      productNome: json['product_nome']?.toString() ?? '',
      productDescricao: json['product_descricao']?.toString() ?? '',
      productCategoria: json['product_categoria']?.toString() ?? '',
      productValor: _toDouble(json['product_valor']),
      comissaoValor: _toDouble(json['comissao_valor']),
      comissaoPercent: _toDouble(json['comissao_percent'] ?? 20.0),
      chargeType: json['charge_type']?.toString() ?? 'recorrente',
      status: json['status']?.toString() ?? 'ativo',
      wooviSubscriptionId: json['woovi_subscription_id']?.toString() ?? '',
      dataInicio: _toDateTime(json['data_inicio']),
      proximaCobranca: json['proxima_cobranca'] != null
          ? _toDateTimeNullable(json['proxima_cobranca'])
          : null,
      dataCancelamento: json['data_cancelamento'] != null
          ? _toDateTimeNullable(json['data_cancelamento'])
          : null,
      comissoesGeradas: (json['comissoes_geradas'] ?? 0) as int,
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static DateTime _toDateTime(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString()) ?? DateTime.now();
  }

  static DateTime? _toDateTimeNullable(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }
}

// ---------------------------------------------------------------------------
// Enum: tipo de usuário (para detecção automática no login)
// ---------------------------------------------------------------------------

enum UserAccountType {
  affiliate,  // só afiliado
  customer,   // só cliente
  both,       // afiliado E cliente (ex: comprou produto sendo afiliado)
  unknown,    // não encontrado em nenhuma coleção
}
