import { z } from 'zod';
import type { DiscordApi, DiscordChannel } from '../discord/api.js';
import { PermissionBits } from '../discord/permissions.js';
import type { SettingsRepository, WarningRepository } from '../db/repositories.js';
import { AppError } from '../errors.js';
import type { ModerationLogService } from './moderationLogService.js';

export const purgeRequestSchema = z.object({
  channelId: z.string().min(1),
  messageIds: z.array(z.string().min(1)).min(2).max(100),
  confirm: z.literal(true),
});

export const banRequestSchema = z.object({
  userId: z.string().min(1),
  reason: z.string().max(512).optional(),
  deleteMessageSeconds: z.number().int().min(0).max(7 * 24 * 3600).default(0),
  confirm: z.literal(true),
});

export const kickRequestSchema = z.object({
  userId: z.string().min(1),
  reason: z.string().max(512).optional(),
  confirm: z.literal(true),
});

export const timeoutRequestSchema = z.object({
  userId: z.string().min(1),
  durationSeconds: z.number().int().min(1).max(28 * 24 * 3600),
  reason: z.string().max(512).optional(),
  confirm: z.literal(true),
});

export const warningRequestSchema = z.object({
  userId: z.string().min(1),
  reason: z.string().min(1).max(512),
  autoTimeout: z.boolean().default(false),
});

export const lockdownRequestSchema = z.object({
  channelIds: z.array(z.string().min(1)).min(1),
  confirm: z.literal(true),
});

export const unlockRequestSchema = z.object({
  channelIds: z.array(z.string().min(1)).min(1),
  confirm: z.literal(true),
});

export const slowmodeRequestSchema = z.object({
  channelId: z.string().min(1),
  seconds: z.number().int().min(0).max(21_600),
});

export type PurgeRequest = z.infer<typeof purgeRequestSchema>;
export type BanRequest = z.infer<typeof banRequestSchema>;
export type KickRequest = z.infer<typeof kickRequestSchema>;
export type TimeoutRequest = z.infer<typeof timeoutRequestSchema>;
export type WarningRequest = z.infer<typeof warningRequestSchema>;
export type LockdownRequest = z.infer<typeof lockdownRequestSchema>;
export type UnlockRequest = z.infer<typeof unlockRequestSchema>;
export type SlowmodeRequest = z.infer<typeof slowmodeRequestSchema>;

const EVERYONE_OVERWRITE_ID = '@everyone';

export class ModerationService {
  constructor(
    private readonly api: DiscordApi,
    private readonly settings: SettingsRepository,
    private readonly warnings: WarningRepository,
    private readonly moderationLog: ModerationLogService,
  ) {}

  async ban(guildId: string, actorId: string | null, request: BanRequest): Promise<{ userId: string }> {
    await this.api.banMember(guildId, request.userId, {
      deleteMessageSeconds: request.deleteMessageSeconds,
      ...(request.reason === undefined ? {} : { reason: request.reason }),
    });
    await this.moderationLog.record({
      guildId,
      action: 'Ban',
      actorId,
      targetId: request.userId,
      detail: request.reason ?? null,
      success: true,
    });
    return { userId: request.userId };
  }

  async unban(guildId: string, actorId: string | null, userId: string): Promise<{ userId: string }> {
    await this.api.unbanMember(guildId, userId);
    await this.moderationLog.record({
      guildId,
      action: 'Unban',
      actorId,
      targetId: userId,
      detail: null,
      success: true,
    });
    return { userId };
  }

  async kick(guildId: string, actorId: string | null, request: KickRequest): Promise<{ userId: string }> {
    await this.api.kickMember(
      guildId,
      request.userId,
      request.reason === undefined ? undefined : request.reason,
    );
    await this.moderationLog.record({
      guildId,
      action: 'Kick',
      actorId,
      targetId: request.userId,
      detail: request.reason ?? null,
      success: true,
    });
    return { userId: request.userId };
  }

  async timeout(
    guildId: string,
    actorId: string | null,
    request: TimeoutRequest,
  ): Promise<{ userId: string; until: string }> {
    const until = new Date(Date.now() + request.durationSeconds * 1000).toISOString();
    await this.api.timeoutMember(
      guildId,
      request.userId,
      until,
      request.reason === undefined ? undefined : request.reason,
    );
    await this.moderationLog.record({
      guildId,
      action: 'Timeout',
      actorId,
      targetId: request.userId,
      detail: request.reason ?? null,
      success: true,
    });
    return { userId: request.userId, until };
  }

  async clearTimeout(
    guildId: string,
    actorId: string | null,
    userId: string,
  ): Promise<{ userId: string }> {
    await this.api.timeoutMember(guildId, userId, null);
    await this.moderationLog.record({
      guildId,
      action: 'Clear timeout',
      actorId,
      targetId: userId,
      detail: null,
      success: true,
    });
    return { userId };
  }

  async purge(
    guildId: string,
    actorId: string | null,
    request: PurgeRequest,
  ): Promise<{ channelId: string; deleted: number }> {
    await this.api.bulkDeleteMessages(request.channelId, request.messageIds);
    await this.moderationLog.record({
      guildId,
      action: 'Purge',
      actorId,
      targetId: request.channelId,
      detail: `${request.messageIds.length} messages`,
      success: true,
    });
    return { channelId: request.channelId, deleted: request.messageIds.length };
  }

  /**
   * Denies SEND_MESSAGES for @everyone on the selected channels. The previous
   * overwrite is persisted so an unlock restores the exact previous state.
   */
  async lockdown(
    guildId: string,
    actorId: string | null,
    request: LockdownRequest,
    lockRepository: {
      save(entry: {
        guildId: string;
        channelId: string;
        previousOverwrite: string;
        createdAt: string;
      }): void;
    },
  ): Promise<{ channelIds: string[] }> {
    const settings = this.settings.get(guildId);
    const locked = new Set(settings.lockedChannelIds);
    const deny = (PermissionBits.SEND_MESSAGES | PermissionBits.ADD_REACTIONS).toString();
    const allow = '0';

    for (const channelId of request.channelIds) {
      const channel = await this.api.getChannel(channelId);
      const existing = channel.permission_overwrites?.find(
        (overwrite) => overwrite.id === EVERYONE_OVERWRITE_ID,
      );
      lockRepository.save({
        guildId,
        channelId,
        previousOverwrite: JSON.stringify(existing ?? null),
        createdAt: new Date().toISOString(),
      });
      await this.api.updateChannelOverwrite(channelId, EVERYONE_OVERWRITE_ID, {
        type: 0,
        allow,
        deny,
      });
      locked.add(channelId);
    }

    settings.lockedChannelIds = [...locked];
    this.settings.save(guildId, settings);

    await this.moderationLog.record({
      guildId,
      action: 'Lockdown',
      actorId,
      targetId: request.channelIds.join(','),
      detail: `${request.channelIds.length} channels`,
      success: true,
    });

    return { channelIds: request.channelIds };
  }

  async unlock(
    guildId: string,
    actorId: string | null,
    request: UnlockRequest,
    lockRepository: {
      list(guildId: string): { channelId: string; previousOverwrite: string }[];
      remove(guildId: string, channelId: string): void;
    },
  ): Promise<{ channelIds: string[] }> {
    const settings = this.settings.get(guildId);
    const locked = new Set(settings.lockedChannelIds);
    const stored = new Map(
      lockRepository.list(guildId).map((entry) => [entry.channelId, entry.previousOverwrite]),
    );

    for (const channelId of request.channelIds) {
      const previousRaw = stored.get(channelId);
      const previous =
        previousRaw === undefined ? null : (JSON.parse(previousRaw) as DiscordChannel['permission_overwrites'] extends (infer T)[] | undefined ? T | null : never);
      if (previous) {
        await this.api.updateChannelOverwrite(channelId, previous.id, {
          type: previous.type,
          allow: previous.allow,
          deny: previous.deny,
        });
      } else {
        await this.api.deleteChannelOverwrite(channelId, EVERYONE_OVERWRITE_ID);
      }
      lockRepository.remove(guildId, channelId);
      locked.delete(channelId);
    }

    settings.lockedChannelIds = [...locked];
    this.settings.save(guildId, settings);

    await this.moderationLog.record({
      guildId,
      action: 'Unlock',
      actorId,
      targetId: request.channelIds.join(','),
      detail: `${request.channelIds.length} channels`,
      success: true,
    });

    return { channelIds: request.channelIds };
  }

  async setSlowmode(
    guildId: string,
    actorId: string | null,
    request: SlowmodeRequest,
  ): Promise<{ channelId: string; seconds: number }> {
    await this.api.updateChannel(request.channelId, {
      rate_limit_per_user: request.seconds,
    });
    const settings = this.settings.get(guildId);
    if (request.seconds === 0) {
      delete settings.slowmodeSecondsByChannel[request.channelId];
    } else {
      settings.slowmodeSecondsByChannel[request.channelId] = request.seconds;
    }
    this.settings.save(guildId, settings);
    await this.moderationLog.record({
      guildId,
      action: 'Slowmode',
      actorId,
      targetId: request.channelId,
      detail: `${request.seconds}s`,
      success: true,
    });
    return { channelId: request.channelId, seconds: request.seconds };
  }

  /** Applies slowmode to every text channel of the guild in one action. */
  async massSlowmode(
    guildId: string,
    actorId: string | null,
    seconds: number,
  ): Promise<{ channelIds: string[] }> {
    const channels = await this.api.getGuildChannels(guildId);
    const textChannels = channels.filter((channel) => channel.type === 0);
    for (const channel of textChannels) {
      await this.api.updateChannel(channel.id, { rate_limit_per_user: seconds });
    }
    const settings = this.settings.get(guildId);
    for (const channel of textChannels) {
      if (seconds === 0) {
        delete settings.slowmodeSecondsByChannel[channel.id];
      } else {
        settings.slowmodeSecondsByChannel[channel.id] = seconds;
      }
    }
    this.settings.save(guildId, settings);
    await this.moderationLog.record({
      guildId,
      action: 'Mass slowmode',
      actorId,
      targetId: null,
      detail: `${textChannels.length} channels, ${seconds}s`,
      success: true,
    });
    return { channelIds: textChannels.map((channel) => channel.id) };
  }

  async issueWarning(
    guildId: string,
    actorId: string | null,
    request: WarningRequest,
  ): Promise<{ warningId: number; warningCount: number; autoTimedOut: boolean }> {
    const warning = this.warnings.insert({
      guildId,
      userId: request.userId,
      reason: request.reason,
      warnedBy: actorId ?? 'system',
    });
    const warningCount = this.warnings.countForUser(guildId, request.userId);

    const settings = this.settings.get(guildId);
    const threshold = settings.autoTimeoutThreshold;
    let autoTimedOut = false;

    if (
      request.autoTimeout &&
      threshold !== null &&
      warningCount >= threshold &&
      settings.autoTimeoutDurationSeconds !== null
    ) {
      const until = new Date(Date.now() + settings.autoTimeoutDurationSeconds * 1000).toISOString();
      await this.api.timeoutMember(guildId, request.userId, until, 'Automatic timeout after warnings');
      autoTimedOut = true;
    }

    await this.moderationLog.record({
      guildId,
      action: autoTimedOut ? 'Warning (auto-timeout)' : 'Warning',
      actorId,
      targetId: request.userId,
      detail: request.reason,
      success: true,
    });

    return { warningId: warning.id, warningCount, autoTimedOut };
  }

  listWarnings(guildId: string): ReturnType<WarningRepository['listByGuild']> {
    return this.warnings.listByGuild(guildId);
  }

  static assertChannelBelongsToGuild(channels: DiscordChannel[], channelId: string): DiscordChannel {
    const channel = channels.find((candidate) => candidate.id === channelId);
    if (!channel) {
      throw AppError.notFound(`Channel ${channelId} is not part of this server.`);
    }
    return channel;
  }
}
