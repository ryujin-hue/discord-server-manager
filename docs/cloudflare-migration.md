# Cloudflare Migration Guide — XAX Server Manager

This document describes the migration of the Node/Fastify/SQLite/Discord.js backend to Cloudflare Pages Functions + D1, what changed, and what is now a documented limitation.

## Architecture

```
┌──────────────────────┐     ┌────────────────────────────────────────────┐
│  Flutter app (Dart)  │     │  Cloudflare Pages                          │
│  Android / iOS       │────▶│  ├── dist/          (static landing site)  │
│                      │     │  └── functions/     (Pages Functions API)  │
│  OAuth2 PKCE flow    │     │      ├── [[path]].ts (route dispatcher)    │
│  Bearer token auth   │     │      └── _lib/       (services, repos,     │
└──────────────────────┘     │                     auth, http, rateLimit) │
                             │                                            │
                             │  D1 (SQLite-compatible)                    │
                             │  ├── guild_settings, warnings, ...         │
                             │  └── auth_states, rate_limit, cron_state   │
                             │                                            │
                             │  Cron Worker (scheduled announcements +    │
                             │  daily snapshots)                          │
                             └────────────────────────────────────────────┘
                                          │
                                          ▼
                             ┌────────────────────────────┐
                             │  Discord REST API v10      │
                             │  (Bot token for REST calls)│
                             └────────────────────────────┘
```

### What moved to Cloudflare

| Original (Node) | Cloudflare equivalent |
|---|---|
| Fastify HTTP server | Pages Functions (`functions/[[path]].ts`) |
| `better-sqlite3` | D1 (`functions/_lib/db.ts`) |
| `setInterval` scheduler | Cron Triggers (`workers/scheduler/`) |
| `process.env` config | `wrangler.toml` `[vars]` + Cloudflare Secrets |
| `node:crypto` | WebCrypto (`crypto.subtle`, `crypto.randomUUID`) |
| In-process token cache | Per-isolate memory cache (best-effort) |

### What did NOT move (documented limitations)

The Discord Gateway uses a **persistent WebSocket** with heartbeats, session resume, and real-time event processing. Cloudflare Workers/Pages Functions are request-scoped and cannot maintain a long-lived WebSocket connection reliably. The following features depend on live Gateway events and have **no Cloudflare-native equivalent**:

| Feature | Gateway dependency | Status |
|---|---|---|
| Welcome/goodbye messages | `GUILD_MEMBER_ADD` / `GUILD_MEMBER_REMOVE` | **Unavailable** |
| Reaction roles (via reactions) | `MESSAGE_REACTION_ADD` | **Unavailable** (reaction-role *setup* still works; only the live reaction listener is gone) |
| Invite tracking (live attribution) | `INVITE_CREATE` / `INVITE_DELETE` | **Unavailable** (invite listing still works via REST) |
| Persistent bot presence | Gateway connection | **Unavailable** (bot shows offline unless it joins via a separate always-on process) |

**Button-role interactions** are the one exception: Discord can deliver button clicks to an HTTPS endpoint via the Interactions API. This is fully implemented at `POST /interactions` with Ed25519 signature verification.

If you need live Gateway features, you must run a separate always-on process (e.g., a small Node worker on a VPS or Cloudflare's forthcoming WebSocket Durable Objects). The migration does not fake this.

## OAuth2 flow

The flow is **Public Client + PKCE** (no Client Secret), unchanged from the original:

1. Flutter app generates a PKCE verifier, code challenge, and state (`lib/features/auth/data/pkce.dart`).
2. App calls `GET /auth/authorize?state=...&code_challenge=...&code_challenge_method=S256`.
3. Server registers `state` as single-use in D1 (`auth_states` table) and 302-redirects to Discord.
4. User authorizes on Discord.
5. Discord redirects to `GET /auth/mobile-callback?code=...&state=...`.
6. Server consumes the state (replay protection via atomic UPDATE), then 302-redirects to `my-discord-manager://oauth2/callback?code=...&state=...`.
7. App exchanges the code for a token directly with Discord (`/oauth2/token`).
8. App uses the access token as `Bearer` for all REST API calls.

The redirect URI is derived from the deployment URL (`PUBLIC_BASE_URL` or request origin), so it is never hardcoded before the real Pages domain is known.

## Security

- **No secrets in git**: `DISCORD_BOT_TOKEN`, `DISCORD_PUBLIC_KEY` are set via `wrangler pages secret put` and never appear in `wrangler.toml` or source.
- **OAuth2 state**: single-use, SHA-256 hashed, 10-minute TTL, atomic consumption in D1.
- **Rate limiting**: D1 fixed-window counters for `/auth/authorize`, `/auth/mobile-callback`, and `/interactions`.
- **CORS**: restricted to configured `ALLOWED_ORIGINS`; native mobile requests (no `Origin` header) get no CORS headers.
- **Token auth scheme fix**: per-request OAuth2 user tokens now use `Bearer` (not `Bot`); only the configured bot token uses `Bot`.
- **No token persistence**: tokens are never written to D1 or logs. Only a SHA-256 fingerprint is used as an in-memory cache key.

## Deployment steps

### 1. Create D1 databases

```bash
npx wrangler d1 create discord-server-manager          # note the database_id
npx wrangler d1 create discord-server-manager-preview   # note the preview database_id
```

Set the returned IDs as GitHub secrets: `D1_DATABASE_ID`, `D1_PREVIEW_DATABASE_ID`.

### 2. Apply migrations

```bash
npx wrangler d1 migrations apply discord-server-manager --remote --config wrangler.toml
```

### 3. Set Cloudflare secrets

```bash
npx wrangler pages secret put DISCORD_BOT_TOKEN   --project-name=discord-server-manager
npx wrangler pages secret put DISCORD_PUBLIC_KEY  --project-name=discord-server-manager
```

### 4. Configure GitHub secrets

In `Settings → Secrets and variables → Actions`:

| Secret | Value |
|---|---|
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token with Pages + Workers + D1 permissions |
| `CLOUDFLARE_ACCOUNT_ID` | Your Cloudflare account id |
| `D1_DATABASE_ID` | From step 1 |
| `D1_PREVIEW_DATABASE_ID` | From step 1 |
| `DISCORD_CLIENT_ID` | Discord application public client id |

### 5. Push to `main`

The `deploy-cloudflare.yml` workflow builds the site, applies migrations, and deploys both Pages and the Cron Worker.

### 6. Configure Discord Developer Portal

- **OAuth2 → General**: Redirect URI = `https://<your-pages-domain>/auth/mobile-callback`
- **OAuth2 → General**: Scopes = `identify`, `guilds`
- **Interactions Endpoint URL** (optional, for button roles): `https://<your-pages-domain>/interactions`
- **Bot**: Invite with Administrator or the permissions listed in `functions/_lib/discord/permissions.ts`

### 7. Flutter production build

```bash
# env.json (not committed)
{
  "DISCORD_CLIENT_ID": "your-client-id",
  "BACKEND_URL": "https://<your-pages-domain>",
  "GITHUB_REPO": "ryujin-hue/discord-server-manager"
}

flutter build apk --release --dart-define-from-file=env.json
```
