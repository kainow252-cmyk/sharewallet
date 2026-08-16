import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Cliente HTTP para o Cloudflare Worker (D1 SQLite).
/// Resposta típica: < 100ms global.
class CfApiService {
  // Usa o custom domain api.sharewallet.com.br (mesmo TLD que o app).
  // O domínio workers.dev tem bug de HTTP/2 quando o browser envia
  // Origin: https://sharewallet.com.br - a stream H2 trava e nunca responde.
  // Com api.sharewallet.com.br (same-site) o CORS funciona corretamente.
  static const String _base = 'https://api.sharewallet.com.br';
  // Timeout reduzido de 10s → 5s: Worker Cloudflare responde em <200ms global.
  // Se o Worker não responder em 5s, algo está errado; continuar esperando não ajuda.
  static const Duration _timeout = Duration(seconds: 5);

  // Cache em memória para getAffiliateByEmail — evita re-query D1 no mesmo login.
  // TTL de 5 minutos: suficiente para a sessão de login sem dados obsoletos.
  static final Map<String, _CacheEntry> _emailCache = {};

  // -- HTTP helpers ----------------------------------------------------------

  static Future<dynamic> _get(String path) async {
    final uri = Uri.parse('$_base$path');
    try {
      final res = await http.get(uri).timeout(_timeout);
      final body = jsonDecode(res.body);
      if (body['success'] == true) return body['result'];
      debugPrint('[CfApi] GET $path error: ${body['error']}');
      return null;
    } catch (e) {
      debugPrint('[CfApi] GET $path exception: $e');
      return null;
    }
  }

  static Future<dynamic> _post(String path, Map<String, dynamic> data) async {
    final uri = Uri.parse('$_base$path');
    try {
      final res = await http
          .post(uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(data))
          .timeout(_timeout);
      final body = jsonDecode(res.body);
      if (body['success'] == true) return body['result'];
      debugPrint('[CfApi] POST $path error: ${body['error']}');
      return null;
    } catch (e) {
      debugPrint('[CfApi] POST $path exception: $e');
      return null;
    }
  }

  static Future<dynamic> _put(String path, Map<String, dynamic> data) async {
    final uri = Uri.parse('$_base$path');
    try {
      final res = await http
          .put(uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(data))
          .timeout(_timeout);
      final body = jsonDecode(res.body);
      if (body['success'] == true) return body['result'];
      debugPrint('[CfApi] PUT $path error: ${body['error']}');
      return null;
    } catch (e) {
      debugPrint('[CfApi] PUT $path exception: $e');
      return null;
    }
  }

  static Future<dynamic> _patch(String path, Map<String, dynamic> data) async {
    final uri = Uri.parse('$_base$path');
    try {
      final res = await http
          .patch(uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(data))
          .timeout(_timeout);
      final body = jsonDecode(res.body);
      if (body['success'] == true) return body['result'];
      debugPrint('[CfApi] PATCH $path error: ${body['error']}');
      return null;
    } catch (e) {
      debugPrint('[CfApi] PATCH $path exception: $e');
      return null;
    }
  }

  static Future<dynamic> _delete(String path) async {
    final uri = Uri.parse('$_base$path');
    try {
      final res = await http.delete(uri).timeout(_timeout);
      final body = jsonDecode(res.body);
      if (body['success'] == true) return body['result'];
      debugPrint('[CfApi] DELETE $path error: ${body['error']}');
      return null;
    } catch (e) {
      debugPrint('[CfApi] DELETE $path exception: $e');
      return null;
    }
  }

  /// DELETE com body JSON + header customizado (ex: reset admin)
  static Future<Map<String, dynamic>?> _deleteWithBody(
    String path,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$_base$path');
    try {
      final res = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          ...?headers,
        },
        body: jsonEncode(data),
      ).timeout(_timeout);
      final body = jsonDecode(res.body);
      return Map<String, dynamic>.from(body);
    } catch (e) {
      debugPrint('[CfApi] DELETE+body $path exception: $e');
      return null;
    }
  }

  // -- ADMIN RESET -----------------------------------------------------------

  /// Apaga dados do sistema. target: 'sales' | 'subscriptions' | 'withdrawals' | 'all'
  static const String _resetSecret = 'sharewallet_reset_2024';

  static Future<Map<String, dynamic>?> adminReset(String target) async {
    final raw = await _deleteWithBody(
      '/api/admin/reset',
      {'target': target},
      headers: {'X-Admin-Secret': _resetSecret},
    );
    if (raw == null) return null;
    // Worker retorna {success:true, result:{success:true, target:..., results:{...}}}
    // Desembala o 'result' interno para facilitar o uso no Flutter
    if (raw['success'] == true && raw['result'] is Map) {
      return Map<String, dynamic>.from(raw['result'] as Map);
    }
    // Erro: propaga o body cru para exibir 'error'
    return raw;
  }

  // -- GESTÃO DE SENHAS (admin) ----------------------------------------------

  /// Lista afiliados com firebase_uid para gestão de senhas.
  static Future<List<Map<String, dynamic>>> adminListUsers() async {
    final uri = Uri.parse('$_base/api/admin/list-users');
    try {
      final res = await http.get(
        uri,
        headers: {'X-Admin-Secret': _resetSecret},
      ).timeout(_timeout);
      final body = jsonDecode(res.body);
      if (body is Map && body['result'] is Map) {
        final result = body['result'] as Map;
        if (result['users'] is List) {
          return List<Map<String, dynamic>>.from(
            (result['users'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[CfApi] adminListUsers error: $e');
    }
    return [];
  }

  /// Redefine a senha de um afiliado via Firebase Admin (sem precisar do usuário).
  static Future<Map<String, dynamic>?> adminResetPassword(
      String uid, String newPassword) async {
    final uri = Uri.parse('$_base/api/admin/reset-password');
    try {
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'X-Admin-Secret': _resetSecret,
        },
        body: jsonEncode({'uid': uid, 'password': newPassword}),
      ).timeout(const Duration(seconds: 15));
      final body = jsonDecode(res.body);
      if (body is Map) return Map<String, dynamic>.from(body);
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[CfApi] adminResetPassword error: $e');
      return null;
    }
  }

  // -- WITHDRAWAL CONFIG (limites globais de saque) --------------------------

  static Future<Map<String, dynamic>> getWithdrawalConfig() async {
    final res = await _get('/api/admin/withdrawal-config');
    if (res is Map && res['config'] is Map) {
      return Map<String, dynamic>.from(res['config'] as Map);
    }
    return {'min_saque': 0.0, 'max_saque': 0.0};
  }

  static Future<bool> saveWithdrawalConfig({
    required double minSaque,
    required double maxSaque,
  }) async {
    final res = await _post('/api/admin/withdrawal-config', {
      'min_saque': minSaque,
      'max_saque': maxSaque,
    });
    return res != null && res['success'] == true;
  }

  // -- PRODUCTS --------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getProducts({bool all = false}) async {
    final res = await _get(all ? '/api/products/all' : '/api/products');
    if (res == null) return [];
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<Map<String, dynamic>?> saveProduct(Map<String, dynamic> data, {bool isNew = false}) async {
    if (isNew) return await _post('/api/products', data);
    return await _put('/api/products/${data['id']}', data);
  }

  static Future<bool> toggleProduct(String id) async {
    final res = await _patch('/api/products/$id/toggle', {});
    return res != null;
  }

  static Future<bool> deleteProduct(String id) async {
    final res = await _delete('/api/products/$id');
    return res != null;
  }

  // -- AFFILIATES ------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getAffiliates() async {
    final res = await _get('/api/affiliates');
    if (res == null) return [];
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<Map<String, dynamic>?> getAffiliateById(String id) async {
    return await _get('/api/affiliates/$id');
  }

  static Future<Map<String, dynamic>?> getAffiliateByCode(String code) async {
    if (code.trim().isEmpty) return null;
    return await _get('/api/affiliates/by-code/$code');
  }

  static Future<Map<String, dynamic>?> getAffiliateByEmail(String email) async {
    // Guard: email vazio geraria URL /api/affiliates/by-email/ -> 404
    if (email.trim().isEmpty) return null;

    // Verifica cache em memória antes de chamar a API
    final cached = _emailCache[email];
    if (cached != null && !cached.isExpired) {
      return cached.data;
    }

    final result = await _get('/api/affiliates/by-email/${Uri.encodeComponent(email)}');

    // Guarda no cache (mesmo null = afiliado não existe, evita re-query)
    _emailCache[email] = _CacheEntry(result);
    return result;
  }

  /// Invalida o cache de email (chamar após createAffiliate ou updateAffiliate)
  static void invalidateEmailCache(String email) {
    _emailCache.remove(email);
  }

  static Future<Map<String, dynamic>?> createAffiliate(Map<String, dynamic> data) async {
    return await _post('/api/affiliates', data);
  }

  static Future<Map<String, dynamic>?> updateAffiliate(String id, Map<String, dynamic> data) async {
    return await _patch('/api/affiliates/$id', data);
  }

  static Future<bool> deleteAffiliate(String id) async {
    final res = await _delete('/api/affiliates/$id');
    return res != null;
  }

  // -- WALLET ----------------------------------------------------------------

  static Future<Map<String, dynamic>?> getWallet(String userId) async {
    return await _get('/api/wallet/$userId');
  }

  static Future<Map<String, dynamic>?> updateWallet(String userId, Map<String, dynamic> data) async {
    return await _patch('/api/wallet/$userId', data);
  }

  // -- SUBSCRIPTIONS ---------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getSubscriptions() async {
    final res = await _get('/api/subscriptions');
    if (res == null) return [];
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<List<Map<String, dynamic>>> getSubscriptionsByAffiliate(String code) async {
    final res = await _get('/api/subscriptions/by-affiliate/$code');
    if (res == null) return [];
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<Map<String, dynamic>?> createSubscription(Map<String, dynamic> data) async {
    return await _post('/api/subscriptions', data);
  }

  static Future<Map<String, dynamic>?> updateSubscription(String id, Map<String, dynamic> data) async {
    return await _patch('/api/subscriptions/$id', data);
  }

  // -- WITHDRAWALS -----------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getWithdrawals() async {
    final res = await _get('/api/withdrawals');
    if (res == null) return [];
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<List<Map<String, dynamic>>> getWithdrawalsByUser(String userId) async {
    final res = await _get('/api/withdrawals/by-user/$userId');
    if (res == null) return [];
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<Map<String, dynamic>?> createWithdrawal(Map<String, dynamic> data) async {
    return await _post('/api/withdrawals', data);
  }

  static Future<bool> approveWithdrawal(String id, {String? txId}) async {
    final res = await _patch('/api/withdrawals/$id', {'status': 'aprovado', 'tx_id': txId});
    return res != null;
  }

  static Future<bool> rejectWithdrawal(String id, String motivo) async {
    final res = await _patch('/api/withdrawals/$id', {'status': 'recusado', 'motivo': motivo});
    return res != null;
  }

  // -- SALES -----------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getSalesByUser(String userId) async {
    final res = await _get('/api/sales/by-user/$userId');
    if (res == null) return [];
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<Map<String, dynamic>?> createSale(Map<String, dynamic> data) async {
    return await _post('/api/sales', data);
  }

  /// Admin: lista todas as vendas com filtros opcionais.
  /// Parâmetros aceitos pelo worker: status, product_id, affiliate_code,
  /// date_from, date_to, charge_type (pixRecorrente|pixAvulso), limit.
  static Future<List<Map<String, dynamic>>> getAllSales({
    String? status,
    String? productId,
    String? affiliateCode,
    String? dateFrom,
    String? dateTo,
    String? chargeType,
    int limit = 500,
  }) async {
    final params = <String, String>{};
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (productId != null && productId.isNotEmpty) params['product_id'] = productId;
    if (affiliateCode != null && affiliateCode.isNotEmpty) params['affiliate_code'] = affiliateCode;
    if (dateFrom != null && dateFrom.isNotEmpty) params['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) params['date_to'] = dateTo;
    if (chargeType != null && chargeType.isNotEmpty) params['charge_type'] = chargeType;
    params['limit'] = '$limit';

    final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    final path = '/api/sales${query.isNotEmpty ? '?$query' : ''}';
    final res = await _get(path);
    if (res == null) return [];
    return List<Map<String, dynamic>>.from(res);
  }

  // -- RANKING ---------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getRanking() async {
    final res = await _get('/api/ranking');
    if (res == null) return [];
    return List<Map<String, dynamic>>.from(res);
  }

  // -- METRICS ---------------------------------------------------------------

  static Future<Map<String, dynamic>?> getMetrics() async {
    return await _get('/api/metrics');
  }

  // -- EMAIL -----------------------------------------------------------------

  /// Envia e-mail de confirmação de pagamento via MailChannels (Worker).
  /// Retorna true se enviado com sucesso.
  static Future<bool> sendConfirmationEmail({
    required String toEmail,
    required String toName,
    required String productName,
    required String productDescricao,
    required double valor,
    required double comissao,
    required String affiliateCode,
    required String paymentId,
  }) async {
    try {
      final res = await _post('/api/send-email', {
        'toEmail':          toEmail,
        'toName':           toName,
        'productName':      productName,
        'productDescricao': productDescricao,
        'valor':            valor,
        'comissao':         comissao,
        'affiliateCode':    affiliateCode,
        'paymentId':        paymentId,
      });
      return res != null && res['sent'] == true;
    } catch (_) {
      return false;
    }
  }

  // -- PAYMENT STATUS --------------------------------------------------------

  /// Consulta o status de um pagamento PIX pelo payment_id numérico do MP.
  static Future<Map<String, dynamic>?> getPaymentStatus(String paymentId) async {
    return await _get('/api/payment-status/$paymentId');
  }

  // ── Documentos de venda ────────────────────────────────────────────────────

  /// Envia os documentos coletados na tela de compra para a API
  /// [saleId]       : ID provisório gerado antes do pagamento (ex: "pre_TIMESTAMP")
  /// [productId]    : ID do produto
  /// [affiliateCode]: código do afiliado
  /// [clienteNome]  : nome do comprador
  /// [clienteEmail] : email do comprador
  /// [docsData]     : mapa { tipo: base64String } ex: {'cnh': 'data:image/...'}
  static Future<String?> uploadSaleDocs({
    required String saleId,
    required String productId,
    required String affiliateCode,
    required String clienteNome,
    required String clienteEmail,
    required Map<String, String> docsData,
  }) async {
    try {
      final result = await _post('/api/sale-docs', {
        'sale_id': saleId,
        'product_id': productId,
        'affiliate_code': affiliateCode,
        'cliente_nome': clienteNome,
        'cliente_email': clienteEmail,
        'docs_data': docsData,
      });
      return result?['id'] as String?;
    } catch (e) {
      debugPrint('[CfApiService] uploadSaleDocs error: $e');
      return null;
    }
  }

  /// Busca os documentos de uma venda pelo sale_id
  static Future<Map<String, dynamic>?> getSaleDocs(String saleId) async {
    return await _get('/api/sale-docs/$saleId');
  }

  /// Busca todos os documentos de vendas de um afiliado
  static Future<List<Map<String, dynamic>>> getSaleDocsByAffiliate(String code) async {
    final result = await _get('/api/sale-docs/by-affiliate/$code');
    if (result == null) return [];
    final list = result['result'] as List?;
    if (list == null) return [];
    return list.cast<Map<String, dynamic>>();
  }
}

// ---------------------------------------------------------------------------
// Cache helper interno para CfApiService
// ---------------------------------------------------------------------------
class _CacheEntry {
  final Map<String, dynamic>? data;
  final DateTime _createdAt;
  static const Duration _ttl = Duration(minutes: 5);

  _CacheEntry(this.data) : _createdAt = DateTime.now();

  bool get isExpired => DateTime.now().difference(_createdAt) > _ttl;
}
