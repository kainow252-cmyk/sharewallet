// flutter_service_worker.js — SW SUICIDA / KILL SWITCH
//
// Este arquivo substitui o Service Worker padrão do Flutter.
// Quando o SW antigo detectar este arquivo novo (via update check),
// ele vai instalar este SW, que imediatamente:
//   1. Apaga TODOS os caches (flutter-app-cache, flutter-app-manifest, etc.)
//   2. Se desregistra
//   3. Força o browser a recarregar a página com o código mais recente
//
// Isso resolve o problema de "422 persistente" causado pelo SW antigo
// continuando a servir main.dart.js desatualizado do cache.
'use strict';

self.addEventListener('install', function(event) {
  // Ativa imediatamente sem esperar outros SWs
  self.skipWaiting();
});

self.addEventListener('activate', function(event) {
  event.waitUntil(
    // 1. Apagar todos os caches
    caches.keys().then(function(cacheNames) {
      return Promise.all(
        cacheNames.map(function(cacheName) {
          return caches.delete(cacheName);
        })
      );
    }).then(function() {
      // 2. Assumir controle de todos os clientes imediatamente
      return self.clients.claim();
    }).then(function() {
      // 3. Notificar todos os clientes para recarregar
      return self.clients.matchAll({ type: 'window' }).then(function(clients) {
        clients.forEach(function(client) {
          client.navigate(client.url);
        });
      });
    }).then(function() {
      // 4. Se auto-desregistrar
      return self.registration.unregister();
    })
  );
});

// Sem listener 'fetch' — SW suicida não precisa interceptar requests.
// Registrar um listener vazio causaria Chrome warning "No-op fetch handler"
// e overhead desnecessário em todas as navegações.
