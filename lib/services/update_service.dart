import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Informações sobre uma versão disponível
class VersionInfo {
  final String version;       // ex: "1.0.2"
  final int buildNumber;      // ex: 3
  final String apkUrl;        // URL direta para baixar o APK
  final String changelog;     // Novidades desta versão
  final bool forceUpdate;     // true = não pode ignorar
  final DateTime releasedAt;

  const VersionInfo({
    required this.version,
    required this.buildNumber,
    required this.apkUrl,
    required this.changelog,
    required this.forceUpdate,
    required this.releasedAt,
  });

  factory VersionInfo.fromMap(Map<String, dynamic> m) => VersionInfo(
        version: m['version'] as String? ?? '1.0.0',
        buildNumber: (m['build_number'] as num?)?.toInt() ?? 1,
        apkUrl: m['apk_url'] as String? ?? 'https://api.sharewallet.com.br/apk/download',
        changelog: m['changelog'] as String? ?? '',
        forceUpdate: m['force_update'] as bool? ?? false,
        releasedAt: DateTime.tryParse(m['released_at'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// Resultado da checagem de update
class UpdateCheckResult {
  final bool hasUpdate;
  final bool forceUpdate;
  final VersionInfo? info;
  final String? error;

  const UpdateCheckResult({
    required this.hasUpdate,
    this.forceUpdate = false,
    this.info,
    this.error,
  });

  static const noUpdate = UpdateCheckResult(hasUpdate: false);
}

class UpdateService {
  static const _apiUrl = 'https://api.sharewallet.com.br/api/version';
  static const _skipKey = 'update_skip_version';
  static const _lastCheckKey = 'update_last_check';
  // Intervalo mínimo entre checks: 1 hora
  static const _checkIntervalHours = 1;

  /// Verifica se há uma nova versão disponível.
  /// Retorna [UpdateCheckResult] com os detalhes.
  static Future<UpdateCheckResult> check({bool force = false}) async {
    // Apenas Android verifica update (não Web, não iOS)
    if (kIsWeb) return UpdateCheckResult.noUpdate;

    try {
      // Throttle: não verifica mais de 1x por hora (exceto force)
      if (!force) {
        final prefs = await SharedPreferences.getInstance();
        final lastCheck = prefs.getString(_lastCheckKey);
        if (lastCheck != null) {
          final last = DateTime.tryParse(lastCheck);
          if (last != null) {
            final diff = DateTime.now().difference(last).inHours;
            if (diff < _checkIntervalHours) {
              return UpdateCheckResult.noUpdate;
            }
          }
        }
      }

      // Pega versão instalada atual
      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 1;

      // Consulta Worker
      final res = await http.get(
        Uri.parse(_apiUrl),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) {
        return UpdateCheckResult(
          hasUpdate: false,
          error: 'HTTP ${res.statusCode}',
        );
      }

      final data = json.decode(res.body) as Map<String, dynamic>;
      final result = data['result'] as Map<String, dynamic>? ?? data;
      final versionInfo = VersionInfo.fromMap(result);

      // Grava timestamp do check
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastCheckKey, DateTime.now().toIso8601String());

      if (versionInfo.buildNumber <= currentBuild) {
        return UpdateCheckResult.noUpdate;
      }

      // Verifica se usuário já ignorou esta versão (skip)
      final skippedVersion = prefs.getString(_skipKey) ?? '';
      if (!versionInfo.forceUpdate && skippedVersion == versionInfo.version) {
        return UpdateCheckResult.noUpdate;
      }

      return UpdateCheckResult(
        hasUpdate: true,
        forceUpdate: versionInfo.forceUpdate,
        info: versionInfo,
      );
    } catch (e) {
      debugPrint('[UpdateService] Erro ao verificar update: $e');
      return UpdateCheckResult(hasUpdate: false, error: e.toString());
    }
  }

  /// Marca a versão como "ignorada" (só funciona se não for forceUpdate)
  static Future<void> skipVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_skipKey, version);
  }

  /// Abre a URL de download do APK
  static Future<void> downloadApk(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
