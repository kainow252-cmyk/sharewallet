var __defProp = Object.defineProperty;
var __name = (target, value) => __defProp(target, "name", { value, configurable: true });

// ── Google Play Internal Testing — join-beta helper ───────────────────────────
//
// Gera um JWT assinado com RSASSA-PKCS1-v1_5 (RS256) usando a private key
// da service account, troca por um access_token OAuth2, depois chama a API
// do Google Play Developer para adicionar o email como testador interno.
//
// A private_key e o client_email são armazenados como Secrets no Worker
// (variáveis de ambiente injetadas via wrangler secret put):
//   PLAY_SA_EMAIL   = rotaposto-play@linen-jet-475102-s0.iam.gserviceaccount.com
//   PLAY_SA_KEY     = -----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n
//   PLAY_PACKAGE    = com.affiliatewallet.wallet
//   PLAY_BETA_LINK  = (link de opt-in da Play Store — opcional)

/** Converte string base64url para Uint8Array */
function b64uDecode(str) {
  // base64url → base64 padrão
  str = str.replace(/-/g, "+").replace(/_/g, "/");
  while (str.length % 4) str += "=";
  const bin = atob(str);
  return Uint8Array.from(bin, c => c.charCodeAt(0));
}

/** Codifica Uint8Array/string para base64url sem padding */
function b64uEncode(buf) {
  const bytes = buf instanceof Uint8Array ? buf : new TextEncoder().encode(buf);
  let bin = "";
  bytes.forEach(b => bin += String.fromCharCode(b));
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/**
 * Importa a chave PEM RSA privada (PKCS#8) para uso com Web Crypto API.
 * O Cloudflare Workers suporta SubtleCrypto com RS256.
 */
async function importRsaKey(pemKey) {
  // Remove cabeçalho/rodapé PEM e espaços
  const base64 = pemKey
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\\n/g, "")
    .replace(/\n/g, "")
    .trim();

  const keyBytes = Uint8Array.from(atob(base64), c => c.charCodeAt(0));

  return crypto.subtle.importKey(
    "pkcs8",
    keyBytes.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );
}

/**
 * Cria e assina um JWT para a service account do Google.
 * Scope: https://www.googleapis.com/auth/androidpublisher
 */
async function createServiceAccountJwt(clientEmail, privateKeyPem) {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: clientEmail,
    scope: "https://www.googleapis.com/auth/androidpublisher",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const headerB64  = b64uEncode(JSON.stringify(header));
  const payloadB64 = b64uEncode(JSON.stringify(payload));
  const signingInput = `${headerB64}.${payloadB64}`;

  const key = await importRsaKey(privateKeyPem);
  const sigBuf = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(signingInput)
  );
  const sigB64 = b64uEncode(new Uint8Array(sigBuf));

  return `${signingInput}.${sigB64}`;
}

/**
 * Troca o JWT por um Google OAuth2 access_token.
 */
async function getAccessToken(jwt) {
  const resp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!resp.ok) {
    const txt = await resp.text();
    throw new Error(`OAuth2 token error ${resp.status}: ${txt}`);
  }
  const data = await resp.json();
  return data.access_token;
}

/**
 * Adiciona o email como testador interno no Google Play Developer API.
 * GET atual → adiciona email → PUT de volta.
 */
async function addPlayTester(accessToken, packageName, email) {
  const baseUrl = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/testers`;
  const headers = {
    Authorization: `Bearer ${accessToken}`,
    "Content-Type": "application/json",
  };

  // GET lista atual de testadores
  const getResp = await fetch(baseUrl, { headers });
  let testers = [];
  if (getResp.ok) {
    const data = await getResp.json();
    testers = data.testers || [];
  }

  // Verifica se já está na lista
  const emailLower = email.toLowerCase();
  const already = testers.some(t => t.toLowerCase() === emailLower);
  if (already) {
    return { alreadyTester: true };
  }

  // Adiciona email
  testers.push(email);

  // PUT lista atualizada
  const putResp = await fetch(baseUrl, {
    method: "PUT",
    headers,
    body: JSON.stringify({ testers }),
  });

  if (!putResp.ok) {
    const txt = await putResp.text();
    throw new Error(`Play API PUT error ${putResp.status}: ${txt}`);
  }

  return { alreadyTester: false };
}

/**
 * Handler do endpoint POST /app/join-beta
 * Body JSON: { "email": "user@example.com" }
 * Resposta 200: { "ok": true, "message": "..." }
 * Resposta 4xx/5xx: { "error": "..." }
 */
async function handleJoinBeta(request, env) {
  // CORS preflight
  if (request.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type",
      },
    });
  }

  if (request.method !== "POST") {
    return jsonResp({ error: "Method not allowed" }, 405);
  }

  // Ler body
  let body;
  try {
    body = await request.json();
  } catch {
    return jsonResp({ error: "JSON inválido" }, 400);
  }

  const email = (body.email || "").trim().toLowerCase();
  const emailRx = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRx.test(email)) {
    return jsonResp({ error: "Email inválido" }, 400);
  }

  // Credenciais da service account (Secrets do Worker)
  const saEmail  = env.PLAY_SA_EMAIL;
  const saKey    = env.PLAY_SA_KEY;
  const pkgName  = env.PLAY_PACKAGE || "com.affiliatewallet.wallet";

  if (!saEmail || !saKey) {
    return jsonResp({ error: "Configuração incompleta no servidor" }, 500);
  }

  try {
    const jwt         = await createServiceAccountJwt(saEmail, saKey);
    const accessToken = await getAccessToken(jwt);
    const result      = await addPlayTester(accessToken, pkgName, email);

    const msg = result.alreadyTester
      ? "Você já é testador! Verifique seu Gmail para o link de download."
      : "Convite enviado! Verifique seu Gmail em instantes.";

    return jsonResp({ ok: true, message: msg }, 200);

  } catch (err) {
    // Log interno — não expõe detalhes ao cliente
    console.error("join-beta error:", err.message);
    return jsonResp({
      error: "Não foi possível enviar o convite. Tente novamente."
    }, 500);
  }
}

function jsonResp(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
}

// ── worker.js ─────────────────────────────────────────────────────────────────
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
          "Access-Control-Allow-Methods": "GET, HEAD, POST, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type",
          "Access-Control-Max-Age": "86400"
        }
      });
    }

    // ── Beta tester: adiciona email como testador interno na Play Store ───────
    if (path === "/app/join-beta") {
      return handleJoinBeta(request, env);
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
    // ── Download APK via R2 (proxy mesmo domínio) ────────────────────────────
    //
    // FLUXO CORRETO (testado, funciona sem nova guia):
    //   Flutter: downloadApkBlob() faz fetch() same-origin → Blob → <a download>
    //   Worker:  serve APK do R2 com Content-Type correto, SEM redirect
    //
    // Por que NÃO usar redirect 302 para GitHub:
    //   • redirect cross-origin → Chrome Android abre nova guia ❌
    //
    // Por que proxy R2 funciona com fetch+Blob:
    //   • fetch() same-origin → browser não abre nova guia ✅
    //   • blob:// URL é same-origin → <a download> é respeitado ✅
    //   • Chrome mostra "ABRIR" na notificação ao terminar ✅
    if (path === "/app/download" || path === "/download/apk" ||
        path === "/app/ShareWallet.apk" || path === "/ShareWallet.apk") {
      const APK_KEY = "ShareWallet-v1.0.5.apk";
      try {
        const obj = await env.APK_BUCKET.get(APK_KEY);
        if (!obj) {
          const GITHUB_APK = "https://github.com/kainow252-cmyk/sharewallet/releases/download/v1.0.5/ShareWallet-v1.0.5.apk";
          return Response.redirect(GITHUB_APK, 302);
        }
        const headers = new Headers();
        headers.set("Content-Type", "application/vnd.android.package-archive");
        headers.set("Content-Disposition", 'attachment; filename="ShareWallet.apk"');
        if (obj.size) headers.set("Content-Length", String(obj.size));
        headers.set("Cache-Control", "no-store");
        headers.set("Access-Control-Allow-Origin", "*");
        return new Response(obj.body, { status: 200, headers });
      } catch (_) {
        const GITHUB_APK = "https://github.com/kainow252-cmyk/sharewallet/releases/download/v1.0.5/ShareWallet-v1.0.5.apk";
        return Response.redirect(GITHUB_APK, 302);
      }
    }
    // ─────────────────────────────────────────────────────────────────────────

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
        // /install não existe mais — tudo sem extensão vira SPA
        if (!pagesPath.includes(".") && pagesPath !== "/") {
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