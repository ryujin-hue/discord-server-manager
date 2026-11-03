/**
 * Bindings and configuration for the Cloudflare deployment.
 *
 * There is no `process.env` on Workers: everything comes from `env` (vars and
 * secrets bound in wrangler.toml / the Pages dashboard). Nothing here is a
 * hardcoded production domain.
 */

export interface Env {
  /** Cloudflare D1 database (bound in wrangler.toml). */
  DB: D1Database;
  /** Public Discord application id (a var, not a secret). */
  DISCORD_CLIENT_ID: string;
  /** Bot token (secret). Required for every REST endpoint that acts on Discord. */
  DISCORD_BOT_TOKEN?: string;
  /** Discord application public key (secret), for Interactions signature checks. */
  DISCORD_PUBLIC_KEY?: string;
  /** Comma separated CORS allowlist. Empty means same-origin only. */
  ALLOWED_ORIGINS?: string;
  /** Optional override; otherwise derived from the incoming request URL. */
  PUBLIC_BASE_URL?: string;
  /** Optional bot user id; resolved lazily from /users/@me when empty. */
  BOT_USER_ID?: string;
  /** "true" advertises that Gateway-backed features are unavailable. */
  GATEWAY_ADVERTISE_UNAVAILABLE?: string;
}

/** The public HTTPS base URL of this deployment, without a trailing slash. */
export function publicBaseUrl(env: Env, request: Request): string {
  const configured = (env.PUBLIC_BASE_URL ?? '').trim().replace(/\/+$/, '');
  if (configured.length > 0) {
    return configured;
  }
  return new URL(request.url).origin;
}

export function allowedOrigins(env: Env): string[] {
  return (env.ALLOWED_ORIGINS ?? '')
    .split(',')
    .map((origin) => origin.trim().replace(/\/+$/, ''))
    .filter((origin) => origin.length > 0);
}

export function gatewayUnavailable(env: Env): { connected: boolean; error?: string } {
  return env.GATEWAY_ADVERTISE_UNAVAILABLE === 'false'
    ? { connected: false, error: 'gateway_disabled' }
    : { connected: false, error: 'gateway_unavailable_on_workers' };
}

/**
 * The original Node backend resolved the bot id once at startup. Workers have
 * no startup, so prefer the configured value and otherwise resolve it lazily.
 */
export async function resolveBotUserId(
  env: Env,
  getCurrentUser: () => Promise<{ id: string }>,
): Promise<string> {
  const configured = (env.BOT_USER_ID ?? '').trim();
  if (configured.length > 0) {
    return configured;
  }
  try {
    return (await getCurrentUser()).id;
  } catch {
    return 'unknown';
  }
}

export function requireBotToken(env: Env): string {
  const token = env.DISCORD_BOT_TOKEN;
  if (!token) {
    throw new Error('DISCORD_BOT_TOKEN is not configured for this environment.');
  }
  return token;
}
