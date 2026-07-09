# AgentDock API (Cloudflare Workers)

独立部署到 **`api.agentdockstatus.app`**，与官网静态站 `www.agentdockstatus.app` 分离。

## 能力

| 接口 | 说明 |
|------|------|
| `POST /v1/event` | App 启动 / 心跳（匿名 `install_id`） |
| `POST /v1/crash` | 崩溃上报 |
| `GET /v1/download/:file` | 记下载后 302 到官网 pkg |
| `POST /v1/admin/login` | 看板登录（账号密码只在 Worker 后端） |
| `GET /v1/admin/stats` | 汇总数据（需登录 cookie） |
| `GET /v1/admin/crashes` | 最近崩溃列表 |

## 一次性部署

```bash
cd api
npm install
cp .dev.vars.example .dev.vars   # 本地调试用

# 1) 创建 D1，把输出的 database_id 填进 wrangler.toml
npm run db:create

# 2) 迁移表结构
npm run db:migrate

# 3) 生产密钥（不要提交仓库）
npx wrangler secret put ADMIN_PASSWORD
npx wrangler secret put SESSION_SECRET

# 4) 部署(会按 wrangler.toml 绑定 api.agentdockstatus.app)
npm run deploy
```

DNS：`api.agentdockstatus.app` 需在同一 Cloudflare zone；`custom_domain = true` 会自动处理。

看板：部署官网后打开 `https://www.agentdockstatus.app/admin.html`（账号 `admin`，密码为你设的 secret）。

## 本地调试

```bash
npm run db:migrate:local
npm run dev
# http://127.0.0.1:8787/health
```

## 隐私

只收：`install_id`、版本、系统版本、架构、事件类型、崩溃短栈。  
不收：会话内容、路径、token、邮箱、机器名。
