/**
 * AgentDock API — Cloudflare Worker
 *
 * 独立部署到 api.agentdockstatus.app(与官网静态站分离)。
 *
 * 公开:
 *   POST /v1/event              启动/心跳
 *   POST /v1/crash              崩溃上报
 *   GET  /v1/download/:file     记一次下载后 302 到官网 pkg
 *
 * 看板(账号密码只在后端;密码用 wrangler secret):
 *   POST /v1/admin/login
 *   POST /v1/admin/logout
 *   GET  /v1/admin/stats
 *   GET  /v1/admin/crashes
 */

export interface Env {
  DB: D1Database;
  SITE_ORIGIN: string;
  ADMIN_USER: string;
  ADMIN_PASSWORD: string;
  SESSION_SECRET: string;
}

const SESSION_TTL_SEC = 60 * 60 * 24 * 7; // 7 天
const MAX_STACK = 8_000;
const MAX_REASON = 2_000;
const MAX_NAME = 200;
const ALLOWED_EVENTS = new Set(["launch", "heartbeat"]);

type Json = Record<string, unknown>;

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      return await handle(request, env);
    } catch (err) {
      // 必须也过 cors:否则 500 无 ACAO,浏览器只显示 CORS 失败,掩盖真实错误
      const detail = err instanceof Error ? err.message : String(err);
      console.error("unhandled", detail, err);
      return cors(json({ error: "internal_error", detail }, 500), request, env);
    }
  },
};

async function handle(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const path = url.pathname.replace(/\/+$/, "") || "/";
  const method = request.method.toUpperCase();

  if (method === "OPTIONS") {
    return cors(new Response(null, { status: 204 }), request, env);
  }

  let res: Response;
  if (method === "GET" && path === "/health") {
    res = json({ ok: true });
  } else if (method === "POST" && path === "/v1/event") {
    res = await postEvent(request, env);
  } else if (method === "POST" && path === "/v1/crash") {
    res = await postCrash(request, env);
  } else if (method === "GET" && path.startsWith("/v1/download/")) {
    res = await getDownload(request, env, path.slice("/v1/download/".length));
  } else if (method === "POST" && path === "/v1/admin/login") {
    res = await adminLogin(request, env);
  } else if (method === "POST" && path === "/v1/admin/logout") {
    res = await adminLogout(request, env);
  } else if (method === "GET" && path === "/v1/admin/stats") {
    res = await adminStats(request, env);
  } else if (method === "GET" && path === "/v1/admin/crashes") {
    res = await adminCrashes(request, env, url);
  } else {
    res = json({ error: "not_found" }, 404);
  }

  return cors(res, request, env);
}

// ─── Public: events / crash / download ───────────────────────────────

async function postEvent(request: Request, env: Env): Promise<Response> {
  const body = await readJson(request);
  if (!body) return json({ error: "invalid_json" }, 400);

  const installId = asInstallId(body.install_id);
  const event = asString(body.event);
  if (!installId || !event || !ALLOWED_EVENTS.has(event)) {
    return json({ error: "invalid_payload" }, 400);
  }

  await env.DB.prepare(
    `INSERT INTO events (install_id, event, app_version, os_version, arch)
     VALUES (?, ?, ?, ?, ?)`,
  )
    .bind(
      installId,
      event,
      clip(asString(body.app_version), 32),
      clip(asString(body.os_version), 32),
      clip(asString(body.arch), 16),
    )
    .run();

  return json({ ok: true });
}

async function postCrash(request: Request, env: Env): Promise<Response> {
  const body = await readJson(request);
  if (!body) return json({ error: "invalid_json" }, 400);

  const installId = asInstallId(body.install_id);
  if (!installId) return json({ error: "invalid_payload" }, 400);

  await env.DB.prepare(
    `INSERT INTO crashes
       (install_id, app_version, os_version, arch, name, reason, stack)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
  )
    .bind(
      installId,
      clip(asString(body.app_version), 32),
      clip(asString(body.os_version), 32),
      clip(asString(body.arch), 16),
      clip(asString(body.name), MAX_NAME),
      clip(asString(body.reason), MAX_REASON),
      clip(asString(body.stack), MAX_STACK),
    )
    .run();

  return json({ ok: true });
}

async function getDownload(
  request: Request,
  env: Env,
  rawFile: string,
): Promise<Response> {
  const filename = decodeURIComponent(rawFile).split("/").pop() ?? "";
  // 只允许本产品的安装包名,防止被当成开放跳转器滥用
  if (!/^AgentDock-\d+\.\d+\.\d+\.(pkg|dmg)$/.test(filename)) {
    return json({ error: "invalid_file" }, 400);
  }

  const ip = request.headers.get("CF-Connecting-IP") ?? "";
  const ua = request.headers.get("User-Agent") ?? "";
  const ipHash = ip ? await sha256Hex(`${ip}:${env.SESSION_SECRET}`).then((h) => h.slice(0, 32)) : null;

  await env.DB.prepare(
    `INSERT INTO downloads (filename, ip_hash, user_agent) VALUES (?, ?, ?)`,
  )
    .bind(filename, ipHash, clip(ua, 300))
    .run();

  const target = `${env.SITE_ORIGIN.replace(/\/+$/, "")}/${filename}`;
  return Response.redirect(target, 302);
}

// ─── Admin auth ──────────────────────────────────────────────────────

async function adminLogin(request: Request, env: Env): Promise<Response> {
  const body = await readJson(request);
  if (!body) return json({ error: "invalid_json" }, 400);

  const user = (asString(body.username) ?? "").trim();
  const pass = asString(body.password) ?? "";
  if (!env.ADMIN_PASSWORD || !env.SESSION_SECRET) {
    return json({ error: "admin_not_configured" }, 503);
  }
  // Secret 在控制台粘贴时偶发带尾部换行,比对前 trim
  if (user !== env.ADMIN_USER.trim() || pass !== env.ADMIN_PASSWORD.trim()) {
    return json({ error: "invalid_credentials" }, 401);
  }

  let token: string;
  try {
    token = await mintSession(env.SESSION_SECRET.trim(), env.ADMIN_USER.trim());
  } catch (err) {
    const detail = err instanceof Error ? err.message : String(err);
    console.error("mintSession", detail, err);
    return json({ error: "session_mint_failed", detail }, 500);
  }
  const res = json({ ok: true, token });
  res.headers.append(
    "Set-Cookie",
    // 同源站(apex ↔ api 子域)用 Lax 即可;比 None 更不易被浏览器拦
    cookie("ad_session", token, { maxAge: SESSION_TTL_SEC, httpOnly: true, sameSite: "Lax" }),
  );
  return res;
}

async function adminLogout(_request: Request, env: Env): Promise<Response> {
  const res = json({ ok: true });
  res.headers.append(
    "Set-Cookie",
    cookie("ad_session", "", { maxAge: 0, httpOnly: true, sameSite: "Lax" }),
  );
  void env;
  return res;
}

async function requireAdmin(request: Request, env: Env): Promise<Response | null> {
  const secret = (env.SESSION_SECRET ?? "").trim();
  const adminUser = (env.ADMIN_USER ?? "").trim();
  if (!secret || !adminUser) return json({ error: "admin_not_configured" }, 503);

  // Authorization Bearer 优先(看板存在 localStorage);cookie 作兼容
  let cookieToken = "";
  try {
    cookieToken = parseCookie(request.headers.get("Cookie") ?? "").ad_session ?? "";
  } catch (err) {
    console.error("parseCookie", err instanceof Error ? err.message : err);
  }
  const auth = request.headers.get("Authorization") ?? "";
  const bearer = auth.toLowerCase().startsWith("bearer ")
    ? auth.slice(7).trim()
    : "";
  const token = bearer || cookieToken;
  if (!token) return json({ error: "unauthorized", reason: "missing_token" }, 401);

  let reason = "invalid_token";
  try {
    const result = await verifySessionDetailed(secret, token, adminUser);
    if (result.ok) return null;
    reason = result.reason;
  } catch (err) {
    console.error("verifySession", err instanceof Error ? err.message : err);
    return json({ error: "unauthorized", reason: "verify_threw" }, 401);
  }
  return json({ error: "unauthorized", reason }, 401);
}

async function adminStats(request: Request, env: Env): Promise<Response> {
  const denied = await requireAdmin(request, env);
  if (denied) return denied;

  try {
    // D1 单库单线程:用 batch 一次往返顺序执行,避免 Promise.all 并发打爆连接。
    const results = await env.DB.batch([
      env.DB.prepare(`SELECT COUNT(*) AS n FROM downloads`),
      env.DB.prepare(
        `SELECT COUNT(*) AS n FROM downloads WHERE created_at >= datetime('now', '-1 day')`,
      ),
      env.DB.prepare(
        `SELECT COUNT(*) AS n FROM downloads WHERE created_at >= datetime('now', '-7 day')`,
      ),
      env.DB.prepare(`SELECT COUNT(*) AS n FROM events WHERE event = 'launch'`),
      env.DB.prepare(
        `SELECT COUNT(DISTINCT install_id) AS n FROM events WHERE created_at >= datetime('now', '-1 day')`,
      ),
      env.DB.prepare(
        `SELECT COUNT(DISTINCT install_id) AS n FROM events WHERE created_at >= datetime('now', '-7 day')`,
      ),
      env.DB.prepare(
        `SELECT COUNT(DISTINCT install_id) AS n FROM events WHERE created_at >= datetime('now', '-30 day')`,
      ),
      env.DB.prepare(`SELECT COUNT(*) AS n FROM crashes`),
      env.DB.prepare(
        `SELECT COUNT(*) AS n FROM crashes WHERE created_at >= datetime('now', '-1 day')`,
      ),
      env.DB.prepare(
        `SELECT filename, COUNT(*) AS n FROM downloads GROUP BY filename ORDER BY n DESC LIMIT 20`,
      ),
      env.DB.prepare(
        `SELECT app_version, COUNT(DISTINCT install_id) AS n
         FROM events WHERE event = 'launch' AND app_version IS NOT NULL
         GROUP BY app_version ORDER BY n DESC LIMIT 20`,
      ),
    ]);

    for (let i = 0; i < results.length; i++) {
      if (results[i] && results[i].success === false) {
        console.error("adminStats batch step failed", i, results[i].error);
        return json({ error: "stats_query_failed", step: i }, 500);
      }
    }

    const num = (i: number): number => {
      const row = results[i]?.results?.[0] as { n?: number | string } | undefined;
      return Number(row?.n ?? 0);
    };

    return json({
      downloads: { total: num(0), today: num(1), last_7d: num(2) },
      usage: {
        launches_total: num(3),
        active_today: num(4),
        active_7d: num(5),
        active_30d: num(6),
      },
      crashes: { total: num(7), today: num(8) },
      downloads_by_file: results[9]?.results ?? [],
      launches_by_version: results[10]?.results ?? [],
    });
  } catch (err) {
    // 已登录管理员可见简短原因,便于排查(仍过外层 cors)
    const detail = err instanceof Error ? err.message : "unknown";
    console.error("adminStats", detail, err);
    return json({ error: "stats_failed", detail }, 500);
  }
}

async function adminCrashes(
  request: Request,
  env: Env,
  url: URL,
): Promise<Response> {
  const denied = await requireAdmin(request, env);
  if (denied) return denied;

  try {
    const limit = Math.min(100, Math.max(1, Number(url.searchParams.get("limit") ?? "30") || 30));
    const rows = await env.DB.prepare(
      `SELECT id, install_id, app_version, os_version, arch, name, reason, stack, created_at
       FROM crashes ORDER BY id DESC LIMIT ?`,
    )
      .bind(limit)
      .all();

    return json({ crashes: rows.results ?? [] });
  } catch (err) {
    const detail = err instanceof Error ? err.message : "unknown";
    console.error("adminCrashes", detail, err);
    return json({ error: "crashes_failed", detail }, 500);
  }
}

// ─── Session (HMAC, no DB) ───────────────────────────────────────────

async function mintSession(secret: string, user: string): Promise<string> {
  const exp = Math.floor(Date.now() / 1000) + SESSION_TTL_SEC;
  const payload = `${user}.${exp}`;
  const sig = await hmacHex(secret, payload);
  return `${payload}.${sig}`;
}

async function verifySession(secret: string, token: string, user: string): Promise<boolean> {
  return (await verifySessionDetailed(secret, token, user)).ok;
}

async function verifySessionDetailed(
  secret: string,
  token: string,
  user: string,
): Promise<{ ok: true } | { ok: false; reason: string }> {
  const parts = token.split(".");
  if (parts.length !== 3) return { ok: false, reason: "malformed_token" };
  const [u, expStr, sig] = parts;
  if (!u || !expStr || !sig) return { ok: false, reason: "malformed_token" };
  if (u !== user) return { ok: false, reason: "user_mismatch" };
  // 签名必须是 SHA-256 hex,否则直接拒绝(避免脏 localStorage 走进 crypto)
  if (!/^[0-9a-f]+$/i.test(sig) || sig.length !== 64) {
    return { ok: false, reason: "bad_sig_format" };
  }
  const exp = Number(expStr);
  if (!Number.isFinite(exp)) return { ok: false, reason: "bad_exp" };
  if (exp < Math.floor(Date.now() / 1000)) return { ok: false, reason: "expired" };
  const expect = await hmacHex(secret, `${u}.${expStr}`);
  if (!timingSafeEqual(sig.toLowerCase(), expect)) {
    return { ok: false, reason: "bad_sig" };
  }
  return { ok: true };
}

async function hmacHex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, enc.encode(message));
  return bufferToHex(sig);
}

async function sha256Hex(input: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", enc.encode(input));
  return bufferToHex(buf);
}

function bufferToHex(buf: ArrayBuffer): string {
  const bytes = new Uint8Array(buf);
  let out = "";
  for (let i = 0; i < bytes.length; i++) {
    out += bytes[i]!.toString(16).padStart(2, "0");
  }
  return out;
}

const enc = new TextEncoder();

const timingSafe = {
  equal(a: string, b: string): boolean {
    if (a.length !== b.length) return false;
    let out = 0;
    for (let i = 0; i < a.length; i++) out |= a.charCodeAt(i) ^ b.charCodeAt(i);
    return out === 0;
  },
};

// ─── Helpers ─────────────────────────────────────────────────────────

function cors(res: Response, request: Request, env: Env): Response {
  const origin = (request.headers.get("Origin") ?? "").replace(/\/+$/, "");
  const site = (env.SITE_ORIGIN ?? "").replace(/\/+$/, "");
  // 官网实际挂在 apex;www 可能未解析。两者都放行,避免看板跨域登录被拦。
  const allowed = new Set([
    site,
    "https://agentdockstatus.app",
    "https://www.agentdockstatus.app",
    "http://127.0.0.1:8787",
    "http://localhost:8787",
    "http://127.0.0.1:5500",
    "http://localhost:5500",
  ]);
  // 直接改原 Response 的 headers,不要 new Headers(res.headers):
  // Fetch Headers 构造会丢掉 Set-Cookie,导致登录 cookie 永远种不上 → 刷新必掉线、看板无数据。
  if (origin && allowed.has(origin)) {
    res.headers.set("Access-Control-Allow-Origin", origin);
    res.headers.set("Access-Control-Allow-Credentials", "true");
    res.headers.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
    res.headers.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.headers.set("Vary", "Origin");
  }
  return res;
}

function json(data: Json | unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });
}

async function readJson(request: Request): Promise<Json | null> {
  try {
    const data = await request.json();
    return data && typeof data === "object" ? (data as Json) : null;
  } catch {
    return null;
  }
}

function asString(v: unknown): string | null {
  return typeof v === "string" ? v : null;
}

function asInstallId(v: unknown): string | null {
  const s = asString(v);
  if (!s) return null;
  // UUID 或任意 8–64 位字母数字/连字符
  if (!/^[A-Za-z0-9_-]{8,64}$/.test(s)) return null;
  return s;
}

function clip(v: string | null, max: number): string | null {
  if (v == null) return null;
  const t = v.trim();
  if (!t) return null;
  return t.length > max ? t.slice(0, max) : t;
}

function cookie(
  name: string,
  value: string,
  opts: { maxAge: number; httpOnly: boolean; sameSite?: "Lax" | "None" | "Strict" },
): string {
  const sameSite = opts.sameSite ?? "Lax";
  const parts = [
    `${name}=${encodeURIComponent(value)}`,
    "Path=/",
    `Max-Age=${opts.maxAge}`,
    `SameSite=${sameSite}`,
    "Secure",
  ];
  // None 必须 Secure(已加);跨站场景才需要 None
  if (opts.httpOnly) parts.push("HttpOnly");
  return parts.join("; ");
}

function parseCookie(header: string): Record<string, string> {
  const out: Record<string, string> = {};
  for (const part of header.split(";")) {
    const i = part.indexOf("=");
    if (i < 0) continue;
    const k = part.slice(0, i).trim();
    const v = part.slice(i + 1).trim();
    if (!k) continue;
    try {
      out[k] = decodeURIComponent(v);
    } catch {
      // 非法 % 编码的 cookie 值直接跳过,避免整请求 500
      out[k] = v;
    }
  }
  return out;
}
