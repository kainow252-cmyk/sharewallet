// Lista de emails com acesso de administrador
// Adicione aqui quantos emails admin forem necessários
const _adminEmails = {
  'admin@affiliatewallet.com',
};

class UserModel {
  final String id;
  final String nome;
  final String cpf;
  final String email;
  final String telefone;
  final String affiliateCode;
  /// Handle único estilo rede social (sem @). Ex: "gelcisilva", "joao.silva", "mktguru"
  /// Gerado automaticamente no cadastro, editável pelo usuário.
  /// Usado para busca (@gelcisilva), indicação, chat futuro.
  final String username;
  final String? sponsorId;
  final String? wooviSubaccountId;
  final double saldo;
  final String status;
  final DateTime createdAt;
  // Chave PIX cadastrada no perfil (pode ser email, CPF, telefone ou aleatória)
  final String pixKey;
  final String pixKeyType;
  // URL da foto de perfil (Firebase Storage)
  final String? photoUrl;

  UserModel({
    required this.id,
    required this.nome,
    required this.cpf,
    required this.email,
    required this.telefone,
    required this.affiliateCode,
    this.username = '',
    this.sponsorId,
    this.wooviSubaccountId,
    this.saldo = 0.0,
    this.status = 'ativo',
    required this.createdAt,
    this.pixKey = '',
    this.pixKeyType = 'EMAIL',
    this.photoUrl,
  });

  // ── Getter de admin: email-based, sem necessidade de campo extra no banco ──
  bool get isAdmin => _adminEmails.contains(email.trim().toLowerCase());

  /// Handle exibível com @ prefix. Ex: "@gelcisilva"
  /// Se username vazio, usa affiliateCode como fallback.
  String get handle {
    if (username.isNotEmpty) return '@$username';
    return affiliateCode.isNotEmpty ? affiliateCode : '@user';
  }

  /// Verifica se o username já foi configurado (não é o valor gerado automático)
  bool get hasCustomUsername => username.isNotEmpty;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      nome: json['nome'] ?? '',
      cpf: json['cpf'] ?? '',
      email: json['email'] ?? '',
      telefone: json['telefone'] ?? '',
      affiliateCode: json['affiliate_code'] ?? '',
      username: json['username']?.toString() ?? '',
      sponsorId: json['sponsor_id']?.toString(),
      wooviSubaccountId: json['woovi_subaccount_id']?.toString(),
      saldo: (json['saldo'] ?? 0).toDouble(),
      status: json['status'] ?? 'ativo',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      pixKey: json['pix_key']?.toString() ?? json['pixKey']?.toString() ?? '',
      pixKeyType: json['pix_key_type']?.toString() ?? json['pixKeyType']?.toString() ?? 'EMAIL',
      photoUrl: json['photo_url']?.toString() ?? json['photoUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'cpf': cpf,
        'email': email,
        'telefone': telefone,
        'affiliate_code': affiliateCode,
        'username': username,
        'sponsor_id': sponsorId,
        'woovi_subaccount_id': wooviSubaccountId,
        'saldo': saldo,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'pix_key': pixKey,
        'pix_key_type': pixKeyType,
        'photo_url': photoUrl,
      };

  String get primeiroNome => nome.split(' ').first;

  UserModel copyWith({
    String? id,
    String? nome,
    String? cpf,
    String? email,
    String? telefone,
    String? affiliateCode,
    String? username,
    String? sponsorId,
    String? wooviSubaccountId,
    double? saldo,
    String? status,
    DateTime? createdAt,
    String? pixKey,
    String? pixKeyType,
    String? photoUrl,
    bool clearPhoto = false,
  }) {
    return UserModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      cpf: cpf ?? this.cpf,
      email: email ?? this.email,
      telefone: telefone ?? this.telefone,
      affiliateCode: affiliateCode ?? this.affiliateCode,
      username: username ?? this.username,
      sponsorId: sponsorId ?? this.sponsorId,
      wooviSubaccountId: wooviSubaccountId ?? this.wooviSubaccountId,
      saldo: saldo ?? this.saldo,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      pixKey: pixKey ?? this.pixKey,
      pixKeyType: pixKeyType ?? this.pixKeyType,
      photoUrl: clearPhoto ? null : (photoUrl ?? this.photoUrl),
    );
  }
}
