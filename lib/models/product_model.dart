import 'package:flutter/material.dart';

// ── Tipo de cobrança ──────────────────────────────────────────────────────────
enum ChargeType {
  pixAutomatico, // Pix Automático/Recorrente — autorização única, débito automático
  pixAvulso,     // QR Code manual a cada cobrança
  unico,         // Produto de pagamento único (sem recorrência)
}

class ProductModel {
  final String id;
  final String nome;
  final double valor;
  final double comissao;    // percentual (ex: 0.20 = 20%)
  final String descricao;
  final String categoria;
  final String? imagemUrl;
  final bool ativo;
  final ChargeType chargeType;
  final String? periodicidade; // mensal, anual, etc.
  final int? diaCobranca;      // dia do mês para débito (ex: 5 = todo dia 5)
  final String? beneficios;    // lista de benefícios separada por '|'

  ProductModel({
    required this.id,
    required this.nome,
    required this.valor,
    required this.comissao,
    required this.descricao,
    this.categoria = 'geral',
    this.imagemUrl,
    this.ativo = true,
    this.chargeType = ChargeType.pixAutomatico,
    this.periodicidade,
    this.diaCobranca,
    this.beneficios,
  });

  // Atalhos
  bool get recorrente => chargeType != ChargeType.unico;
  bool get isPixAutomatico => chargeType == ChargeType.pixAutomatico;
  bool get isPixAvulso => chargeType == ChargeType.pixAvulso;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    ChargeType ct = ChargeType.pixAutomatico;
    if (json['chargeType'] == 'pixAvulso') ct = ChargeType.pixAvulso;
    if (json['chargeType'] == 'unico') ct = ChargeType.unico;

    return ProductModel(
      id: json['id']?.toString() ?? '',
      nome: json['nome'] ?? '',
      valor: (json['valor'] ?? 0).toDouble(),
      comissao: (json['comissao'] ?? 0).toDouble(),
      descricao: json['descricao'] ?? '',
      categoria: json['categoria'] ?? 'geral',
      imagemUrl: json['imagem_url'],
      ativo: json['ativo'] ?? true,
      chargeType: ct,
      periodicidade: json['periodicidade'],
      diaCobranca: json['diaCobranca'],
      beneficios: json['beneficios'],
    );
  }

  double get valorComissao => valor * comissao;
  double get valorPlataforma => valor * (1 - comissao);
  int get comissaoPercent => (comissao * 100).round();

  String get valorFormatado =>
      'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  String get comissaoFormatada =>
      'R\$ ${valorComissao.toStringAsFixed(2).replaceAll('.', ',')}';

  String get chargeTypeLabel {
    switch (chargeType) {
      case ChargeType.pixAutomatico:
        return 'Pix Automático';
      case ChargeType.pixAvulso:
        return 'Pix Avulso';
      case ChargeType.unico:
        return 'Pagamento único';
    }
  }

  Color get chargeTypeColor {
    switch (chargeType) {
      case ChargeType.pixAutomatico:
        return const Color(0xFF0D7A5A); // verde escuro
      case ChargeType.pixAvulso:
        return const Color(0xFF1976D2); // azul
      case ChargeType.unico:
        return const Color(0xFFE65100); // laranja
    }
  }

  IconData get chargeTypeIcon {
    switch (chargeType) {
      case ChargeType.pixAutomatico:
        return Icons.autorenew_rounded;
      case ChargeType.pixAvulso:
        return Icons.pix_rounded;
      case ChargeType.unico:
        return Icons.shopping_bag_rounded;
    }
  }

  List<String> get beneficiosList =>
      beneficios?.split('|').where((b) => b.isNotEmpty).toList() ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'valor': valor,
        'comissao': comissao,
        'descricao': descricao,
        'categoria': categoria,
        'imagem_url': imagemUrl,
        'ativo': ativo,
        'chargeType': chargeType.name,
        'periodicidade': periodicidade,
        'diaCobranca': diaCobranca,
        'beneficios': beneficios,
      };

  // ── Produtos mock ──────────────────────────────────────────────────────────
  static List<ProductModel> get mockProducts => [
        ProductModel(
          id: '1',
          nome: 'Seguro Motoboy',
          valor: 10.00,
          comissao: 0.20,
          descricao:
              'Seguro completo para motoboys com cobertura total em acidentes, roubo e assistência 24h.',
          categoria: 'seguros',
          chargeType: ChargeType.pixAutomatico,
          periodicidade: 'mensal',
          diaCobranca: 5,
          beneficios:
              'Cobertura em acidentes|Proteção contra roubo|Assistência 24h|Indenização hospitalar|Suporte emergencial',
        ),
        ProductModel(
          id: '2',
          nome: 'Telesena+',
          valor: 25.00,
          comissao: 0.25,
          descricao:
              'Acesso premium à plataforma Telesena com sorteios diários e benefícios exclusivos.',
          categoria: 'entretenimento',
          chargeType: ChargeType.pixAutomatico,
          periodicidade: 'mensal',
          diaCobranca: 5,
          beneficios:
              'Sorteios diários|Números da sorte|Acesso VIP|Prêmios em dinheiro|Notificações de sorteio',
        ),
        ProductModel(
          id: '3',
          nome: 'Clube de Benefícios',
          valor: 19.90,
          comissao: 0.30,
          descricao:
              'Descontos em farmácias, supermercados, restaurantes e muito mais todo mês.',
          categoria: 'beneficios',
          chargeType: ChargeType.pixAutomatico,
          periodicidade: 'mensal',
          diaCobranca: 5,
          beneficios:
              'Desconto em farmácias|Cashback em supermercados|Restaurantes parceiros|Descontos em combustível|Saúde e bem-estar',
        ),
        ProductModel(
          id: '4',
          nome: 'Assistência Residencial',
          valor: 15.00,
          comissao: 0.20,
          descricao:
              'Suporte técnico para sua casa: encanamento, elétrica, chaveiro e muito mais.',
          categoria: 'assistencia',
          chargeType: ChargeType.pixAutomatico,
          periodicidade: 'mensal',
          diaCobranca: 5,
          beneficios:
              'Encanamento emergencial|Elétrica 24h|Chaveiro|Vidraceiro|Dedetização anual',
        ),
        ProductModel(
          id: '5',
          nome: 'Curso de Finanças',
          valor: 97.00,
          comissao: 0.40,
          descricao:
              'Aprenda a organizar suas finanças, investir e conquistar sua independência financeira.',
          categoria: 'cursos',
          chargeType: ChargeType.unico,
          beneficios:
              'Acesso vitalício|40 horas de conteúdo|Certificado|Suporte do professor|Comunidade exclusiva',
        ),
        ProductModel(
          id: '6',
          nome: 'Garantia Estendida Digital',
          valor: 29.90,
          comissao: 0.25,
          descricao:
              'Proteja seus dispositivos eletrônicos contra danos e defeitos com cobertura total.',
          categoria: 'garantias',
          chargeType: ChargeType.pixAvulso,
          periodicidade: 'anual',
          beneficios:
              'Celulares e tablets|Notebooks|Smart TVs|Assistência técnica|Reposição garantida',
        ),
      ];
}
