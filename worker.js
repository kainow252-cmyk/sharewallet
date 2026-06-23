// worker.js — sharewallet-router
// Fix v6: intercepta /assets/ e /fonts/ na raiz (requisições do Flutter engine fora do /app/)
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

    // 2. Função utilitária: proxia qualquer path do Pages com bypass de cache
    async function proxyToPages(pagesPath) {
      const pagesUrl = "https://sharewallet-app.pages.dev" + pagesPath + url.search;

      const reqHeaders = new Headers(request.headers);
      reqHeaders.set("Cache-Control", "no-cache, no-store");
      reqHeaders.set("Pragma", "no-cache");
      reqHeaders.set("x-cache-bust", Date.now().toString());

      const resp = await fetch(pagesUrl, {
        method: request.method,
        headers: reqHeaders,
        body: request.method !== "GET" && request.method !== "HEAD" ? request.body : undefined,
        redirect: "follow",
        cf: { cacheEverything: false, cacheTtl: -1, cacheTtlByStatus: { "200-299": -1, "404": -1 } }
      });

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
      // Remove o prefixo /app do path para buscar no Pages
      let pagesPath = path === "/app" ? "/" : path.slice(4); // /app/main.dart.js -> /main.dart.js

      // CORREÇÃO: Flutter com --base-href /app/ resolve fonts como /app/fonts/...
      // mas no Pages o arquivo está em /assets/fonts/...
      if (pagesPath.startsWith("/fonts/")) {
        pagesPath = "/assets" + pagesPath; // /fonts/X -> /assets/fonts/X
      }

      return proxyToPages(pagesPath);
    }

    // 4. Flutter engine carrega alguns assets com path relativo ao origin (sem /app/)
    //    Ex: /assets/fonts/MaterialIcons-Regular.otf, /assets/FontManifest.json
    //    Esses paths existem no Pages na raiz, então proxy direto
    if (path.startsWith("/assets/") || path.startsWith("/fonts/") ||
        path.startsWith("/canvaskit/") || path.startsWith("/icons/")) {
      return proxyToPages(path);
    }

    // 5. Redirect qualquer outra rota para /app/
    return Response.redirect(url.origin + "/app/", 302);
  }
};
