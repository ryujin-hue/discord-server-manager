import { AppError } from './errors';

type Row = { window_start: number; count: number };

/**
 * D1-backed fixed-window rate limiter for sensitive endpoints (OAuth2 callback,
 * authorize, Interactions). Durable across isolates, unlike an in-memory Map.
 *
 * This is defence in depth: Cloudflare WAF rate limiting rules should also be
 * configured for the deployment (see docs/DEPLOYMENT.md).
 */
export async function enforceRateLimit(
  db: D1Database,
  bucketKey: string,
  limit: number,
  windowSeconds: number,
  now = Date.now(),
): Promise<void> {
  const windowMs = windowSeconds * 1000;

  await db
    .prepare(
      `INSERT INTO rate_limit_counters (bucket_key, window_start, count)
       VALUES (?, ?, 1)
       ON CONFLICT (bucket_key) DO UPDATE SET
         window_start = CASE
           WHEN (window_start + ?) <= ? THEN excluded.window_start
           ELSE window_start END,
         count = CASE
           WHEN (window_start + ?) <= ? THEN 1
           ELSE count + 1 END`,
    )
    .bind(bucketKey, now, windowMs, now, windowMs, now)
    .run();

  const row = await db
    .prepare('SELECT window_start, count FROM rate_limit_counters WHERE bucket_key = ?')
    .bind(bucketKey)
    .first<Row>();

  if (row && row.count > limit) {
    const retryAfter = Math.max(1, Math.ceil((row.window_start + windowMs - now) / 1000));
    throw AppError.rateLimited('Too many requests. Please try again later.', retryAfter);
  }

  // Opportunistic cleanup so the table cannot grow without bound.
  await db
    .prepare('DELETE FROM rate_limit_counters WHERE window_start < ?')
    .bind(now - 24 * 60 * 60 * 1000)
    .run();
}

/** Rate-limit key that never contains a token or personal data. */
export function clientBucket(request: Request, prefix: string): string {
  const ip =
    request.headers.get('CF-Connecting-IP') ??
    request.headers.get('X-Forwarded-For')?.split(',')[0]?.trim() ??
    'unknown';
  return `${prefix}:${ip}`;
}
