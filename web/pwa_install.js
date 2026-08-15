/**
 * pwa_install.js — ShareWallet PWA Install v8
 * Lógica:
 *   1. App já instalado (standalone)  → lê sw_pending_ref do localStorage e navega
 *   2. Rota /produto/                 → silêncio total (comprador, não instalar)
 *   3. Rota /admin                    → troca manifest para manifest-admin.json
 *   4. beforeinstallprompt disparou   → banner automático bonito (preserva ?ref=)
 *   5. Prompt bloqueado / sem prompt  → silêncio total
 *
 * v8: Suporte a link de afiliado sharewallet.com.br/ref/CODE
 *     - Lê ?ref= da URL e persiste no localStorage (sw_pending_ref)
 *     - Ao abrir como PWA standalone, aplica o ref pendente na navegação
 *     - SWs são gerenciados apenas pelo flutter_bootstrap.js
 */
(function () {
  'use strict';

  var KEY_INSTALLED   = 'sw_pwa_v3_installed';
  var KEY_DISMISSED   = 'sw_pwa_v3_dismissed';
  var KEY_PENDING_REF = 'sw_pending_ref';
  var KEY_PENDING_TS  = 'sw_pending_ref_ts';
  var DISMISS_TTL     = 7 * 24 * 60 * 60 * 1000;  // 7 dias
  var REF_TTL         = 30 * 24 * 60 * 60 * 1000;  // 30 dias (validade do ref)

  /* ── helpers ─────────────────────────────────────────────── */
  function isStandalone() {
    return window.matchMedia('(display-mode: standalone)').matches ||
           navigator.standalone === true;
  }
  function isIOS() { return /iphone|ipad|ipod/i.test(navigator.userAgent); }
  function isAndroid() { return /android/i.test(navigator.userAgent); }
  function wasInstalled() { return localStorage.getItem(KEY_INSTALLED) === '1'; }
  function isBuyerRoute() {
    var hash = window.location.hash || '';
    return hash.indexOf('/produto/') !== -1;
  }
  function wasDismissed() {
    var t = localStorage.getItem(KEY_DISMISSED);
    return !!t && (Date.now() - parseInt(t)) < DISMISS_TTL;
  }
  function markInstalled() { localStorage.setItem(KEY_INSTALLED, '1'); }
  function markDismissed() { localStorage.setItem(KEY_DISMISSED, String(Date.now())); }

  /* ── Ref de afiliado ─────────────────────────────────────── */
  // Lê ?ref= da URL atual (hash ou search params)
  function readRefFromUrl() {
    // Tenta no hash: #/landing?ref=ABC123
    var hash = window.location.hash || '';
    var hashMatch = hash.match(/[?&]ref=([^&]+)/);
    if (hashMatch) return decodeURIComponent(hashMatch[1]).replace(/^@+/, '');
    // Tenta no search: ?ref=ABC123
    var searchMatch = window.location.search.match(/[?&]ref=([^&]+)/);
    if (searchMatch) return decodeURIComponent(searchMatch[1]).replace(/^@+/, '');
    return null;
  }

  // Persiste ref no localStorage (sobrescreve se houver um mais novo)
  function savePendingRef(code) {
    if (!code) return;
    localStorage.setItem(KEY_PENDING_REF, code);
    localStorage.setItem(KEY_PENDING_TS, String(Date.now()));
  }

  // Lê ref pendente (respeita TTL de 30 dias)
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

  // Limpa ref pendente após ser consumido
  function clearPendingRef() {
    localStorage.removeItem(KEY_PENDING_REF);
    localStorage.removeItem(KEY_PENDING_TS);
  }

  /* ── CSS ─────────────────────────────────────────────────── */
  function injectCSS() {
    if (document.getElementById('pwa-css')) return;
    var s = document.createElement('style');
    s.id = 'pwa-css';
    s.textContent = [
      /* ── animação ── */
      '@keyframes pwa-up{from{transform:translateY(110%);opacity:0}to{transform:translateY(0);opacity:1}}',
      '@keyframes pwa-pulse{0%,100%{box-shadow:0 0 0 0 rgba(201,168,76,.5)}70%{box-shadow:0 0 0 10px rgba(201,168,76,0)}}',

      /* ── banner automático (quando prompt disparar) ── */
      '#pwa-banner{',
        'position:fixed;bottom:0;left:0;right:0;z-index:2147483647;',
        'background:linear-gradient(170deg,#0f2318 0%,#1c3522 100%);',
        'border-top:2px solid #C9A84C;',
        'padding:16px 16px calc(16px + env(safe-area-inset-bottom,0px));',
        'display:flex;align-items:center;gap:14px;',
        'box-shadow:0 -8px 40px rgba(0,0,0,.8);',
        'animation:pwa-up .4s cubic-bezier(.22,.68,0,1.2) both;',
        'font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;',
      '}',
      '#pwa-banner img{width:54px;height:54px;border-radius:14px;flex-shrink:0;border:2px solid rgba(201,168,76,.5);}',
      '#pwa-banner .pwa-txt{flex:1;min-width:0;}',
      '#pwa-banner .pwa-txt b{display:block;font-size:15px;font-weight:800;color:#fff;margin-bottom:3px;}',
      '#pwa-banner .pwa-txt span{font-size:12px;color:rgba(255,255,255,.6);}',
      '#pwa-banner .pwa-actions{display:flex;flex-direction:column;gap:7px;flex-shrink:0;}',
      '#pwa-btn-install{',
        'padding:11px 18px;border-radius:10px;border:none;cursor:pointer;',
        'font-size:14px;font-weight:800;',
        'background:linear-gradient(135deg,#C9A84C,#f0c84a);color:#0f1e12;',
        'box-shadow:0 3px 14px rgba(201,168,76,.5);',
        'animation:pwa-pulse 2s infinite;',
      '}',
      '#pwa-btn-later{',
        'padding:6px;border-radius:8px;border:none;cursor:pointer;',
        'background:transparent;color:rgba(255,255,255,.4);font-size:11px;',
      '}',

      /* ── card guia — mantido no CSS mas nunca exibido (reserva futura) ── */
      '#pwa-guide{',
        'position:fixed;bottom:0;left:0;right:0;z-index:2147483647;',
        'background:linear-gradient(170deg,#0f2318 0%,#1c3522 100%);',
        'border-top:2px solid #C9A84C;',
        'padding:20px 20px calc(20px + env(safe-area-inset-bottom,0px));',
        'box-shadow:0 -8px 40px rgba(0,0,0,.8);',
        'animation:pwa-up .4s cubic-bezier(.22,.68,0,1.2) both;',
        'font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;',
      '}',
      '#pwa-guide .pwa-g-head{display:flex;align-items:center;gap:12px;margin-bottom:16px;}',
      '#pwa-guide .pwa-g-head img{width:46px;height:46px;border-radius:12px;border:2px solid rgba(201,168,76,.4);}',
      '#pwa-guide .pwa-g-head div b{display:block;font-size:15px;font-weight:800;color:#fff;}',
      '#pwa-guide .pwa-g-head div span{font-size:12px;color:rgba(255,255,255,.55);}',

      /* passos visuais */
      '#pwa-guide .pwa-steps{display:flex;flex-direction:column;gap:10px;margin-bottom:16px;}',
      '#pwa-guide .pwa-step{',
        'display:flex;align-items:center;gap:12px;',
        'background:rgba(255,255,255,.05);border-radius:12px;padding:12px;',
        'border:1px solid rgba(201,168,76,.15);',
      '}',
      '#pwa-guide .pwa-step .pwa-num{',
        'width:28px;height:28px;border-radius:50%;flex-shrink:0;',
        'background:#C9A84C;color:#0f1e12;',
        'font-size:13px;font-weight:900;',
        'display:flex;align-items:center;justify-content:center;',
      '}',
      '#pwa-guide .pwa-step .pwa-step-txt{flex:1;}',
      '#pwa-guide .pwa-step .pwa-step-txt b{display:block;font-size:13px;color:#fff;margin-bottom:1px;}',
      '#pwa-guide .pwa-step .pwa-step-txt span{font-size:11px;color:rgba(255,255,255,.5);}',
      '#pwa-guide .pwa-step .pwa-step-ico{font-size:26px;flex-shrink:0;}',

      /* seta animada apontando para os 3 pontos */
      '#pwa-guide .pwa-arrow-hint{',
        'text-align:right;font-size:11px;color:#C9A84C;',
        'margin-bottom:4px;font-weight:700;',
        'animation:pwa-pulse 1.5s infinite;',
      '}',

      '#pwa-guide-close{',
        'width:100%;padding:10px;border-radius:10px;',
        'border:1px solid rgba(255,255,255,.12);background:transparent;',
        'color:rgba(255,255,255,.4);font-size:12px;cursor:pointer;',
      '}',
    ].join('');
    document.head.appendChild(s);
  }

  /* ── fecha um painel ─────────────────────────────────────── */
  function closePanel(id) {
    var el = document.getElementById(id);
    if (!el) return;
    el.style.transition = 'transform .25s ease, opacity .25s ease';
    el.style.transform  = 'translateY(110%)';
    el.style.opacity    = '0';
    setTimeout(function () { el && el.parentNode && el.remove(); }, 300);
  }

  /* ── toast ───────────────────────────────────────────────── */
  function toast(msg) {
    var t = document.createElement('div');
    t.style.cssText = [
      'position:fixed;bottom:90px;left:50%;transform:translateX(-50%);',
      'background:#C9A84C;color:#0f1e12;font-weight:800;',
      'padding:11px 24px;border-radius:28px;font-size:13px;',
      'z-index:2147483647;white-space:nowrap;',
      'box-shadow:0 4px 20px rgba(201,168,76,.5);',
      'font-family:-apple-system,BlinkMacSystemFont,sans-serif;',
      'animation:pwa-up .3s ease both;',
    ].join('');
    t.textContent = msg;
    document.body.appendChild(t);
    setTimeout(function () { t.parentNode && t.remove(); }, 3500);
  }

  var ICON = '/app/icons/Icon-v202606251651-192.png';

  /* ── Banner automático (prompt disponível) ───────────────── */
  function showAutoBanner(promptEvt) {
    closePanel('pwa-guide');
    if (document.getElementById('pwa-banner')) return;

    var el = document.createElement('div');
    el.id  = 'pwa-banner';
    el.innerHTML =
      '<img src="' + ICON + '" alt="ShareWallet">' +
      '<div class="pwa-txt">' +
        '<b>Instalar ShareWallet</b>' +
        '<span>Acesse como app, sem precisar do navegador</span>' +
      '</div>' +
      '<div class="pwa-actions">' +
        '<button id="pwa-btn-install">Instalar</button>' +
        '<button id="pwa-btn-later">Agora não</button>' +
      '</div>';
    document.body.appendChild(el);

    document.getElementById('pwa-btn-later').onclick = function () {
      markDismissed();
      closePanel('pwa-banner');
    };

    document.getElementById('pwa-btn-install').onclick = function () {
      closePanel('pwa-banner');
      promptEvt.prompt();
      promptEvt.userChoice.then(function (r) {
        if (r.outcome === 'accepted') {
          markInstalled();
          toast('✅ ShareWallet instalado!');
        }
      });
    };
  }

  /* ── Troca manifest para admin quando na rota #/admin ─────── */
  function swapManifestIfAdmin() {
    var hash = window.location.hash || '';
    if (hash.indexOf('/admin') === -1) return;
    var link = document.querySelector('link[rel="manifest"]');
    if (!link) return;
    var current = link.getAttribute('href') || '';
    if (current.indexOf('manifest-admin') !== -1) return; // já trocou
    link.setAttribute('href', current.replace('manifest.json', 'manifest-admin.json'));
  }

  /* ── SW registration ─────────────────────────────────────── */
  // v7: NÃO registra Service Worker nem faz reload automático.
  // Motivo: o sw_version.js v3 anterior causava loop infinito de reset:
  //   activate → postMessage(SW_AUTO_RELOAD) → location.reload() → novo SW → loop
  // O Cloudflare Worker já serve cache correto (immutable para main.dart.js).
  // O flutter_bootstrap.js NÃO tem serviceWorkerSettings (removido pelo patch_build.py).
  // Portanto, nenhum SW precisa ser registrado aqui.
  function registerSW() {
    // Desregistra qualquer SW residual de versões anteriores
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.getRegistrations().then(function(regs) {
        regs.forEach(function(r) { r.unregister(); });
      }).catch(function() {});
    }
  }

  /* ── captura o prompt ANTES de qualquer coisa ────────────── */
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

  /* ── init ────────────────────────────────────────────────── */
  function init() {
    injectCSS();
    registerSW();

    // ── Captura ref= da URL e persiste (válido por 30 dias) ──────────────────
    var urlRef = readRefFromUrl();
    if (urlRef) savePendingRef(urlRef);

    // Troca manifest se for rota admin
    swapManifestIfAdmin();

    // Observa mudanças de hash (SPA navigation admin ↔ app)
    window.addEventListener('hashchange', swapManifestIfAdmin);

    // Fecha banner de instalação ao navegar para rota de comprador
    window.addEventListener('hashchange', function () {
      if (isBuyerRoute()) {
        closePanel('pwa-banner');
        closePanel('pwa-guide');
      }
    });

    // ── PWA já instalada (standalone) ────────────────────────────────────────
    // O usuário abriu o ícone do app na tela home do celular.
    // Nunca mostramos a landing nesse caso: redirecionamos direto para o app.
    if (isStandalone()) {
      markInstalled();

      var pendingRef = getPendingRef();

      // Aguarda o Flutter iniciar (150ms é suficiente — só muda o hash antes do router processar)
      setTimeout(function () {
        var currentHash = window.location.hash || '';

        // Se veio com ref pendente de indicação → aplica na landing (cadastro)
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

        // Se está na landing (sem ref) → pula direto para o splash (raiz)
        // O SplashScreen lê o localStorage UID e vai direto para /home se logado
        var isOnLanding = currentHash === '' ||
                          currentHash === '#/' ||
                          currentHash.indexOf('/landing') !== -1;

        if (isOnLanding) {
          // Limpa o sessionStorage gravado pelo index.html ANTES do Flutter ler
          // (evita o Dart redirecionar para /landing mesmo com standalone)
          try { sessionStorage.removeItem('flutter_initial_route'); } catch(e) {}
          window.location.hash = '/';
        }
        // Qualquer outra rota (home, login, produto) → não interfere
      }, 150);

      return;
    }

    // Rota de comprador (/produto/) → silêncio total, sem instalar app
    if (isBuyerRoute()) return;
    // Já instalou antes → silêncio
    if (wasInstalled()) return;
    // Dispensou recentemente → silêncio
    if (wasDismissed()) return;

    // Só mostra em celular e APENAS quando o Chrome oferecer o prompt nativo
    if (!isIOS() && !isAndroid()) return;

    // Aguarda 3s para o app carregar e verifica se o prompt está disponível
    setTimeout(function () {
      if (_prompt) {
        // Chrome deu o prompt → banner automático (toque de 1 botão)
        showAutoBanner(_prompt);
      }
      // Sem prompt → silêncio total. Não mostrar guia de passos.
    }, 3000);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();
