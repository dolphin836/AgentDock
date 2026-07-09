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
      console.error("unhandled", err);
      return json({ error: "internal_error" }, 500);
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

  const token = await mintSession(env.SESSION_SECRET, env.ADMIN_USER);
  const res = json({ ok: true });
  res.headers.append(
    "Set-Cookie",
    cookie("ad_session", token, { maxAge: SESSION_TTL_SEC, httpOnly: true }),
  );
  return res;
}

async function adminLogout(_request: Request, env: Env): Promise<Response> {
  const res = json({ ok: true });
  res.headers.append("Set-Cookie", cookie("ad_session", "", { maxAge: 0, httpOnly: true }));
  // env 引用避免 unused 警告(logout 不需要 DB)
  void env;
  return res;
}

async function requireAdmin(request: Request, env: Env): Promise<Response | null> {
  if (!env.SESSION_SECRET) return json({ error: "admin_not_configured" }, 503);
  const token = parseCookie(request.headers.get("Cookie") ?? "").ad_session;
  if (!token || !(await verifySession(env.SESSION_SECRET, token, env.ADMIN_USER))) {
    return json({ error: "unauthorized" }, 401);
  }
  return null;
}

async function adminStats(request: Request, env: Env): Promise<Response> {
  const denied = await requireAdmin(request, env);
  if (denied) return denied;

  const [
    downloadsTotal,
    downloadsToday,
    downloads7d,
    launchesTotal,
    activeToday,
    active7d,
    active30d,
    crashesTotal,
    crashesToday,
    downloadsByFile,
    launchesByVersion,
  ] = await Promise.all([
    count(env, `SELECT COUNT(*) AS n FROM downloads`),
    count(env, `SELECT COUNT(*) AS n FROM downloads WHERE created_at >= datetime('now', '-1 day')`),
    count(env, `SELECT COUNT(*) AS n FROM downloads WHERE created_at >= datetime('now', '-7 day')`),
    count(env, `SELECT COUNT(*) AS n FROM events WHERE event = 'launch'`),
    count(env, `SELECT COUNT(DISTINCT install_id) AS n FROM events WHERE created_at >= datetime('now', '-1 day')`),
    count(env, `SELECT COUNT(DISTINCT install_id) AS n FROM events WHERE created_at >= datetime('now', '-7 day')`),
    count(env, `SELECT COUNT(DISTINCT install_id) AS n FROM events WHERE created_at >= datetime('now', '-30 day')`),
    count(env, `SELECT COUNT(*) AS n FROM crashes`),
    count(env, `SELECT COUNT(*) AS n FROM crashes WHERE created_at >= datetime('now', '-1 day')`),
    env.DB.prepare(
      `SELECT filename, COUNT(*) AS n FROM downloads GROUP BY filename ORDER BY n DESC LIMIT 20`,
    ).all<{ filename: string; n: number }>(),
    env.DB.prepare(
      `SELECT app_version, COUNT(DISTINCT install_id) AS n
       FROM events WHERE event = 'launch' AND app_version IS NOT NULL
       GROUP BY app_version ORDER BY n DESC LIMIT 20`,
    ).all<{ app_version: string; n: number }>(),
  ]);

  return json({
    downloads: { total: downloadsTotal, today: downloadsToday, last_7d: downloads7d },
    usage: {
      launches_total: launchesTotal,
      active_today: activeToday,
      active_7d: active7d,
      active_30d: active30d,
    },
    crashes: { total: crashesTotal, today: crashesToday },
    downloads_by_file: downloadsByFile.results ?? [],
    launches_by_version: launchesByVersion.results ?? [],
  });
}

async function adminCrashes(
  request: Request,
  env: Env,
  url: URL,
): Promise<Response> {
  const denied = await requireAdmin(request, env);
  if (denied) return denied;

  const limit = Math.min(100, Math.max(1, Number(url.searchParams.get("limit") ?? "30") || 30));
  const rows = await env.DB.prepare(
    `SELECT id, install_id, app_version, os_version, arch, name, reason, stack, created_at
     FROM crashes ORDER BY id DESC LIMIT ?`,
  )
    .bind(limit)
    .all();

  return json({ crashes: rows.results ?? [] });
}

// ─── Session (HMAC, no DB) ───────────────────────────────────────────

async function mintSession(secret: string, user: string): Promise<string> {
  const exp = Math.floor(Date.now() / 1000) + SESSION_TTL_SEC;
  const payload = `${user}.${exp}`;
  const sig = await hmacHex(secret, payload);
  return `${payload}.${sig}`;
}

async function verifySession(secret: string, token: string, user: string): Promise<boolean> {
  const parts = token.split(".");
  if (parts.length !== 3) return false;
  const [u, expStr, sig] = parts;
  if (u !== user) return false;
  const exp = Number(expStr);
  if (!Number.isFinite(exp) || exp < Math.floor(Date.now() / 1000)) return false;
  const expect = await hmacHex(secret, `${u}.${expStr}`);
  return timingSafeEqual(sig, expect);
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
  return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function sha256Hex(input: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", enc.encode(input));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
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
  const site = env.SITE_ORIGIN.replace(/\/+$/, "");
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
  const headers = new Headers(res.headers);
  if (origin && allowed.has(origin)) {
    headers.set("Access-Control-Allow-Origin", origin);
    headers.set("Access-Control-Allow-Credentials", "true");
    headers.set("Access-Control-Allow-Headers", "Content-Type");
    headers.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    headers.set("Vary", "Origin");
  }
  return new Response(res.body, { status: res.status, statusText: res.statusText, headers });
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
  opts: { maxAge: number; httpOnly: boolean },
): string {
  const parts = [
    `${name}=${encodeURIComponent(value)}`,
    "Path=/",
    `Max-Age=${opts.maxAge}`,
    "SameSite=None",
    "Secure",
  ];
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
    if (k) out[k] = decodeURIComponent(v);
  }
  return out;
}

async function count(env: Env, sql: string): Promise<number> {
  const row = await env.DB.prepare(sql).first<{ n: number }>();
  return Number(row?.n ?? 0);
}
