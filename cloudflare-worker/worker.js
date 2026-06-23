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
  'Access-Control-Allow-Origin':  '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Requested-With, X-Idempotency-Key, X-Device-Session-Id',
  'Access-Control-Max-Age':       '86400',
  'Vary':                         'Origin',
  // Evita que o Cloudflare edge reutilize streams H2 "stale" quando
  // o browser envia Origin diferente — causava TimeoutException no Flutter web
  'Cache-Control':                'no-store',
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
    // Preflight CORS — responder imediatamente para qualquer Origin
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS });
    }

    try {
      return await _handleRequest(request, env);
    } catch (e) {
      // Captura qualquer exceção não tratada e retorna JSON com CORS
      // (sem isso, o Worker pode não retornar nenhuma Response no H2,
      //  travando a stream indefinidamente no browser)
      console.error('[Worker] Unhandled exception:', e);
      return new Response(
        JSON.stringify({ success: false, error: 'Internal error: ' + String(e) }),
        { status: 500, headers: { ...CORS, 'Content-Type': 'application/json' } },
      );
    }
  },
};

// ── Envio de e-mail via Resend ──────────────────────────────────────────────
// Domínio verificado: send.sharewallet.com.br
// RESEND_API_KEY deve estar em: Cloudflare Dashboard > Workers > sharewallet-api > Settings > Variables
async function sendConfirmationEmail({ toEmail, toName, productName, productDescricao, valor, comissao, affiliateCode, paymentId, dataPagamento }, env) {
  const valorFmt     = `R$ ${Number(valor).toFixed(2).replace('.', ',')}`;
  const comissaoFmt  = `R$ ${Number(comissao).toFixed(2).replace('.', ',')}`;
  const dataFmt      = dataPagamento
    ? new Date(dataPagamento).toLocaleString('pt-BR', { timeZone: 'America/Sao_Paulo' })
    : new Date().toLocaleString('pt-BR', { timeZone: 'America/Sao_Paulo' });

  const html = `<!DOCTYPE html>
<html lang="pt-BR">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Pagamento Confirmado — ShareWallet</title>
<style>
  body{margin:0;padding:0;background:#f4f6f9;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;}
  .wrap{max-width:560px;margin:32px auto;background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,.10);}
  .header{background:linear-gradient(135deg,#1B5E20,#2E7D32);padding:32px 28px;text-align:center;}
  .header h1{color:#fff;margin:0;font-size:22px;font-weight:800;}
  .header p{color:rgba(255,255,255,.85);margin:6px 0 0;font-size:13px;}
  .check{width:64px;height:64px;background:rgba(255,255,255,.2);border-radius:50%;display:inline-flex;align-items:center;justify-content:center;margin-bottom:12px;}
  .body{padding:28px;}
  .greeting{font-size:16px;color:#1a1a2e;margin-bottom:20px;}
  .card{background:#f8fffe;border:1.5px solid #c8e6c9;border-radius:12px;padding:20px;margin-bottom:18px;}
  .card-title{font-size:11px;font-weight:700;color:#2E7D32;text-transform:uppercase;letter-spacing:.8px;margin-bottom:12px;}
  .row{display:flex;justify-content:space-between;align-items:center;padding:8px 0;border-bottom:1px solid #e8f5e9;}
  .row:last-child{border-bottom:none;}
  .label{font-size:13px;color:#666;}
  .value{font-size:13px;font-weight:600;color:#1a1a2e;}
  .value.green{color:#1B5E20;}
  .commission-box{background:linear-gradient(135deg,#1B5E20,#2E7D32);border-radius:12px;padding:20px;text-align:center;margin-bottom:18px;}
  .commission-box p{color:rgba(255,255,255,.85);margin:0 0 4px;font-size:13px;}
  .commission-box .amount{color:#fff;font-size:34px;font-weight:900;margin:4px 0;}
  .commission-box .sub{color:rgba(255,255,255,.7);font-size:11px;}
  .code-box{background:#f0f4ff;border:1.5px dashed #7986cb;border-radius:10px;padding:14px;text-align:center;margin-bottom:18px;}
  .code-box p{margin:0;font-size:12px;color:#555;}
  .code-box .code{font-size:22px;font-weight:800;letter-spacing:3px;color:#3f51b5;margin:6px 0 0;}
  .footer{background:#f8f9fa;padding:20px 28px;text-align:center;border-top:1px solid #eee;}
  .footer p{font-size:11px;color:#999;margin:4px 0;}
  .footer a{color:#2E7D32;text-decoration:none;font-weight:600;}
  .badge{display:inline-block;background:#e8f5e9;color:#1B5E20;font-size:10px;font-weight:700;border-radius:20px;padding:3px 10px;text-transform:uppercase;letter-spacing:.5px;}
</style>
</head>
<body>
<div class="wrap">
  <div class="header">
    <div class="check">✓</div>
    <h1>Pagamento Confirmado!</h1>
    <p>Sua assinatura foi ativada com sucesso</p>
  </div>
  <div class="body">
    <p class="greeting">Olá, <strong>${toName}</strong>! 🎉</p>
    <p style="font-size:14px;color:#555;margin-top:-8px;">Seu pagamento foi processado e sua assinatura já está ativa.</p>

    <div class="card">
      <div class="card-title">📦 Produto Contratado</div>
      <div class="row"><span class="label">Produto</span><span class="value">${productName}</span></div>
      <div class="row"><span class="label">Descrição</span><span class="value" style="max-width:260px;text-align:right;font-size:12px;">${productDescricao || 'Assinatura mensal'}</span></div>
      <div class="row"><span class="label">Valor mensal</span><span class="value green">${valorFmt}/mês</span></div>
      <div class="row"><span class="label">Modalidade</span><span class="value">Pix Recorrente</span></div>
      <div class="row"><span class="label">Status</span><span class="value green">✅ Ativo</span></div>
    </div>

    <div class="card">
      <div class="card-title">🧾 Detalhes do Pagamento</div>
      <div class="row"><span class="label">Nº do Pagamento</span><span class="value" style="font-size:11px;color:#888;">${paymentId}</span></div>
      <div class="row"><span class="label">Data/hora</span><span class="value">${dataFmt}</span></div>
      <div class="row"><span class="label">Valor pago</span><span class="value green">${valorFmt}</span></div>
      <div class="row"><span class="label">Próxima cobrança</span><span class="value">em 30 dias (automática)</span></div>
    </div>

    <div class="commission-box">
      <p>💰 Sua comissão creditada</p>
      <div class="amount">${comissaoFmt}</div>
      <div class="sub">adicionado à sua carteira ShareWallet</div>
    </div>

    <div class="code-box">
      <p>🔑 Seu código de afiliado</p>
      <div class="code">${affiliateCode}</div>
      <p style="margin-top:6px;font-size:11px;color:#888;">Compartilhe e ganhe comissão por cada nova assinatura!</p>
    </div>

    <div style="text-align:center;margin-top:8px;">
      <span class="badge">Renovação automática todo mês via Pix</span>
    </div>
  </div>
  <div class="footer">
    <p><strong>ShareWallet</strong> — Plataforma de Afiliados</p>
    <p>Dúvidas? <a href="mailto:suporte@sharewallet.com.br">suporte@sharewallet.com.br</a></p>
    <p style="margin-top:8px;font-size:10px;color:#bbb;">Este é um e-mail automático, não responda diretamente.</p>
  </div>
</div>
</body>
</html>`;

  const payload = {
    personalizations: [{
      to: [{ email: toEmail, name: toName }],
    }],
    from: { email: 'noreply@sharewallet.com.br', name: 'ShareWallet' },
    reply_to: { email: 'suporte@sharewallet.com.br', name: 'Suporte ShareWallet' },
    subject: `✅ Pagamento confirmado — ${productName}`,
    content: [{ type: 'text/html', value: html }],
  };

  // Usa Resend como provedor principal (domínio send.sharewallet.com.br verificado)
  // RESEND_API_KEY deve estar em: Cloudflare Dashboard > Workers > sharewallet-api > Settings > Variables
  try {
    const resendKey = env?.RESEND_API_KEY ?? null;
    if (!resendKey) return { sent: false, error: 'RESEND_API_KEY não configurada' };
    const resendPayload = {
      from:    'ShareWallet <noreply@sharewallet.com.br>',
      to:      [toEmail],
      subject: `✅ Pagamento confirmado — ${productName}`,
      html:    payload.content[0].value,
    };
    const resendResp = await fetch('https://api.resend.com/emails', {
      method:  'POST',
      headers: {
        'Content-Type':  'application/json',
        'Authorization': `Bearer ${resendKey}`,
      },
      body: JSON.stringify(resendPayload),
    });
    if (resendResp.ok) return { sent: true };
    const errBody = await resendResp.text().catch(() => resendResp.status);
    return { sent: false, error: `Resend HTTP ${resendResp.status}: ${errBody}` };
  } catch (e) {
    return { sent: false, error: `Resend exception: ${e.message}` };
  }

  return { sent: false, error: 'nenhum provedor disponível' };
}

async function _handleRequest(request, env) {
    const url  = new URL(request.url);
    const path = url.pathname.replace(/\/$/, ''); // remove trailing slash
    const method = request.method;
    const DB = env.DB;

    // ── Auto-migration: garante coluna saque_minimo na tabela affiliates ─────
    // SQLite ignora silenciosamente se a coluna já existir graças ao try/catch.
    try {
      await DB.prepare(
        `ALTER TABLE affiliates ADD COLUMN saque_minimo REAL NOT NULL DEFAULT 0`
      ).run();
    } catch (_) { /* coluna já existe — ignorar */ }

    // ── Auto-migration: campos extras na tabela sales ─────────────────────────
    // cliente_nome, cliente_email, payment_id — necessários para relatório de vendas
    await Promise.allSettled([
      DB.prepare(`ALTER TABLE sales ADD COLUMN cliente_nome TEXT DEFAULT ''`).run(),
      DB.prepare(`ALTER TABLE sales ADD COLUMN cliente_email TEXT DEFAULT ''`).run(),
      DB.prepare(`ALTER TABLE sales ADD COLUMN payment_id TEXT DEFAULT ''`).run(),
      DB.prepare(`ALTER TABLE sales ADD COLUMN charge_type TEXT DEFAULT 'pixAvulso'`).run(),
    ]);

    // ── Auto-migration: dados do cliente na tabela subscriptions ─────────────
    // cliente_email, cliente_nome, cliente_cpf — usados para notificações futuras
    await Promise.allSettled([
      DB.prepare(`ALTER TABLE subscriptions ADD COLUMN cliente_email TEXT DEFAULT ''`).run(),
      DB.prepare(`ALTER TABLE subscriptions ADD COLUMN cliente_nome  TEXT DEFAULT ''`).run(),
      DB.prepare(`ALTER TABLE subscriptions ADD COLUMN cliente_cpf   TEXT DEFAULT ''`).run(),
    ]);

    // ── Auto-migration: recriar mp_plans sem coluna init_point (nova estrutura) ─
    // A versão anterior tinha init_point; agora o init_point vem do preapproval
    // individual (passo 2), não do plano. Dropamos e recriamos para garantir.
    await DB.prepare(`CREATE TABLE IF NOT EXISTS mp_plans (
      produto_id TEXT PRIMARY KEY,
      plan_id    TEXT NOT NULL,
      valor      REAL NOT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )`).run().catch(() => {});
    // Remove planos antigos que tinham init_point (criados sem Pix bank_transfer+pix)
    // Na próxima assinatura um novo plano correto será criado automaticamente
    await DB.prepare(`DELETE FROM mp_plans WHERE plan_id IN (
      SELECT plan_id FROM mp_plans WHERE created_at < '2026-06-24'
    )`).run().catch(() => {});

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
          affiliate_code=CASE WHEN excluded.affiliate_code != '' THEN excluded.affiliate_code ELSE affiliates.affiliate_code END,
          sponsor_code=COALESCE(excluded.sponsor_code, affiliates.sponsor_code),
          saque_minimo=CASE WHEN excluded.saque_minimo IS NOT NULL THEN excluded.saque_minimo ELSE COALESCE(affiliates.saque_minimo,0) END,
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
            telefone=excluded.telefone, pix_key=excluded.pix_key,
            affiliate_code=CASE WHEN excluded.affiliate_code != '' THEN excluded.affiliate_code ELSE affiliates.affiliate_code END,
            sponsor_code=COALESCE(excluded.sponsor_code, affiliates.sponsor_code)`
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
          affiliate_code:'affiliate_code', affiliateCode:'affiliate_code',
          sponsor_code:'sponsor_code', sponsorCode:'sponsor_code',
          saldo_disponivel:'saldo_disponivel', saldo_pendente:'saldo_pendente',
          total_comissoes:'total_comissoes', total_sacado:'total_sacado',
          total_indicados:'total_indicados', total_assinaturas:'total_assinaturas',
          saque_minimo:'saque_minimo', saqueMinimo:'saque_minimo'
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
      const userId = b.userId ?? b.user_id ?? '';

      // -- Validação de saque mínimo por afiliado ---------------------------
      const affRow = await DB.prepare(
        `SELECT saque_minimo FROM affiliates WHERE id=? LIMIT 1`
      ).bind(userId).first();
      const saqueMinimo = affRow?.saque_minimo ?? 0;
      if (saqueMinimo > 0 && (b.valor ?? 0) < saqueMinimo) {
        return new Response(JSON.stringify({
          success: false,
          error: `Valor mínimo para saque é R$ ${saqueMinimo.toFixed(2).replace('.',',')}`,
          saque_minimo: saqueMinimo
        }), { status: 422, headers: { ...CORS, 'Content-Type': 'application/json' } });
      }

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

    // ── POST /api/withdrawals/:id/pay — executa PIX via MercadoPago ──────────
    // Chamado pelo Flutter após criar o saque com status 'pendente'.
    // Recebe o accessToken MP no header X-MP-Token (protegido — não expõe no client).
    // Fluxo: busca saque no D1 → chama MP Money Transfer API → atualiza status.
    const wdPayMatch = path.match(/^\/api\/withdrawals\/([^/]+)\/pay$/);
    if (wdPayMatch && method === 'POST') {
      const wdId = wdPayMatch[1];

      // 1. Busca saque no D1
      const wd = await DB.prepare(`SELECT * FROM withdrawals WHERE id=?`).bind(wdId).first();
      if (!wd) return err('Saque não encontrado', 404);
      if (wd.status !== 'pendente') {
        return err(`Saque já processado (status: ${wd.status})`, 400);
      }

      // 2. Pega token MP — prioridade: header > D1 config > env.MP_ACCESS_TOKEN
      let mpToken = request.headers.get('X-MP-Token') || null;
      if (!mpToken) {
        const mpCfg = await DB.prepare(`SELECT value FROM config WHERE key='mercadopago'`).first().catch(() => null);
        if (mpCfg?.value) {
          try {
            const cfg = JSON.parse(mpCfg.value);
            mpToken = cfg?.production?.access_token || cfg?.access_token || null;
          } catch (_) {}
        }
      }
      if (!mpToken && env?.MP_ACCESS_TOKEN) {
        // Fallback: variável de ambiente configurada no Cloudflare Dashboard
        mpToken = env.MP_ACCESS_TOKEN;
      }
      if (!mpToken) {
        return err('Token MP não configurado. Configure nas credenciais do painel admin.', 500);
      }

      // 3. Lê body com metadados opcionais (pixKeyType, affiliateNome)
      let body = {};
      try { body = await request.json(); } catch (_) {}
      const pixKeyType  = body.pixKeyType  || wd.pix_key_type || 'email';
      const affiliateNome = body.affiliateNome || wd.affiliate_nome || '';
      const pixKey      = wd.pix_key;
      const valor       = wd.valor;

      // Mapeia tipo de chave PIX para formato MP
      const mpKeyTypeMap = { cpf: 'cpf', email: 'email', phone: 'phone', random_key: 'random_key' };
      const mpKeyType = mpKeyTypeMap[pixKeyType.toLowerCase()] || 'email';

      // 4. Chama MercadoPago Money Transfer API (PIX Out)
      // Endpoint: POST https://api.mercadopago.com/v1/account/bank_transfers
      // Docs: https://www.mercadopago.com.br/developers/pt/reference/mp_transfer/_v1_account_bank_transfers/post
      try {
        const mpBody = {
          amount: valor,
          origin_amount: valor,
          description: `Comissão ShareWallet — ${affiliateNome || wdId}`,
          external_reference: wdId,
          origin: { type: 'mercadopago' },
          destination: {
            type: 'pix',
            key: { key: pixKey, type: mpKeyType },
          },
        };

        const mpResp = await fetch('https://api.mercadopago.com/v1/account/bank_transfers', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${mpToken}`,
            'Content-Type': 'application/json',
            'X-Idempotency-Key': wdId,
          },
          body: JSON.stringify(mpBody),
        });

        const mpData = await mpResp.json();
        console.log('[Worker /pay] MP response:', JSON.stringify(mpData));

        // Verifica aprovação: status 200-201 + status_detail 'accredited' ou status 'approved'
        const mpStatus = mpData.status || mpData.transaction_status || '';
        const mpTxId   = String(mpData.id || mpData.transaction_id || wdId);
        const mpOk     = mpResp.status >= 200 && mpResp.status < 300 &&
                         (mpStatus === 'approved' || mpStatus === 'accredited' ||
                          mpStatus === 'pending'  || mpData.id != null);

        if (mpOk) {
          // 5a. Sucesso ou pendente no MP — registra tx_id e atualiza status
          const newStatus = (mpStatus === 'approved' || mpStatus === 'accredited') ? 'aprovado' : 'processando';
          await DB.prepare(
            `UPDATE withdrawals SET status=?, processado_em=datetime('now'), tx_id=? WHERE id=?`
          ).bind(newStatus, mpTxId, wdId).run();

          // Atualiza carteira: remove de pendente, soma em total_sacado
          await DB.prepare(
            `UPDATE wallets SET saldo_pendente=MAX(0,saldo_pendente-?), total_sacado=total_sacado+?, updated_at=datetime('now') WHERE user_id=?`
          ).bind(valor, valor, wd.user_id).run();
          await DB.prepare(
            `UPDATE affiliates SET total_sacado=total_sacado+? WHERE id=?`
          ).bind(valor, wd.user_id).run();

          const wdUpdated = await DB.prepare(`SELECT * FROM withdrawals WHERE id=?`).bind(wdId).first();
          return ok({ id: mpTxId, status: newStatus, withdrawal: wdUpdated });

        } else {
          // 5b. MP recusou — devolve saldo ao disponível e marca como recusado
          await DB.prepare(
            `UPDATE withdrawals SET status='recusado', processado_em=datetime('now'), motivo=? WHERE id=?`
          ).bind(`MP: ${mpData.message || mpData.error || JSON.stringify(mpData).slice(0,200)}`, wdId).run();
          await DB.prepare(
            `UPDATE wallets SET saldo_disponivel=saldo_disponivel+?, saldo_pendente=MAX(0,saldo_pendente-?), updated_at=datetime('now') WHERE user_id=?`
          ).bind(valor, valor, wd.user_id).run();
          return err(`MercadoPago recusou: ${mpData.message || mpData.error || mpStatus}`, 422);
        }

      } catch (mpErr) {
        console.error('[Worker /pay] Erro MP:', String(mpErr));
        // Erro de rede/timeout — mantém pendente para retry pelo admin
        return err(`Erro ao conectar com MercadoPago: ${String(mpErr)}`, 502);
      }
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
    // Consultado pelo Flutter via polling para saber se o PIX foi pago.
    // Estratégia dupla:
    //   1º) Consulta o D1 (sub já processada pelo webhook → resposta instantânea)
    //   2º) Se não encontrar ou ainda pendente → consulta a API do MP diretamente
    //       (garante que pagamentos aprovados sejam detectados mesmo se o webhook atrasar)
    const payStatusMatch = path.match(/^\/api\/payment-status\/([^/]+)$/);
    if (payStatusMatch && method === 'GET') {
      const paymentId = payStatusMatch[1];
      // Buscar tanto sub_pix_ (pix único/avulso) quanto sub_rec_ (preapproval recorrente)
      const subIdPix = `sub_pix_${paymentId}`;
      const subIdRec = `sub_rec_${paymentId}`;

      const statusMap = {
        'ativa':     'approved',
        'pendente':  'pending',
        'cancelada': 'cancelled',
        'expirada':  'cancelled',
      };

      // ── 1ª tentativa: D1 (rápido, sem chamada externa) ──────────────────
      // Verifica os dois IDs possíveis de subscription
      const sub = await DB.prepare(
        `SELECT id, status, valor, comissao, affiliate_code, product_nome, created_at
         FROM subscriptions WHERE id=? OR id=? LIMIT 1`
      ).bind(subIdPix, subIdRec).first().catch(() => null);

      // Sub encontrada E já aprovada → retorna imediatamente
      if (sub && sub.status === 'ativa') {
        return ok({
          paymentId,
          status:       'approved',
          subStatus:    sub.status,
          valor:        sub.valor,
          comissao:     sub.comissao,
          productNome:  sub.product_nome,
          affiliateCode: sub.affiliate_code,
          processedAt:  sub.created_at,
          source:       'd1',
        });
      }

      // ── 2ª tentativa: API do MercadoPago diretamente ─────────────────────
      // Necessário quando: (a) webhook ainda não chegou, (b) webhook falhou
      try {
        // Obtém access_token do D1 config (configurado pelo admin)
        let mpAccessToken = null;
        const mpCfgRow = await DB.prepare(
          `SELECT value FROM config WHERE key='mp_config' LIMIT 1`
        ).first().catch(() => null);
        if (mpCfgRow?.value) {
          try {
            const cfg = JSON.parse(mpCfgRow.value);
            mpAccessToken = cfg?.production?.access_token || cfg?.sandbox?.access_token || null;
          } catch (_) {}
        }
        // Fallback: variável de ambiente (nunca exposta no código)
        if (!mpAccessToken && env?.MP_ACCESS_TOKEN) {
          mpAccessToken = env.MP_ACCESS_TOKEN;
        }

        if (mpAccessToken) {
          const mpResp = await fetch(
            `https://api.mercadopago.com/v1/payments/${paymentId}`,
            { headers: { 'Authorization': `Bearer ${mpAccessToken}` } }
          ).catch(() => null);

          if (mpResp?.ok) {
            const payment = await mpResp.json().catch(() => null);
            const mpStatus = payment?.status ?? 'pending'; // approved | pending | rejected | cancelled
            const extRef   = payment?.external_reference || '';
            const valor    = payment?.transaction_amount || 0;
            const metadata = payment?.metadata || {};

            const affiliateCode = metadata.affiliate_code || extRef.split('_')[1] || '';
            const produtoId     = metadata.produto_id     || extRef.split('_')[2] || '';
            const comissao      = metadata.comissao       || (valor * 0.20);

            // Se aprovado pelo MP mas webhook ainda não criou a sub → cria agora
            if (mpStatus === 'approved') {
              const existSub2 = await DB.prepare(
                `SELECT id FROM subscriptions WHERE id=?`
              ).bind(subId).first().catch(() => null);

              if (!existSub2) {
                const produtoNome = payment.description || produtoId || '';
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
                ).run().catch(() => {});
              } else {
                await DB.prepare(
                  `UPDATE subscriptions SET status='ativa' WHERE id=? AND status != 'ativa'`
                ).bind(subId).run().catch(() => {});
              }

              // Credita comissão se ainda não creditada
              if (affiliateCode && comissao > 0) {
                const saleId = `sale_mp_${paymentId}`;
                const existSale = await DB.prepare(
                  `SELECT id FROM sales WHERE id=?`
                ).bind(saleId).first().catch(() => null);
                if (!existSale) {
                  const { results: affs } = await DB.prepare(
                    `SELECT id FROM affiliates WHERE affiliate_code=?`
                  ).bind(affiliateCode).all().catch(() => ({ results: [] }));
                  const affId = affs[0]?.id || null;
                  if (affId) {
                    const produtoNome2 = payment.description || produtoId || '';
                    const p2Nome  = [payment.payer?.first_name, payment.payer?.last_name].filter(Boolean).join(' ') || '';
                    const p2Email = payment.payer?.email || '';
                    await DB.prepare(
                      `INSERT INTO sales (id, user_id, product_id, product_nome, valor, comissao, affiliate_code, status, created_at, cliente_nome, cliente_email, payment_id, charge_type)
                       VALUES (?,?,?,?,?,?,?,'aprovado',datetime('now'),?,?,?,'pixRecorrente')`
                    ).bind(saleId, affId, produtoId, produtoNome2, valor, comissao, affiliateCode, p2Nome, p2Email, String(paymentId)).run().catch(() => {});
                    for (const a of affs) {
                      await DB.prepare(
                        `INSERT INTO wallets (user_id, saldo_disponivel, saldo_pendente, total_recebido)
                         VALUES (?,?,0,?)
                         ON CONFLICT(user_id) DO UPDATE SET
                           saldo_disponivel=saldo_disponivel+?,
                           total_recebido=total_recebido+?,
                           updated_at=datetime('now')`
                      ).bind(a.id, comissao, comissao, comissao, comissao).run().catch(() => {});
                    }
                    await DB.prepare(
                      `UPDATE affiliates SET total_comissoes=total_comissoes+?, saldo_disponivel=saldo_disponivel+?, total_assinaturas=total_assinaturas+1 WHERE affiliate_code=?`
                    ).bind(comissao, comissao, affiliateCode).run().catch(() => {});
                  }
                }
              }
            }

            // Mapeia status MP → status polling
            const payStatusFromMp = mpStatus === 'approved' ? 'approved'
              : (mpStatus === 'rejected' || mpStatus === 'cancelled') ? 'cancelled'
              : 'pending';

            return ok({
              paymentId,
              status:       payStatusFromMp,
              subStatus:    sub?.status ?? null,
              valor,
              comissao,
              productNome:  payment.description || '',
              affiliateCode,
              processedAt:  payment.date_approved || null,
              source:       'mp_api',
            });
          }
        }
      } catch (_) {
        // Falha silenciosa — retorna status baseado no D1 se disponível
      }

      // ── Fallback final: retorna o que tiver no D1 (ou not_found) ─────────
      if (sub) {
        const payStatus = statusMap[sub.status] ?? 'pending';
        return ok({
          paymentId,
          status:       payStatus,
          subStatus:    sub.status,
          valor:        sub.valor,
          comissao:     sub.comissao,
          productNome:  sub.product_nome,
          affiliateCode: sub.affiliate_code,
          processedAt:  sub.created_at,
          source:       'd1_fallback',
        });
      }

      return ok({ paymentId, status: 'not_found', subStatus: null, source: 'none' });
    }

    // ── /api/sales ─────────────────────────────────────────────────────────
    const salesByUser = path.match(/^\/api\/sales\/by-user\/([^/]+)$/);
    if (salesByUser && method === 'GET') {
      const { results } = await DB.prepare(
        `SELECT * FROM sales WHERE user_id=? ORDER BY created_at DESC LIMIT 100`
      ).bind(salesByUser[1]).all();
      return ok(results);
    }

    // ── GET /api/sales — todas as vendas (admin) ────────────────────────────
    // Suporta query params: ?status=aprovado&product_id=p_xxx&affiliate_code=ABC
    //                        &date_from=2024-01-01&date_to=2024-12-31&limit=500
    if (path === '/api/sales' && method === 'GET') {
      const qStatus       = url.searchParams.get('status');
      const qProduct      = url.searchParams.get('product_id');
      const qAffiliate    = url.searchParams.get('affiliate_code');
      const qDateFrom     = url.searchParams.get('date_from');
      const qDateTo       = url.searchParams.get('date_to');
      const qChargeType   = url.searchParams.get('charge_type');
      const qLimit        = parseInt(url.searchParams.get('limit') || '1000');

      // Constrói query dinâmica com JOIN p/ buscar nome do afiliado
      const conditions = [];
      const binds      = [];

      if (qStatus)     { conditions.push(`s.status = ?`);                     binds.push(qStatus); }
      if (qProduct)    { conditions.push(`s.product_id = ?`);                  binds.push(qProduct); }
      if (qAffiliate)  { conditions.push(`s.affiliate_code = ?`);              binds.push(qAffiliate); }
      if (qDateFrom)   { conditions.push(`date(s.created_at) >= date(?)`);     binds.push(qDateFrom); }
      if (qDateTo)     { conditions.push(`date(s.created_at) <= date(?)`);     binds.push(qDateTo); }
      if (qChargeType) { conditions.push(`s.charge_type = ?`);                 binds.push(qChargeType); }

      const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
      const sql = `
        SELECT
          s.*,
          a.nome  AS affiliate_nome_join,
          a.email AS affiliate_email_join
        FROM sales s
        LEFT JOIN affiliates a ON a.affiliate_code = s.affiliate_code
        ${where}
        ORDER BY s.created_at DESC
        LIMIT ?`;
      binds.push(qLimit);

      const { results } = await DB.prepare(sql).bind(...binds).all();
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
                 affiliate_code, status, created_at,
                 cliente_nome, cliente_email, payment_id, charge_type)
               VALUES (?, ?, ?, ?, ?, ?, ?, 'aprovado', datetime('now'), ?, ?, ?, ?)`
            ).bind(
              saleId, affId, produtoId, produtoNome, valor, comissao, affiliateCode,
              '', '', String(paymentId), 'pixRecorrente'
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

      // ── Enviar e-mail de confirmação após confirmação manual ─────────────
      if (affiliateCode) {
        const affRow = await DB.prepare(
          `SELECT nome, email FROM affiliates WHERE affiliate_code=? LIMIT 1`
        ).bind(affiliateCode).first().catch(() => null);
        if (affRow?.email) {
          const prodDescRow = await DB.prepare(
            `SELECT descricao FROM products WHERE id=? LIMIT 1`
          ).bind(produtoId).first().catch(() => null);
          sendConfirmationEmail({
            toEmail:          affRow.email,
            toName:           affRow.nome || 'Cliente',
            productName:      produtoNome,
            productDescricao: prodDescRow?.descricao || '',
            valor,
            comissao,
            affiliateCode,
            paymentId,
            dataPagamento:    new Date().toISOString(),
          }, env).catch(() => {});
        }
      }

      return ok({ confirmed: true, sub, emailSent: !!affiliateCode });
    }

    // ── /api/health ────────────────────────────────────────────────────────
    if (path === '/api/health') {
      return ok({ status: 'ok', ts: new Date().toISOString() });
    }

    // ── POST /api/send-email ── envia e-mail de confirmação de pagamento ──
    if (path === '/api/send-email' && method === 'POST') {
      try {
        const b = await request.json();
        const ok2 = await sendConfirmationEmail({
          toEmail:          b.toEmail || b.email || '',
          toName:           b.toName  || b.nome  || 'Cliente',
          productName:      b.productName  || b.product_nome || '',
          productDescricao: b.productDescricao || b.descricao || '',
          valor:            b.valor    || 0,
          comissao:         b.comissao || 0,
          affiliateCode:    b.affiliateCode || b.affiliate_code || '',
          paymentId:        b.paymentId || b.payment_id || '',
          dataPagamento:    b.dataPagamento || b.created_at || null,
        }, env);
        return ok(ok2); // { sent: true/false, error?: string }
      } catch (e) {
        return ok({ sent: false, error: String(e) });
      }
    }

    // ── GET /api/mp/account-info ────────────────────────────────────────────
    // Proxy server-side para api.mercadopago.com/users/me
    // O browser não pode chamar a API do MP diretamente por CORS.
    // O Worker faz a chamada server-side usando o MP_ACCESS_TOKEN secret
    // e repassa apenas os campos relevantes de volta para o Flutter.
    if (path === '/api/mp/account-info' && method === 'GET') {
      try {
        const mpToken = env.MP_ACCESS_TOKEN;
        if (!mpToken) {
          return err('MP_ACCESS_TOKEN não configurado no Worker', 500);
        }
        const mpResp = await fetch('https://api.mercadopago.com/users/me', {
          headers: {
            'Authorization': `Bearer ${mpToken}`,
            'Content-Type': 'application/json',
          },
        });
        if (!mpResp.ok) {
          const body = await mpResp.text();
          return err(`Erro MP ${mpResp.status}: ${body}`, mpResp.status);
        }
        const data = await mpResp.json();
        const statusDetail = data.status || {};
        return ok({
          ok: true,
          email:              data.email        || '',
          user_id:            String(data.id    || ''),
          site_id:            data.site_id      || '',
          account_status:     statusDetail.site_status || 'unknown',
          sell_permission:    statusDetail.sell         || {},
          buy_permission:     statusDetail.buy          || {},
          immediate_payment:  statusDetail.immediate_payment || {},
          account_type:       data.account_type      || '',
          level_id:           data.level_id          || '',
          context_id:         data.context_id        || '',
          tags:               data.tags              || [],
          permalink:          data.permalink         || '',
          registration_date:  data.registration_date || '',
        });
      } catch (e) {
        return err(`Erro ao buscar info MP: ${e.message}`, 500);
      }
    }

    // ── /api/mp/pix  ──────────────────────────────────────────────────────
    // Proxy server-side para POST https://api.mercadopago.com/v1/payments
    // Necessário porque o browser bloqueia chamadas diretas ao MP (CORS).
    // O Flutter envia o body pronto; o Worker injeta o Authorization header
    // com o access_token armazenado no D1 (nunca exposto ao cliente).
    if (path === '/api/mp/pix' && method === 'POST') {
      try {
        // 1. Buscar access_token do MP no D1
        let accessToken = null;
        const mpCfgRow = await DB.prepare(
          `SELECT value FROM config WHERE key='mp_config' LIMIT 1`
        ).first().catch(() => null);
        if (mpCfgRow?.value) {
          try {
            const cfg = JSON.parse(mpCfgRow.value);
            accessToken = cfg?.production?.access_token || cfg?.access_token || null;
          } catch (_) {}
        }
        // Fallback: variável de ambiente
        if (!accessToken && env?.MP_ACCESS_TOKEN) accessToken = env.MP_ACCESS_TOKEN;
        if (!accessToken) return err('Token MP não configurado', 500);

        // 2. Ler body enviado pelo Flutter
        const pixBody = await request.json().catch(() => null);
        if (!pixBody) return err('Body inválido', 400);

        // 3. Extrair idempotency key do header (opcional) ou do external_reference
        const idempotencyKey = request.headers.get('X-Idempotency-Key')
          || pixBody.external_reference
          || `pix_${Date.now()}`;

        // 4. Chamar API do MP server-side (sem CORS)
        const mpResp = await fetch('https://api.mercadopago.com/v1/payments', {
          method: 'POST',
          headers: {
            'Authorization':     `Bearer ${accessToken}`,
            'Content-Type':      'application/json',
            'X-Idempotency-Key': idempotencyKey,
          },
          body: JSON.stringify(pixBody),
        });

        const mpData = await mpResp.json().catch(() => ({}));

        if (!mpResp.ok) {
          // Propaga erro do MP com status original
          return new Response(JSON.stringify({
            success: false,
            status:  mpResp.status,
            error:   mpData?.message || mpData?.cause?.[0]?.description || `Erro MP ${mpResp.status}`,
            mp_data: mpData,
          }), {
            status: mpResp.status,
            headers: { 'Content-Type': 'application/json', ...CORS },
          });
        }

        // 5. Retornar resposta do MP ao Flutter
        return ok({
          id:                   mpData.id,
          status:               mpData.status,
          status_detail:        mpData.status_detail,
          external_reference:   mpData.external_reference,
          transaction_amount:   mpData.transaction_amount,
          point_of_interaction: mpData.point_of_interaction,
          date_created:         mpData.date_created,
          date_of_expiration:   mpData.date_of_expiration,
        });
      } catch (e) {
        return err(`Erro proxy MP Pix: ${e.message}`, 500);
      }
    }

    // ── /api/mp/preapproval/debug  ────────────────────────────────────────
    // Endpoint temporário de diagnóstico: echo do body recebido sem chamar MP.
    // Permite capturar exatamente o que o Flutter envia.
    if (path === '/api/mp/preapproval/debug' && method === 'POST') {
      try {
        const rawText  = await request.text();
        let parsedBody = null;
        try { parsedBody = JSON.parse(rawText); } catch (_) {}
        return ok({
          debug: true,
          raw_body:     rawText,
          parsed_body:  parsedBody,
          headers: {
            content_type:    request.headers.get('Content-Type'),
            idempotency_key: request.headers.get('X-Idempotency-Key'),
          },
        });
      } catch (e) {
        return err(`Debug error: ${e.message}`, 500);
      }
    }

    // ── /api/mp/plan  ─────────────────────────────────────────────────────
    // Cria ou reutiliza um preapproval_plan por produto.
    // O plano é a base do fluxo 2 passos: plan → preapproval por cliente.
    // Armazena o plan_id no D1 para reutilizar (evita duplicar planos).
    // Body: { produto_id, produto_nome, valor, notification_url, back_url }
    // Retorna: { plan_id, init_point }
    if (path === '/api/mp/plan' && method === 'POST') {
      try {
        // 1. Access token
        let accessToken = null;
        const mpCfgRow = await DB.prepare(`SELECT value FROM config WHERE key='mp_config' LIMIT 1`).first().catch(() => null);
        if (mpCfgRow?.value) {
          try { const cfg = JSON.parse(mpCfgRow.value); accessToken = cfg?.production?.access_token || cfg?.access_token || null; } catch (_) {}
        }
        if (!accessToken && env?.MP_ACCESS_TOKEN) accessToken = env.MP_ACCESS_TOKEN;
        if (!accessToken) return err('Token MP não configurado', 500);

        const body = await request.json().catch(() => null);
        if (!body) return err('Body inválido', 400);

        const produtoId       = body.produto_id || 'default';
        const produtoNome     = body.produto_nome || 'Assinatura';
        const valor           = Math.round(parseFloat(body.valor || 0) * 100) / 100;
        const notificationUrl = body.notification_url || '';
        const backUrl         = body.back_url || 'https://sharewallet.com.br';

        if (valor <= 0) return err('Valor inválido', 400);

        // 2. Verificar se já existe plan para este produto no D1
        await DB.prepare(`CREATE TABLE IF NOT EXISTS mp_plans (
          produto_id TEXT PRIMARY KEY,
          plan_id    TEXT NOT NULL,
          valor      REAL NOT NULL,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )`).run().catch(() => {});

        const existingPlan = await DB.prepare(
          `SELECT plan_id, valor FROM mp_plans WHERE produto_id = ?`
        ).bind(produtoId).first().catch(() => null);

        // Reutilizar se valor não mudou
        if (existingPlan && Math.abs(existingPlan.valor - valor) < 0.01) {
          console.log('[Plan] Reutilizando plano existente:', existingPlan.plan_id);
          return ok({ plan_id: existingPlan.plan_id, reused: true });
        }

        // 3. Criar novo plano no MP com Pix habilitado (doc oficial)
        const planBody = {
          reason:       `${produtoNome} - ShareWallet`,
          back_url:     backUrl,
          auto_recurring: {
            frequency:          1,
            frequency_type:     'months',
            transaction_amount: valor,
            currency_id:        'BRL',
          },
          payment_methods_allowed: {
            payment_types: [
              { id: 'bank_transfer' },   // ← habilita Pix Automático BACEN
            ],
            payment_methods: [
              { id: 'pix' },             // ← especifica método pix
            ],
          },
          ...(notificationUrl ? { notification_url: notificationUrl } : {}),
        };

        const mpResp = await fetch('https://api.mercadopago.com/preapproval_plan', {
          method:  'POST',
          headers: {
            'Authorization':     `Bearer ${accessToken}`,
            'Content-Type':      'application/json',
            'X-Idempotency-Key': `plan_${produtoId}_${Date.now()}`,
          },
          body: JSON.stringify(planBody),
        });

        const mpData = await mpResp.json().catch(() => ({}));
        console.log('[Plan] MP status:', mpResp.status, '| plan_id:', mpData?.id || '-');

        if (!mpResp.ok) {
          return new Response(JSON.stringify({
            success: false, status: mpResp.status,
            error: mpData?.message || `Erro MP ${mpResp.status}`, mp_data: mpData,
          }), { status: mpResp.status, headers: { 'Content-Type': 'application/json', ...CORS } });
        }

        // 4. Salvar plan no D1 (sem init_point — vem do preapproval individual)
        await DB.prepare(
          `INSERT OR REPLACE INTO mp_plans (produto_id, plan_id, valor) VALUES (?, ?, ?)`
        ).bind(produtoId, mpData.id, valor).run().catch(() => {});

        return ok({ plan_id: mpData.id, reused: false });

      } catch (e) {
        return err(`Erro ao criar plano MP: ${e.message}`, 500);
      }
    }

    // ── /api/mp/preapproval  ──────────────────────────────────────────────
    // Fluxo DEFINITIVO — doc oficial MP:
    // "Assinaturas SEM plano associado com pagamento PENDENTE"
    // https://developers/pt/docs/subscriptions/integration-configuration/
    //          subscription-no-associated-plan/pending-payments
    //
    // POST direto para /preapproval com status:"pending" e SEM card_token_id.
    // O MP retorna init_point onde o cliente escolhe: Pix, conta MP ou cartão.
    //
    // IMPORTANTE: o fluxo "COM plano + card_token_id" é EXCLUSIVO para cartão.
    // Para Pix sem cartão, SEMPRE usar o fluxo sem plano + pending.
    //
    // Flutter envia: { produto_id, produto_nome, valor, payer_email,
    //                  external_reference, notification_url, back_url, metadata }
    // Retorna: { success, id, status:"pending", init_point, external_reference }
    if (path === '/api/mp/preapproval' && method === 'POST') {
      try {
        // ── 0. Access token ──────────────────────────────────────────────
        let accessToken = null;
        const mpCfgRow = await DB.prepare(
          `SELECT value FROM config WHERE key='mp_config' LIMIT 1`
        ).first().catch(() => null);
        if (mpCfgRow?.value) {
          try {
            const cfg = JSON.parse(mpCfgRow.value);
            accessToken = cfg?.production?.access_token || cfg?.access_token || null;
          } catch (_) {}
        }
        if (!accessToken && env?.MP_ACCESS_TOKEN) accessToken = env.MP_ACCESS_TOKEN;
        if (!accessToken) return err('Token MP não configurado', 500);

        // ── 1. Ler e validar body do Flutter ────────────────────────────
        const preBody = await request.json().catch(() => null);
        if (!preBody) return err('Body inválido', 400);

        console.log('[Preapproval] Body Flutter:', JSON.stringify(preBody));

        const produtoNome = preBody.produto_nome  || preBody.reason  || 'Assinatura ShareWallet';
        const payerEmail  = preBody.payer_email   || '';
        const safeAmount  = Math.round(parseFloat(
          preBody.valor ?? preBody.auto_recurring?.transaction_amount ?? 0
        ) * 100) / 100;
        const backUrl     = preBody.back_url           || 'https://sharewallet.com.br';
        const notifUrl    = preBody.notification_url   || '';
        const extRef      = preBody.external_reference || `REC_${Date.now()}`;

        if (safeAmount <= 0) return err('Valor inválido', 400);
        if (!payerEmail)     return err('payer_email obrigatório', 400);

        // ── 2. Montar body do preapproval (SEM plano, SEM card_token) ───
        // Doc oficial: "Assinaturas sem plano com pagamento pendente"
        // Campos obrigatórios: reason, payer_email, auto_recurring, back_url, status
        const startDate = new Date(Date.now() + 2 * 60 * 60 * 1000).toISOString(); // +2h

        const mpBody = {
          reason:             produtoNome,
          external_reference: extRef,
          payer_email:        payerEmail,
          auto_recurring: {
            frequency:          1,
            frequency_type:     'months',
            transaction_amount: safeAmount,
            currency_id:        'BRL',
            start_date:         startDate,
          },
          back_url: backUrl,
          status:   'pending',   // ← sem card_token = pending → client escolhe método
          ...(notifUrl ? { notification_url: notifUrl } : {}),
        };

        console.log('[Preapproval] Enviando para MP. Body:', JSON.stringify(mpBody));

        // ── 3. Chamar API do MP ─────────────────────────────────────────
        const mpResp = await fetch('https://api.mercadopago.com/preapproval', {
          method:  'POST',
          headers: {
            'Authorization':     `Bearer ${accessToken}`,
            'Content-Type':      'application/json',
            'X-Idempotency-Key': `pre_${extRef}`,
          },
          body: JSON.stringify(mpBody),
        });

        const mpData = await mpResp.json().catch(() => ({}));
        console.log('[Preapproval] MP resp:', mpResp.status,
          '| id:', mpData?.id || '-',
          '| init_point:', mpData?.init_point?.substring(0, 80) || '-');

        if (!mpResp.ok) {
          return new Response(JSON.stringify({
            success:   false,
            error:     mpData?.message || `Erro MP ${mpResp.status}`,
            mp_data:   mpData,
            sent_body: mpBody,
          }), { status: mpResp.status, headers: { 'Content-Type': 'application/json', ...CORS } });
        }

        // ── 4. Retornar init_point ao Flutter ───────────────────────────
        // O init_point abre checkout onde o cliente escolhe:
        //   • Pix Automático (banco do cliente: Nubank, BB, Itaú…)
        //   • Conta Mercado Pago
        //   • Cartão de crédito/débito
        return ok({
          id:                 mpData.id,
          status:             mpData.status || 'pending',
          init_point:         mpData.init_point,
          external_reference: extRef,
          date_created:       mpData.date_created || new Date().toISOString(),
          auto_recurring: {
            frequency:          1,
            frequency_type:     'months',
            transaction_amount: safeAmount,
            currency_id:        'BRL',
          },
        });

      } catch (e) {
        console.error('[Preapproval] Erro inesperado:', e.message);
        return err(`Erro proxy MP Preapproval: ${e.message}`, 500);
      }
    }


        // ── /api/webhook/mp/preapproval ────────────────────────────────────────
    // Recebe notificações de assinaturas recorrentes (preapproval) do MercadoPago.
    // Disparado quando: assinatura autorizada, pagamento mensal cobrado, cancelamento.
    // Docs: https://www.mercadopago.com.br/developers/pt/docs/subscriptions/additional-content/notifications
    if (path === '/api/webhook/mp/preapproval' && (method === 'POST' || method === 'GET')) {
      try {
        if (method === 'GET') return ok({ received: true });

        const body = await request.json().catch(() => ({}));
        const url  = new URL(request.url);

        // MP envia: { type: "subscription_preapproval", data: { id: "preapproval_id" } }
        let preapprovalId = body?.data?.id || body?.id ||
            url.searchParams.get('data.id') || url.searchParams.get('id');
        const topic = body?.type || body?.topic || url.searchParams.get('topic') || '';

        if (!preapprovalId) return ok({ received: true, skipped: true });
        preapprovalId = String(preapprovalId);

        // Buscar token MP
        const mpCfg = await DB.prepare(`SELECT value FROM config WHERE key='mp_config' LIMIT 1`).first().catch(() => null);
        let accessToken = null;
        if (mpCfg?.value) {
          try {
            const cfg = JSON.parse(mpCfg.value);
            accessToken = cfg?.production?.access_token || cfg?.access_token || null;
          } catch (_) {}
        }
        if (!accessToken && env?.MP_ACCESS_TOKEN) accessToken = env.MP_ACCESS_TOKEN;
        if (!accessToken) return ok({ received: true, error: 'no_token' });

        // Consultar API MP para obter status do preapproval
        const mpResp = await fetch(
          `https://api.mercadopago.com/preapproval/${preapprovalId}`,
          { headers: { 'Authorization': `Bearer ${accessToken}` } }
        );
        if (!mpResp.ok) return ok({ received: true, error: `MP ${mpResp.status}` });

        const pa       = await mpResp.json();
        const status   = pa.status;   // authorized | paused | cancelled | pending
        const extRef   = pa.external_reference || '';
        const valor    = pa.auto_recurring?.transaction_amount || 0;
        const metadata = pa.metadata || {};

        const affiliateCode = metadata.affiliate_code || extRef.split('_')[1] || '';
        const produtoId     = metadata.produto_id     || extRef.split('_')[2] || '';
        const comissao      = metadata.comissao       || (valor * 0.20);
        const subId         = `sub_rec_${preapprovalId}`;
        const produtoNome   = pa.reason || produtoId || '';
        const clienteEmail  = metadata.cliente_email || pa.payer_email || '';
        const clienteNome   = metadata.cliente_nome  || '';
        const clienteCpf    = metadata.cliente_cpf   || '';

        // Quando autorizado (1ª cobrança paga) ou pagamento efetuado → ativar
        if (status === 'authorized') {
          const existSub = await DB.prepare(`SELECT id, status FROM subscriptions WHERE id=?`).bind(subId).first().catch(() => null);

          if (existSub) {
            if (existSub.status !== 'ativa') {
              await DB.prepare(`UPDATE subscriptions SET status='ativa' WHERE id=?`).bind(subId).run();
            }
          } else {
            const proximaData = new Date();
            proximaData.setDate(proximaData.getDate() + 30);
            await DB.prepare(
              `INSERT INTO subscriptions
                (id, product_id, product_nome, valor, comissao, affiliate_code,
                 charge_type, status, dia_cobranca, data_inicio, proxima_cobranca,
                 cliente_email, cliente_nome, cliente_cpf)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)
               ON CONFLICT(id) DO UPDATE SET
                 status='ativa',
                 cliente_email=COALESCE(NULLIF(excluded.cliente_email,''), cliente_email),
                 cliente_nome =COALESCE(NULLIF(excluded.cliente_nome, ''), cliente_nome)`
            ).bind(
              subId, produtoId, produtoNome, valor, comissao,
              affiliateCode, 'pixRecorrente', 'ativa', 5,
              new Date().toISOString(), proximaData.toISOString(),
              clienteEmail, clienteNome, clienteCpf
            ).run();
          }

          // Creditar comissão
          if (affiliateCode && comissao > 0) {
            const { results: affs } = await DB.prepare(
              `SELECT id FROM affiliates WHERE affiliate_code=?`
            ).bind(affiliateCode).all().catch(() => ({ results: [] }));
            const affId = affs[0]?.id || null;
            if (affId) {
              const saleId = `sale_rec_${preapprovalId}`;
              const existSale = await DB.prepare(`SELECT id FROM sales WHERE id=?`).bind(saleId).first().catch(() => null);
              if (!existSale) {
                await DB.prepare(
                  `INSERT INTO sales
                    (id, user_id, product_id, product_nome, valor, comissao,
                     affiliate_code, status, created_at, payment_id, charge_type)
                   VALUES (?,?,?,?,?,?,?,'aprovado',datetime('now'),?,?)`
                ).bind(saleId, affId, produtoId, produtoNome, valor, comissao,
                  affiliateCode, preapprovalId, 'pixRecorrente').run();
                // Creditar em todos os registros do afiliado
                for (const a of affs) {
                  await DB.prepare(
                    `INSERT INTO wallets (user_id, saldo_disponivel, saldo_pendente, total_recebido)
                     VALUES (?,?,0,?)
                     ON CONFLICT(user_id) DO UPDATE SET
                       saldo_disponivel=saldo_disponivel+?,
                       total_recebido=total_recebido+?,
                       updated_at=datetime('now')`
                  ).bind(a.id, comissao, comissao, comissao, comissao).run();
                }
                await DB.prepare(
                  `UPDATE affiliates SET
                     total_comissoes=total_comissoes+?,
                     saldo_disponivel=saldo_disponivel+?,
                     total_assinaturas=total_assinaturas+1
                   WHERE affiliate_code=?`
                ).bind(comissao, comissao, affiliateCode).run();
              }
            }
          }
        } else if (status === 'cancelled' || status === 'paused') {
          await DB.prepare(
            `UPDATE subscriptions SET status=? WHERE id=?`
          ).bind(status === 'cancelled' ? 'cancelada' : 'pausada', subId).run().catch(() => {});
        }

        return ok({ received: true, preapprovalId, status, affiliateCode, subId });
      } catch (e) {
        return ok({ received: true, error: String(e) });
      }
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

        // Fallback: variável de ambiente (configurada no Cloudflare Dashboard)
        if (!accessToken && env?.MP_ACCESS_TOKEN) {
          accessToken = env.MP_ACCESS_TOKEN;
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
        const extRef  = payment.external_reference || '';
        // Prefixo do external_reference define o tipo:
        //   PIX_   → Pix Único (avulso)
        //   SW_    → checkout preference (recorrente legado)
        //   REC_   → preapproval recorrente
        const chargeType = extRef.startsWith('PIX_') ? 'pixAvulso' : 'pixRecorrente';
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
                const payerNome  = [payment.payer?.first_name, payment.payer?.last_name].filter(Boolean).join(' ') || '';
                const payerEmail = payment.payer?.email || '';
                await DB.prepare(
                  `INSERT INTO sales
                    (id, user_id, product_id, product_nome, valor, comissao,
                     affiliate_code, status, created_at,
                     cliente_nome, cliente_email, payment_id, charge_type)
                   VALUES (?, ?, ?, ?, ?, ?, ?, 'aprovado', datetime('now'), ?, ?, ?, ?)`
                ).bind(
                  saleId, affId, produtoId, produtoNome,
                  valor, comissao, affiliateCode,
                  payerNome, payerEmail, String(paymentId), chargeType
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

          // ── Enviar e-mail de confirmação para o afiliado ────────────────
          // Busca email do afiliado para envio (fire-and-forget, não bloqueia resposta)
          if (affiliateCode) {
            const affEmailRow = await DB.prepare(
              `SELECT nome, email FROM affiliates WHERE affiliate_code=? LIMIT 1`
            ).bind(affiliateCode).first().catch(() => null);
            if (affEmailRow?.email) {
              const prodDescRow = await DB.prepare(
                `SELECT descricao FROM products WHERE id=? LIMIT 1`
              ).bind(produtoId).first().catch(() => null);
              sendConfirmationEmail({
                toEmail:          affEmailRow.email,
                toName:           affEmailRow.nome || 'Cliente',
                productName:      produtoNome,
                productDescricao: prodDescRow?.descricao || '',
                valor,
                comissao,
                affiliateCode,
                paymentId,
                dataPagamento:    payment.date_approved || new Date().toISOString(),
              }, env).catch(() => {}); // fire-and-forget
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

    // ── GET /assets/* — proxy direto para o Pages (bypass CDN cache poisoning) ──
    // O CDN da zona sharewallet.com.br pode ter objetos corrompidos (32 bytes)
    // cacheados com immutable de deploys anteriores. Este Worker faz fetch direto
    // no deployment mais recente do Pages, sem passar pelo cache da zona.
    //
    // Flutter usa este endpoint para FontManifest.json e fontes quando o CDN falha.
    // URL: https://api.sharewallet.com.br/assets/<path>
    // Ex: /assets/FontManifest.json → pages.dev/app/assets/FontManifest.json
    //     /assets/fonts/MaterialIcons-Regular.e20afb18.otf → pages.dev/app/assets/fonts/...
    if (path.startsWith('/assets/') && method === 'GET') {
      try {
        const assetPath = path.slice('/assets/'.length); // remove "/assets/" prefix
        // Usar o deployment preview mais recente (sem CDN de zona) para garantir conteúdo fresco
        const pagesUrl = `https://115c8082.sharewallet-app.pages.dev/app/assets/${assetPath}`;
        const upstream = await fetch(pagesUrl, {
          headers: { 'Accept': request.headers.get('Accept') || '*/*' },
          cf: { cacheEverything: false }, // nunca cachear no Worker
        });
        if (!upstream.ok) {
          return new Response(`Asset não encontrado: ${assetPath}`, {
            status: upstream.status,
            headers: { ...CORS },
          });
        }
        const contentType = upstream.headers.get('Content-Type') || 'application/octet-stream';
        const body = await upstream.arrayBuffer();
        return new Response(body, {
          status: 200,
          headers: {
            ...CORS,
            'Content-Type': contentType,
            'Cache-Control': 'no-store, no-cache, must-revalidate',
            'X-Asset-Proxy': 'worker', // identificar que veio pelo proxy
          },
        });
      } catch (e) {
        return err(`Erro ao buscar asset: ${e.message}`, 500);
      }
    }

    // ── /api/admin/reset — zerar tabelas (vendas / assinaturas / saques) ─────
    // PERIGO: apaga dados permanentemente. Requer header X-Admin-Secret.
    // Body JSON: { "target": "sales" | "subscriptions" | "withdrawals" | "all" }
    if (path === '/api/admin/reset' && method === 'DELETE') {
      // Autenticação mínima via secret no header
      const secret = request.headers.get('X-Admin-Secret') || '';
      if (!secret || secret !== (env.ADMIN_RESET_SECRET || 'sharewallet_reset_2024')) {
        return err('Não autorizado', 401);
      }

      let body = {};
      try { body = await request.json(); } catch (_) {}
      const target = body.target || 'none';

      const allowed = ['sales', 'subscriptions', 'withdrawals', 'all'];
      if (!allowed.includes(target)) {
        return err(`target inválido: ${target}. Use: ${allowed.join(', ')}`, 400);
      }

      const results = {};

      // Zerar vendas
      if (target === 'sales' || target === 'all') {
        const r = await DB.prepare(`DELETE FROM sales`).run();
        results.sales = { deleted: r.meta?.changes ?? 0 };
      }

      // Zerar assinaturas + recalcular totais nos afiliados
      if (target === 'subscriptions' || target === 'all') {
        const r = await DB.prepare(`DELETE FROM subscriptions`).run();
        results.subscriptions = { deleted: r.meta?.changes ?? 0 };
        // Zerando total_assinaturas nos afiliados
        await DB.prepare(`UPDATE affiliates SET total_assinaturas = 0`).run();
      }

      // Zerar saques + recalcular saldos nos afiliados e wallets
      if (target === 'withdrawals' || target === 'all') {
        const r = await DB.prepare(`DELETE FROM withdrawals`).run();
        results.withdrawals = { deleted: r.meta?.changes ?? 0 };
        // Zerando total_sacado nos afiliados
        await DB.prepare(`UPDATE affiliates SET total_sacado = 0`).run();
      }

      // Se zerou tudo: também zera wallets, comissões e saldos dos afiliados
      if (target === 'all') {
        await DB.prepare(`DELETE FROM wallets`).run();
        await DB.prepare(`UPDATE affiliates SET
          saldo_disponivel    = 0,
          total_comissoes     = 0,
          total_sacado        = 0,
          total_indicados     = 0,
          total_assinaturas   = 0
        `).run();
        results.wallets   = 'zerado';
        results.affiliates_totals = 'zerado';
      }

      return ok({ success: true, target, results, ts: new Date().toISOString() });
    }

    return err('Rota não encontrada: ' + path, 404);
}
