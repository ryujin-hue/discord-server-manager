import { createHash } from 'node:crypto';
import type { DiscordApi, DiscordUserGuild } from '../discord/api.js';
import { guildAdministratorOrManage } from '../discord/permissions.js';
import { AppError } from '../errors.js';
import { DiscordApiError } from '../discord/rest.js';

export type GuildAccess = {
  guildId: string;
  guild: DiscordUserGuild;
  /** Identifies the caller. Resolved from the guild owner id or the matching guild record. */
  callerId: string | null;
};

type CacheEntry = {
  expiresAt: number;
  guilds: DiscordUserGuild[];
};

export function tokenFingerprint(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

export class AccessGuard {
  private readonly cache = new Map<string, CacheEntry>();

  constructor(
    private readonly api: DiscordApi,
    private readonly ttlMs = 60_000,
    private readonly knownGuilds?: { remember(guildIds: readonly string[]): void },
  ) {}

  /** Resolves the bearer token from an Authorization header. */
  static extractBearer(header: string | undefined): string {
    if (header === undefined) {
      throw AppError.unauthorized('Authorization header is missing.');
    }
    const match = /^Bearer\s+(.+)$/i.exec(header.trim());
    if (!match || match[1] === undefined || match[1].trim() === '') {
      throw AppError.unauthorized('Authorization header must use the Bearer scheme.');
    }
    return match[1].trim();
  }

  async requireGuild(authorizationHeader: string | undefined, guildId: string): Promise<GuildAccess> {
    const token = AccessGuard.extractBearer(authorizationHeader);
    const guilds = await this.listGuilds(token);
    const guild = guilds.find((candidate) => candidate.id === guildId);

    if (!guild) {
      throw AppError.forbidden('You do not administer this server.');
    }

    const permissions = BigInt(guild.permissions);
    if (!guild.owner && !guildAdministratorOrManage(permissions)) {
      throw AppError.forbidden(
        'Administering this server requires the owner role, Administrator or Manage Server.',
      );
    }

    return { guildId, guild, callerId: guild.owner_id ?? null };
  }

  /** Lists the caller's guilds, using a 60 second cache keyed by a SHA-256 of the token. */
  async listGuilds(token: string): Promise<DiscordUserGuild[]> {
    const key = tokenFingerprint(token);
    const cached = this.cache.get(key);
    if (cached && cached.expiresAt > Date.now()) {
      return cached.guilds;
    }

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
    this.knownGuilds?.remember(guilds.map((guild) => guild.id));
    return guilds;
  }

  clearCache(): void {
    this.cache.clear();
  }
}
