/**
 * pwa_install.js — ShareWallet PWA Install / Update Manager
 *
 * Comportamento:
 *  1. Primeira visita no celular → banner "Instalar app" (se não instalado)
 *  2. Visitas seguintes com app instalado → sem banner
 *  3. Nova versão disponível (SW detecta) → banner "Atualizar app"
 *
 * Compatível com Chrome Android (BeforeInstallPromptEvent).
 * iOS Safari: mostra instrução manual "Compartilhar → Adicionar à tela de início".
 */

(function () {
  'use strict';

  /* ─── Constantes ─────────────────────────────────────────── */
  var STORAGE_KEY_INSTALLED   = 'sw_pwa_installed';   // 'yes' quando instalou
  var STORAGE_KEY_DISMISSED   = 'sw_pwa_dismissed';   // timestamp do último dismiss
  var DISMISS_COOLDOWN_MS     = 3 * 24 * 60 * 60 * 1000; // 3 dias
  var BANNER_DELAY_MS         = 3000;  // espera 3s antes de mostrar o banner

  /* ─── Utilitários ────────────────────────────────────────── */
  function isMobile() {
    return /Android|iPhone|iPad|iPod|Opera Mini|IEMobile|WPDesktop/i.test(navigator.userAgent);
  }

  function isIOS() {
    return /iPhone|iPad|iPod/i.test(navigator.userAgent);
  }

  function isStandalone() {
    // Retorna true se o app JÁ está rodando como PWA instalada
    return window.matchMedia('(display-mode: standalone)').matches ||
           window.navigator.standalone === true ||
           document.referrer.indexOf('android-app://') === 0;
  }

  function wasRecentlyDismissed() {
    var ts = localStorage.getItem(STORAGE_KEY_DISMISSED);
    if (!ts) return false;
    return (Date.now() - parseInt(ts, 10)) < DISMISS_COOLDOWN_MS;
  }

  function markInstalled() {
    localStorage.setItem(STORAGE_KEY_INSTALLED, 'yes');
  }

  function isMarkedInstalled() {
    return localStorage.getItem(STORAGE_KEY_INSTALLED) === 'yes';
  }

  /* ─── Estilos inline do banner ───────────────────────────── */
  function injectStyles() {
    var css = [
      '#sw-pwa-banner {',
      '  position: fixed; bottom: 0; left: 0; right: 0; z-index: 99999;',
      '  background: linear-gradient(135deg, #071A10 0%, #0D2B1A 100%);',
      '  border-top: 1.5px solid rgba(0,229,180,0.35);',
      '  padding: 14px 16px 20px;',
      '  box-shadow: 0 -4px 24px rgba(0,0,0,0.55);',
      '  display: flex; align-items: center; gap: 12px;',
      '  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;',
      '  animation: sw-slide-up 0.35s cubic-bezier(.22,.68,0,1.2) both;',
      '}',
      '@keyframes sw-slide-up {',
      '  from { transform: translateY(100%); opacity: 0; }',
      '  to   { transform: translateY(0);    opacity: 1; }',
      '}',
      '#sw-pwa-banner .sw-icon {',
      '  width: 48px; height: 48px; border-radius: 12px; flex-shrink: 0;',
      '  background: rgba(0,229,180,0.12); border: 1.5px solid rgba(0,229,180,0.3);',
      '  display: flex; align-items: center; justify-content: center; overflow: hidden;',
      '}',
      '#sw-pwa-banner .sw-icon img { width: 36px; height: 36px; object-fit: cover; border-radius: 8px; }',
      '#sw-pwa-banner .sw-text { flex: 1; min-width: 0; }',
      '#sw-pwa-banner .sw-text h3 {',
      '  margin: 0 0 2px; font-size: 14px; font-weight: 700;',
      '  color: #fff; line-height: 1.3;',
      '}',
      '#sw-pwa-banner .sw-text p {',
      '  margin: 0; font-size: 12px; color: rgba(255,255,255,0.6); line-height: 1.4;',
      '}',
      '#sw-pwa-banner .sw-actions { display: flex; flex-direction: column; gap: 6px; flex-shrink: 0; }',
      '#sw-pwa-btn-install, #sw-pwa-btn-update {',
      '  padding: 9px 16px; border-radius: 9px; border: none; cursor: pointer;',
      '  font-size: 13px; font-weight: 700; letter-spacing: 0.2px;',
      '  background: linear-gradient(135deg, #00E5B4, #00C49A);',
      '  color: #071A10;',
      '  box-shadow: 0 2px 10px rgba(0,229,180,0.4);',
      '  transition: opacity 0.15s;',
      '}',
      '#sw-pwa-btn-install:active, #sw-pwa-btn-update:active { opacity: 0.8; }',
      '#sw-pwa-btn-dismiss {',
      '  padding: 6px 12px; border-radius: 8px; border: 1px solid rgba(255,255,255,0.15);',
      '  background: transparent; color: rgba(255,255,255,0.5);',
      '  font-size: 12px; cursor: pointer; text-align: center;',
      '}',

      /* Banner de instrução iOS */
      '#sw-ios-hint {',
      '  position: fixed; bottom: 0; left: 0; right: 0; z-index: 99999;',
      '  background: linear-gradient(135deg, #071A10 0%, #0D2B1A 100%);',
      '  border-top: 1.5px solid rgba(0,229,180,0.35);',
      '  padding: 16px 20px 24px;',
      '  box-shadow: 0 -4px 24px rgba(0,0,0,0.55);',
      '  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;',
      '  animation: sw-slide-up 0.35s cubic-bezier(.22,.68,0,1.2) both;',
      '}',
      '#sw-ios-hint h3 { margin: 0 0 8px; font-size: 14px; font-weight: 700; color: #fff; }',
      '#sw-ios-hint p { margin: 0 0 6px; font-size: 13px; color: rgba(255,255,255,0.7); line-height: 1.5; }',
      '#sw-ios-hint .sw-ios-step { display: flex; align-items: center; gap: 8px; margin-bottom: 6px; }',
      '#sw-ios-hint .sw-ios-step span { font-size: 20px; }',
      '#sw-ios-hint .sw-ios-close {',
      '  margin-top: 12px; width: 100%; padding: 10px; border-radius: 9px;',
      '  border: 1px solid rgba(255,255,255,0.2); background: transparent;',
      '  color: rgba(255,255,255,0.6); font-size: 13px; cursor: pointer;',
      '}',

      /* Snackbar de confirmação */
      '#sw-snackbar {',
      '  position: fixed; bottom: 80px; left: 50%; transform: translateX(-50%);',
      '  background: #00E5B4; color: #071A10; font-weight: 700;',
      '  padding: 10px 20px; border-radius: 24px;',
      '  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;',
      '  font-size: 13px; z-index: 100000; white-space: nowrap;',
      '  box-shadow: 0 4px 16px rgba(0,229,180,0.5);',
      '  animation: sw-slide-up 0.3s ease both;',
      '}',
    ].join('\n');

    var style = document.createElement('style');
    style.textContent = css;
    document.head.appendChild(style);
  }

  /* ─── Snackbar de confirmação ────────────────────────────── */
  function showSnackbar(msg) {
    var old = document.getElementById('sw-snackbar');
    if (old) old.remove();
    var el = document.createElement('div');
    el.id = 'sw-snackbar';
    el.textContent = msg;
    document.body.appendChild(el);
    setTimeout(function () { if (el.parentNode) el.remove(); }, 3500);
  }

  /* ─── Banner principal (Android / Chrome) ───────────────── */
  function buildBanner(type) {
    // type: 'install' | 'update'
    var isUpdate = type === 'update';

    var banner = document.createElement('div');
    banner.id = 'sw-pwa-banner';
    banner.innerHTML = [
      '<div class="sw-icon">',
      '  <img src="/app/icons/Icon-192.png" alt="ShareWallet" onerror="this.style.display=\'none\'">',
      '</div>',
      '<div class="sw-text">',
      '  <h3>' + (isUpdate ? '🔄 Atualização disponível' : '📲 Instalar ShareWallet') + '</h3>',
      '  <p>' + (isUpdate
          ? 'Nova versão do app pronta. Atualize para aproveitar as melhorias!'
          : 'Adicione à tela inicial e acesse sem precisar abrir o navegador.')
      + '</p>',
      '</div>',
      '<div class="sw-actions">',
      '  <button id="' + (isUpdate ? 'sw-pwa-btn-update' : 'sw-pwa-btn-install') + '">',
      '    ' + (isUpdate ? 'Atualizar' : 'Instalar'),
      '  </button>',
      '  <button id="sw-pwa-btn-dismiss">Agora não</button>',
      '</div>',
    ].join('');

    return banner;
  }

  function removeBanner() {
    var b = document.getElementById('sw-pwa-banner');
    if (b) {
      b.style.animation = 'none';
      b.style.transition = 'transform 0.25s ease, opacity 0.25s ease';
      b.style.transform = 'translateY(100%)';
      b.style.opacity = '0';
      setTimeout(function () { if (b.parentNode) b.remove(); }, 280);
    }
  }

  /* ─── Instalar PWA (Android/Chrome) ─────────────────────── */
  var _deferredPrompt = null;

  function showInstallBanner() {
    if (!_deferredPrompt) return;
    if (isStandalone() || isMarkedInstalled()) return;
    if (wasRecentlyDismissed()) return;

    var banner = buildBanner('install');
    document.body.appendChild(banner);

    document.getElementById('sw-pwa-btn-install').addEventListener('click', function () {
      removeBanner();
      _deferredPrompt.prompt();
      _deferredPrompt.userChoice.then(function (result) {
        if (result.outcome === 'accepted') {
          markInstalled();
          showSnackbar('✅ ShareWallet instalado com sucesso!');
        }
        _deferredPrompt = null;
      });
    });

    document.getElementById('sw-pwa-btn-dismiss').addEventListener('click', function () {
      localStorage.setItem(STORAGE_KEY_DISMISSED, Date.now().toString());
      removeBanner();
    });
  }

  /* ─── Banner de instrução iOS ────────────────────────────── */
  function showIOSHint() {
    if (isStandalone() || isMarkedInstalled()) return;
    if (wasRecentlyDismissed()) return;

    var hint = document.createElement('div');
    hint.id = 'sw-ios-hint';
    hint.innerHTML = [
      '<h3>📲 Instalar ShareWallet no iPhone/iPad</h3>',
      '<div class="sw-ios-step"><span>1️⃣</span><p>Toque no botão <strong>Compartilhar</strong> (ícone de seta para cima) na barra do Safari</p></div>',
      '<div class="sw-ios-step"><span>2️⃣</span><p>Role para baixo e toque em <strong>"Adicionar à Tela de Início"</strong></p></div>',
      '<div class="sw-ios-step"><span>3️⃣</span><p>Toque em <strong>Adicionar</strong> — pronto! O ícone aparecerá na sua tela</p></div>',
      '<button class="sw-ios-close" id="sw-ios-close-btn">Entendi, talvez depois</button>',
    ].join('');

    document.body.appendChild(hint);

    document.getElementById('sw-ios-close-btn').addEventListener('click', function () {
      localStorage.setItem(STORAGE_KEY_DISMISSED, Date.now().toString());
      var el = document.getElementById('sw-ios-hint');
      if (el) el.remove();
    });
  }

  /* ─── Banner de Atualização ──────────────────────────────── */
  function showUpdateBanner() {
    // Remove eventual banner de instalação
    var existing = document.getElementById('sw-pwa-banner');
    if (existing) existing.remove();

    var banner = buildBanner('update');
    document.body.appendChild(banner);

    document.getElementById('sw-pwa-btn-update').addEventListener('click', function () {
      removeBanner();
      // Força reload sem cache para aplicar a nova versão
      window.location.reload(true);
    });

    document.getElementById('sw-pwa-btn-dismiss').addEventListener('click', function () {
      localStorage.setItem(STORAGE_KEY_DISMISSED, Date.now().toString());
      removeBanner();
    });
  }

  /* ─── Service Worker com detecção de versão ─────────────── */
  function registerSW() {
    if (!('serviceWorker' in navigator)) return;

    // Escuta mensagem do SW indicando nova versão disponível
    navigator.serviceWorker.addEventListener('message', function (event) {
      if (event.data && event.data.type === 'SW_UPDATE_AVAILABLE') {
        // Pequeno delay para não sobrepor o carregamento do Flutter
        setTimeout(function () { showUpdateBanner(); }, 1500);
      }
    });

    navigator.serviceWorker.register('/app/sw_version.js', { scope: '/app/' })
      .then(function (reg) {
        // Verifica updates imediatamente e depois a cada 60s
        reg.update();
        setInterval(function () { reg.update(); }, 60 * 1000);

        // Quando um SW novo fica "waiting", notifica para atualizar
        reg.addEventListener('updatefound', function () {
          var newWorker = reg.installing;
          if (!newWorker) return;
          newWorker.addEventListener('statechange', function () {
            if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
              // Novo SW instalado mas aguardando — avisa o usuário
              setTimeout(function () { showUpdateBanner(); }, 1000);
            }
          });
        });
      })
      .catch(function (err) {
        // SW opcional — falha silenciosa
        if (window.console) console.log('[PWA] SW registration skipped:', err.message);
      });
  }

  /* ─── Detectar se já está instalado via appinstalled ─────── */
  window.addEventListener('appinstalled', function () {
    markInstalled();
    removeBanner();
    showSnackbar('✅ ShareWallet instalado! Acesse pelo ícone na sua tela.');
  });

  /* ─── Captura o prompt ANTES que o browser o descarte ────── */
  window.addEventListener('beforeinstallprompt', function (e) {
    e.preventDefault();  // impede o mini-infobar automático do Chrome
    _deferredPrompt = e;

    // Só mostra se não estiver em modo standalone e não tiver dismissado recentemente
    if (!isStandalone() && !isMarkedInstalled() && !wasRecentlyDismissed()) {
      setTimeout(function () { showInstallBanner(); }, BANNER_DELAY_MS);
    }
  });

  /* ─── Init: roda assim que o DOM estiver pronto ──────────── */
  function init() {
    injectStyles();

    // Se já está rodando como PWA, marca como instalado e não mostra nada
    if (isStandalone()) {
      markInstalled();
      registerSW();  // ainda registra SW para detectar updates futuros
      return;
    }

    // Apenas celulares
    if (!isMobile()) {
      registerSW();
      return;
    }

    // iOS: Chrome não suporta BeforeInstallPromptEvent — mostra hint manual
    if (isIOS() && !isMarkedInstalled() && !wasRecentlyDismissed()) {
      setTimeout(function () { showIOSHint(); }, BANNER_DELAY_MS);
    }

    // Android: o banner aparece via beforeinstallprompt (já capturado acima)
    registerSW();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();
