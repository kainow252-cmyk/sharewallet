var __defProp = Object.defineProperty;
var __name = (target, value) => __defProp(target, "name", { value, configurable: true });

// worker.js
var PAGES_BASE = "https://sharewallet-app.pages.dev";
var FIREBASE_APP = "https://affiliate-wallet-75853.firebaseapp.com";
var IMMUTABLE_PATTERNS = [
  // Arquivo principal do Flutter (hash no nome ou sempre o mesmo por deploy)
  /^\/main\.dart\.js$/,
  /^\/main\.dart\.js\.map$/,
  // Arquivos de assets do Flutter com hash no nome
  /\/assets\/.*\.[a-f0-9]{8,}\./i,
  // Fontes com hash
  /\/fonts\/.*\.[a-f0-9]{8,}\./i,
  // CanvasKit wasm/js (versionados por deploy)
  /^\/canvaskit\//,
  // Qualquer arquivo .wasm
  /\.wasm$/,
  // Ícones PNG com hash
  /\/icons\/.*Icon.*\.png$/
];
var SHORT_CACHE_PATTERNS = [];
var NO_CACHE_PATTERNS = [
  /^\/index\.html$/,
  /^\/$/,
  // raiz → index.html
  /^\/app\/?$/,
  // /app/ → index.html
  /^\/manifest\.json$/,
  /^\/flutter_service_worker\.js$/,
  /^\/flutter_bootstrap\.js$/,
  // CRÍTICO: ponto de entrada do Flutter (muda a cada build)
  /^\/flutter\.js$/,
  // CRÍTICO: SDK loader (muda entre versões)
  /^\/sw_version\.js$/,
  /^\/pwa_install\.js$/,
  /^\/version\.json$/,
  /^\/AssetManifest\.json$/,
  /^\/FontManifest\.json$/,
  /^\/NOTICES$/
];
function getCachePolicy(path) {
  for (const pattern of IMMUTABLE_PATTERNS) {
    if (pattern.test(path)) {
      return {
        cacheControl: "public, max-age=31536000, immutable",
        deleteEtag: false,
        cfCacheEverything: true,
        cfCacheTtl: 31536e3
      };
    }
  }
  for (const pattern of SHORT_CACHE_PATTERNS) {
    if (pattern.test(path)) {
      return {
        cacheControl: "public, max-age=600, stale-while-revalidate=3600",
        deleteEtag: false,
        cfCacheEverything: true,
        cfCacheTtl: 600
      };
    }
  }
  for (const pattern of NO_CACHE_PATTERNS) {
    if (pattern.test(path)) {
      return {
        cacheControl: "no-cache, no-store, must-revalidate",
        deleteEtag: true,
        cfCacheEverything: false,
        cfCacheTtl: 0
      };
    }
  }
  return {
    cacheControl: "public, max-age=3600, stale-while-revalidate=86400",
    deleteEtag: false,
    cfCacheEverything: true,
    cfCacheTtl: 3600
  };
}
__name(getCachePolicy, "getCachePolicy");
async function proxyToPages(pagesPath, searchStr, policy, method, body, reqHeaders, attempt) {
  attempt = attempt || 1;
  const maxAttempts = 3;
  const pagesUrl = PAGES_BASE + pagesPath + (searchStr ? searchStr : "");
  const upstreamHeaders = new Headers(reqHeaders);
  upstreamHeaders.delete("if-none-match");
  upstreamHeaders.delete("if-modified-since");
  upstreamHeaders.set("Accept-Encoding", "gzip, deflate, br");
  let resp;
  try {
    const cfOptions = policy.cfCacheEverything ? { cacheEverything: true, cacheTtl: policy.cfCacheTtl } : { cacheEverything: false, cacheTtl: 0, bypassCache: true };
    resp = await fetch(pagesUrl, {
      method,
      headers: upstreamHeaders,
      body: method !== "GET" && method !== "HEAD" ? body : void 0,
      redirect: "follow",
      cf: cfOptions
    });
  } catch (err) {
    if (attempt < maxAttempts) {
      await new Promise((r) => setTimeout(r, 300 * attempt));
      return proxyToPages(pagesPath, searchStr, policy, method, body, reqHeaders, attempt + 1);
    }
    return new Response("Service unavailable", { status: 503 });
  }
  if (resp.status === 503 && attempt < maxAttempts) {
    await new Promise((r) => setTimeout(r, 300 * attempt));
    return proxyToPages(pagesPath, searchStr, policy, method, body, reqHeaders, attempt + 1);
  }
  const newHeaders = new Headers(resp.headers);
  newHeaders.set("Cache-Control", policy.cacheControl);
  if (!policy.cfCacheEverything) {
    newHeaders.set("CDN-Cache-Control", "no-store");
    newHeaders.set("Cloudflare-CDN-Cache-Control", "no-store");
    newHeaders.set("Surrogate-Control", "no-store");
  }
  if (policy.deleteEtag) {
    newHeaders.delete("ETag");
    newHeaders.delete("Last-Modified");
  }
  newHeaders.set("X-Frame-Options", "ALLOWALL");
  newHeaders.set("Content-Security-Policy", "frame-ancestors *");
  newHeaders.delete("CF-Cache-Status");
  newHeaders.set("Access-Control-Allow-Origin", "*");
  return new Response(resp.body, {
    status: resp.status,
    headers: newHeaders
  });
}
__name(proxyToPages, "proxyToPages");
var worker_default = {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;
    if (method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, HEAD, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type",
          "Access-Control-Max-Age": "86400"
        }
      });
    }
    if (path.startsWith("/__/auth/")) {
      const firebaseUrl = FIREBASE_APP + path + url.search;
      const resp = await fetch(firebaseUrl, {
        method,
        headers: request.headers,
        body: method !== "GET" && method !== "HEAD" ? request.body : void 0,
        redirect: "follow"
      });
      const headers = new Headers(resp.headers);
      headers.set("Cache-Control", "no-store");
      return new Response(resp.body, { status: resp.status, headers });
    }
    if (path === "/" || path === "") {
      return Response.redirect(url.origin + "/app/", 302);
    }
    // Proxy APK do GitHub Releases — mesmo dominio = sem nova guia no Chrome
    if (path === "/app/download" || path === "/download/apk") {
      const APK_URL = "https://github.com/kainow252-cmyk/sharewallet/releases/download/v1.0.5/ShareWallet-v1.0.5.apk";
      const apkResp = await fetch(APK_URL, {
        headers: { "User-Agent": "Mozilla/5.0" }
      });
      const headers = new Headers();
      headers.set("Content-Type", "application/vnd.android.package-archive");
      headers.set("Content-Disposition", "attachment; filename=ShareWallet.apk");
      headers.set("Cache-Control", "no-cache");
      headers.set("Access-Control-Allow-Origin", "*");
      const cl = apkResp.headers.get("Content-Length");
      if (cl) headers.set("Content-Length", cl);
      return new Response(apkResp.body, { status: 200, headers });
    }

    // Página de instalação: dispara download + botão "Instalar agora" via intent://
    if (path === "/app/install" || path === "/install-apk") {
      const APK_DOWNLOAD_URL = url.origin + "/app/download";
      const html_page = `<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
<title>Instalar ShareWallet</title>
<style>
  *{box-sizing:border-box;margin:0;padding:0}
  body{min-height:100vh;background:linear-gradient(160deg,#0A1628 0%,#0D3B2E 100%);
       display:flex;flex-direction:column;align-items:center;justify-content:center;
       font-family:Roboto,sans-serif;color:#fff;padding:24px;text-align:center}
  .logo{width:72px;height:72px;border-radius:20px;margin-bottom:20px;box-shadow:0 0 32px #00E5B440}
  h1{font-size:22px;font-weight:900;margin-bottom:8px}
  .sub{color:rgba(255,255,255,.55);font-size:14px;margin-bottom:32px;line-height:1.5}
  .steps{width:100%;max-width:340px;margin-bottom:32px}
  .step{display:flex;align-items:center;gap:12px;padding:12px 16px;border-radius:12px;
        background:rgba(255,255,255,.04);border:1px solid rgba(0,229,180,.15);margin-bottom:8px;
        transition:all .3s}
  .step.active{background:rgba(0,229,180,.1);border-color:rgba(0,229,180,.4)}
  .step.done{background:rgba(0,229,180,.06);border-color:rgba(0,229,180,.25)}
  .dot{width:32px;height:32px;border-radius:50%;display:flex;align-items:center;justify-content:center;
       font-size:14px;font-weight:800;flex-shrink:0;background:rgba(255,255,255,.08);color:rgba(255,255,255,.4)}
  .step.active .dot{background:#00E5B4;color:#0A1628}
  .step.done .dot{background:rgba(0,229,180,.2);color:#00E5B4}
  .step-text{text-align:left;font-size:13px;font-weight:600;color:rgba(255,255,255,.5)}
  .step.active .step-text{color:#fff}
  .step.done .step-text{color:#00E5B4}
  .btn{display:block;width:100%;max-width:340px;padding:16px;border-radius:14px;
       background:#00E5B4;color:#0A1628;font-size:16px;font-weight:900;
       text-decoration:none;border:none;cursor:pointer;margin-bottom:12px;
       box-shadow:0 4px 20px rgba(0,229,180,.3);transition:opacity .2s}
  .btn:hover{opacity:.9}
  .btn:disabled,.btn.hidden{opacity:.35;pointer-events:none}
  .progress{width:100%;max-width:340px;height:6px;background:rgba(255,255,255,.08);
            border-radius:3px;margin-bottom:24px;overflow:hidden;display:none}
  .progress.show{display:block}
  .progress-bar{height:100%;background:#00E5B4;border-radius:3px;width:0%;
                transition:width .3s}
  .hint{color:rgba(255,255,255,.3);font-size:11px;line-height:1.5;max-width:300px}
  .spinner{width:20px;height:20px;border:2px solid rgba(0,229,180,.3);border-top-color:#00E5B4;
           border-radius:50%;animation:spin .8s linear infinite;display:none;margin:0 auto 16px}
  .spinner.show{display:block}
  @keyframes spin{to{transform:rotate(360deg)}}
</style>
</head>
<body>
<img class="logo" src="/app/icons/Icon-192.png" onerror="this.style.display='none'">
<h1>ShareWallet</h1>
<p class="sub">Baixando o app...<br>Aguarde um momento.</p>

<div class="progress" id="prog"><div class="progress-bar" id="bar"></div></div>
<div class="spinner" id="spin"></div>

<div class="steps">
  <div class="step active" id="s1">
    <div class="dot" id="d1">1</div>
    <div class="step-text" id="t1">Baixando APK (62 MB)...</div>
  </div>
  <div class="step" id="s2">
    <div class="dot">2</div>
    <div class="step-text">Toque em <b>Instalar agora</b></div>
  </div>
  <div class="step" id="s3">
    <div class="dot">3</div>
    <div class="step-text">App instalado — Abrir</div>
  </div>
</div>

<button class="btn hidden" id="btnInstall" onclick="installNow()">
  ⬇️ Instalar agora
</button>
<button class="btn" id="btnOpen" style="background:rgba(0,229,180,.15);color:#00E5B4;box-shadow:none;display:none" onclick="openApp()">
  🚀 Abrir ShareWallet
</button>

<p class="hint" id="hint">O download iniciou automaticamente.<br>Aguarde a notificação do Chrome.</p>

<script>
const DOWNLOAD_URL = "${APK_DOWNLOAD_URL}";
const INSTALL_URL = "intent://ShareWallet.apk#Intent;action=android.intent.action.VIEW;type=application/vnd.android.package-archive;package=com.android.chrome;end";
const DOWNLOADS_URL = "intent://downloads#Intent;action=android.intent.action.MAIN;category=android.intent.category.LAUNCHER;package=com.google.android.documentsui;end";

let downloadDone = false;
let progressInterval = null;

function setStep(n) {
  for (let i = 1; i <= 3; i++) {
    document.getElementById('s'+i).className = 'step' + (i < n ? ' done' : i === n ? ' active' : '');
    document.getElementById('d'+i).textContent = i < n ? '✓' : i;
  }
}

function fakeProgress() {
  const bar = document.getElementById('bar');
  const prog = document.getElementById('prog');
  const spin = document.getElementById('spin');
  prog.classList.add('show');
  spin.classList.add('show');
  let pct = 0;
  progressInterval = setInterval(() => {
    // Progresso simulado: rápido até 85%, depois espera
    if (pct < 85) pct += (85 - pct) * 0.04 + 0.3;
    bar.style.width = Math.min(pct, 95) + '%';
  }, 300);
}

function downloadComplete() {
  if (downloadDone) return;
  downloadDone = true;
  clearInterval(progressInterval);
  // Barra 100%
  const bar = document.getElementById('bar');
  const spin = document.getElementById('spin');
  bar.style.width = '100%';
  setTimeout(() => { spin.classList.remove('show'); }, 400);
  // Atualiza UI
  setStep(2);
  document.getElementById('t1').textContent = '✓ APK baixado com sucesso!';
  document.querySelector('.sub').textContent = 'Download concluído! Toque em Instalar agora.';
  document.getElementById('hint').textContent = 'Toque no botão abaixo para instalar.';
  // Mostra botão instalar
  const btn = document.getElementById('btnInstall');
  btn.textContent = '📦 Instalar agora';
  btn.classList.remove('hidden');
  // Tenta abrir instalador automaticamente
  autoInstall();
}

function autoInstall() {
  // Tenta abrir o gerenciador de downloads/instalador automaticamente
  try {
    window.location.href = DOWNLOADS_URL;
  } catch(e) {}
}

function installNow() {
  // Abre o gerenciador de downloads do Android onde o APK está salvo
  window.location.href = DOWNLOADS_URL;
  setTimeout(() => {
    // Se o intent falhar, tenta abrir direto
    try {
      window.location.href = "content://downloads/my_downloads";
    } catch(e) {}
  }, 1500);
  setStep(3);
  setTimeout(() => {
    document.getElementById('btnOpen').style.display = 'block';
  }, 3000);
}

function openApp() {
  // Tenta abrir o app via deep link
  window.location.href = "sharewallet://";
  setTimeout(() => {
    window.location.href = "https://payment.sharewallet.com.br/app/";
  }, 1500);
}

// Inicia ao carregar a página
window.addEventListener('DOMContentLoaded', () => {
  fakeProgress();

  // Dispara o download via <a> tag
  const a = document.createElement('a');
  a.href = DOWNLOAD_URL;
  a.download = 'ShareWallet.apk';
  a.style.display = 'none';
  document.body.appendChild(a);
  a.click();
  setTimeout(() => a.remove(), 500);

  // Polling: verifica se download foi concluído via notificação
  // Chrome Mobile notifica via visibilitychange quando o download termina
  document.addEventListener('visibilitychange', () => {
    if (!document.hidden && !downloadDone) {
      // Usuário voltou para a aba = provável que download terminou
      setTimeout(downloadComplete, 800);
    }
  });

  // Timeout máximo: 4 minutos (62MB / ~250KB/s) → marca como concluído
  setTimeout(downloadComplete, 240000);

  // Botão manual visível após 10s se usuário não voltar
  setTimeout(() => {
    if (!downloadDone) {
      const btn = document.getElementById('btnInstall');
      btn.textContent = '📦 Download concluído? Instalar agora';
      btn.classList.remove('hidden');
      document.getElementById('hint').textContent =
        'Se o download terminou, toque no botão acima.';
    }
  }, 10000);
});
</script>
</body>
</html>`;
      return new Response(html_page, {
        status: 200,
        headers: {
          "Content-Type": "text/html;charset=UTF-8",
          "Cache-Control": "no-store",
          "X-Frame-Options": "ALLOWALL",
          "Content-Security-Policy": "frame-ancestors *",
        }
      });
    }
    if (path === "/app" || path.startsWith("/app/")) {
      let pagesPath;
      if (path === "/app" || path === "/app/") {
        pagesPath = "/index.html";
      } else {
        pagesPath = path.slice(4) || "/";
        if (pagesPath.startsWith("/fonts/")) {
          pagesPath = "/assets" + pagesPath;
        }
        // Paths estáticos conhecidos (sem extensão mas não são rotas SPA)
        const STATIC_PATHS = ["/install", "/install/"];
        if (!pagesPath.includes(".") && pagesPath !== "/" && !STATIC_PATHS.includes(pagesPath)) {
          pagesPath = "/index.html";
        }
      }
      const policy = getCachePolicy(pagesPath);
      return proxyToPages(pagesPath, url.search, policy, method, request.body, request.headers);
    }
    if (path.startsWith("/assets/") || path.startsWith("/fonts/") || path.startsWith("/canvaskit/") || path.startsWith("/icons/") || path === "/manifest.json" || path === "/flutter.js" || path === "/flutter_bootstrap.js" || path === "/flutter_service_worker.js" || path === "/version.json" || path === "/main.dart.js" || path.endsWith(".wasm") || path.endsWith(".js.map")) {
      const policy = getCachePolicy(path);
      return proxyToPages(path, url.search, policy, method, request.body, request.headers);
    }
    return Response.redirect(url.origin + "/app/", 302);
  }
};
export {
  worker_default as default
};
//# sourceMappingURL=worker.js.map