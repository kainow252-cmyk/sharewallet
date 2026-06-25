/**
 * sw_version.js — ShareWallet PWA Service Worker v2
 *
 * IMPORTANTE: O Chrome só dispara beforeinstallprompt se houver um SW
 * registrado com fetch handler. Este SW é mínimo — não cacheia nada,
 * só intercepta o fetch e passa para a rede.
 *
 * Também detecta mudança de APP_VERSION e notifica o cliente para
 * exibir o banner "Atualizar app".
 *
 * APP_VERSION é injetada pelo patch_build.py.
 */

var APP_VERSION   = '__APP_VERSION__';
var VERSION_CACHE = 'sw-ver-v1';

/* ── Install: ativa imediatamente ─────────────────────────── */
self.addEventListener('install', function(e) {
  self.skipWaiting();
  e.waitUntil(
    caches.open(VERSION_CACHE).then(function(c) {
      return c.put('version', new Response(APP_VERSION,
        { headers: { 'Content-Type': 'text/plain' } }));
    })
  );
});

/* ── Activate: assume controle de todas as abas ───────────── */
self.addEventListener('activate', function(e) {
  e.waitUntil(clients.claim());
});

/* ── Fetch: OBRIGATÓRIO para Chrome considerar instalável ─── */
/* Estratégia: network-first, sem cache próprio               */
self.addEventListener('fetch', function(e) {
  // Só intercepta requests do mesmo origin
  if (!e.request.url.startsWith(self.location.origin)) return;

  e.respondWith(
    fetch(e.request).then(function(resp) {
      // Aproveita para checar versão na raiz do app
      var url = e.request.url;
      if (url.endsWith('/app/') || url.endsWith('/app/index.html') ||
          url.endsWith('/app')) {
        checkVersion();
      }
      return resp;
    }).catch(function() {
      // Offline: tenta cache do browser (não temos cache próprio)
      return fetch(e.request);
    })
  );
});

/* ── Verifica versão e notifica se mudou ──────────────────── */
function checkVersion() {
  caches.open(VERSION_CACHE).then(function(c) {
    c.match('version').then(function(r) {
      if (!r) {
        // Primeira vez — grava versão atual
        c.put('version', new Response(APP_VERSION,
          { headers: { 'Content-Type': 'text/plain' } }));
        return;
      }
      r.text().then(function(cached) {
        if (cached !== APP_VERSION) {
          // Versão mudou — atualiza cache e notifica clientes
          c.put('version', new Response(APP_VERSION,
            { headers: { 'Content-Type': 'text/plain' } }));
          self.clients.matchAll({ includeUncontrolled: true })
            .then(function(list) {
              list.forEach(function(cl) {
                cl.postMessage({ type: 'SW_UPDATE_AVAILABLE', v: APP_VERSION });
              });
            });
        }
      });
    });
  });
}
