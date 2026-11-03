import { AppError } from '../errors.js';

export type DiscordHttpMethod = 'GET' | 'POST' | 'PATCH' | 'PUT' | 'DELETE';

export type DiscordRequestOptions = {
  method: DiscordHttpMethod;
  /** Route template used for rate-limit bucketing, e.g. `/guilds/{guild_id}/members/{user_id}`. */
  route: string;
  /** Concrete request path, e.g. `/guilds/123/members/456`. */
  path: string;
  /** Values of the major parameters that Discord uses to split rate-limit buckets. */
  majorParams?: readonly (string | number)[];
  query?: Readonly<Record<string, string | number | boolean | undefined>>;
  body?: unknown;
  headers?: Readonly<Record<string, string>>;
  /** Overrides the client token, used when acting on behalf of an end user. */
  token?: string;
  parse?: 'json' | 'text' | 'none';
};

export interface DiscordHttpClient {
  request<T>(options: DiscordRequestOptions): Promise<T>;
}

export type DiscordApiErrorInit = {
  status: number;
  message: string;
  code?: number | undefined;
  retryAfter?: number | undefined;
  body?: unknown;
};

export class DiscordApiError extends Error {
  readonly status: number;
  readonly code: number | undefined;
  readonly retryAfter: number | undefined;
  readonly body: unknown;

  constructor(init: DiscordApiErrorInit) {
    super(init.message);
    this.name = 'DiscordApiError';
    this.status = init.status;
    this.code = init.code;
    this.retryAfter = init.retryAfter;
    this.body = init.body;
  }
}

export type DiscordRestClientOptions = {
  token?: string | undefined;
  baseUrl?: string | undefined;
  fetchImpl?: typeof fetch | undefined;
  sleep?: ((ms: number) => Promise<void>) | undefined;
  /** Upper bound for how long a request may wait inline for a rate limit reset. */
  maxWaitMs?: number | undefined;
  userAgent?: string | undefined;
};

type BucketState = {
  remaining: number;
  resetAt: number;
};

const DEFAULT_BASE_URL = 'https://discord.com/api/v10';
const DEFAULT_MAX_WAIT_MS = 5000;

export class DiscordRestClient implements DiscordHttpClient {
  private readonly token: string | undefined;
  private readonly baseUrl: string;
  private readonly fetchImpl: typeof fetch;
  private readonly sleep: (ms: number) => Promise<void>;
  private readonly maxWaitMs: number;
  private readonly userAgent: string;
  private readonly buckets = new Map<string, BucketState>();

  constructor(options: DiscordRestClientOptions = {}) {
    this.token = options.token;
    this.baseUrl = options.baseUrl ?? DEFAULT_BASE_URL;
    this.fetchImpl = options.fetchImpl ?? fetch;
    this.sleep = options.sleep ?? ((ms: number) => new Promise((resolve) => setTimeout(resolve, ms)));
    this.maxWaitMs = options.maxWaitMs ?? DEFAULT_MAX_WAIT_MS;
    this.userAgent = options.userAgent ?? 'DiscordServerManager/1.0 (backend)';
  }

  async request<T>(options: DiscordRequestOptions): Promise<T> {
    const bucketKey = this.bucketKey(options);
    const maxAttempts = 5;

    for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
      await this.waitForBucket(bucketKey);

      const response = await this.send(options);
      this.updateBucket(bucketKey, response.headers);

      if (response.status === 429) {
        const retryAfter = this.parseRetryAfter(response);
        if (retryAfter !== undefined && retryAfter * 1000 <= this.maxWaitMs) {
          await this.sleep(retryAfter * 1000);
          continue;
        }
        throw new DiscordApiError({
          status: 429,
          message: 'Discord rate limit exceeded.',
          retryAfter: retryAfter ?? 1,
          body: await response.json().catch(() => undefined),
        });
      }

      if (response.status === 204 || response.status === 205) {
        return undefined as T;
      }

      const contentType = response.headers.get('content-type') ?? '';
      const parse = options.parse ?? (contentType.includes('application/json') ? 'json' : 'text');

      if (!response.ok) {
        const body = await response.json().catch(() => undefined);
        throw this.toApiError(response.status, body);
      }

      if (parse === 'none') {
        return undefined as T;
      }
      if (parse === 'text') {
        return (await response.text()) as T;
      }
      return (await response.json()) as T;
    }

    throw new DiscordApiError({ status: 429, message: 'Discord rate limit retry budget exhausted.', retryAfter: 1 });
  }

  private async send(options: DiscordRequestOptions): Promise<Response> {
    const url = new URL(this.baseUrl + options.path);
    for (const [key, value] of Object.entries(options.query ?? {})) {
      if (value !== undefined) {
        url.searchParams.set(key, String(value));
      }
    }

    const headers: Record<string, string> = {
      Accept: 'application/json',
      'User-Agent': this.userAgent,
      ...options.headers,
    };
    const token = options.token ?? this.token;
    if (token) {
      headers.Authorization = `Bot ${token}`;
    }

    let body: string | undefined;
    if (options.body !== undefined) {
      body = JSON.stringify(options.body);
      headers['Content-Type'] = 'application/json';
    }

    return this.fetchImpl(url.toString(), {
      method: options.method,
      headers,
      ...(body === undefined ? {} : { body }),
    });
  }

  private bucketKey(options: DiscordRequestOptions): string {
    return `${options.method}:${options.route}:${(options.majorParams ?? []).join('/')}`;
  }

  private updateBucket(bucketKey: string, headers: Headers): void {
    const remaining = Number(headers.get('x-ratelimit-remaining'));
    const resetAfter = Number(headers.get('x-ratelimit-reset-after'));
    if (!Number.isFinite(remaining) || !Number.isFinite(resetAfter)) {
      return;
    }
    this.buckets.set(bucketKey, {
      remaining,
      resetAt: Date.now() + resetAfter * 1000,
    });
  }

  private async waitForBucket(bucketKey: string): Promise<void> {
    const bucket = this.buckets.get(bucketKey);
    if (!bucket || bucket.remaining > 0) {
      return;
    }
    const waitMs = bucket.resetAt - Date.now();
    if (waitMs <= 0) {
      bucket.remaining = 1;
      return;
    }
    if (waitMs > this.maxWaitMs) {
      throw new DiscordApiError({
        status: 429,
        message: 'Discord rate limit exceeded.',
        retryAfter: Math.ceil(waitMs / 1000),
      });
    }
    await this.sleep(waitMs);
    bucket.remaining = 1;
  }

  private parseRetryAfter(response: Response): number | undefined {
    const header = response.headers.get('retry-after');
    if (header) {
      const parsed = Number(header);
      if (Number.isFinite(parsed)) {
        return parsed;
      }
    }
    const resetAfter = Number(response.headers.get('x-ratelimit-reset-after'));
    if (Number.isFinite(resetAfter)) {
      return resetAfter;
    }
    return undefined;
  }

  private toApiError(status: number, body: unknown): DiscordApiError {
    const parsedBody = body as { code?: number; message?: string } | undefined;
    const code = typeof parsedBody?.code === 'number' ? parsedBody.code : undefined;
    const message =
      typeof parsedBody?.message === 'string' && parsedBody.message.length > 0
        ? parsedBody.message
        : `Discord request failed with status ${status}.`;
    return new DiscordApiError({ status, message, code, body });
  }
}

export function mapDiscordError(error: unknown): AppError {
  if (error instanceof DiscordApiError) {
    if (error.status === 429) {
      return AppError.rateLimited(error.message, error.retryAfter ?? 1);
    }
    if (error.status === 401) {
      return AppError.unauthorized(error.message, error.code);
    }
    if (error.status === 403) {
      return AppError.forbidden(error.message, error.code);
    }
    if (error.status === 404) {
      return AppError.notFound(error.message, error.code);
    }
    if (error.status >= 500) {
      return AppError.upstream(error.message, error.code);
    }
    return new AppError({
      code: 'upstream_error',
      statusCode: 502,
      message: error.message,
      discordCode: error.code,
    });
  }
  return AppError.internal(error instanceof Error ? error.message : 'Unexpected error.');
}
