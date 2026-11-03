import type { DiscordApi, DiscordUserGuild } from '../discord/api';
import { guildAdministratorOrManage } from '../discord/permissions';
import { AppError } from '../errors';
import { DiscordApiError } from '../discord/rest';
import type { Repositories } from '../db';

export type GuildAccess = {
  guildId: string;
  guild: DiscordUserGuild;
  callerId: string | null;
};

type CacheEntry = { expiresAt: number; guilds: DiscordUserGuild[] };

/** SHA-256 of a token, used only as an in-memory cache key. Never persisted. */
export async function tokenFingerprint(token: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(token));
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, '0')).join('');
}

/**
 * Port of backend/src/services/accessGuard.ts.
 *
 * The 60 second cache stays in memory (per isolate). Workers have no shared
 * process memory, so a cache hit is best-effort; correctness never depends on
 * it and no token or token hash is ever written to D1 or to a log.
 */
export class AccessGuard {
  private readonly cache = new Map<string, CacheEntry>();

  constructor(
    private readonly api: DiscordApi,
    private readonly repos: Repositories,
    private readonly ttlMs = 60_000,
  ) {}

  static extractBearer(header: string | null | undefined): string {
    if (header === undefined || header === null) {
      throw AppError.unauthorized('Authorization header is missing.');
    }
    const match = /^Bearer\s+(.+)$/i.exec(header.trim());
    if (!match || match[1] === undefined || match[1].trim() === '') {
      throw AppError.unauthorized('Authorization header must use the Bearer scheme.');
    }
    return match[1].trim();
  }

  async requireGuild(authorizationHeader: string | null | undefined, guildId: string): Promise<GuildAccess> {
    const token = AccessGuard.extractBearer(authorizationHeader);
    const guilds = await this.listGuilds(token);
    const guild = guilds.find((candidate) => candidate.id === guildId);

    if (!guild) {
      throw AppError.forbidden('You do not administer this server.');
    }
    if (!guild.owner && !guildAdministratorOrManage(BigInt(guild.permissions))) {
      throw AppError.forbidden(
        'Administering this server requires the owner role, Administrator or Manage Server.',
      );
    }
    return { guildId, guild, callerId: guild.owner_id ?? null };
  }

  async listGuilds(token: string): Promise<DiscordUserGuild[]> {
    const key = await tokenFingerprint(token);
    const cached = this.cache.get(key);
    if (cached && cached.expiresAt > Date.now()) return cached.guilds;

    let guilds: DiscordUserGuild[];
    try {
      guilds = await this.api.listUserGuilds(token);
    } catch (error) {
      if (error instanceof DiscordApiError && error.status === 401) {
        throw AppError.unauthorized('The access token was rejected by Discord.', error.code);
      }
      throw error;
    }

    this.cache.set(key, { expiresAt: Date.now() + this.ttlMs, guilds });
    await this.repos.knownGuilds.remember(guilds.map((guild) => guild.id));
    return guilds;
  }

  clearCache(): void {
    this.cache.clear();
  }
}
