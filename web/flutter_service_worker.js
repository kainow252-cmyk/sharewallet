// flutter_service_worker.js — SW REMOVEDOR SILENCIOSO
//
// Propósito único: desregistrar qualquer SW antigo do Flutter sem causar reload.
//
// O Flutter build gera um SW que cacheia main.dart.js (4MB) e serve código
// antigo mesmo após novos deploys. Este arquivo substitui esse SW.
//
// IMPORTANTE: NÃO faz client.navigate() nem postMessage — apenas limpa caches
// e se destrói silenciosamente, sem causar reloads ou loops.
//
'use strict';

self.addEventListener('install', function(event) {
  // Ativa imediatamente sem esperar fechar abas
  self.skipWaiting();
});

self.addEventListener('activate', function(event) {
  event.waitUntil(
    // 1. Apagar todos os caches do Flutter
    caches.keys().then(function(cacheNames) {
      return Promise.all(
        cacheNames.map(function(cacheName) {
          return caches.delete(cacheName);
        })
      );
    }).then(function() {
      // 2. Assumir controle (necessário para poder se desregistrar)
      return self.clients.claim();
    }).then(function() {
      // 3. Se auto-desregistrar silenciosamente
      // NÃO faz reload nem navigate — o browser vai usar os arquivos do servidor
      // normalmente na próxima requisição (que terão Cache-Control: immutable).
      return self.registration.unregister();
    })
  );
});

// SEM listener 'fetch' — não intercepta nada, não cacheia nada.
// SEM client.navigate() — não causa reloads/loops.
