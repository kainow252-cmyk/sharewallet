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

    // /app/install — serve install.html do Cloudflare Pages (mesmo que /install/index.html)
    // O STATIC_PATHS no bloco /app/* abaixo já cuida disso — sem interceptar aqui
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