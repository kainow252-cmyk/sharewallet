/**
 * sw_version.js — ShareWallet SW Removedor v4
 *
 * Este Service Worker NÃO faz cache, NÃO faz reload automático.
 * Propósito único: desregistrar SWs antigos silenciosamente.
 *
 * Histórico:
 *   v3 → causava loop de reset: activate→postMessage(SW_AUTO_RELOAD)→reload→instala novo SW→loop
 *   v4 → sem postMessage, sem reload, apenas limpa e se destrói
 *
 * APP_VERSION é injetada pelo patch_build.py (usada para cache-busting da URL do SW).
 */

var APP_VERSION   = '__APP_VERSION__';
var VERSION_CACHE = 'sw-ver-v1';

/* ── Install: ativa imediatamente ─────────────────────────── */
self.addEventListener('install', function(e) {
  self.skipWaiting();
});

/* ── Activate: limpa caches e se destrói ──────────────────── */
self.addEventListener('activate', function(e) {
  e.waitUntil(
    // Apaga todos os caches de versões anteriores
    caches.keys().then(function(names) {
      return Promise.all(names.map(function(name) {
        return caches.delete(name);
      }));
    }).then(function() {
      return self.clients.claim();
    }).then(function() {
      // Se desregistra silenciosamente — SEM postMessage, SEM reload
      // O browser vai buscar os arquivos frescos do servidor normalmente.
      return self.registration.unregister();
    })
  );
});

/* ── Fetch: NÃO registrado — não intercepta nada ──────────── */
