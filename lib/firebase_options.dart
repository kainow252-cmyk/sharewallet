// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Configurações Firebase geradas automaticamente via API
/// Projeto: affiliate-wallet-75853
/// Gerado em: 2025-06-03
///
/// ⚠️  IMPORTANTE: Antes de usar Firebase, crie o Firestore Database:
/// https://console.cloud.google.com/datastore/setup?project=affiliate-wallet-75853
/// Escolha "Cloud Firestore" → "Modo nativo" → Região "southamerica-east1"
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return web;
      case TargetPlatform.linux:
        return web;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions não suportado nesta plataforma.',
        );
    }
  }

  // ── Web ────────────────────────────────────────────────────────────────────
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAapUKRo74zDOzrjjtZnAjodjptUnnHrCM',
    appId: '1:470218127330:web:310f8672bbdefe2f4aabbb',
    messagingSenderId: '470218127330',
    projectId: 'affiliate-wallet-75853',
    authDomain: '5060-i06gofqj3ttmhnho7nu9e-82b888ba.sandbox.novita.ai',
    storageBucket: 'affiliate-wallet-75853.firebasestorage.app',
  );

  // ── Android ────────────────────────────────────────────────────────────────
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCN639SuHRlNzGZUa9rW7cgrNUN5lZ-wpA',
    appId: '1:470218127330:android:d3af2223eaf22d2d4aabbb',
    messagingSenderId: '470218127330',
    projectId: 'affiliate-wallet-75853',
    storageBucket: 'affiliate-wallet-75853.firebasestorage.app',
  );

  // ── iOS ────────────────────────────────────────────────────────────────────
  // Configure no Firebase Console se for suportar iOS
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCN639SuHRlNzGZUa9rW7cgrNUN5lZ-wpA',
    appId: '1:470218127330:ios:placeholder',
    messagingSenderId: '470218127330',
    projectId: 'affiliate-wallet-75853',
    storageBucket: 'affiliate-wallet-75853.firebasestorage.app',
    iosClientId: '470218127330-d1tr5j60i6db3ui56jgdqhar039dilvh.apps.googleusercontent.com',
    iosBundleId: 'com.affiliatewallet.wallet',
  );

  // ── macOS ──────────────────────────────────────────────────────────────────
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCN639SuHRlNzGZUa9rW7cgrNUN5lZ-wpA',
    appId: '1:470218127330:ios:placeholder',
    messagingSenderId: '470218127330',
    projectId: 'affiliate-wallet-75853',
    storageBucket: 'affiliate-wallet-75853.firebasestorage.app',
    iosClientId: '470218127330-d1tr5j60i6db3ui56jgdqhar039dilvh.apps.googleusercontent.com',
    iosBundleId: 'com.affiliatewallet.wallet',
  );
}
