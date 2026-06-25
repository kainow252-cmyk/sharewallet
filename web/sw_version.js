/**
 * sw_version.js — ShareWallet PWA Version Service Worker
 *
 * Este SW é registrado APENAS para detectar atualizações de versão.
 * NÃO faz cache de nenhum recurso — o Cloudflare Pages já cuida disso.
 *
 * Funcionamento:
 *  - Ao instalar, grava a versão atual no cache de versão
 *  - No próximo fetch de /app/ ele verifica se a versão mudou
 *  - Se mudou, envia mensagem SW_UPDATE_AVAILABLE para o cliente
 *
 * A APP_VERSION é injetada pelo patch_build.py no momento do deploy.
 */

var APP_VERSION = '__APP_VERSION__';  // substituído pelo patch_build.py
var VERSION_CACHE = 'sw-version-v1';
var VERSION_KEY   = 'app_version';

/* ─── Install: grava a versão atual ─────────────────────────── */
self.addEventListener('install', function (event) {
  // Ativa imediatamente sem esperar abas fecharem
  self.skipWaiting();

  event.waitUntil(
    caches.open(VERSION_CACHE).then(function (cache) {
      // Grava a versão como uma Response fake no cache
      return cache.put(
        VERSION_KEY,
        new Response(APP_VERSION, { headers: { 'Content-Type': 'text/plain' } })
      );
    })
  );
});

/* ─── Activate: assume o controle de todas as abas ──────────── */
self.addEventListener('activate', function (event) {
  event.waitUntil(clients.claim());
});

/* ─── Fetch: apenas monitora /app/ para detectar se versão mudou ─ */
self.addEventListener('fetch', function (event) {
  // Só verifica na raiz do app (evita overhead em assets)
  var url = event.request.url;
  var isAppRoot = url.endsWith('/app/') || url.endsWith('/app/index.html') || url.endsWith('/app');

  if (!isAppRoot) return;  // passa direto para a rede sem interceptar

  event.respondWith(
    fetch(event.request).then(function (networkResponse) {
      // Após buscar na rede, verifica se a versão mudou
      checkVersionAndNotify();
      return networkResponse;
    }).catch(function () {
      // Offline: retorna da rede diretamente (sem cache próprio)
      return fetch(event.request);
    })
  );
});

/* ─── Verifica versão e notifica clientes ───────────────────── */
function checkVersionAndNotify() {
  caches.open(VERSION_CACHE).then(function (cache) {
    cache.match(VERSION_KEY).then(function (cachedResponse) {
      if (!cachedResponse) {
        // Primeira vez — só grava
        cache.put(VERSION_KEY, new Response(APP_VERSION,
          { headers: { 'Content-Type': 'text/plain' } }));
        return;
      }

      cachedResponse.text().then(function (cachedVersion) {
        if (cachedVersion !== APP_VERSION) {
          // Versão mudou! Atualiza o cache e notifica todos os clientes
          cache.put(VERSION_KEY, new Response(APP_VERSION,
            { headers: { 'Content-Type': 'text/plain' } }));

          self.clients.matchAll({ includeUncontrolled: true }).then(function (clientList) {
            clientList.forEach(function (client) {
              client.postMessage({ type: 'SW_UPDATE_AVAILABLE', version: APP_VERSION });
            });
          });
        }
      });
    });
  });
}
