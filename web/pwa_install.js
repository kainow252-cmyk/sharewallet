/**
 * pwa_install.js — ShareWallet PWA Install v10
 *
 * LÓGICA SIMPLES:
 *   1. standalone → pula landing, abre app direto
 *   2. /produto/  → silêncio
 *   3. /admin     → troca manifest
 *   4. Mobile     → espera até 5s pelo beforeinstallprompt
 *                   Se chegar → botão INSTALAR 1 clique
 *                   Se não chegar → nada (não mostra guia confuso)
 *   5. Dismissed < 3 dias → silêncio
 */
(function () {
  'use strict';

  var KEY_INSTALLED   = 'sw_pwa_v3_installed';
  var KEY_DISMISSED   = 'sw_pwa_v10_dismissed';
  var KEY_PENDING_REF = 'sw_pending_ref';
  var KEY_PENDING_TS  = 'sw_pending_ref_ts';
  var DISMISS_TTL     = 3 * 24 * 60 * 60 * 1000;
  var REF_TTL         = 30 * 24 * 60 * 60 * 1000;

  /* ── helpers ─────────────────────────────────────────────── */
  function isStandalone() {
    return window.matchMedia('(display-mode: standalone)').matches ||
           navigator.standalone === true;
  }
  function isIOS()     { return /iphone|ipad|ipod/i.test(navigator.userAgent); }
  function isAndroid() { return /android/i.test(navigator.userAgent); }
  function isMobile()  { return isIOS() || isAndroid(); }

  function wasInstalled() { return localStorage.getItem(KEY_INSTALLED) === '1'; }
  function isBuyerRoute() { return (window.location.hash || '').indexOf('/produto/') !== -1; }
  function isAdminRoute() { return (window.location.hash || '').indexOf('/admin') !== -1; }
  function wasDismissed() {
    var t = localStorage.getItem(KEY_DISMISSED);
    return !!t && (Date.now() - parseInt(t)) < DISMISS_TTL;
  }
  function markInstalled() { localStorage.setItem(KEY_INSTALLED, '1'); }
  function markDismissed() { localStorage.setItem(KEY_DISMISSED, String(Date.now())); }

  /* ── ref de afiliado ─────────────────────────────────────── */
  function readRefFromUrl() {
    var hash = window.location.hash || '';
    var hm = hash.match(/[?&]ref=([^&]+)/);
    if (hm) return decodeURIComponent(hm[1]).replace(/^@+/, '');
    var sm = window.location.search.match(/[?&]ref=([^&]+)/);
    if (sm) return decodeURIComponent(sm[1]).replace(/^@+/, '');
    return null;
  }
  function savePendingRef(code) {
    if (!code) return;
    localStorage.setItem(KEY_PENDING_REF, code);
    localStorage.setItem(KEY_PENDING_TS, String(Date.now()));
  }
  function getPendingRef() {
    var code = localStorage.getItem(KEY_PENDING_REF);
    var ts   = parseInt(localStorage.getItem(KEY_PENDING_TS) || '0');
    if (!code) return null;
    if (Date.now() - ts > REF_TTL) {
      localStorage.removeItem(KEY_PENDING_REF);
      localStorage.removeItem(KEY_PENDING_TS);
      return null;
    }
    return code;
  }
  function clearPendingRef() {
    localStorage.removeItem(KEY_PENDING_REF);
    localStorage.removeItem(KEY_PENDING_TS);
  }

  /* ── fechar painel ───────────────────────────────────────── */
  function closePanel(id) {
    var el = document.getElementById(id);
    if (!el) return;
    el.style.transition = 'transform .3s ease, opacity .3s ease';
    el.style.transform  = 'translateY(110%)';
    el.style.opacity    = '0';
    setTimeout(function () { if (el.parentNode) el.remove(); }, 350);
  }

  /* ── toast ───────────────────────────────────────────────── */
  function toast(msg) {
    var t = document.createElement('div');
    t.style.cssText =
      'position:fixed;bottom:100px;left:50%;transform:translateX(-50%);' +
      'background:#C9A84C;color:#0f1e12;font-weight:800;' +
      'padding:12px 26px;border-radius:30px;font-size:14px;' +
      'z-index:2147483647;white-space:nowrap;' +
      'box-shadow:0 4px 24px rgba(201,168,76,.5);' +
      'font-family:-apple-system,BlinkMacSystemFont,sans-serif;';
    t.textContent = msg;
    document.body.appendChild(t);
    setTimeout(function () { if (t.parentNode) t.remove(); }, 3500);
  }

  var ICON = '/app/icons/Icon-v202606251651-192.png';

  /* ── CSS ─────────────────────────────────────────────────── */
  function injectCSS() {
    if (document.getElementById('pwa-css')) return;
    var s = document.createElement('style');
    s.id = 'pwa-css';
    s.textContent =
      '@keyframes pwa-up{from{transform:translateY(110%);opacity:0}to{transform:translateY(0);opacity:1}}' +
      '@keyframes pwa-pulse{0%,100%{box-shadow:0 0 0 0 rgba(201,168,76,.45)}70%{box-shadow:0 0 0 12px rgba(201,168,76,0)}}' +

      '#pwa-banner{' +
        'position:fixed;bottom:0;left:0;right:0;z-index:2147483647;' +
        'background:linear-gradient(170deg,#0f2318 0%,#1a3520 100%);' +
        'border-top:2px solid #C9A84C;' +
        'padding:16px 16px calc(16px + env(safe-area-inset-bottom,0px));' +
        'box-shadow:0 -10px 48px rgba(0,0,0,.85);' +
        'animation:pwa-up .4s cubic-bezier(.22,.68,0,1.2) both;' +
        'font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;' +
      '}' +
      '#pwa-banner .pwa-row{display:flex;align-items:center;gap:13px;margin-bottom:14px;}' +
      '#pwa-banner img{width:52px;height:52px;border-radius:14px;flex-shrink:0;border:2px solid rgba(201,168,76,.5);}' +
      '#pwa-banner .pwa-info{flex:1;min-width:0;}' +
      '#pwa-banner .pwa-info b{display:block;font-size:15px;font-weight:800;color:#fff;margin-bottom:3px;}' +
      '#pwa-banner .pwa-info span{font-size:12px;color:rgba(255,255,255,.6);}' +
      '#pwa-banner .pwa-close{' +
        'width:32px;height:32px;border-radius:50%;border:none;cursor:pointer;' +
        'background:rgba(255,255,255,.1);color:rgba(255,255,255,.5);' +
        'font-size:16px;flex-shrink:0;display:flex;align-items:center;justify-content:center;' +
      '}' +
      '#pwa-btn-install{' +
        'width:100%;padding:15px;border-radius:14px;border:none;cursor:pointer;' +
        'font-size:16px;font-weight:800;letter-spacing:.2px;' +
        'background:linear-gradient(135deg,#C9A84C 0%,#f0c84a 100%);color:#0f1e12;' +
        'box-shadow:0 4px 20px rgba(201,168,76,.5);' +
        'animation:pwa-pulse 2s infinite;' +
        'display:flex;align-items:center;justify-content:center;gap:8px;' +
      '}';
    document.head.appendChild(s);
  }

  /* ── Banner install (1 clique) ───────────────────────────── */
  function showBanner(promptEvt) {
    if (document.getElementById('pwa-banner')) return;

    var el = document.createElement('div');
    el.id  = 'pwa-banner';
    el.innerHTML =
      '<div class="pwa-row">' +
        '<img src="' + ICON + '" alt="">' +
        '<div class="pwa-info">' +
          '<b>Instalar ShareWallet</b>' +
          '<span>Acesse como app, sem precisar do navegador</span>' +
        '</div>' +
        '<button class="pwa-close" id="pwa-close-btn">✕</button>' +
      '</div>' +
      '<button id="pwa-btn-install">📲&nbsp; Instalar app — grátis</button>';
    document.body.appendChild(el);

    document.getElementById('pwa-close-btn').onclick = function () {
      markDismissed();
      closePanel('pwa-banner');
    };

    document.getElementById('pwa-btn-install').onclick = function () {
      closePanel('pwa-banner');
      if (promptEvt) {
        promptEvt.prompt();
        promptEvt.userChoice.then(function (r) {
          if (r.outcome === 'accepted') {
            markInstalled();
            toast('✅ ShareWallet instalado!');
          }
        });
      }
    };
  }

  /* ── troca manifest admin ────────────────────────────────── */
  function swapManifestIfAdmin() {
    if (!isAdminRoute()) return;
    var link = document.querySelector('link[rel="manifest"]');
    if (!link) return;
    var cur = link.getAttribute('href') || '';
    if (cur.indexOf('manifest-admin') !== -1) return;
    link.setAttribute('href', cur.replace('manifest.json', 'manifest-admin.json'));
  }

  /* ── limpa SWs residuais ─────────────────────────────────── */
  function registerSW() {
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.getRegistrations()
        .then(function (regs) { regs.forEach(function (r) { r.unregister(); }); })
        .catch(function () {});
    }
  }

  /* ── captura prompt o quanto antes ──────────────────────── */
  var _prompt        = null;
  var _bannerShown   = false;
  var _readyToShow   = false;   // true quando o timeout de 2s disparou

  window.addEventListener('beforeinstallprompt', function (e) {
    e.preventDefault();
    _prompt = e;
    // Se o timeout já passou e ainda estávamos esperando → mostra agora
    if (_readyToShow && !_bannerShown && !wasDismissed() && !wasInstalled()) {
      _bannerShown = true;
      showBanner(_prompt);
    }
  });

  window.addEventListener('appinstalled', function () {
    markInstalled();
    closePanel('pwa-banner');
    toast('✅ ShareWallet instalado!');
  });

  /* ── INIT ────────────────────────────────────────────────── */
  function init() {
    injectCSS();
    registerSW();

    var urlRef = readRefFromUrl();
    if (urlRef) savePendingRef(urlRef);

    swapManifestIfAdmin();
    window.addEventListener('hashchange', swapManifestIfAdmin);
    window.addEventListener('hashchange', function () {
      if (isBuyerRoute()) closePanel('pwa-banner');
    });

    /* 1. PWA já instalada (standalone) */
    if (isStandalone()) {
      markInstalled();
      var pendingRef = getPendingRef();
      setTimeout(function () {
        var h = window.location.hash || '';
        if (pendingRef) {
          clearPendingRef();
          if (h.indexOf('/produto/') === -1 && h.indexOf('/login') === -1 &&
              h.indexOf('/home') === -1 && h.indexOf('/admin') === -1) {
            window.location.hash = '/landing?ref=' + encodeURIComponent(pendingRef);
          }
          return;
        }
        var onLanding = !h || h === '#' || h === '#/' || h.indexOf('/landing') !== -1;
        if (onLanding) {
          try { sessionStorage.removeItem('flutter_initial_route'); } catch(e) {}
          window.location.hash = '/';
        }
      }, 150);
      return;
    }

    /* 2. Comprador → silêncio */
    if (isBuyerRoute()) return;

    /* 3. Desktop → silêncio */
    if (!isMobile()) return;

    /* 4. Já instalou / dispensou → silêncio */
    if (wasInstalled() || wasDismissed()) return;

    /*
     * 5. Aguarda até 5s pelo beforeinstallprompt.
     *    - Se chegar antes de 2s → mostra imediatamente ao completar 2s
     *    - Se chegar entre 2s e 5s → mostra na hora que chegar
     *    - Se não chegar em 5s → silêncio (Chrome bloqueou, não confunde o usuário)
     */
    setTimeout(function () {
      if (isBuyerRoute() || isStandalone()) return;
      _readyToShow = true;
      if (_prompt && !_bannerShown) {
        _bannerShown = true;
        showBanner(_prompt);
      }
      // Sem prompt após 2s → espera mais 3s (total 5s) antes de desistir
    }, 2000);

    setTimeout(function () {
      // Após 5s: se o prompt não chegou, não mostra nada
      // (evita guia confuso de "três pontinhos")
      _readyToShow = false;
    }, 5000);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();
