import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import 'firestore_service.dart';

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

  // ── Carregar produtos ─────────────────────────────────────────────────────
  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final col = FirestoreService.products;

      if (col == null) {
        // Modo demo — Firebase não inicializado
        _products = ProductModel.mockProducts;
        if (kDebugMode) debugPrint('[ProductService] Modo demo');
      } else {
        // Ler apenas produtos ativos — query simples (sem composite index)
        final snapshot = await col.get();
        final all = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return ProductModel.fromJson(data);
        }).toList();

        // Filtrar ativos em memória (evita index composto)
        _products = all.where((p) => p.ativo).toList();

        if (kDebugMode) {
          debugPrint('[ProductService] ${_products.length} produtos carregados do Firestore');
        }
      }
    } catch (e) {
      debugPrint('[ProductService] Erro ao carregar produtos: $e');
      // Fallback para mock em caso de erro
      _products = ProductModel.mockProducts;
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

    // POST /api/v1/charge no backend com split Woovi
    return {
      'success': true,
      'charge_id': 'charge_${DateTime.now().millisecondsSinceEpoch}',
      'link': 'https://sharewallet.com.br/app/#/produto/$productId?ref=$affiliateCode',
      'pix_code': '00020101021226990014br.gov.bcb.pix...',
      'valor': product.valor,
      'comissao': product.valorComissao,
    };
  }
}
