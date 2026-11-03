import { z } from 'zod';
import { AppError } from './errors';
import { DiscordApiError, mapDiscordError } from './discord/rest';
import { allowedOrigins, type Env } from './env';

const JSON_HEADERS = { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' };

export function ok(data: unknown, status = 200, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify({ data }), {
    status,
    headers: { ...JSON_HEADERS, ...headers },
  });
}

export function failure(error: {
  code: string; message: string; discordCode?: number; retryAfter?: number;
}, status: number, headers: Record<string, string> = {}): Response {
  const body: Record<string, unknown> = { code: error.code, message: error.message };
  if (error.discordCode !== undefined) body.discordCode = error.discordCode;
  if (error.retryAfter !== undefined) body.retryAfter = error.retryAfter;
  return new Response(JSON.stringify({ error: body }), {
    status,
    headers: { ...JSON_HEADERS, ...headers },
  });
}

/** Maps any thrown value to the exact error envelope the Flutter app expects. */
export function errorResponse(error: unknown, headers: Record<string, string> = {}): Response {
  if (error instanceof AppError) {
    return failure(
      { code: error.code, message: error.message, discordCode: error.discordCode, retryAfter: error.retryAfter },
      error.statusCode,
      headers,
    );
  }
  if (error instanceof DiscordApiError) {
    const mapped = mapDiscordError(error);
    return failure(
      { code: mapped.code, message: mapped.message, discordCode: mapped.discordCode, retryAfter: mapped.retryAfter },
      mapped.statusCode,
      headers,
    );
  }
  if (error instanceof z.ZodError) {
    return failure(
      { code: 'validation_failed', message: error.issues.map((issue) => issue.message).join('; ') },
      400,
      headers,
    );
  }
  // Never expose internal error details to a client.
  return failure({ code: 'internal_error', message: 'Unexpected internal error.' }, 500, headers);
}

export function notFound(method: string, pathname: string, headers: Record<string, string> = {}): Response {
  return failure(
    { code: 'not_found', message: `Route ${method} ${pathname} does not exist.` },
    404,
    headers,
  );
}

export function parse<T>(schema: z.ZodType<T>, value: unknown): T {
  const result = schema.safeParse(value);
  if (!result.success) {
    const message = result.error.issues
      .map((issue) => `${issue.path.join('.') || 'body'}: ${issue.message}`)
      .join('; ');
    throw AppError.validation(message);
  }
  return result.data;
}

const MAX_BODY_BYTES = 1_000_000;

/** Reads and validates a JSON body. Rejects empty, oversized and non-JSON bodies. */
export async function readJson(request: Request): Promise<unknown> {
  const contentType = request.headers.get('content-type') ?? '';
  if (!contentType.toLowerCase().includes('application/json')) {
    throw AppError.validation('Content-Type must be application/json.');
  }
  const raw = await request.text();
  if (new TextEncoder().encode(raw).byteLength > MAX_BODY_BYTES) {
    throw AppError.validation('Request body is too large.');
  }
  try {
    return JSON.parse(raw) as unknown;
  } catch {
    throw AppError.validation('Request body is not valid JSON.');
  }
}

/** CORS headers for an allowed browser origin. Same-origin/native requests get none. */
export function corsHeaders(env: Env, request: Request): Record<string, string> {
  const origin = request.headers.get('Origin');
  if (!origin) return {};
  const allowed = allowedOrigins(env);
  if (!allowed.includes(origin.trim().replace(/\/+$/, ''))) return {};
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
    'Access-Control-Max-Age': '600',
    Vary: 'Origin',
  };
}

export function withHeaders(response: Response, headers: Record<string, string>): Response {
  if (Object.keys(headers).length === 0) return response;
  const merged = new Headers(response.headers);
  for (const [key, value] of Object.entries(headers)) merged.set(key, value);
  return new Response(response.body, { status: response.status, statusText: response.statusText, headers: merged });
}

/** Constant-time-ish comparison of two ASCII secrets. */
export function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let difference = 0;
  for (let index = 0; index < a.length; index += 1) {
    difference |= a.charCodeAt(index) ^ b.charCodeAt(index);
  }
  return difference === 0;
}
