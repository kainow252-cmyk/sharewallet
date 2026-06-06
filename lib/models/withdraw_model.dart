class WithdrawModel {
  final String id;
  final String userId;
  final double valor;
  final String pixKey;
  final String pixKeyType; // CPF, EMAIL, PHONE, ALEATORIA
  final String status; // PENDING, APPROVED, REJECTED
  final DateTime createdAt;
  final DateTime? processedAt;

  WithdrawModel({
    required this.id,
    required this.userId,
    required this.valor,
    required this.pixKey,
    this.pixKeyType = 'CPF',
    this.status = 'PENDING',
    required this.createdAt,
    this.processedAt,
  });

  factory WithdrawModel.fromJson(Map<String, dynamic> json) {
    return WithdrawModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      valor: (json['valor'] ?? 0).toDouble(),
      pixKey: json['pix_key'] ?? '',
      pixKeyType: json['pix_key_type'] ?? 'CPF',
      status: json['status'] ?? 'PENDING',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      processedAt: json['processed_at'] != null
          ? DateTime.parse(json['processed_at'])
          : null,
    );
  }

  /// Factory para resposta da API NestJS
  factory WithdrawModel.fromApiJson(Map<String, dynamic> json) {
    return WithdrawModel(
      id: json['id']?.toString() ?? '',
      userId: '',
      valor: (json['valueInReais'] as num?)?.toDouble() ?? 0.0,
      pixKey: json['pixKey'] as String? ?? '',
      pixKeyType: json['pixKeyType'] as String? ?? 'EMAIL',
      status: _mapApiStatus(json['status'] as String? ?? 'PENDING'),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      processedAt: json['processedAt'] != null
          ? DateTime.parse(json['processedAt'] as String)
          : null,
    );
  }

  /// Factory para Cloudflare D1
  factory WithdrawModel.fromD1(Map<String, dynamic> r) {
    return WithdrawModel(
      id: r['id']?.toString() ?? '',
      userId: r['user_id']?.toString() ?? '',
      valor: (r['valor'] as num? ?? 0).toDouble(),
      pixKey: r['pix_key']?.toString() ?? '',
      pixKeyType: 'PIX',
      status: _d1Status(r['status']?.toString() ?? 'pendente'),
      createdAt: r['solicitado_em'] != null
          ? DateTime.tryParse(r['solicitado_em'].toString()) ?? DateTime.now()
          : DateTime.now(),
      processedAt: r['processado_em'] != null
          ? DateTime.tryParse(r['processado_em'].toString())
          : null,
    );
  }

  static String _d1Status(String s) {
    switch (s) {
      case 'aprovado': return 'APPROVED';
      case 'recusado': return 'REJECTED';
      case 'processando': return 'PROCESSING';
      default: return 'PENDING';
    }
  }

  static String _mapApiStatus(String s) {
    switch (s) {
      case 'COMPLETED': return 'APPROVED';
      case 'FAILED': return 'REJECTED';
      case 'PROCESSING': return 'PENDING';
      default: return s;
    }
  }

  String get valorFormatado => 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';

  static String statusLabel(String status) {
    switch (status) {
      case 'APPROVED': return 'Aprovado';
      case 'PENDING': return 'Processando';
      case 'REJECTED': return 'Rejeitado';
      default: return status;
    }
  }

  static List<WithdrawModel> get mockWithdraws => [
        WithdrawModel(
          id: 'w1', userId: 'u1',
          valor: 50.00, pixKey: '123.456.789-00',
          status: 'APPROVED',
          createdAt: DateTime.now().subtract(const Duration(days: 10)),
          processedAt: DateTime.now().subtract(const Duration(days: 9)),
        ),
        WithdrawModel(
          id: 'w2', userId: 'u1',
          valor: 75.50, pixKey: '123.456.789-00',
          status: 'PENDING',
          createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        ),
      ];
}
