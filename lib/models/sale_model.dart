class SaleModel {
  final String id;
  final String userId;
  final String productId;
  final String productNome;
  final double valor;
  final double comissao;
  final double plataforma;
  final String status; // PENDING, COMPLETED, CANCELLED
  final String? wooviChargeId;
  final DateTime createdAt;

  SaleModel({
    required this.id,
    required this.userId,
    required this.productId,
    required this.productNome,
    required this.valor,
    required this.comissao,
    required this.plataforma,
    this.status = 'PENDING',
    this.wooviChargeId,
    required this.createdAt,
  });

  factory SaleModel.fromJson(Map<String, dynamic> json) {
    return SaleModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      productNome: json['product_nome'] ?? '',
      valor: (json['valor'] ?? 0).toDouble(),
      comissao: (json['comissao'] ?? 0).toDouble(),
      plataforma: (json['plataforma'] ?? 0).toDouble(),
      status: json['status'] ?? 'PENDING',
      wooviChargeId: json['woovi_charge_id'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  /// Factory para resposta da API NestJS (snake_case → camelCase)
  factory SaleModel.fromApiJson(Map<String, dynamic> json) {
    final totalValue = (json['totalValue'] as int? ?? 0);
    final commission = (json['commission'] as int? ?? 0);
    final platformValue = (json['platformValue'] as int? ?? 0);
    return SaleModel(
      id: json['id']?.toString() ?? '',
      userId: '',
      productId: json['productId']?.toString() ?? '',
      productNome: json['productName'] as String? ?? 'Produto',
      valor: totalValue / 100.0,
      comissao: commission / 100.0,
      plataforma: platformValue / 100.0,
      status: _mapApiStatus(json['status'] as String? ?? 'PENDING'),
      wooviChargeId: json['wooviCorrelationId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  static String _mapApiStatus(String apiStatus) {
    switch (apiStatus) {
      case 'PAID': return 'COMPLETED';
      case 'EXPIRED': return 'CANCELLED';
      default: return apiStatus;
    }
  }

  bool get isCompleted => status == 'COMPLETED';
  bool get isPending => status == 'PENDING';

  String get valorFormatado => 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  String get comissaoFormatada => 'R\$ ${comissao.toStringAsFixed(2).replaceAll('.', ',')}';

  static String statusLabel(String status) {
    switch (status) {
      case 'COMPLETED': return 'Pago';
      case 'PENDING': return 'Aguardando';
      case 'CANCELLED': return 'Cancelado';
      default: return status;
    }
  }

  // Mock data
  static List<SaleModel> get mockSales => [
        SaleModel(
          id: '1', userId: 'u1', productId: '1',
          productNome: 'Seguro Motoboy',
          valor: 10.00, comissao: 2.00, plataforma: 8.00,
          status: 'COMPLETED',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        SaleModel(
          id: '2', userId: 'u1', productId: '2',
          productNome: 'Telesena+',
          valor: 25.00, comissao: 6.25, plataforma: 18.75,
          status: 'COMPLETED',
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
        SaleModel(
          id: '3', userId: 'u1', productId: '3',
          productNome: 'Clube de Benefícios',
          valor: 19.90, comissao: 5.97, plataforma: 13.93,
          status: 'COMPLETED',
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
        ),
        SaleModel(
          id: '4', userId: 'u1', productId: '5',
          productNome: 'Curso de Finanças',
          valor: 97.00, comissao: 38.80, plataforma: 58.20,
          status: 'COMPLETED',
          createdAt: DateTime.now().subtract(const Duration(days: 7)),
        ),
        SaleModel(
          id: '5', userId: 'u1', productId: '1',
          productNome: 'Seguro Motoboy',
          valor: 10.00, comissao: 2.00, plataforma: 8.00,
          status: 'PENDING',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ];
}
