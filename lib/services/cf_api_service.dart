import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Cliente HTTP para o Cloudflare Worker (D1 SQLite).
/// Resposta típica: < 100ms global.
class CfApiService {
  static const String _base = 'https://sharewallet-api.kainow252.workers.dev';
  static const Duration _timeout = Duration(seconds: 10);

  // ── HTTP helpers ──────────────────────────────────────────────────────────

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

  // ── PRODUCTS ──────────────────────────────────────────────────────────────

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

  // ── AFFILIATES ────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getAffiliates() async {
    final res = await _get('/api/affiliates');
    if (res == null) return [];
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<Map<String, dynamic>?> getAffiliateById(String id) async {
    return await _get('/api/affiliates/$id');
  }

  static Future<Map<String, dynamic>?> getAffiliateByCode(String code) async {
    return await _get('/api/affiliates/by-code/$code');
  }

  static Future<Map<String, dynamic>?> getAffiliateByEmail(String email) async {
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

  // ── WALLET ────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getWallet(String userId) async {
    return await _get('/api/wallet/$userId');
  }

  static Future<Map<String, dynamic>?> updateWallet(String userId, Map<String, dynamic> data) async {
    return await _patch('/api/wallet/$userId', data);
  }

  // ── SUBSCRIPTIONS ─────────────────────────────────────────────────────────

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

  // ── WITHDRAWALS ───────────────────────────────────────────────────────────

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

  // ── SALES ─────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getSalesByUser(String userId) async {
    final res = await _get('/api/sales/by-user/$userId');
    if (res == null) return [];
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<Map<String, dynamic>?> createSale(Map<String, dynamic> data) async {
    return await _post('/api/sales', data);
  }

  // ── RANKING ───────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getRanking() async {
    final res = await _get('/api/ranking');
    if (res == null) return [];
    return List<Map<String, dynamic>>.from(res);
  }

  // ── METRICS ───────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getMetrics() async {
    return await _get('/api/metrics');
  }
}
