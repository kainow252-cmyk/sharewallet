import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Serviço base de comunicação com o backend NestJS.
/// O Flutter NUNCA fala diretamente com a Woovi — sempre via backend.
class ApiService {
  // ── Configuração ──────────────────────────────────────────────────────────
  // Mude para a URL real do seu backend quando estiver em produção
  static const String _baseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://localhost:3000/api',
  );

  // ── Token JWT armazenado localmente ───────────────────────────────────────
  static String? _token;

  static Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  static Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
  }

  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  static bool get hasToken => _token != null;

  // ── Headers padrão ────────────────────────────────────────────────────────
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // ── GET ───────────────────────────────────────────────────────────────────
  static Future<ApiResponse> get(String path) async {
    try {
      final uri = Uri.parse('$_baseUrl$path');
      if (kDebugMode) debugPrint('GET $uri');

      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));

      return _parse(response);
    } catch (e) {
      return ApiResponse.error('Erro de conexão: $e');
    }
  }

  // ── POST ──────────────────────────────────────────────────────────────────
  static Future<ApiResponse> post(String path, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$_baseUrl$path');
      if (kDebugMode) debugPrint('POST $uri | body: ${jsonEncode(body)}');

      final response = await http
          .post(uri, headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));

      return _parse(response);
    } catch (e) {
      return ApiResponse.error('Erro de conexão: $e');
    }
  }

  // ── PUT ───────────────────────────────────────────────────────────────────
  static Future<ApiResponse> put(String path, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final response = await http
          .put(uri, headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      return _parse(response);
    } catch (e) {
      return ApiResponse.error('Erro de conexão: $e');
    }
  }

  // ── Parser ────────────────────────────────────────────────────────────────
  static ApiResponse _parse(http.Response response) {
    if (kDebugMode) {
      debugPrint('Response ${response.statusCode}: ${response.body.substring(0, response.body.length.clamp(0, 300))}');
    }

    try {
      final data = jsonDecode(response.body);
      final isSuccess = response.statusCode >= 200 && response.statusCode < 300;

      if (isSuccess) {
        return ApiResponse.success(data);
      } else {
        final message = data['message'] ?? data['error'] ?? 'Erro desconhecido';
        return ApiResponse.error(message.toString(), statusCode: response.statusCode);
      }
    } catch (_) {
      return ApiResponse.error('Resposta inválida do servidor', statusCode: response.statusCode);
    }
  }
}

// ── Resposta padronizada ───────────────────────────────────────────────────

class ApiResponse {
  final bool success;
  final dynamic data;
  final String? errorMessage;
  final int? statusCode;

  ApiResponse._({
    required this.success,
    this.data,
    this.errorMessage,
    this.statusCode,
  });

  factory ApiResponse.success(dynamic data) =>
      ApiResponse._(success: true, data: data);

  factory ApiResponse.error(String message, {int? statusCode}) =>
      ApiResponse._(success: false, errorMessage: message, statusCode: statusCode);

  bool get isUnauthorized => statusCode == 401;
}
