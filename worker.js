// worker.js — sharewallet-router
// Fix v7: retry automático em 503 (propagação de deploy do Pages)
export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const path = url.pathname;

    // 1. Firebase Auth handler
    if (path.startsWith("/__/auth/")) {
      const firebaseUrl = "https://affiliate-wallet-75853.firebaseapp.com" + path + url.search;
      const resp = await fetch(firebaseUrl, {
        method: request.method,
        headers: request.headers,
        body: request.method !== "GET" && request.method !== "HEAD" ? request.body : undefined,
        redirect: "follow"
      });
      return new Response(resp.body, { status: resp.status, headers: resp.headers });
    }

    // 2. Proxy para Pages com retry automático em 503
    //    Cloudflare Pages pode retornar 503 temporário durante propagação de deploy.
    //    3 tentativas com 300ms de intervalo resolvem o problema na grande maioria dos casos.
    async function proxyToPages(pagesPath, attempt) {
      attempt = attempt || 1;
      const maxAttempts = 3;
      const pagesUrl = "https://sharewallet-app.pages.dev" + pagesPath + url.search;

      const reqHeaders = new Headers(request.headers);
      reqHeaders.set("Cache-Control", "no-cache, no-store");
      reqHeaders.set("Pragma", "no-cache");
      // Bust de cache diferente a cada tentativa para evitar resposta cacheada de 503
      reqHeaders.set("x-cache-bust", Date.now().toString() + "-" + attempt);

      let resp;
      try {
        resp = await fetch(pagesUrl, {
          method: request.method,
          headers: reqHeaders,
          body: request.method !== "GET" && request.method !== "HEAD" ? request.body : undefined,
          redirect: "follow",
          cf: { cacheEverything: false, cacheTtl: -1, cacheTtlByStatus: { "200-299": -1, "404": -1, "503": -1 } }
        });
      } catch (err) {
        // Erro de rede → retenta se ainda tiver tentativas
        if (attempt < maxAttempts) {
          await new Promise(r => setTimeout(r, 300 * attempt));
          return proxyToPages(pagesPath, attempt + 1);
        }
        return new Response("Service unavailable", { status: 503 });
      }

      // 503 do Pages → retenta automaticamente (comum durante propagação de deploy)
      if (resp.status === 503 && attempt < maxAttempts) {
        await new Promise(r => setTimeout(r, 300 * attempt));
        return proxyToPages(pagesPath, attempt + 1);
      }

      const newHeaders = new Headers(resp.headers);
      newHeaders.set("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0");
      newHeaders.set("Pragma", "no-cache");
      newHeaders.set("Surrogate-Control", "no-store");
      newHeaders.delete("ETag");
      newHeaders.delete("Last-Modified");
      newHeaders.set("CF-Cache-Status", "BYPASS");

      return new Response(resp.body, { status: resp.status, headers: newHeaders });
    }

    // 3. /app/* — proxy principal para Cloudflare Pages
    if (path === "/app" || path.startsWith("/app/")) {
      let pagesPath = path === "/app" ? "/" : path.slice(4); // /app/main.dart.js -> /main.dart.js

      // Flutter com --base-href /app/ resolve fonts como /app/fonts/...
      // mas no Pages o arquivo está em /assets/fonts/...
      if (pagesPath.startsWith("/fonts/")) {
        pagesPath = "/assets" + pagesPath; // /fonts/X -> /assets/fonts/X
      }

      return proxyToPages(pagesPath);
    }

    // 4. Flutter engine carrega alguns assets com path relativo ao origin (sem /app/)
    //    Ex: /assets/fonts/MaterialIcons-Regular.otf, /assets/FontManifest.json
    if (path.startsWith("/assets/") || path.startsWith("/fonts/") ||
        path.startsWith("/canvaskit/") || path.startsWith("/icons/")) {
      return proxyToPages(path);
    }

    // 5. Redirect qualquer outra rota para /app/
    return Response.redirect(url.origin + "/app/", 302);
  }
};
