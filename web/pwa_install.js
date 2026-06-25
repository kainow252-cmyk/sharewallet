/**
 * pwa_install.js — ShareWallet PWA Install v3
 * Lógica:
 *   1. App já instalado (standalone)  → silêncio total
 *   2. beforeinstallprompt disparou   → banner automático bonito
 *   3. Prompt bloqueado pelo Chrome   → card visual "como instalar pelo menu"
 *   4. iOS Safari                     → card visual com seta para ícone compartilhar
 */
(function () {
  'use strict';

  var KEY_INSTALLED = 'sw_pwa_v3_installed';
  var KEY_DISMISSED = 'sw_pwa_v3_dismissed';
  var DISMISS_TTL   = 7 * 24 * 60 * 60 * 1000; // 7 dias

  /* ── helpers ─────────────────────────────────────────────── */
  function isStandalone() {
    return window.matchMedia('(display-mode: standalone)').matches ||
           navigator.standalone === true;
  }
  function isIOS() { return /iphone|ipad|ipod/i.test(navigator.userAgent); }
  function isAndroid() { return /android/i.test(navigator.userAgent); }
  function wasInstalled() { return localStorage.getItem(KEY_INSTALLED) === '1'; }
  function wasDismissed() {
    var t = localStorage.getItem(KEY_DISMISSED);
    return !!t && (Date.now() - parseInt(t)) < DISMISS_TTL;
  }
  function markInstalled() { localStorage.setItem(KEY_INSTALLED, '1'); }
  function markDismissed() { localStorage.setItem(KEY_DISMISSED, String(Date.now())); }

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

      /* ── card "instale pelo menu" (quando prompt bloqueado) ── */
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

  /* ── Guia manual — Android (menu ⋮ do Chrome) ───────────── */
  function showAndroidGuide() {
    if (document.getElementById('pwa-guide')) return;
    if (document.getElementById('pwa-banner')) return;

    var el = document.createElement('div');
    el.id  = 'pwa-guide';
    el.innerHTML =
      '<div class="pwa-g-head">' +
        '<img src="' + ICON + '" alt="ShareWallet">' +
        '<div>' +
          '<b>Instalar ShareWallet</b>' +
          '<span>Adicione à sua tela inicial</span>' +
        '</div>' +
      '</div>' +

      /* seta apontando canto direito = onde fica o ⋮ */
      '<div class="pwa-arrow-hint">toque nos 3 pontos ⋮ &nbsp;↗</div>' +

      '<div class="pwa-steps">' +

        '<div class="pwa-step">' +
          '<div class="pwa-num">1</div>' +
          '<div class="pwa-step-txt">' +
            '<b>Toque nos 3 pontos  ⋮</b>' +
            '<span>Canto superior direito do Chrome</span>' +
          '</div>' +
          '<div class="pwa-step-ico">⋮</div>' +
        '</div>' +

        '<div class="pwa-step">' +
          '<div class="pwa-num">2</div>' +
          '<div class="pwa-step-txt">' +
            '<b>Toque "Adicionar à tela inicial"</b>' +
            '<span>ou "Instalar app" se aparecer</span>' +
          '</div>' +
          '<div class="pwa-step-ico">➕</div>' +
        '</div>' +

        '<div class="pwa-step">' +
          '<div class="pwa-num">3</div>' +
          '<div class="pwa-step-txt">' +
            '<b>Toque "Adicionar"</b>' +
            '<span>O ícone aparece na sua tela!</span>' +
          '</div>' +
          '<div class="pwa-step-ico">✅</div>' +
        '</div>' +

      '</div>' +
      '<button id="pwa-guide-close">Fechar</button>';

    document.body.appendChild(el);
    document.getElementById('pwa-guide-close').onclick = function () {
      markDismissed();
      closePanel('pwa-guide');
    };
  }

  /* ── Guia manual — iOS (botão compartilhar Safari) ──────── */
  function showIOSGuide() {
    if (document.getElementById('pwa-guide')) return;

    var el = document.createElement('div');
    el.id  = 'pwa-guide';
    el.innerHTML =
      '<div class="pwa-g-head">' +
        '<img src="' + ICON + '" alt="ShareWallet">' +
        '<div>' +
          '<b>Instalar ShareWallet</b>' +
          '<span>Adicione à sua tela inicial</span>' +
        '</div>' +
      '</div>' +

      '<div class="pwa-arrow-hint">toque em Compartilhar &nbsp;↓</div>' +

      '<div class="pwa-steps">' +

        '<div class="pwa-step">' +
          '<div class="pwa-num">1</div>' +
          '<div class="pwa-step-txt">' +
            '<b>Toque em Compartilhar  ⬆</b>' +
            '<span>Ícone na barra inferior do Safari</span>' +
          '</div>' +
          '<div class="pwa-step-ico">⬆</div>' +
        '</div>' +

        '<div class="pwa-step">' +
          '<div class="pwa-num">2</div>' +
          '<div class="pwa-step-txt">' +
            '<b>"Adicionar à Tela de Início"</b>' +
            '<span>Role a lista para encontrar</span>' +
          '</div>' +
          '<div class="pwa-step-ico">➕</div>' +
        '</div>' +

        '<div class="pwa-step">' +
          '<div class="pwa-num">3</div>' +
          '<div class="pwa-step-txt">' +
            '<b>Toque "Adicionar"</b>' +
            '<span>O ícone aparece na tela!</span>' +
          '</div>' +
          '<div class="pwa-step-ico">✅</div>' +
        '</div>' +

      '</div>' +
      '<button id="pwa-guide-close">Fechar</button>';

    document.body.appendChild(el);
    document.getElementById('pwa-guide-close').onclick = function () {
      markDismissed();
      closePanel('pwa-guide');
    };
  }

  /* ── SW registration ─────────────────────────────────────── */
  function registerSW() {
    if (!('serviceWorker' in navigator)) return;
    navigator.serviceWorker.addEventListener('message', function (ev) {
      if (ev.data && ev.data.type === 'SW_UPDATE_AVAILABLE') {
        // banner de update
        setTimeout(function () {
          var el = document.createElement('div');
          el.id  = 'pwa-banner';
          el.innerHTML =
            '<img src="' + ICON + '" alt="ShareWallet">' +
            '<div class="pwa-txt">' +
              '<b>🔄 Atualização disponível</b>' +
              '<span>Nova versão do ShareWallet pronta</span>' +
            '</div>' +
            '<div class="pwa-actions">' +
              '<button id="pwa-btn-install">Atualizar</button>' +
              '<button id="pwa-btn-later">Depois</button>' +
            '</div>';
          document.body.appendChild(el);
          document.getElementById('pwa-btn-install').onclick = function () {
            window.location.reload(true);
          };
          document.getElementById('pwa-btn-later').onclick = function () {
            closePanel('pwa-banner');
          };
        }, 1000);
      }
    });
    navigator.serviceWorker.register('/app/sw_version.js', { scope: '/app/' })
      .catch(function () {});
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

    // Já está como PWA → silêncio total
    if (isStandalone()) { markInstalled(); return; }
    // Já instalou antes → silêncio
    if (wasInstalled()) return;
    // Dispensou recentemente → silêncio
    if (wasDismissed()) return;

    // Só mostra em celular
    if (!isIOS() && !isAndroid()) return;

    // Aguarda 3s para o app carregar, depois decide
    setTimeout(function () {
      if (_prompt) {
        // Chrome deu o prompt → banner automático
        showAutoBanner(_prompt);
      } else if (isIOS()) {
        // iOS → guia compartilhar
        showIOSGuide();
      } else {
        // Android sem prompt (bloqueado) → guia menu ⋮
        showAndroidGuide();
      }
    }, 3000);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();
