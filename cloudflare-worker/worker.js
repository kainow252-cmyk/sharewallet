// ── ShareWallet API Worker ─────────────────────────────────────────────────
// Cloudflare Worker + D1 (SQLite) — resposta < 50ms global

// ── Firebase Admin — credenciais do service account ──────────────────────────
const FB_PROJECT_ID    = 'affiliate-wallet-75853';
const FB_CLIENT_EMAIL  = 'firebase-adminsdk-fbsvc@affiliate-wallet-75853.iam.gserviceaccount.com';
// Private key PKCS#8 em base64 (sem header/footer/newlines)
const FB_PRIVATE_KEY_B64 = 'MIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQDVcuGYySx0vGgvdnqMxmompoo9fVAtRSX4R1WNTY23Z9HMrZGqiOu6UQkddEUz9RthcoNg7LV9owrS9pe/plfLj8vrxvCNmQbiG3dKMfxAjbn9vLpzdbJHq0xHv8rnDnQ31kckAV9g8eeU7dDcDp8LKJoCHbyMp44kGHFjfXoov1ZzryqLEJ0VPFAOjWwLbeD695NYOxtJ/DpS71/FiTr1TWONPKmn9G8yvQY74yXaPGEgIMT4zl+uLeLYrXmahhD84gJ5XXDkLie/o691eizHGwW+7lBbWa+HN0o7FA065yjGaa7pnJDRiZNwmqgF+Kj2OtPQ6B1z46RyuDS6CAJnAgMBAAECggEAMJLeJ+jQBxjBFNv/c33LtlP77ZZQ4pxz0ZZaL7fQYkZsBgoRth9GlbXPPzawcOx8eKaYozv66UZrNisLyX9PR3HH1DYHlBGY8WeSs/3AC+i0xLtoKtJD6e9fgoxw3jf51qMauWTeka87JjcgapOhOebZdVXTDKcsv6YYV628WP0XUBSZr6Fsrw7vBKjT9S4l98S9aSn0DExFBcXnYUpRaNLys7J2JBdEIWmvCy3lXTwNaL9Eee6Uj81PtxsfSEm0KT3eQrkP6nmRS/sup1k1Yb5bWe3AedGEnqA+7r1rI0tdPWC64swGY4qMrVqEYQmiuKQSpn4RNgfXebJitwlSUQKBgQD5W12atWmEERQUNVYZ+bJAYHQfCHVOfz1SJAgq/YYl2YAop3Vqpqcaj65qDjkl4K9Ka4iwhD6BvQgOzcuuNd5FijAzVdWed72lmoU5OciZjKFyfhGamOfr4TnEKb7QO7zoxEWCKQW1nho3FOeLoDBF+v+jSwpzt1xs5QetjwSE5QKBgQDbIp5/742M+aiglIYqluXVcGmeKWcHJiCNuPaQ+LtSBmhpGErWHfGP8qM3rd7/EBTsDbzlKX+Eb8s9Qd1TLdj7bORrmwLZrNoLD7kbutISv6VlYiS6TGrbOxJERjIEgupjAyv2lmHC79ttqYo6cbHwWSUX1G9vGU32eK6QaaphWwKBgGRMjN0i5Vta50GtpoFyP3HHmk21QEIfyhGVLrfkHCZzUyqHGSKaABMeAiDksbX7p2Z+1I9z0hSrbWdO/gOH5W0BRZwQhYllTqIjAj1fccHZoEMGVJxjrr3hbTPrOrZVoQnbkL3nNEW2X4MSZIR0HZa4fEU5dO3Qrlua0DjOkxnFAoGAPgMT+3xdAFH+SEL/nLnLHJWNLfblcv51I+X90JSy3cl2bpczRlh+7Y9qZO1NN7zjTtGsbOVLcrz4NMOY0FsfFjeAhHr/WX4yzgKLDa/Wlvuo4IHfhuDtNFEJIE0FBoXNsmtJW6S+0Z1y6RubRGK8ShnQB2hUiIoOp/sK208rqhUCgYAtx5cb1sNYBWEsKVnObrdYo4szByt1ByRx5xAXacfEcEQJC+he69ALMmsQasa8SNj0vOfcl+5Z2Bp26SovdgzwaHu+r6ZcJ/ANZAYk1nOXPyXB4M16x2cIFzI8B2f8MbF3rVMzp2/ZtqMxdveBidNLUZ2j5nojyPpTsE13ioJ6Kg==';

// ── Helpers JWT/Firebase Auth ─────────────────────────────────────────────────

// Converte base64 padrão para base64url
function toBase64Url(b64) {
  return b64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
}

// Codifica objeto como base64url JSON
function b64UrlEncode(obj) {
  return toBase64Url(btoa(JSON.stringify(obj)));
}

// Gera JWT RS256 assinado com a chave privada do service account
async function makeFirebaseJWT() {
  const now = Math.floor(Date.now() / 1000);
  const header  = b64UrlEncode({ alg: 'RS256', typ: 'JWT' });
  const payload = b64UrlEncode({
    iss: FB_CLIENT_EMAIL,
    sub: FB_CLIENT_EMAIL,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/firebase https://www.googleapis.com/auth/identitytoolkit',
  });

  // Importar chave privada PKCS#8
  const keyBytes = Uint8Array.from(atob(FB_PRIVATE_KEY_B64), c => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8', keyBytes.buffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false, ['sign']
  );

  // Assinar header.payload
  const data = new TextEncoder().encode(`${header}.${payload}`);
  const sig  = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', cryptoKey, data);
  const sigB64 = toBase64Url(btoa(String.fromCharCode(...new Uint8Array(sig))));

  return `${header}.${payload}.${sigB64}`;
}

// Obtém access token OAuth2 para chamar APIs do Firebase/Google
async function getFirebaseAccessToken() {
  const jwt = await makeFirebaseJWT();
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
  });
  const data = await res.json();
  return data.access_token || null;
}

// Deleta usuário do Firebase Authentication pelo UID
// Endpoint correto: POST /v1/projects/{project}/accounts:delete com { localId }
// (DELETE /accounts/{uid} não existe na API REST — retorna 404 HTML)
async function deleteFirebaseAuthUser(uid) {
  try {
    const token = await getFirebaseAccessToken();
    if (!token) return { ok: false, error: 'Falha ao obter access token Firebase' };

    const res = await fetch(
      `https://identitytoolkit.googleapis.com/v1/projects/${FB_PROJECT_ID}/accounts:delete`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ localId: uid }),
      }
    );

    // 200 = deletado com sucesso
    if (res.status === 200) return { ok: true };

    const body = await res.json().catch(() => ({}));
    const msg = body?.error?.message || '';

    // USER_NOT_FOUND = usuário já não existia no Firebase Auth → ok (idempotente)
    if (msg === 'USER_NOT_FOUND') return { ok: true, note: 'Usuário não existia no Firebase Auth' };

    return { ok: false, error: `Firebase Auth API ${res.status}: ${msg || JSON.stringify(body)}` };
  } catch (e) {
    return { ok: false, error: String(e) };
  }
}

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

function err(msg, status = 400) {
  return json({ success: false, error: msg }, status);
}

function ok(result) {
  return json({ success: true, result });
}

// ── Roteador principal ────────────────────────────────────────────────────────
export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS });
    }

    const url  = new URL(request.url);
    const path = url.pathname.replace(/\/$/, ''); // remove trailing slash
    const method = request.method;
    const DB = env.DB;

    // ── /api/products ──────────────────────────────────────────────────────
    if (path === '/api/products' && method === 'GET') {
      const { results } = await DB.prepare(
        `SELECT * FROM products WHERE ativo = 1 ORDER BY nome`
      ).all();
      return ok(results);
    }

    if (path === '/api/products/all' && method === 'GET') {
      const { results } = await DB.prepare(
        `SELECT * FROM products ORDER BY nome`
      ).all();
      return ok(results);
    }

    if (path === '/api/products' && method === 'POST') {
      const b = await request.json();
      const id = b.id || 'p_' + Date.now();
      await DB.prepare(
        `INSERT INTO products (id,nome,descricao,valor,comissao,categoria,charge_type,
          periodicidade,dia_cobranca,beneficios,imagem_url,ativo)
         VALUES (?,?,?,?,?,?,?,?,?,?,?,?)
         ON CONFLICT(id) DO UPDATE SET
          nome=excluded.nome, descricao=excluded.descricao, valor=excluded.valor,
          comissao=excluded.comissao, categoria=excluded.categoria,
          charge_type=excluded.charge_type, periodicidade=excluded.periodicidade,
          dia_cobranca=excluded.dia_cobranca, beneficios=excluded.beneficios,
          imagem_url=excluded.imagem_url, ativo=excluded.ativo`
      ).bind(
        id, b.nome, b.descricao??'', b.valor??0, b.comissao??0,
        b.categoria??'geral', b.chargeType??b.charge_type??'pixRecorrente',
        b.periodicidade??null, b.diaCobranca??b.dia_cobranca??null,
        b.beneficios??null, b.imagem_url??null, b.ativo===false?0:1
      ).run();
      const product = await DB.prepare(`SELECT * FROM products WHERE id=?`).bind(id).first();
      return ok(product);
    }

    // PUT /api/products/:id
    const productMatch = path.match(/^\/api\/products\/([^/]+)$/);
    if (productMatch && method === 'PUT') {
      const id = productMatch[1];
      const b = await request.json();
      await DB.prepare(
        `UPDATE products SET nome=?,descricao=?,valor=?,comissao=?,categoria=?,
          charge_type=?,periodicidade=?,dia_cobranca=?,beneficios=?,imagem_url=?,ativo=?
         WHERE id=?`
      ).bind(
        b.nome, b.descricao??'', b.valor??0, b.comissao??0,
        b.categoria??'geral', b.chargeType??b.charge_type??'pixRecorrente',
        b.periodicidade??null, b.diaCobranca??b.dia_cobranca??null,
        b.beneficios??null, b.imagem_url??null, b.ativo===false?0:1, id
      ).run();
      const product = await DB.prepare(`SELECT * FROM products WHERE id=?`).bind(id).first();
      return ok(product);
    }

    // PATCH /api/products/:id/toggle
    const toggleMatch = path.match(/^\/api\/products\/([^/]+)\/toggle$/);
    if (toggleMatch && method === 'PATCH') {
      const id = toggleMatch[1];
      await DB.prepare(
        `UPDATE products SET ativo = CASE WHEN ativo=1 THEN 0 ELSE 1 END WHERE id=?`
      ).bind(id).run();
      const product = await DB.prepare(`SELECT * FROM products WHERE id=?`).bind(id).first();
      return ok(product);
    }

    // DELETE /api/products/:id
    if (productMatch && method === 'DELETE') {
      const id = productMatch[1];
      await DB.prepare(`DELETE FROM products WHERE id=?`).bind(id).run();
      return ok({ deleted: id });
    }

    // ── /api/affiliates ────────────────────────────────────────────────────
    if (path === '/api/affiliates' && method === 'GET') {
      const { results } = await DB.prepare(
        `SELECT * FROM affiliates ORDER BY nome`
      ).all();
      return ok(results);
    }

    // GET /api/affiliates/by-code/:code
    const affByCode = path.match(/^\/api\/affiliates\/by-code\/([^/]+)$/);
    if (affByCode && method === 'GET') {
      const row = await DB.prepare(
        `SELECT * FROM affiliates WHERE affiliate_code=?`
      ).bind(affByCode[1]).first();
      if (!row) return err('Afiliado não encontrado', 404);
      return ok(row);
    }

    // GET /api/affiliates/by-email/:email
    const affByEmail = path.match(/^\/api\/affiliates\/by-email\/(.+)$/);
    if (affByEmail && method === 'GET') {
      const email = decodeURIComponent(affByEmail[1]);
      const row = await DB.prepare(
        `SELECT * FROM affiliates WHERE email=?`
      ).bind(email).first();
      if (!row) return err('Afiliado não encontrado', 404);
      return ok(row);
    }

    // GET /api/affiliates/:id
    const affMatch = path.match(/^\/api\/affiliates\/([^/]+)$/);
    if (affMatch && method === 'GET') {
      const row = await DB.prepare(
        `SELECT * FROM affiliates WHERE id=?`
      ).bind(affMatch[1]).first();
      if (!row) return err('Afiliado não encontrado', 404);
      return ok(row);
    }

    // POST /api/affiliates  — criar ou atualizar afiliado
    if (path === '/api/affiliates' && method === 'POST') {
      const b = await request.json();
      const id = b.id || 'aff_' + Date.now();
      await DB.prepare(
        `INSERT INTO affiliates
          (id,nome,email,cpf,telefone,affiliate_code,sponsor_code,pix_key,status)
         VALUES (?,?,?,?,?,?,?,?,?)
         ON CONFLICT(id) DO UPDATE SET
          nome=excluded.nome, email=excluded.email, cpf=excluded.cpf,
          telefone=excluded.telefone, pix_key=excluded.pix_key,
          status=excluded.status`
      ).bind(
        id, b.nome??'', b.email??'', b.cpf??'', b.telefone??'',
        b.affiliateCode??b.affiliate_code??'',
        b.sponsorCode??b.sponsor_code??null,
        b.pixKey??b.pix_key??null,
        b.status??'ativo'
      ).run();
      const aff = await DB.prepare(`SELECT * FROM affiliates WHERE id=?`).bind(id).first();
      return ok(aff);
    }

    // PATCH /api/affiliates/:id  — atualizar campos parcialmente (upsert se não existe)
    if (affMatch && method === 'PATCH') {
      const id = affMatch[1];
      const b = await request.json();

      // Verifica se afiliado já existe no D1
      const existing = await DB.prepare(`SELECT id FROM affiliates WHERE id=?`).bind(id).first();

      if (!existing) {
        // Afiliado não existe no D1 (criado via Firebase) → INSERT com campos disponíveis
        await DB.prepare(
          `INSERT INTO affiliates
            (id, nome, email, cpf, telefone, affiliate_code, sponsor_code, pix_key, status)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
           ON CONFLICT(id) DO UPDATE SET
            nome=excluded.nome, email=excluded.email, cpf=excluded.cpf,
            telefone=excluded.telefone, pix_key=excluded.pix_key`
        ).bind(
          id,
          b.nome ?? '',
          b.email ?? '',
          b.cpf ?? '',
          b.telefone ?? '',
          b.affiliateCode ?? b.affiliate_code ?? '',
          b.sponsorCode ?? b.sponsor_code ?? null,
          b.pixKey ?? b.pix_key ?? null,
          b.status ?? 'ativo'
        ).run();
      } else {
        // Afiliado existe → UPDATE parcial apenas nos campos enviados
        const fields = [];
        const vals   = [];
        const map = {
          nome:'nome', email:'email', cpf:'cpf', telefone:'telefone',
          pix_key:'pix_key', pixKey:'pix_key', status:'status',
          saldo_disponivel:'saldo_disponivel', saldo_pendente:'saldo_pendente',
          total_comissoes:'total_comissoes', total_sacado:'total_sacado',
          total_indicados:'total_indicados', total_assinaturas:'total_assinaturas'
        };
        for (const [k, col] of Object.entries(map)) {
          if (b[k] !== undefined) { fields.push(`${col}=?`); vals.push(b[k]); }
        }
        if (fields.length) {
          vals.push(id);
          await DB.prepare(`UPDATE affiliates SET ${fields.join(',')} WHERE id=?`)
            .bind(...vals).run();
        }
      }

      const aff = await DB.prepare(`SELECT * FROM affiliates WHERE id=?`).bind(id).first();
      return ok(aff);
    }

    // DELETE /api/affiliates/:id — excluir afiliado e dados relacionados
    if (affMatch && method === 'DELETE') {
      const id = affMatch[1];

      // Verifica se existe
      const existing = await DB.prepare(`SELECT id, affiliate_code FROM affiliates WHERE id=?`).bind(id).first();
      if (!existing) {
        return new Response(JSON.stringify({ success: false, error: 'Afiliado não encontrado' }), {
          status: 404, headers: { ...CORS, 'Content-Type': 'application/json' }
        });
      }

      // 1. Remove do Firebase Authentication PRIMEIRO (libera email para novo cadastro)
      const fbResult = await deleteFirebaseAuthUser(id);

      // 2. Remove wallet do D1
      await DB.prepare(`DELETE FROM wallets WHERE user_id=?`).bind(id).run().catch(() => null);

      // 3. Remove sales do D1
      await DB.prepare(`DELETE FROM sales WHERE user_id=? OR affiliate_code=?`)
        .bind(id, existing.affiliate_code).run().catch(() => null);

      // 4. Cancela assinaturas ativas (mantém histórico)
      await DB.prepare(
        `UPDATE subscriptions SET status='cancelada', motivo='Afiliado excluído' WHERE affiliate_code=? AND status='ativa'`
      ).bind(existing.affiliate_code).run().catch(() => null);

      // 5. Remove afiliado do D1 por último
      await DB.prepare(`DELETE FROM affiliates WHERE id=?`).bind(id).run();

      return ok({ deleted: true, id, firebaseAuth: fbResult });
    }

    // ── /api/wallet/:userId ────────────────────────────────────────────────
    const walletMatch = path.match(/^\/api\/wallet\/([^/]+)$/);
    if (walletMatch && method === 'GET') {
      const uid = walletMatch[1];
      let row = await DB.prepare(`SELECT * FROM wallets WHERE user_id=?`).bind(uid).first();
      if (!row) {
        // Tenta achar wallet pelo affiliate_code se o uid não tem carteira direta
        // Isso cobre o caso de afiliados criados antes do Firebase UID ser o id do D1
        const aff = await DB.prepare(
          `SELECT id, affiliate_code FROM affiliates WHERE id=?`
        ).bind(uid).first().catch(() => null);
        if (aff?.affiliate_code) {
          // Procura wallet pelo id do afiliado no D1 (pode ser código antigo)
          const affOld = await DB.prepare(
            `SELECT id FROM affiliates WHERE affiliate_code=? AND id!=?`
          ).bind(aff.affiliate_code, uid).first().catch(() => null);
          if (affOld?.id) {
            row = await DB.prepare(`SELECT * FROM wallets WHERE user_id=?`).bind(affOld.id).first();
          }
        }
        if (!row) {
          // Só cria carteira zerada se o afiliado ainda existe no D1
          const affExists = await DB.prepare(
            `SELECT id FROM affiliates WHERE id=?`
          ).bind(uid).first().catch(() => null);
          if (affExists) {
            await DB.prepare(
              `INSERT OR IGNORE INTO wallets (user_id) VALUES (?)`
            ).bind(uid).run();
            row = await DB.prepare(`SELECT * FROM wallets WHERE user_id=?`).bind(uid).first();
          }
        }
      }
      // Pega últimas transações — busca pelo uid direto e também pelo affiliate_code
      const affForSales = await DB.prepare(
        `SELECT affiliate_code FROM affiliates WHERE id=?`
      ).bind(uid).first().catch(() => null);
      const affCode = affForSales?.affiliate_code || '';

      let salesResults = [];
      if (affCode) {
        // Busca sales tanto por user_id quanto por affiliate_code (cobre ambos os casos)
        const { results: s1 } = await DB.prepare(
          `SELECT * FROM sales WHERE user_id=? ORDER BY created_at DESC LIMIT 50`
        ).bind(uid).all();
        const { results: s2 } = await DB.prepare(
          `SELECT * FROM sales WHERE affiliate_code=? AND user_id!=? ORDER BY created_at DESC LIMIT 50`
        ).bind(affCode, uid).all();
        // Merge e deduplica por id
        const seen = new Set();
        salesResults = [...s1, ...s2].filter(s => {
          if (seen.has(s.id)) return false;
          seen.add(s.id);
          return true;
        }).sort((a, b) => new Date(b.created_at) - new Date(a.created_at)).slice(0, 50);
      } else {
        const { results } = await DB.prepare(
          `SELECT * FROM sales WHERE user_id=? ORDER BY created_at DESC LIMIT 50`
        ).bind(uid).all();
        salesResults = results;
      }

      const { results: withdrawals } = await DB.prepare(
        `SELECT * FROM withdrawals WHERE user_id=? ORDER BY solicitado_em DESC LIMIT 20`
      ).bind(uid).all();
      return ok({ wallet: row, sales: salesResults, withdrawals });
    }

    if (walletMatch && method === 'PATCH') {
      const uid = walletMatch[1];
      const b = await request.json();
      await DB.prepare(
        `INSERT INTO wallets (user_id,saldo_disponivel,saldo_pendente,total_recebido,total_sacado,total_indicados)
         VALUES (?,?,?,?,?,?)
         ON CONFLICT(user_id) DO UPDATE SET
          saldo_disponivel=excluded.saldo_disponivel,
          saldo_pendente=excluded.saldo_pendente,
          total_recebido=excluded.total_recebido,
          total_sacado=excluded.total_sacado,
          total_indicados=excluded.total_indicados,
          updated_at=datetime('now')`
      ).bind(
        uid,
        b.saldo_disponivel??0, b.saldo_pendente??0,
        b.total_recebido??0, b.total_sacado??0, b.total_indicados??0
      ).run();
      const row = await DB.prepare(`SELECT * FROM wallets WHERE user_id=?`).bind(uid).first();
      return ok(row);
    }

    // ── /api/subscriptions ─────────────────────────────────────────────────
    if (path === '/api/subscriptions' && method === 'GET') {
      const { results } = await DB.prepare(
        `SELECT * FROM subscriptions ORDER BY data_inicio DESC`
      ).all();
      return ok(results);
    }

    // GET /api/subscriptions/by-affiliate/:code
    const subByAff = path.match(/^\/api\/subscriptions\/by-affiliate\/([^/]+)$/);
    if (subByAff && method === 'GET') {
      const { results } = await DB.prepare(
        `SELECT * FROM subscriptions WHERE affiliate_code=? ORDER BY data_inicio DESC`
      ).bind(subByAff[1]).all();
      return ok(results);
    }

    if (path === '/api/subscriptions' && method === 'POST') {
      const b = await request.json();
      const id = b.id || 'sub_' + Date.now();
      await DB.prepare(
        `INSERT INTO subscriptions
          (id,product_id,product_nome,valor,comissao,affiliate_code,affiliate_nome,
           charge_type,status,pix_key,dia_cobranca,data_inicio,proxima_cobranca,
           woovi_subscription_id)
         VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)
         ON CONFLICT(id) DO NOTHING`
      ).bind(
        id, b.productId??b.product_id??'',
        b.productNome??b.product_nome??'',
        b.valor??0, b.comissao??0,
        b.affiliateCode??b.affiliate_code??'',
        b.affiliateNome??b.affiliate_nome??null,
        b.chargeType??b.charge_type??'pixRecorrente',
        b.status??'ativa',
        b.pixKey??b.pix_key??null,
        b.diaCobranca??b.dia_cobranca??5,
        b.dataInicio??b.data_inicio??new Date().toISOString(),
        b.proximaCobranca??b.proxima_cobranca??null,
        b.wooviSubscriptionId??null
      ).run();
      // Atualizar total_assinaturas do afiliado
      if (b.affiliateCode || b.affiliate_code) {
        const code = b.affiliateCode??b.affiliate_code;
        await DB.prepare(
          `UPDATE affiliates SET total_assinaturas = total_assinaturas + 1 WHERE affiliate_code=?`
        ).bind(code).run();
      }
      const sub = await DB.prepare(`SELECT * FROM subscriptions WHERE id=?`).bind(id).first();
      return ok(sub);
    }

    // PATCH /api/subscriptions/:id
    const subMatch = path.match(/^\/api\/subscriptions\/([^/]+)$/);
    if (subMatch && method === 'PATCH') {
      const id = subMatch[1];
      const b = await request.json();
      const fields = [];
      const vals   = [];
      const map = {
        status:'status', motivo:'motivo',
        data_cancelamento:'data_cancelamento',
        proxima_cobranca:'proxima_cobranca'
      };
      for (const [k, col] of Object.entries(map)) {
        if (b[k] !== undefined) { fields.push(`${col}=?`); vals.push(b[k]); }
      }
      if (fields.length) {
        vals.push(id);
        await DB.prepare(`UPDATE subscriptions SET ${fields.join(',')} WHERE id=?`)
          .bind(...vals).run();
      }
      const sub = await DB.prepare(`SELECT * FROM subscriptions WHERE id=?`).bind(id).first();
      return ok(sub);
    }

    // ── /api/withdrawals ───────────────────────────────────────────────────
    if (path === '/api/withdrawals' && method === 'GET') {
      const { results } = await DB.prepare(
        `SELECT * FROM withdrawals ORDER BY solicitado_em DESC`
      ).all();
      return ok(results);
    }

    const wdByUser = path.match(/^\/api\/withdrawals\/by-user\/([^/]+)$/);
    if (wdByUser && method === 'GET') {
      const { results } = await DB.prepare(
        `SELECT * FROM withdrawals WHERE user_id=? ORDER BY solicitado_em DESC`
      ).bind(wdByUser[1]).all();
      return ok(results);
    }

    if (path === '/api/withdrawals' && method === 'POST') {
      const b = await request.json();
      const id = b.id || 'wd_' + Date.now();
      await DB.prepare(
        `INSERT INTO withdrawals (id,user_id,affiliate_nome,affiliate_code,valor,pix_key,status)
         VALUES (?,?,?,?,?,?,?)`
      ).bind(
        id, b.userId??b.user_id??'',
        b.affiliateNome??b.affiliate_nome??'',
        b.affiliateCode??b.affiliate_code??'',
        b.valor??0, b.pixKey??b.pix_key??'', 'pendente'
      ).run();
      // Deduz do saldo disponível
      await DB.prepare(
        `UPDATE wallets SET
          saldo_disponivel = saldo_disponivel - ?,
          saldo_pendente   = saldo_pendente   + ?,
          updated_at       = datetime('now')
         WHERE user_id=?`
      ).bind(b.valor??0, b.valor??0, b.userId??b.user_id??'').run();
      const wd = await DB.prepare(`SELECT * FROM withdrawals WHERE id=?`).bind(id).first();
      return ok(wd);
    }

    const wdMatch = path.match(/^\/api\/withdrawals\/([^/]+)$/);
    if (wdMatch && method === 'PATCH') {
      const id = wdMatch[1];
      const b = await request.json();
      const wd = await DB.prepare(`SELECT * FROM withdrawals WHERE id=?`).bind(id).first();
      if (!wd) return err('Saque não encontrado', 404);

      if (b.status === 'aprovado') {
        await DB.prepare(
          `UPDATE withdrawals SET status='aprovado', processado_em=datetime('now'), tx_id=? WHERE id=?`
        ).bind(b.tx_id??null, id).run();
        // Deduz do pendente e do total_sacado do afiliado
        await DB.prepare(
          `UPDATE wallets SET saldo_pendente=saldo_pendente-?, total_sacado=total_sacado+?, updated_at=datetime('now') WHERE user_id=?`
        ).bind(wd.valor, wd.valor, wd.user_id).run();
        await DB.prepare(
          `UPDATE affiliates SET total_sacado=total_sacado+? WHERE id=?`
        ).bind(wd.valor, wd.user_id).run();
      } else if (b.status === 'recusado') {
        await DB.prepare(
          `UPDATE withdrawals SET status='recusado', processado_em=datetime('now'), motivo=? WHERE id=?`
        ).bind(b.motivo??'', id).run();
        // Devolve ao saldo disponível
        await DB.prepare(
          `UPDATE wallets SET saldo_disponivel=saldo_disponivel+?, saldo_pendente=saldo_pendente-?, updated_at=datetime('now') WHERE user_id=?`
        ).bind(wd.valor, wd.valor, wd.user_id).run();
      }
      const updated = await DB.prepare(`SELECT * FROM withdrawals WHERE id=?`).bind(id).first();
      return ok(updated);
    }

    // ── /api/payment-status/:paymentId ─────────────────────────────────────
    // Consultado pelo Flutter via polling para saber se o PIX foi pago
    const payStatusMatch = path.match(/^\/api\/payment-status\/([^/]+)$/);
    if (payStatusMatch && method === 'GET') {
      const paymentId = payStatusMatch[1];
      const subId = `sub_pix_${paymentId}`;

      // Busca status da subscription no D1
      const sub = await DB.prepare(
        `SELECT id, status, valor, comissao, affiliate_code, product_nome, created_at
         FROM subscriptions WHERE id=?`
      ).bind(subId).first().catch(() => null);

      if (!sub) {
        return ok({ paymentId, status: 'not_found', subStatus: null });
      }

      // Mapeia status da sub para status do pagamento
      const statusMap = {
        'ativa':     'approved',
        'pendente':  'pending',
        'cancelada': 'cancelled',
        'expirada':  'cancelled',
      };
      const payStatus = statusMap[sub.status] ?? 'pending';

      return ok({
        paymentId,
        status:      payStatus,       // 'approved' | 'pending' | 'cancelled'
        subStatus:   sub.status,      // status real da sub no D1
        valor:       sub.valor,
        comissao:    sub.comissao,
        productNome: sub.product_nome,
        affiliateCode: sub.affiliate_code,
        processedAt: sub.created_at,
      });
    }

    // ── /api/sales ─────────────────────────────────────────────────────────
    const salesByUser = path.match(/^\/api\/sales\/by-user\/([^/]+)$/);
    if (salesByUser && method === 'GET') {
      const { results } = await DB.prepare(
        `SELECT * FROM sales WHERE user_id=? ORDER BY created_at DESC LIMIT 100`
      ).bind(salesByUser[1]).all();
      return ok(results);
    }

    if (path === '/api/sales' && method === 'POST') {
      const b = await request.json();
      const id = b.id || 'sale_' + Date.now();
      await DB.prepare(
        `INSERT INTO sales (id,user_id,product_id,product_nome,valor,comissao,affiliate_code,status)
         VALUES (?,?,?,?,?,?,?,?)`
      ).bind(
        id, b.userId??b.user_id??'',
        b.productId??b.product_id??'',
        b.productNome??b.product_nome??'',
        b.valor??0, b.comissao??0,
        b.affiliateCode??b.affiliate_code??'', 'aprovado'
      ).run();
      // Credita na carteira do afiliado
      const comissaoValor = (b.valor??0) * (b.comissao??0);
      if (comissaoValor > 0 && (b.userId??b.user_id)) {
        const uid = b.userId??b.user_id;
        await DB.prepare(
          `INSERT INTO wallets (user_id,saldo_disponivel,total_recebido)
           VALUES (?,?,?)
           ON CONFLICT(user_id) DO UPDATE SET
            saldo_disponivel=saldo_disponivel+?,
            total_recebido=total_recebido+?,
            updated_at=datetime('now')`
        ).bind(uid, comissaoValor, comissaoValor, comissaoValor, comissaoValor).run();
        await DB.prepare(
          `UPDATE affiliates SET
            total_comissoes=total_comissoes+?,
            saldo_disponivel=saldo_disponivel+?
           WHERE id=?`
        ).bind(comissaoValor, comissaoValor, uid).run();
      }
      const sale = await DB.prepare(`SELECT * FROM sales WHERE id=?`).bind(id).first();
      return ok(sale);
    }

    // ── /api/ranking ───────────────────────────────────────────────────────
    if (path === '/api/ranking' && method === 'GET') {
      const { results } = await DB.prepare(
        `SELECT id, nome, affiliate_code,
                total_assinaturas,
                total_assinaturas  AS assinaturas,
                total_comissoes,
                total_comissoes    AS comissao_total,
                total_indicados
         FROM affiliates
         WHERE status='ativo'
         ORDER BY total_comissoes DESC
         LIMIT 50`
      ).all();
      // Adicionar position e nivel calculado
      const ranked = results.map((r, i) => {
        const ass = r.total_assinaturas || 0;
        let nivel = 'Bronze';
        if (ass >= 50) nivel = 'Diamante';
        else if (ass >= 20) nivel = 'Ouro';
        else if (ass >= 5)  nivel = 'Prata';
        return { ...r, position: i + 1, nivel };
      });
      return ok(ranked);
    }

    // ── /api/metrics ───────────────────────────────────────────────────────
    if (path === '/api/metrics' && method === 'GET') {
      const [aff, subs, wds, sales, mrrData, comissoesMes, receitaMes] = await Promise.all([
        DB.prepare(`SELECT COUNT(*) as total, SUM(CASE WHEN status='ativo' THEN 1 ELSE 0 END) as ativos FROM affiliates`).first(),
        DB.prepare(`SELECT COUNT(*) as total, SUM(CASE WHEN status='ativa' THEN 1 ELSE 0 END) as ativas, SUM(CASE WHEN status='pendente' THEN 1 ELSE 0 END) as pendentes FROM subscriptions`).first(),
        DB.prepare(`SELECT COUNT(*) as total, SUM(CASE WHEN status='pendente' THEN 1 ELSE 0 END) as pendentes, SUM(CASE WHEN status='pendente' THEN valor ELSE 0 END) as valor_pendente FROM withdrawals`).first(),
        DB.prepare(`SELECT SUM(valor) as receita_total, SUM(comissao) as comissoes_total FROM sales WHERE status='aprovado'`).first(),
        // MRR = soma dos valores das assinaturas ativas (recorrentes)
        DB.prepare(`SELECT SUM(valor) as mrr FROM subscriptions WHERE status='ativa' AND (charge_type='pixRecorrente' OR charge_type IS NULL)`).first(),
        // Comissões do mês atual
        DB.prepare(`SELECT SUM(comissao) as comissoes_mes FROM sales WHERE status='aprovado' AND strftime('%Y-%m', created_at) = strftime('%Y-%m', 'now')`).first(),
        // Receita do mês atual
        DB.prepare(`SELECT SUM(valor) as receita_mes FROM sales WHERE status='aprovado' AND strftime('%Y-%m', created_at) = strftime('%Y-%m', 'now')`).first(),
      ]);
      return ok({
        totalAfiliados: aff?.total ?? 0,
        afiliadosAtivos: aff?.ativos ?? 0,
        totalAssinaturas: subs?.total ?? 0,
        assinaturasAtivas: subs?.ativas ?? 0,
        assinaturasPendentes: subs?.pendentes ?? 0,
        saquesPendentes: wds?.pendentes ?? 0,
        valorSaquesPendentes: wds?.valor_pendente ?? 0,
        receitaTotal: sales?.receita_total ?? 0,
        receitaMes: receitaMes?.receita_mes ?? 0,
        comissoesTotal: sales?.comissoes_total ?? 0,
        comissoesMes: comissoesMes?.comissoes_mes ?? 0,
        mrr: mrrData?.mrr ?? 0,
      });
    }

    // ── /api/webhook/mp/confirm/:paymentId ─── confirmação manual (admin) ──
    const mpConfirm = path.match(/^\/api\/webhook\/mp\/confirm\/([^/]+)$/);
    if (mpConfirm && method === 'POST') {
      const paymentId = mpConfirm[1];
      const b = await request.json().catch(() => ({}));
      const affiliateCode = b.affiliate_code || '';
      const valor         = b.valor || 0;
      const comissao      = b.comissao || (valor * 0.20);
      const produtoId     = b.product_id || '';
      const produtoNome   = b.product_nome || '';
      const subId         = b.sub_id || `sub_pix_${paymentId}`;

      // Upsert subscription como 'ativa'
      const proximaData = new Date();
      proximaData.setDate(proximaData.getDate() + 30);
      await DB.prepare(
        `INSERT INTO subscriptions
          (id, product_id, product_nome, valor, comissao, affiliate_code,
           charge_type, status, dia_cobranca, data_inicio, proxima_cobranca)
         VALUES (?,?,?,?,?,?,?,?,?,?,?)
         ON CONFLICT(id) DO UPDATE SET status='ativa'`
      ).bind(
        subId, produtoId, produtoNome, valor, comissao,
        affiliateCode, 'pixRecorrente', 'ativa', 5,
        new Date().toISOString(), proximaData.toISOString()
      ).run();

      // Creditar comissão e registrar venda
      if (affiliateCode && comissao > 0) {
        const aff = await DB.prepare(
          `SELECT id FROM affiliates WHERE affiliate_code=?`
        ).bind(affiliateCode).first().catch(() => null);
        if (aff?.id) {
          const affId = aff.id;
          const saleId = `sale_confirm_${paymentId}`;
          const existSale = await DB.prepare(
            `SELECT id FROM sales WHERE id=?`
          ).bind(saleId).first().catch(() => null);

          if (!existSale) {
            // Registrar na tabela sales (necessário para métricas e relatórios)
            await DB.prepare(
              `INSERT INTO sales
                (id, user_id, product_id, product_nome, valor, comissao,
                 affiliate_code, status, created_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, 'aprovado', datetime('now'))`
            ).bind(
              saleId, affId, produtoId, produtoNome, valor, comissao, affiliateCode
            ).run();

            await DB.prepare(
              `INSERT INTO wallets (user_id, saldo_disponivel, total_recebido)
               VALUES (?, ?, ?)
               ON CONFLICT(user_id) DO UPDATE SET
                 saldo_disponivel = saldo_disponivel + ?,
                 total_recebido   = total_recebido   + ?,
                 updated_at       = datetime('now')`
            ).bind(affId, comissao, comissao, comissao, comissao).run();
            await DB.prepare(
              `UPDATE affiliates SET
                 total_comissoes   = total_comissoes   + ?,
                 saldo_disponivel  = saldo_disponivel  + ?,
                 total_assinaturas = total_assinaturas + 1
               WHERE affiliate_code=?`
            ).bind(comissao, comissao, affiliateCode).run();
          }
        }
      }

      const sub = await DB.prepare(`SELECT * FROM subscriptions WHERE id=?`).bind(subId).first();
      return ok({ confirmed: true, sub });
    }

    // ── /api/health ────────────────────────────────────────────────────────
    if (path === '/api/health') {
      return ok({ status: 'ok', ts: new Date().toISOString() });
    }

    // ── /api/webhook/mp ────────────────────────────────────────────────────
    // Recebe notificações do MercadoPago (pagamento aprovado/pendente/etc.)
    // Docs: https://www.mercadopago.com.br/developers/pt/docs/your-integrations/notifications/webhooks
    if (path === '/api/webhook/mp' && (method === 'POST' || method === 'GET')) {
      try {
        // MercadoPago pode enviar GET (validação) ou POST (notificação real)
        if (method === 'GET') {
          return ok({ received: true });
        }

        const body = await request.json().catch(() => ({}));
        const url  = new URL(request.url);

        // Extrair payment_id de onde o MP puder enviar
        let paymentId = body?.data?.id
          || body?.id
          || url.searchParams.get('data.id')
          || url.searchParams.get('id');

        const topic = body?.type || body?.topic || url.searchParams.get('topic') || '';

        // Só processa eventos de payment
        if (!paymentId || (!topic.includes('payment') && topic !== '')) {
          return ok({ received: true, skipped: true, topic });
        }

        paymentId = String(paymentId);

        // Buscar config do MP (access_token) no D1 config
        const mpCfg = await DB.prepare(
          `SELECT value FROM config WHERE key='mp_config' LIMIT 1`
        ).first().catch(() => null);

        let accessToken = null;
        if (mpCfg?.value) {
          try {
            const cfg = JSON.parse(mpCfg.value);
            accessToken = cfg?.production?.access_token || cfg?.access_token || null;
          } catch (_) {}
        }

        // Fallback: token hardcoded de produção
        if (!accessToken) {
          accessToken = 'APP_USR-6134195606061357-042317-6774542c427c45a6f274a4e19d7019c3-3235638414';
        }

        // Consultar API do MercadoPago para obter status real do pagamento
        const mpResp = await fetch(
          `https://api.mercadopago.com/v1/payments/${paymentId}`,
          {
            headers: {
              'Authorization': `Bearer ${accessToken}`,
              'Content-Type':  'application/json',
            },
          }
        );

        if (!mpResp.ok) {
          return ok({ received: true, error: `MP API ${mpResp.status}`, paymentId });
        }

        const payment = await mpResp.json();
        const status  = payment.status;           // approved | pending | rejected | cancelled
        const extRef  = payment.external_reference || ''; // PIX_affiliateCode_produtoId_ts
        const valor   = payment.transaction_amount || 0;
        const metadata = payment.metadata || {};

        const affiliateCode = metadata.affiliate_code || extRef.split('_')[1] || '';
        const produtoId     = metadata.produto_id     || extRef.split('_')[2] || '';
        const comissao      = metadata.comissao       || (valor * 0.20);

        // ── Atualizar subscription no D1 ─────────────────────────────────
        const subId    = `sub_pix_${paymentId}`;
        const existSub = await DB.prepare(
          `SELECT id, status FROM subscriptions WHERE id=?`
        ).bind(subId).first().catch(() => null);

        if (status === 'approved') {
          // ── Pegar nome do produto via subscription ou descrição do pagamento ──
          const produtoNome = payment.description || produtoId || '';

          if (existSub) {
            // Atualizar status para 'ativa' (se ainda não estiver)
            if (existSub.status !== 'ativa') {
              await DB.prepare(
                `UPDATE subscriptions SET status='ativa' WHERE id=?`
              ).bind(subId).run();
            }
          } else {
            // Subscription não existe ainda → criar agora
            const proximaData = new Date();
            proximaData.setDate(proximaData.getDate() + 30);
            await DB.prepare(
              `INSERT INTO subscriptions
                (id, product_id, product_nome, valor, comissao, affiliate_code,
                 charge_type, status, dia_cobranca, data_inicio, proxima_cobranca)
               VALUES (?,?,?,?,?,?,?,?,?,?,?)
               ON CONFLICT(id) DO UPDATE SET status='ativa'`
            ).bind(
              subId, produtoId, produtoNome, valor, comissao,
              affiliateCode, 'pixRecorrente', 'ativa', 5,
              new Date().toISOString(), proximaData.toISOString()
            ).run();
          }

          // ── Creditar comissão na wallet do afiliado ────────────────────────
          if (affiliateCode && comissao > 0) {
            // Busca TODOS os registros com este affiliate_code (pode haver mais de um:
            // o id antigo do D1 e o Firebase UID inserido pelo app)
            const { results: affs } = await DB.prepare(
              `SELECT id FROM affiliates WHERE affiliate_code=?`
            ).bind(affiliateCode).all().catch(() => ({ results: [] }));

            const affId = affs[0]?.id || null;

            if (affId) {
              // Verificar se esta venda já foi registrada (idempotência)
              const saleId = `sale_mp_${paymentId}`;
              const existSale = await DB.prepare(
                `SELECT id FROM sales WHERE id=?`
              ).bind(saleId).first().catch(() => null);

              if (!existSale) {
                // ── INSERT na tabela sales ─────────────────────────────────
                // CRÍTICO: sem isso receitaTotal e comissoesTotal ficam 0 nos relatórios
                await DB.prepare(
                  `INSERT INTO sales
                    (id, user_id, product_id, product_nome, valor, comissao,
                     affiliate_code, status, created_at)
                   VALUES (?, ?, ?, ?, ?, ?, ?, 'aprovado', datetime('now'))`
                ).bind(
                  saleId, affId, produtoId, produtoNome,
                  valor, comissao, affiliateCode
                ).run();

                // ── Creditar na carteira de TODOS os IDs associados ─────────
                // Cobre o caso em que há id antigo (D1) e Firebase UID
                for (const a of affs) {
                  await DB.prepare(
                    `INSERT INTO wallets (user_id, saldo_disponivel, saldo_pendente, total_recebido)
                     VALUES (?, ?, 0, ?)
                     ON CONFLICT(user_id) DO UPDATE SET
                       saldo_disponivel = saldo_disponivel + ?,
                       total_recebido   = total_recebido   + ?,
                       updated_at       = datetime('now')`
                  ).bind(a.id, comissao, comissao, comissao, comissao).run();
                }

                // ── Atualizar totais no registro do afiliado ────────────────
                const assinaturasIncr = existSub ? 0 : 1;
                if (assinaturasIncr > 0) {
                  await DB.prepare(
                    `UPDATE affiliates SET
                       total_comissoes   = total_comissoes   + ?,
                       saldo_disponivel  = saldo_disponivel  + ?,
                       total_assinaturas = total_assinaturas + 1
                     WHERE affiliate_code=?`
                  ).bind(comissao, comissao, affiliateCode).run();
                } else {
                  await DB.prepare(
                    `UPDATE affiliates SET
                       total_comissoes  = total_comissoes  + ?,
                       saldo_disponivel = saldo_disponivel + ?
                     WHERE affiliate_code=?`
                  ).bind(comissao, comissao, affiliateCode).run();
                }
              }
              // Se existSale: pagamento já processado anteriormente → ignorar (idempotência)
            }
          }

        } else if (status === 'rejected' || status === 'cancelled') {
          if (existSub) {
            await DB.prepare(
              `UPDATE subscriptions SET status='cancelada', motivo=? WHERE id=?`
            ).bind(`Pagamento ${status}`, subId).run();
          }
        }
        // status === 'pending' → mantém como 'pendente', não faz nada

        return ok({ received: true, paymentId, status, affiliateCode, subId });

      } catch (e) {
        // Sempre retorna 200 para o MercadoPago não reenviar infinitamente
        return ok({ received: true, error: String(e) });
      }
    }

    return err('Rota não encontrada: ' + path, 404);
  },
};
