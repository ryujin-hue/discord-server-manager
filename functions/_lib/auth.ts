import { z } from 'zod';
import type { AppContext } from './context';
import { publicBaseUrl } from './env';
import { AppError } from './errors';
import { failure, ok, parse } from './http';
import { clientBucket, enforceRateLimit } from './rateLimit';

/** The one and only approved redirect destination. Never taken from input. */
export const MOBILE_CALLBACK = 'my-discord-manager://oauth2/callback';
export const CALLBACK_ALLOWED_PARAMS = ['code', 'state', 'error', 'error_description'] as const;

const STATE_TTL_SECONDS = 600;
const AUTHORIZE_RATE_LIMIT = { limit: 20, windowSeconds: 60 };
const CALLBACK_RATE_LIMIT = { limit: 30, windowSeconds: 60 };

const stateSchema = z.string().min(16).max(256).regex(/^[A-Za-z0-9._~-]+$/);
const codeChallengeSchema = z.string().min(43).max(128).regex(/^[A-Za-z0-9._~-]+$/);

const authorizeQuerySchema = z.object({
  state: stateSchema,
  code_challenge: codeChallengeSchema,
  code_challenge_method: z.literal('S256'),
});

function hexToBytes(hex: string): Uint8Array {
  if (!/^[0-9a-fA-F]+$/.test(hex) || hex.length % 2 !== 0) {
    throw new Error('Invalid hex value.');
  }
  const bytes = new Uint8Array(hex.length / 2);
  for (let index = 0; index < bytes.length; index += 1) {
    bytes[index] = Number.parseInt(hex.slice(index * 2, index * 2 + 2), 16);
  }
  return bytes;
}

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, '0')).join('');
}

/**
 * Single-use, short-lived OAuth2 state store.
 *
 * Only a SHA-256 hash of the state is stored, never the state itself and never
 * any token. The atomic UPDATE guarantees a state can be consumed exactly once,
 * which is the replay protection that a stateless Pages Function otherwise lacks.
 */
export class AuthStateStore {
  constructor(private readonly db: D1Database) {}

  async issue(state: string, now = Date.now()): Promise<void> {
    const hash = await sha256Hex(state);
    await this.db
      .prepare(
        `INSERT INTO auth_states (state_hash, created_at, expires_at, consumed_at)
         VALUES (?, ?, ?, NULL)
         ON CONFLICT (state_hash) DO UPDATE SET
           created_at = excluded.created_at,
           expires_at = excluded.expires_at,
           consumed_at = NULL`,
      )
      .bind(hash, now, now + STATE_TTL_SECONDS * 1000)
      .run();
  }

  /** Returns true when the state existed, was unexpired and was not used before. */
  async consume(state: string, now = Date.now()): Promise<boolean> {
    const hash = await sha256Hex(state);
    const result = await this.db
      .prepare(
        `UPDATE auth_states SET consumed_at = ?
         WHERE state_hash = ? AND consumed_at IS NULL AND expires_at >= ?`,
      )
      .bind(now, hash, now)
      .run();
    return Number(result.meta?.changes ?? 0) === 1;
  }

  /** True when a state was registered through /auth/authorize. */
  async isKnown(state: string, now = Date.now()): Promise<boolean> {
    const hash = await sha256Hex(state);
    const row = await this.db
      .prepare('SELECT expires_at FROM auth_states WHERE state_hash = ?')
      .bind(hash)
      .first<Record<string, unknown>>();
    return row !== null && Number(row.expires_at) >= now;
  }

  async purgeExpired(now = Date.now()): Promise<void> {
    await this.db.prepare('DELETE FROM auth_states WHERE expires_at < ?').bind(now).run();
  }
}

function redirectToMobile(params: URLSearchParams): Response {
  const target = new URL(MOBILE_CALLBACK);
  const query = params.toString();
  if (query.length > 0) target.search = query;
  return new Response(null, {
    status: 302,
    headers: { Location: target.toString(), 'Cache-Control': 'no-store', 'Referrer-Policy': 'no-referrer' },
  });
}

function safeDescription(value: string | null): string | null {
  if (value === null) return null;
  return value.slice(0, 500);
}

/**
 * GET /auth/authorize
 *
 * Server-built Discord authorization URL. The public client still owns the
 * PKCE verifier and its own state (see lib/features/auth/data/pkce.dart); the
 * server additionally registers the state as single-use in D1. The redirect_uri
 * is derived from the request, so no domain is hardcoded before deployment.
 */
export async function handleAuthorize(ctx: AppContext): Promise<Response> {
  const { env, request } = ctx;
  const url = new URL(request.url);
  await enforceRateLimit(env.DB, clientBucket(request, 'auth:authorize'), AUTHORIZE_RATE_LIMIT.limit, AUTHORIZE_RATE_LIMIT.windowSeconds);

  const query = Object.fromEntries(url.searchParams.entries());
  const parsed = authorizeQuerySchema.safeParse(query);
  if (!parsed.success) throw AppError.validation('Invalid authorization request.');

  const store = new AuthStateStore(env.DB);
  await store.issue(parsed.data.state);
  await store.purgeExpired();

  const base = publicBaseUrl(env, request);
  const authorize = new URL('https://discord.com/oauth2/authorize');
  authorize.searchParams.set('client_id', env.DISCORD_CLIENT_ID);
  authorize.searchParams.set('response_type', 'code');
  authorize.searchParams.set('redirect_uri', `${base}/auth/mobile-callback`);
  authorize.searchParams.set('scope', 'identify guilds');
  authorize.searchParams.set('code_challenge', parsed.data.code_challenge);
  authorize.searchParams.set('code_challenge_method', 'S256');
  authorize.searchParams.set('state', parsed.data.state);

  return new Response(null, {
    status: 302,
    headers: { Location: authorize.toString(), 'Cache-Control': 'no-store', 'Referrer-Policy': 'no-referrer' },
  });
}

/**
 * GET /auth/mobile-callback — the Discord redirect URI.
 *
 * Hardened version of backend/src/routes/auth.ts:
 *  - only whitelisted parameters are forwarded (no open redirect, no token leakage),
 *  - Discord error responses are validated and forwarded to the app,
 *  - state issued by /auth/authorize is consumed exactly once (replay protection),
 *  - rate limited,
 *  - the destination is a fixed custom scheme,
 *  - legacy clients (older APKs that build the Discord URL themselves) are
 *    still forwarded so existing installations keep working; they continue to
 *    validate state client-side as before.
 */
export async function handleMobileCallback(ctx: AppContext): Promise<Response> {
  const { env, request } = ctx;
  const url = new URL(request.url);
  await enforceRateLimit(env.DB, clientBucket(request, 'auth:callback'), CALLBACK_RATE_LIMIT.limit, CALLBACK_RATE_LIMIT.windowSeconds);

  const forwarded = new URLSearchParams();
  for (const name of CALLBACK_ALLOWED_PARAMS) {
    const value = url.searchParams.get(name);
    if (value !== null && value.length > 0) {
      forwarded.set(name, name === 'error_description' ? (safeDescription(value) ?? '') : value.slice(0, 2048));
    }
  }

  const error = url.searchParams.get('error');
  const state = url.searchParams.get('state');
  const code = url.searchParams.get('code');

  if (error) {
    if (state) {
      const store = new AuthStateStore(env.DB);
      if (await store.isKnown(state)) await store.consume(state);
    }
    return redirectToMobile(forwarded);
  }

  if (!state || !code) {
    forwarded.delete('code');
    forwarded.set('error', 'invalid_request');
    forwarded.set('error_description', 'Discord did not return a code and state.');
    return redirectToMobile(forwarded);
  }

  const store = new AuthStateStore(env.DB);
  const known = await store.isKnown(state);
  if (known && !(await store.consume(state))) {
    forwarded.delete('code');
    forwarded.set('error', 'invalid_state');
    forwarded.set('error_description', 'The sign in response was already used or expired.');
    return redirectToMobile(forwarded);
  }

  // Only code and state are ever forwarded on success.
  const success = new URLSearchParams();
  success.set('code', code);
  success.set('state', state);
  return redirectToMobile(success);
}

export async function handleCallbackConfig(ctx: AppContext): Promise<Response> {
  const base = publicBaseUrl(ctx.env, ctx.request);
  return ok({ redirectUri: `${base}/auth/mobile-callback`, callbackScheme: 'my-discord-manager' });
}

/* -------------------------------------------------------------------------- */
/* Discord Interactions Endpoint (Cloudflare-native Gateway alternative)      */
/* -------------------------------------------------------------------------- */

export async function verifyDiscordSignature(
  publicKeyHex: string,
  signatureHex: string,
  timestamp: string,
  rawBody: string,
): Promise<boolean> {
  try {
    const key = await crypto.subtle.importKey(
      'raw',
      hexToBytes(publicKeyHex),
      { name: 'Ed25519' },
      false,
      ['verify'],
    );
    return await crypto.subtle.verify(
      { name: 'Ed25519' },
      key,
      hexToBytes(signatureHex),
      new TextEncoder().encode(timestamp + rawBody),
    );
  } catch {
    return false;
  }
}

type InteractionBody = {
  type?: number;
  guild_id?: string;
  member?: { user?: { id?: string } };
  user?: { id?: string };
  data?: { custom_id?: string };
};

const interactionBodySchema = z.object({
  type: z.number().int().optional(),
  guild_id: z.string().optional(),
  member: z.object({ user: z.object({ id: z.string().optional() }).optional() }).optional(),
  user: z.object({ id: z.string().optional() }).optional(),
  data: z.object({ custom_id: z.string().optional() }).optional(),
});

function ephemeral(content: string): Response {
  return new Response(JSON.stringify({ type: 4, data: { content, flags: 64 } }), {
    status: 200,
    headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' },
  });
}

/**
 * POST /interactions
 *
 * Button-role interactions no longer need the persistent Gateway WebSocket:
 * Discord can deliver them to an HTTPS endpoint. This is the only Gateway
 * feature with a true Cloudflare-native equivalent. Guild member/reaction/
 * invite events have no webhook equivalent and remain a documented limitation.
 */
export async function handleInteractions(ctx: AppContext): Promise<Response> {
  const { env, request } = ctx;
  const publicKey = env.DISCORD_PUBLIC_KEY ?? '';
  if (publicKey.length === 0) {
    return failure({ code: 'internal_error', message: 'Interactions are not configured.' }, 503);
  }

  const signature = request.headers.get('X-Signature-Ed25519') ?? '';
  const timestamp = request.headers.get('X-Signature-Timestamp') ?? '';
  const rawBody = await request.text();
  if (!(await verifyDiscordSignature(publicKey, signature, timestamp, rawBody))) {
    return failure({ code: 'unauthorized', message: 'Invalid interaction signature.' }, 401);
  }

  let parsedBody: unknown;
  try {
    parsedBody = JSON.parse(rawBody) as unknown;
  } catch {
    return failure({ code: 'validation_failed', message: 'Invalid JSON body.' }, 400);
  }
  const body = parse(interactionBodySchema, parsedBody) as InteractionBody;

  if (body.type === 1) {
    return new Response(JSON.stringify({ type: 1 }), {
      status: 200,
      headers: { 'Content-Type': 'application/json; charset=utf-8' },
    });
  }

  if (body.type !== 3) return ephemeral('Unsupported interaction.');

  const guildId = body.guild_id;
  const userId = body.member?.user?.id ?? body.user?.id;
  const customId = body.data?.custom_id;
  if (!guildId || !userId || !customId?.startsWith('role:')) return ephemeral('Unsupported component.');
  const roleId = customId.slice('role:'.length);
  if (roleId.length === 0) return ephemeral('Unsupported component.');

  await enforceRateLimit(env.DB, `interactions:${guildId}:${userId}`, 15, 60);

  try {
    const member = await ctx.api.getGuildMember(guildId, userId);
    if (member.roles.includes(roleId)) {
      await ctx.api.removeMemberRole(guildId, userId, roleId);
      return ephemeral('Role removed.');
    }
    await ctx.api.addMemberRole(guildId, userId, roleId);
    return ephemeral('Role granted.');
  } catch {
    await ctx.moderationLog.record({
      guildId,
      action: 'Button role',
      actorId: userId,
      targetId: roleId,
      detail: 'The role could not be granted.',
      success: false,
    });
    return ephemeral('The role could not be granted.');
  }
}
