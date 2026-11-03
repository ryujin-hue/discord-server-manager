import type { DiscordHttpClient, DiscordRequestOptions } from '../src/discord/rest.js';
import type { BackendConfig } from '../src/config.js';

export type RecordedCall = {
  method: string;
  path: string;
  route: string;
  query: Readonly<Record<string, string | number | boolean | undefined>> | undefined;
  body: unknown;
  token: string | undefined;
};

type Responder = (call: RecordedCall) => unknown;

type Rule = {
  method: string;
  pattern: RegExp;
  responder: Responder;
};

/**
 * A scripted Discord HTTP client. Tests register responders for the endpoints
 * they exercise; every call is recorded for assertions.
 */
export class FakeDiscordHttp implements DiscordHttpClient {
  readonly calls: RecordedCall[] = [];
  private readonly rules: Rule[] = [];

  on(method: string, pattern: RegExp, responder: Responder | object): this {
    const resolved: Responder =
      typeof responder === 'function'
        ? (responder as Responder)
        : () => responder;
    this.rules.push({ method, pattern, responder: resolved });
    return this;
  }

  callsTo(method: string, fragment: string): RecordedCall[] {
    return this.calls.filter(
      (call) => call.method === method && call.path.includes(fragment),
    );
  }

  request<T>(options: DiscordRequestOptions): Promise<T> {
    const call: RecordedCall = {
      method: options.method,
      path: options.path,
      route: options.route,
      query: options.query,
      body: options.body,
      token: options.token ?? undefined,
    };
    this.calls.push(call);

    for (const rule of this.rules) {
      if (rule.method === options.method && rule.pattern.test(options.path)) {
        return Promise.resolve(rule.responder(call) as T);
      }
    }
    return Promise.reject(
      new Error(`FakeDiscordHttp has no responder for ${options.method} ${options.path}`),
    );
  }
}

export function testConfig(overrides: Partial<BackendConfig> = {}): BackendConfig {
  return {
    discordClientId: '1234567890',
    discordBotToken: 'bot-token-for-tests',
    publicBaseUrl: 'https://backend.test',
    gatewayEnabled: false,
    port: 0,
    dbPath: ':memory:',
    ...overrides,
  };
}

export function guildPayload(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    id: 'guild-1',
    name: 'Test Guild',
    icon: null,
    owner: true,
    owner_id: 'user-1',
    permissions: '8',
    member_count: 120,
    approximate_member_count: 120,
    approximate_presence_count: 30,
    verification_level: 1,
    ...overrides,
  };
}
