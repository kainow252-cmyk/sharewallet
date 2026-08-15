import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Serviço de autenticação biométrica (digital / face ID) com armazenamento
/// seguro de credenciais para login automático na PWA.
class BiometricService {
  static final _auth    = LocalAuthentication();
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyEmail = 'sw_bio_email';
  static const _keyPass  = 'sw_bio_pass';
  static const _keyEnabled = 'sw_bio_enabled';

  // ── Verificação de suporte ──────────────────────────────────────────────

  /// Retorna true se o dispositivo tem biometria configurada E disponível.
  static Future<bool> isAvailable() async {
    if (kIsWeb) return false; // PWA web não suporta local_auth
    try {
      final canCheck  = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      if (!canCheck || !isSupported) return false;

      final biometrics = await _auth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint('[BiometricService] isAvailable error: $e');
      return false;
    }
  }

  /// Retorna true se usuário já ativou biometria E tem credenciais salvas.
  static Future<bool> isEnabled() async {
    if (kIsWeb) return false;
    try {
      final enabled = await _storage.read(key: _keyEnabled);
      if (enabled != 'true') return false;
      final email = await _storage.read(key: _keyEmail);
      final pass  = await _storage.read(key: _keyPass);
      return email != null && email.isNotEmpty &&
             pass  != null && pass.isNotEmpty;
    } catch (e) {
      if (kDebugMode) debugPrint('[BiometricService] isEnabled error: $e');
      return false;
    }
  }

  // ── Autenticação ────────────────────────────────────────────────────────

  /// Solicita biometria ao usuário.
  /// Retorna true se autenticado com sucesso.
  static Future<bool> authenticate() async {
    if (kIsWeb) return false;
    try {
      return await _auth.authenticate(
        localizedReason: 'Use sua digital ou reconhecimento facial para entrar no ShareWallet',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // permite PIN como fallback
          sensitiveTransaction: false,
        ),
      );
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint('[BiometricService] authenticate error: $e');
      return false;
    }
  }

  // ── Credenciais ─────────────────────────────────────────────────────────

  /// Salva email + senha com criptografia AES no Keystore Android.
  static Future<void> saveCredentials(String email, String password) async {
    if (kIsWeb) return;
    try {
      await _storage.write(key: _keyEmail, value: email);
      await _storage.write(key: _keyPass,  value: password);
      await _storage.write(key: _keyEnabled, value: 'true');
    } catch (e) {
      if (kDebugMode) debugPrint('[BiometricService] saveCredentials error: $e');
    }
  }

  /// Carrega credenciais salvas. Retorna null se não existirem.
  static Future<({String email, String password})?> loadCredentials() async {
    if (kIsWeb) return null;
    try {
      final email = await _storage.read(key: _keyEmail);
      final pass  = await _storage.read(key: _keyPass);
      if (email == null || pass == null || email.isEmpty || pass.isEmpty) {
        return null;
      }
      return (email: email, password: pass);
    } catch (e) {
      if (kDebugMode) debugPrint('[BiometricService] loadCredentials error: $e');
      return null;
    }
  }

  /// Remove credenciais e desativa biometria.
  static Future<void> disable() async {
    if (kIsWeb) return;
    try {
      await _storage.delete(key: _keyEmail);
      await _storage.delete(key: _keyPass);
      await _storage.delete(key: _keyEnabled);
    } catch (e) {
      if (kDebugMode) debugPrint('[BiometricService] disable error: $e');
    }
  }

  // ── Fluxo completo: autentica + carrega credenciais ─────────────────────

  /// Tenta fazer login via biometria:
  /// 1. Verifica se está habilitado
  /// 2. Autentica com digital/face
  /// 3. Carrega e retorna credenciais
  static Future<({String email, String password})?> loginWithBiometric() async {
    if (kIsWeb) return null;
    try {
      final enabled = await isEnabled();
      if (!enabled) return null;

      final ok = await authenticate();
      if (!ok) return null;

      return await loadCredentials();
    } catch (e) {
      if (kDebugMode) debugPrint('[BiometricService] loginWithBiometric error: $e');
      return null;
    }
  }
}
