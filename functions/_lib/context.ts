import type { Env } from './env';
import { requireBotToken } from './env';
import { createRepositories, type Repositories } from './db';
import { DiscordApi } from './discord/api';
import { DiscordRestClient, type DiscordHttpClient } from './discord/rest';
import { AccessGuard } from './services/accessGuard';
import { ModerationLogService } from './services/moderationLog';
import { ModerationService } from './services/moderation';
import { AutoModService } from './services/automod';
import { AccessService } from './services/access';
import { EngagementService } from './services/engagement';
import { ToolService } from './services/tools';
import { GuildService } from './services/guild';

export interface AppContext {
  env: Env;
  request: Request;
  repos: Repositories;
  api: DiscordApi;
  guard: AccessGuard;
  moderation: ModerationService;
  automod: AutoModService;
  access: AccessService;
  engagement: EngagementService;
  tools: ToolService;
  guild: GuildService;
  moderationLog: ModerationLogService;
  /** Resolves the bot user id lazily (no startup hook on Workers). */
  botUserId: () => Promise<string>;
}

export type ContextOptions = {
  env: Env;
  request: Request;
  /** Injectable for unit tests. Defaults to a real Discord REST client. */
  httpClient?: DiscordHttpClient;
};

/**
 * Builds the per-request object graph. Cheap to create: it holds no state that
 * must survive between requests (all durable state lives in D1).
 */
export function createContext(options: ContextOptions): AppContext {
  const { env, request } = options;
  const repos = createRepositories(env.DB);
  const httpClient =
    options.httpClient ??
    new DiscordRestClient({ token: requireBotToken(env), userAgent: 'XAXServerManager/1.0 (cloudflare)' });
  const api = new DiscordApi(httpClient);
  const moderationLog = new ModerationLogService(api, repos);

  return {
    env,
    request,
    repos,
    api,
    guard: new AccessGuard(api, repos),
    moderation: new ModerationService(api, repos, moderationLog),
    automod: new AutoModService(api, moderationLog),
    access: new AccessService(api, moderationLog),
    engagement: new EngagementService(api, repos, moderationLog),
    tools: new ToolService(api, moderationLog),
    guild: new GuildService(api, repos, moderationLog),
    moderationLog,
    botUserId: async () => {
      const configured = (env.BOT_USER_ID ?? '').trim();
      if (configured.length > 0) return configured;
      try {
        return (await api.getCurrentUser()).id;
      } catch {
        return 'unknown';
      }
    },
  };
}
