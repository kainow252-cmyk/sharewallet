/**
 * sw_version.js — ShareWallet PWA Service Worker v3
 *
 * Quando o app é aberto e detecta nova versão:
 *  → Recarrega SILENCIOSAMENTE (sem pedir ao usuário)
 *
 * APP_VERSION é injetada pelo patch_build.py a cada deploy.
 */

var APP_VERSION   = '__APP_VERSION__';
var VERSION_CACHE = 'sw-ver-v1';

/* ── Install: ativa imediatamente ─────────────────────────── */
self.addEventListener('install', function(e) {
  self.skipWaiting();  // assume controle sem esperar fechar abas
  e.waitUntil(
    caches.open(VERSION_CACHE).then(function(c) {
      return c.put('version', new Response(APP_VERSION,
        { headers: { 'Content-Type': 'text/plain' } }));
    })
  );
});

/* ── Activate: assume controle de todas as abas ───────────── */
self.addEventListener('activate', function(e) {
  e.waitUntil(
    clients.claim().then(function() {
      // Ao ativar um novo SW, notifica TODOS os clientes para recarregar
      return self.clients.matchAll({ includeUncontrolled: true, type: 'window' })
        .then(function(list) {
          list.forEach(function(cl) {
            // Reload silencioso — sem mostrar banner
            cl.postMessage({ type: 'SW_AUTO_RELOAD' });
          });
        });
    })
  );
});

/* ── Fetch: OBRIGATÓRIO para Chrome disparar beforeinstallprompt ── */
/* NUNCA intercepta: não cacheia, não retorna 503, passa tudo direto para a rede. */
/* Anteriormente o catch retornava Response(503) que bloqueava arquivos .wasm grandes. */
self.addEventListener('fetch', function(e) {
  // Passthrough total — não intercepta nem altera nada.
  // O Chrome só dispara beforeinstallprompt se houver um fetch handler registrado.
  // Mas NÃO usamos e.respondWith() para não atrasar nem causar 503 em recursos grandes.
});
