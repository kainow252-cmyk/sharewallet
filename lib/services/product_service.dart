import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import 'cf_api_service.dart';

class ProductService extends ChangeNotifier {
  List<ProductModel> _products = [];
  bool _isLoading = false;
  String _selectedCategory = 'todos';

  List<ProductModel> get products => _products;
  bool get isLoading => _isLoading;
  String get selectedCategory => _selectedCategory;

  List<String> get categories {
    final cats = ['todos'];
    final unique = _products.map((p) => p.categoria).toSet().toList();
    cats.addAll(unique);
    return cats;
  }

  List<ProductModel> get filteredProducts {
    if (_selectedCategory == 'todos') return _products;
    return _products.where((p) => p.categoria == _selectedCategory).toList();
  }

  static const Map<String, String> categoryLabels = {
    'todos': 'Todos',
    'seguros': 'Seguros',
    'entretenimento': 'Entretenimento',
    'beneficios': 'Benefícios',
    'assistencia': 'Assistência',
    'cursos': 'Cursos',
    'garantias': 'Garantias',
  };

  static const Map<String, String> categoryIcons = {
    'seguros': '🛡️',
    'entretenimento': '🎯',
    'beneficios': '🎁',
    'assistencia': '🔧',
    'cursos': '📚',
    'garantias': '✅',
    'geral': '📦',
  };

  // ── Carregar produtos via Cloudflare D1 ───────────────────────────────────
  Future<void> loadProducts({bool forceRefresh = false}) async {
    if (!forceRefresh && _products.isNotEmpty) return;

    _isLoading = true;
    notifyListeners();

    try {
      final rows = await CfApiService.getProducts();
      _products = rows.map((r) => ProductModel.fromJson(_normalize(r))).toList();
      if (kDebugMode) debugPrint('[ProductService] ${_products.length} produtos (D1)');
    } catch (e) {
      debugPrint('[ProductService] Erro: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  Future<Map<String, dynamic>> gerarLinkCompra({
    required String productId,
    required String affiliateCode,
    required String userId,
  }) async {
    final product = _products.firstWhere((p) => p.id == productId);
    return {
      'success': true,
      'charge_id': 'charge_${DateTime.now().millisecondsSinceEpoch}',
      'link': 'https://sharewallet.com.br/app/#/produto/$productId?ref=$affiliateCode',
      'pix_code': '00020101021226990014br.gov.bcb.pix...',
      'valor': product.valor,
      'comissao': product.valorComissao,
    };
  }

  // D1 usa snake_case — normaliza para o ProductModel.fromJson
  static Map<String, dynamic> _normalize(Map<String, dynamic> r) => {
    'id': r['id'],
    'nome': r['nome'],
    'descricao': r['descricao'],
    'valor': r['valor'],
    'comissao': r['comissao'],
    'categoria': r['categoria'],
    'chargeType': r['charge_type'],
    'periodicidade': r['periodicidade'],
    'diaCobranca': r['dia_cobranca'],
    'beneficios': r['beneficios'],
    'imagem_url': r['imagem_url'],
    'ativo': r['ativo'] == 1 || r['ativo'] == true,
  };
}
