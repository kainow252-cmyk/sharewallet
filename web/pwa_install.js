/**
 * pwa_install.js — ShareWallet PWA Install v9
 *
 * LÓGICA v9 (mobile-first, sem depender do beforeinstallprompt):
 *
 *   1. standalone (PWA já instalada)  → pula landing, abre app direto
 *   2. /produto/                      → silêncio total (comprador)
 *   3. /admin                         → troca manifest para admin
 *   4. Mobile (Android/iOS)           → mostra banner manual SEMPRE
 *      a) beforeinstallprompt OK      → botão "Instalar" 1 clique (Chrome Android)
 *      b) iOS                         → guia passo-a-passo (Compartilhar → Add to Home)
 *      c) Chrome sem prompt           → guia passo-a-passo (menu ⋮ → Instalar app)
 *   5. Dismissed < 3 dias             → não mostra novamente
 */
(function () {
  'use strict';

  var KEY_INSTALLED   = 'sw_pwa_v3_installed';
  var KEY_DISMISSED   = 'sw_pwa_v9_dismissed';   // v9: chave nova para resetar dismiss antigo
  var KEY_PENDING_REF = 'sw_pending_ref';
  var KEY_PENDING_TS  = 'sw_pending_ref_ts';
  var DISMISS_TTL     = 3 * 24 * 60 * 60 * 1000;  // 3 dias (reduzido de 7)
  var REF_TTL         = 30 * 24 * 60 * 60 * 1000;

  /* ── helpers ──────────────────────────────────────────────────────────── */
  function isStandalone() {
    return window.matchMedia('(display-mode: standalone)').matches ||
           navigator.standalone === true;
  }
  function isIOS() {
    return /iphone|ipad|ipod/i.test(navigator.userAgent);
  }
  function isAndroid() {
    return /android/i.test(navigator.userAgent);
  }
  function isMobile() {
    return isIOS() || isAndroid();
  }
  function wasInstalled() {
    return localStorage.getItem(KEY_INSTALLED) === '1';
  }
  function isBuyerRoute() {
    return (window.location.hash || '').indexOf('/produto/') !== -1;
  }
  function isAdminRoute() {
    return (window.location.hash || '').indexOf('/admin') !== -1;
  }
  function wasDismissed() {
    var t = localStorage.getItem(KEY_DISMISSED);
    if (!t) return false;
    return (Date.now() - parseInt(t)) < DISMISS_TTL;
  }
  function markInstalled()  { localStorage.setItem(KEY_INSTALLED, '1'); }
  function markDismissed()  { localStorage.setItem(KEY_DISMISSED, String(Date.now())); }

  /* ── ref de afiliado ─────────────────────────────────────────────────── */
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

  /* ── fechar painel ──────────────────────────────────────────────────── */
  function closePanel(id) {
    var el = document.getElementById(id);
    if (!el) return;
    el.style.transition = 'transform .3s ease, opacity .3s ease';
    el.style.transform  = 'translateY(110%)';
    el.style.opacity    = '0';
    setTimeout(function () { if (el.parentNode) el.remove(); }, 350);
  }

  /* ── toast ──────────────────────────────────────────────────────────── */
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

  /* ── CSS ──────────────────────────────────────────────────────────────  */
  var ICON = '/app/icons/Icon-v202606251651-192.png';

  function injectCSS() {
    if (document.getElementById('pwa-css')) return;
    var s = document.createElement('style');
    s.id = 'pwa-css';
    s.textContent =
      '@keyframes pwa-up{from{transform:translateY(110%);opacity:0}to{transform:translateY(0);opacity:1}}' +
      '@keyframes pwa-pulse{0%,100%{box-shadow:0 0 0 0 rgba(201,168,76,.45)}70%{box-shadow:0 0 0 10px rgba(201,168,76,0)}}' +
      '@keyframes pwa-bounce{0%,100%{transform:translateY(0)}50%{transform:translateY(-5px)}}' +

      /* ── banner principal ─────────────────────────────────────────── */
      '#pwa-banner{' +
        'position:fixed;bottom:0;left:0;right:0;z-index:2147483647;' +
        'background:linear-gradient(170deg,#0f2318 0%,#1a3520 100%);' +
        'border-top:2px solid #C9A84C;' +
        'padding:16px 16px calc(16px + env(safe-area-inset-bottom,0px));' +
        'box-shadow:0 -10px 48px rgba(0,0,0,.85);' +
        'animation:pwa-up .45s cubic-bezier(.22,.68,0,1.2) both;' +
        'font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;' +
      '}' +

      /* linha de cima: logo + texto + fechar */
      '#pwa-banner .pwa-row{display:flex;align-items:center;gap:12px;margin-bottom:12px;}' +
      '#pwa-banner .pwa-row img{width:50px;height:50px;border-radius:13px;flex-shrink:0;border:2px solid rgba(201,168,76,.5);}' +
      '#pwa-banner .pwa-info{flex:1;min-width:0;}' +
      '#pwa-banner .pwa-info b{display:block;font-size:15px;font-weight:800;color:#fff;margin-bottom:2px;}' +
      '#pwa-banner .pwa-info span{font-size:12px;color:rgba(255,255,255,.6);}' +
      '#pwa-banner .pwa-close{' +
        'width:30px;height:30px;border-radius:50%;border:none;cursor:pointer;' +
        'background:rgba(255,255,255,.1);color:rgba(255,255,255,.55);' +
        'font-size:16px;line-height:1;flex-shrink:0;' +
        'display:flex;align-items:center;justify-content:center;' +
      '}' +

      /* botão instalar único */
      '#pwa-btn-install{' +
        'width:100%;padding:14px;border-radius:12px;border:none;cursor:pointer;' +
        'font-size:15px;font-weight:800;letter-spacing:.3px;' +
        'background:linear-gradient(135deg,#C9A84C 0%,#f0c84a 100%);color:#0f1e12;' +
        'box-shadow:0 4px 18px rgba(201,168,76,.5);' +
        'animation:pwa-pulse 2s infinite;' +
        'display:flex;align-items:center;justify-content:center;gap:8px;' +
      '}' +

      /* guia passo a passo (iOS / Chrome sem prompt) */
      '#pwa-guide{' +
        'position:fixed;bottom:0;left:0;right:0;z-index:2147483647;' +
        'background:linear-gradient(170deg,#0f2318 0%,#1a3520 100%);' +
        'border-top:2px solid #C9A84C;' +
        'padding:18px 18px calc(18px + env(safe-area-inset-bottom,0px));' +
        'box-shadow:0 -10px 48px rgba(0,0,0,.85);' +
        'animation:pwa-up .45s cubic-bezier(.22,.68,0,1.2) both;' +
        'font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;' +
      '}' +
      '#pwa-guide .pwa-g-title{display:flex;align-items:center;gap:12px;margin-bottom:14px;}' +
      '#pwa-guide .pwa-g-title img{width:44px;height:44px;border-radius:11px;border:2px solid rgba(201,168,76,.4);}' +
      '#pwa-guide .pwa-g-title b{font-size:15px;font-weight:800;color:#fff;display:block;}' +
      '#pwa-guide .pwa-g-title span{font-size:11px;color:rgba(255,255,255,.5);}' +
      '#pwa-guide .pwa-g-close{float:right;width:28px;height:28px;border-radius:50%;border:none;cursor:pointer;background:rgba(255,255,255,.1);color:rgba(255,255,255,.55);font-size:15px;display:flex;align-items:center;justify-content:center;flex-shrink:0;}' +
      '#pwa-guide .pwa-steps{display:flex;flex-direction:column;gap:8px;margin-bottom:14px;}' +
      '#pwa-guide .pwa-step{display:flex;align-items:center;gap:10px;background:rgba(255,255,255,.05);border-radius:12px;padding:11px 12px;border:1px solid rgba(201,168,76,.15);}' +
      '#pwa-guide .pwa-num{width:26px;height:26px;border-radius:50%;flex-shrink:0;background:#C9A84C;color:#0f1e12;font-size:13px;font-weight:900;display:flex;align-items:center;justify-content:center;}' +
      '#pwa-guide .pwa-step-ico{font-size:24px;flex-shrink:0;}' +
      '#pwa-guide .pwa-step-txt{flex:1;}' +
      '#pwa-guide .pwa-step-txt b{display:block;font-size:13px;color:#fff;margin-bottom:1px;}' +
      '#pwa-guide .pwa-step-txt s{font-size:11px;color:rgba(255,255,255,.5);font-style:normal;text-decoration:none;}' +
      '#pwa-guide-dismiss{width:100%;padding:10px;border-radius:10px;border:1px solid rgba(255,255,255,.12);background:transparent;color:rgba(255,255,255,.4);font-size:12px;cursor:pointer;}';
    document.head.appendChild(s);
  }

  /* ── Banner 1 clique — Chrome Android com beforeinstallprompt ────────── */
  function showInstallBanner(promptEvt) {
    if (document.getElementById('pwa-banner') || document.getElementById('pwa-guide')) return;
    closePanel('pwa-guide');

    var el = document.createElement('div');
    el.id  = 'pwa-banner';
    el.innerHTML =
      '<div class="pwa-row">' +
        '<img src="' + ICON + '" alt="">' +
        '<div class="pwa-info">' +
          '<b>Instalar ShareWallet</b>' +
          '<span>Acesse como app direto da tela inicial</span>' +
        '</div>' +
        '<button class="pwa-close" id="pwa-banner-close">✕</button>' +
      '</div>' +
      '<button id="pwa-btn-install">' +
        '<span style="font-size:20px">📲</span> Instalar app — é grátis' +
      '</button>';
    document.body.appendChild(el);

    document.getElementById('pwa-banner-close').onclick = function () {
      markDismissed();
      closePanel('pwa-banner');
    };

    document.getElementById('pwa-btn-install').onclick = function () {
      closePanel('pwa-banner');
      if (promptEvt) {
        promptEvt.prompt();
        promptEvt.userChoice.then(function (r) {
          if (r.outcome === 'accepted') { markInstalled(); toast('✅ ShareWallet instalado!'); }
        });
      }
    };
  }

  /* ── Guia passo-a-passo — iOS e Android sem prompt ────────────────────  */
  function showGuide() {
    if (document.getElementById('pwa-banner') || document.getElementById('pwa-guide')) return;

    var ios     = isIOS();
    var steps   = ios ? [
      { ico: '1️⃣', label: 'Toque em',          detail: 'Compartilhar  (ícone de caixa com seta ↑)' },
      { ico: '2️⃣', label: 'Role e toque em',   detail: '"Adicionar à Tela de Início"' },
      { ico: '3️⃣', label: 'Confirme tocando em', detail: '"Adicionar" no canto superior direito' },
    ] : [
      { ico: '1️⃣', label: 'Toque no menu',     detail: 'Ícone ⋮ (três pontos) no canto superior direito' },
      { ico: '2️⃣', label: 'Toque em',           detail: '"Instalar app" ou "Adicionar à tela inicial"' },
      { ico: '3️⃣', label: 'Confirme e pronto!', detail: 'O app aparece na sua tela inicial' },
    ];

    var stepsHtml = steps.map(function (s) {
      return '<div class="pwa-step">' +
        '<div class="pwa-num">' + (steps.indexOf(s) + 1) + '</div>' +
        '<span class="pwa-step-ico">' + s.ico + '</span>' +
        '<div class="pwa-step-txt">' +
          '<b>' + s.label + '</b>' +
          '<s>' + s.detail + '</s>' +
        '</div>' +
      '</div>';
    }).join('');

    var el = document.createElement('div');
    el.id  = 'pwa-guide';
    el.innerHTML =
      '<div class="pwa-g-title">' +
        '<img src="' + ICON + '" alt="">' +
        '<div style="flex:1">' +
          '<b>Instalar ShareWallet</b>' +
          '<span>' + (ios ? 'Siga os passos abaixo no Safari' : 'Siga os passos abaixo') + '</span>' +
        '</div>' +
        '<button class="pwa-g-close" id="pwa-guide-x">✕</button>' +
      '</div>' +
      '<div class="pwa-steps">' + stepsHtml + '</div>' +
      '<button id="pwa-guide-dismiss">Agora não</button>';
    document.body.appendChild(el);

    document.getElementById('pwa-guide-x').onclick = function () {
      markDismissed(); closePanel('pwa-guide');
    };
    document.getElementById('pwa-guide-dismiss').onclick = function () {
      markDismissed(); closePanel('pwa-guide');
    };
  }

  /* ── Troca manifest admin ─────────────────────────────────────────────── */
  function swapManifestIfAdmin() {
    if (!isAdminRoute()) return;
    var link = document.querySelector('link[rel="manifest"]');
    if (!link) return;
    var cur = link.getAttribute('href') || '';
    if (cur.indexOf('manifest-admin') !== -1) return;
    link.setAttribute('href', cur.replace('manifest.json', 'manifest-admin.json'));
  }

  /* ── limpa SWs residuais ─────────────────────────────────────────────── */
  function registerSW() {
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.getRegistrations()
        .then(function(regs) { regs.forEach(function(r) { r.unregister(); }); })
        .catch(function() {});
    }
  }

  /* ── captura prompt cedo ─────────────────────────────────────────────── */
  var _prompt = null;
  window.addEventListener('beforeinstallprompt', function (e) {
    e.preventDefault();
    _prompt = e;
  });

  window.addEventListener('appinstalled', function () {
    markInstalled();
    closePanel('pwa-banner');
    closePanel('pwa-guide');
    toast('✅ ShareWallet instalado!');
  });

  /* ── INIT ────────────────────────────────────────────────────────────── */
  function init() {
    injectCSS();
    registerSW();

    // Persiste ref de afiliado da URL
    var urlRef = readRefFromUrl();
    if (urlRef) savePendingRef(urlRef);

    swapManifestIfAdmin();
    window.addEventListener('hashchange', swapManifestIfAdmin);

    // Fecha banners ao navegar para rota de comprador
    window.addEventListener('hashchange', function () {
      if (isBuyerRoute()) {
        closePanel('pwa-banner');
        closePanel('pwa-guide');
      }
    });

    /* ── 1. PWA já instalada (standalone) ─────────────────────────── */
    if (isStandalone()) {
      markInstalled();

      var pendingRef = getPendingRef();

      setTimeout(function () {
        var currentHash = window.location.hash || '';

        // Ref pendente de indicação → vai para landing com código
        if (pendingRef) {
          clearPendingRef();
          if (currentHash.indexOf('/produto/') === -1 &&
              currentHash.indexOf('/login')    === -1 &&
              currentHash.indexOf('/home')     === -1 &&
              currentHash.indexOf('/admin')    === -1) {
            window.location.hash = '/landing?ref=' + encodeURIComponent(pendingRef);
          }
          return;
        }

        // Na landing sem ref → vai direto para splash (SplashScreen decide home/login)
        var onLanding = !currentHash || currentHash === '#' || currentHash === '#/' ||
                        currentHash.indexOf('/landing') !== -1;
        if (onLanding) {
          try { sessionStorage.removeItem('flutter_initial_route'); } catch(e) {}
          window.location.hash = '/';
        }
      }, 150);

      return; // não mostra banner
    }

    /* ── 2. Rota comprador → silêncio ─────────────────────────────── */
    if (isBuyerRoute()) return;

    /* ── 3. Desktop → silêncio ────────────────────────────────────── */
    if (!isMobile()) return;

    /* ── 4. Já instalou antes → silêncio ──────────────────────────── */
    if (wasInstalled()) return;

    /* ── 5. Dispensou recentemente → silêncio ─────────────────────── */
    if (wasDismissed()) return;

    /* ── 6. Mostra banner após 2.5s (deixa o app carregar primeiro) ── */
    setTimeout(function () {
      // Rota de comprador pode ter mudado enquanto aguardávamos
      if (isBuyerRoute() || isStandalone()) return;

      if (_prompt) {
        // Chrome Android com prompt nativo disponível → banner 1 clique
        showInstallBanner(_prompt);
      } else {
        // iOS ou Chrome que bloqueou o prompt → guia passo-a-passo
        showGuide();
      }
    }, 2500);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();
