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
  static const Duration _timeout = Duration(seconds: 10);

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
    return _deleteWithBody(
      '/api/admin/reset',
      {'target': target},
      headers: {'X-Admin-Secret': _resetSecret},
    );
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
    return await _get('/api/affiliates/by-email/${Uri.encodeComponent(email)}');
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
}
