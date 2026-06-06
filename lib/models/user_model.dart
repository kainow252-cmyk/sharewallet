class UserModel {
  final String id;
  final String nome;
  final String cpf;
  final String email;
  final String telefone;
  final String affiliateCode;
  final String? sponsorId;
  final String? wooviSubaccountId;
  final double saldo;
  final String status;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.nome,
    required this.cpf,
    required this.email,
    required this.telefone,
    required this.affiliateCode,
    this.sponsorId,
    this.wooviSubaccountId,
    this.saldo = 0.0,
    this.status = 'ativo',
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      nome: json['nome'] ?? '',
      cpf: json['cpf'] ?? '',
      email: json['email'] ?? '',
      telefone: json['telefone'] ?? '',
      affiliateCode: json['affiliate_code'] ?? '',
      sponsorId: json['sponsor_id']?.toString(),
      wooviSubaccountId: json['woovi_subaccount_id']?.toString(),
      saldo: (json['saldo'] ?? 0).toDouble(),
      status: json['status'] ?? 'ativo',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'cpf': cpf,
        'email': email,
        'telefone': telefone,
        'affiliate_code': affiliateCode,
        'sponsor_id': sponsorId,
        'woovi_subaccount_id': wooviSubaccountId,
        'saldo': saldo,
        'status': status,
        'created_at': createdAt.toIso8601String(),
      };

  String get primeiroNome => nome.split(' ').first;

  UserModel copyWith({
    String? id,
    String? nome,
    String? cpf,
    String? email,
    String? telefone,
    String? affiliateCode,
    String? sponsorId,
    String? wooviSubaccountId,
    double? saldo,
    String? status,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      cpf: cpf ?? this.cpf,
      email: email ?? this.email,
      telefone: telefone ?? this.telefone,
      affiliateCode: affiliateCode ?? this.affiliateCode,
      sponsorId: sponsorId ?? this.sponsorId,
      wooviSubaccountId: wooviSubaccountId ?? this.wooviSubaccountId,
      saldo: saldo ?? this.saldo,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
