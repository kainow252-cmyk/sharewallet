/**
 * pwa_install.js — ShareWallet PWA Install / Update Manager v2
 *
 * Comportamento:
 *  1. Registra SW mínimo para o Chrome considerar o site "instalável"
 *  2. Captura beforeinstallprompt → exibe banner customizado
 *  3. Ao instalar → marca localStorage e remove banner
 *  4. Visita seguinte com app instalado → sem banner
 *  5. Nova versão detectada pelo SW → banner de atualização
 *  6. iOS Safari → instrução manual (Compartilhar → Adicionar à tela)
 */
(function () {
  'use strict';

  /* ─── Chaves localStorage ────────────────────────────────── */
  var KEY_INSTALLED = 'sw_pwa_installed';
  var KEY_DISMISSED = 'sw_pwa_dismissed';
  var DISMISS_TTL   = 2 * 24 * 60 * 60 * 1000; // 2 dias

  /* ─── Utilitários ────────────────────────────────────────── */
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
    return isIOS() || isAndroid() ||
           /windows phone|blackberry|mobile/i.test(navigator.userAgent);
  }
  function wasInstalled() {
    return localStorage.getItem(KEY_INSTALLED) === '1';
  }
  function wasDismissed() {
    var t = localStorage.getItem(KEY_DISMISSED);
    return t && (Date.now() - parseInt(t)) < DISMISS_TTL;
  }
  function markInstalled() { localStorage.setItem(KEY_INSTALLED, '1'); }
  function markDismissed() { localStorage.setItem(KEY_DISMISSED, String(Date.now())); }

  /* ─── CSS (injetado uma vez) ─────────────────────────────── */
  function injectCSS() {
    if (document.getElementById('pwa-css')) return;
    var s = document.createElement('style');
    s.id = 'pwa-css';
    s.textContent = [
      /* Banner principal */
      '#pwa-banner{',
        'position:fixed;bottom:0;left:0;right:0;z-index:2147483647;',
        'background:linear-gradient(160deg,#0f1e12 0%,#1a2f1e 100%);',
        'border-top:2px solid #C9A84C;',
        'padding:14px 16px env(safe-area-inset-bottom,16px);',
        'display:flex;align-items:center;gap:12px;',
        'box-shadow:0 -6px 32px rgba(0,0,0,.7);',
        'font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;',
        'animation:pwa-up .35s cubic-bezier(.22,.68,0,1.2) both;',
      '}',
      '@keyframes pwa-up{from{transform:translateY(110%)}to{transform:translateY(0)}}',

      '#pwa-banner .pwa-ico{',
        'width:52px;height:52px;border-radius:13px;flex-shrink:0;overflow:hidden;',
        'border:1.5px solid rgba(201,168,76,.4);',
      '}',
      '#pwa-banner .pwa-ico img{width:100%;height:100%;object-fit:cover;}',

      '#pwa-banner .pwa-txt{flex:1;min-width:0;}',
      '#pwa-banner .pwa-txt h3{',
        'margin:0 0 3px;font-size:15px;font-weight:800;color:#fff;',
      '}',
      '#pwa-banner .pwa-txt p{',
        'margin:0;font-size:12px;color:rgba(255,255,255,.65);line-height:1.4;',
      '}',

      '#pwa-banner .pwa-btns{display:flex;flex-direction:column;gap:7px;flex-shrink:0;}',

      '#pwa-btn-ok{',
        'padding:10px 18px;border-radius:10px;border:none;cursor:pointer;',
        'font-size:13px;font-weight:800;letter-spacing:.3px;',
        'background:linear-gradient(135deg,#C9A84C,#f0c84a);',
        'color:#0f1e12;',
        'box-shadow:0 3px 12px rgba(201,168,76,.5);',
      '}',
      '#pwa-btn-ok:active{opacity:.8;}',

      '#pwa-btn-no{',
        'padding:6px 10px;border-radius:8px;cursor:pointer;',
        'border:1px solid rgba(255,255,255,.18);background:transparent;',
        'color:rgba(255,255,255,.5);font-size:11px;text-align:center;',
      '}',

      /* iOS hint */
      '#pwa-ios{',
        'position:fixed;bottom:0;left:0;right:0;z-index:2147483647;',
        'background:linear-gradient(160deg,#0f1e12 0%,#1a2f1e 100%);',
        'border-top:2px solid #C9A84C;',
        'padding:18px 20px env(safe-area-inset-bottom,20px);',
        'box-shadow:0 -6px 32px rgba(0,0,0,.7);',
        'font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;',
        'animation:pwa-up .35s cubic-bezier(.22,.68,0,1.2) both;',
      '}',
      '#pwa-ios h3{margin:0 0 12px;font-size:15px;font-weight:800;color:#C9A84C;}',
      '#pwa-ios .pwa-step{display:flex;align-items:flex-start;gap:10px;margin-bottom:10px;}',
      '#pwa-ios .pwa-step .pwa-num{',
        'min-width:22px;height:22px;border-radius:50%;',
        'background:#C9A84C;color:#0f1e12;',
        'font-size:12px;font-weight:800;',
        'display:flex;align-items:center;justify-content:center;',
      '}',
      '#pwa-ios .pwa-step p{margin:0;font-size:13px;color:rgba(255,255,255,.8);line-height:1.5;}',
      '#pwa-ios .pwa-step strong{color:#fff;}',
      '#pwa-ios-close{',
        'margin-top:14px;width:100%;padding:11px;border-radius:10px;',
        'border:1px solid rgba(255,255,255,.2);background:rgba(255,255,255,.05);',
        'color:rgba(255,255,255,.6);font-size:13px;cursor:pointer;',
      '}',

      /* Snackbar confirmação */
      '#pwa-toast{',
        'position:fixed;bottom:90px;left:50%;transform:translateX(-50%);',
        'background:#C9A84C;color:#0f1e12;font-weight:800;',
        'padding:11px 22px;border-radius:28px;',
        'font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;',
        'font-size:13px;z-index:2147483647;white-space:nowrap;',
        'box-shadow:0 4px 20px rgba(201,168,76,.6);',
        'animation:pwa-up .3s ease both;',
      '}',
    ].join('');
    document.head.appendChild(s);
  }

  /* ─── Toast ──────────────────────────────────────────────── */
  function toast(msg) {
    var el = document.getElementById('pwa-toast');
    if (el) el.remove();
    el = document.createElement('div');
    el.id = 'pwa-toast';
    el.textContent = msg;
    document.body.appendChild(el);
    setTimeout(function(){ if(el.parentNode) el.remove(); }, 3500);
  }

  /* ─── Remove banner com slide-down ──────────────────────── */
  function closeBanner(id) {
    var el = document.getElementById(id);
    if (!el) return;
    el.style.transition = 'transform .25s ease,opacity .25s ease';
    el.style.transform  = 'translateY(110%)';
    el.style.opacity    = '0';
    setTimeout(function(){ if(el.parentNode) el.remove(); }, 280);
  }

  /* ─── Banner Android (install / update) ─────────────────── */
  function showBanner(type) {
    closeBanner('pwa-banner');
    var isUpdate = type === 'update';

    var el = document.createElement('div');
    el.id  = 'pwa-banner';
    el.innerHTML =
      '<div class="pwa-ico">' +
        '<img src="/app/icons/Icon-v202606251651-192.png" alt="ShareWallet">' +
      '</div>' +
      '<div class="pwa-txt">' +
        '<h3>' + (isUpdate ? '🔄 Atualização disponível' : '📲 Instalar ShareWallet') + '</h3>' +
        '<p>' + (isUpdate
          ? 'Nova versão disponível. Toque para atualizar!'
          : 'Adicione à tela inicial e acesse como um app!') + '</p>' +
      '</div>' +
      '<div class="pwa-btns">' +
        '<button id="pwa-btn-ok">'  + (isUpdate ? 'Atualizar' : 'Instalar') + '</button>' +
        '<button id="pwa-btn-no">Agora não</button>' +
      '</div>';

    document.body.appendChild(el);

    document.getElementById('pwa-btn-no').onclick = function() {
      markDismissed();
      closeBanner('pwa-banner');
    };

    if (isUpdate) {
      document.getElementById('pwa-btn-ok').onclick = function() {
        closeBanner('pwa-banner');
        window.location.reload(true);
      };
    }
    // Para install: onclick setado externamente pelo _deferredPrompt
  }

  /* ─── Banner iOS ─────────────────────────────────────────── */
  function showIOSBanner() {
    if (wasInstalled() || wasDismissed() || isStandalone()) return;
    closeBanner('pwa-ios');

    var el = document.createElement('div');
    el.id  = 'pwa-ios';
    el.innerHTML =
      '<h3>📲 Instalar ShareWallet</h3>' +
      '<div class="pwa-step">' +
        '<div class="pwa-num">1</div>' +
        '<p>Toque no ícone <strong>Compartilhar</strong> ↑ na barra inferior do Safari</p>' +
      '</div>' +
      '<div class="pwa-step">' +
        '<div class="pwa-num">2</div>' +
        '<p>Role para baixo e toque em <strong>"Adicionar à Tela de Início"</strong></p>' +
      '</div>' +
      '<div class="pwa-step">' +
        '<div class="pwa-num">3</div>' +
        '<p>Toque em <strong>Adicionar</strong> — o ícone aparece na tela!</p>' +
      '</div>' +
      '<button id="pwa-ios-close">Entendi, talvez depois</button>';

    document.body.appendChild(el);
    document.getElementById('pwa-ios-close').onclick = function() {
      markDismissed();
      closeBanner('pwa-ios');
    };
  }

  /* ─── Service Worker mínimo ──────────────────────────────── */
  function registerSW() {
    if (!('serviceWorker' in navigator)) return;

    navigator.serviceWorker.addEventListener('message', function(ev) {
      if (ev.data && ev.data.type === 'SW_UPDATE_AVAILABLE') {
        setTimeout(function(){ showBanner('update'); }, 1000);
      }
    });

    navigator.serviceWorker.register('/app/sw_version.js', { scope: '/app/' })
      .then(function(reg) {
        reg.update();
        setInterval(function(){ reg.update(); }, 60000);
        reg.addEventListener('updatefound', function() {
          var nw = reg.installing;
          if (!nw) return;
          nw.addEventListener('statechange', function() {
            if (nw.state === 'installed' && navigator.serviceWorker.controller) {
              setTimeout(function(){ showBanner('update'); }, 800);
            }
          });
        });
      })
      .catch(function(e) {
        // SW opcional — falha silenciosa
      });
  }

  /* ─── Prompt de instalação ───────────────────────────────── */
  var _prompt = null;

  window.addEventListener('beforeinstallprompt', function(e) {
    e.preventDefault();
    _prompt = e;

    if (isStandalone() || wasInstalled() || wasDismissed()) return;

    // Mostra banner após 2.5s (app já carregado)
    setTimeout(function() {
      showBanner('install');
      var btn = document.getElementById('pwa-btn-ok');
      if (!btn) return;
      btn.onclick = function() {
        closeBanner('pwa-banner');
        _prompt.prompt();
        _prompt.userChoice.then(function(r) {
          if (r.outcome === 'accepted') {
            markInstalled();
            toast('✅ ShareWallet instalado!');
          }
          _prompt = null;
        });
      };
    }, 2500);
  });

  window.addEventListener('appinstalled', function() {
    markInstalled();
    closeBanner('pwa-banner');
    toast('✅ ShareWallet instalado com sucesso!');
  });

  /* ─── Init ───────────────────────────────────────────────── */
  function init() {
    injectCSS();

    // Já está rodando como PWA instalado
    if (isStandalone()) {
      markInstalled();
      registerSW();
      return;
    }

    // Registra SW sempre (necessário para o Chrome disparar beforeinstallprompt)
    registerSW();

    // iOS: instrução manual
    if (isIOS() && !wasInstalled() && !wasDismissed()) {
      setTimeout(showIOSBanner, 3000);
    }
    // Android: beforeinstallprompt é disparado automaticamente
    // (o banner aparece via o listener acima)
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();
