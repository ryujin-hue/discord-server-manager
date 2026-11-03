import { z } from 'zod';
import type { DiscordApi, DiscordChannel } from '../discord/api';
import { PermissionBits } from '../discord/permissions';
import { AppError } from '../errors';
import type { Repositories } from '../db';
import type { ModerationLogService } from './moderationLog';

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

type PreviousOverwrite = { id: string; type: number; allow: string; deny: string };

export class ModerationService {
  constructor(
    private readonly api: DiscordApi,
    private readonly repos: Repositories,
    private readonly moderationLog: ModerationLogService,
  ) {}

  async ban(guildId: string, actorId: string | null, request: BanRequest): Promise<{ userId: string }> {
    await this.api.banMember(guildId, request.userId, {
      deleteMessageSeconds: request.deleteMessageSeconds,
      ...(request.reason === undefined ? {} : { reason: request.reason }),
    });
    await this.log(guildId, actorId, 'Ban', request.userId, request.reason ?? null);
    return { userId: request.userId };
  }

  async unban(guildId: string, actorId: string | null, userId: string): Promise<{ userId: string }> {
    await this.api.unbanMember(guildId, userId);
    await this.log(guildId, actorId, 'Unban', userId, null);
    return { userId };
  }

  async kick(guildId: string, actorId: string | null, request: KickRequest): Promise<{ userId: string }> {
    await this.api.kickMember(guildId, request.userId, request.reason);
    await this.log(guildId, actorId, 'Kick', request.userId, request.reason ?? null);
    return { userId: request.userId };
  }

  async timeout(guildId: string, actorId: string | null, request: TimeoutRequest): Promise<{ userId: string; until: string }> {
    const until = new Date(Date.now() + request.durationSeconds * 1000).toISOString();
    await this.api.timeoutMember(guildId, request.userId, until, request.reason);
    await this.log(guildId, actorId, 'Timeout', request.userId, request.reason ?? null);
    return { userId: request.userId, until };
  }

  async clearTimeout(guildId: string, actorId: string | null, userId: string): Promise<{ userId: string }> {
    await this.api.timeoutMember(guildId, userId, null);
    await this.log(guildId, actorId, 'Clear timeout', userId, null);
    return { userId };
  }

  async purge(guildId: string, actorId: string | null, request: PurgeRequest): Promise<{ channelId: string; deleted: number }> {
    await this.api.bulkDeleteMessages(request.channelId, request.messageIds);
    await this.log(guildId, actorId, 'Purge', request.channelId, `${request.messageIds.length} messages`);
    return { channelId: request.channelId, deleted: request.messageIds.length };
  }

  async lockdown(guildId: string, actorId: string | null, request: LockdownRequest): Promise<{ channelIds: string[] }> {
    const settings = await this.repos.settings.get(guildId);
    const locked = new Set(settings.lockedChannelIds);
    const deny = (PermissionBits.SEND_MESSAGES | PermissionBits.ADD_REACTIONS).toString();

    for (const channelId of request.channelIds) {
      const channel = await this.api.getChannel(channelId);
      const existing = channel.permission_overwrites?.find((o) => o.id === EVERYONE_OVERWRITE_ID);
      await this.repos.lockdowns.save({
        guildId,
        channelId,
        previousOverwrite: JSON.stringify(existing ?? null),
        createdAt: new Date().toISOString(),
      });
      await this.api.updateChannelOverwrite(channelId, EVERYONE_OVERWRITE_ID, { type: 0, allow: '0', deny });
      locked.add(channelId);
    }

    settings.lockedChannelIds = [...locked];
    await this.repos.settings.save(guildId, settings);
    await this.log(guildId, actorId, 'Lockdown', request.channelIds.join(','), `${request.channelIds.length} channels`);
    return { channelIds: request.channelIds };
  }

  async unlock(guildId: string, actorId: string | null, request: UnlockRequest): Promise<{ channelIds: string[] }> {
    const settings = await this.repos.settings.get(guildId);
    const locked = new Set(settings.lockedChannelIds);
    const stored = new Map(
      (await this.repos.lockdowns.list(guildId)).map((entry) => [entry.channelId, entry.previousOverwrite]),
    );

    for (const channelId of request.channelIds) {
      const raw = stored.get(channelId);
      const previous = raw === undefined ? null : (JSON.parse(raw) as PreviousOverwrite | null);
      if (previous) {
        await this.api.updateChannelOverwrite(channelId, previous.id, {
          type: previous.type,
          allow: previous.allow,
          deny: previous.deny,
        });
      } else {
        await this.api.deleteChannelOverwrite(channelId, EVERYONE_OVERWRITE_ID);
      }
      await this.repos.lockdowns.remove(guildId, channelId);
      locked.delete(channelId);
    }

    settings.lockedChannelIds = [...locked];
    await this.repos.settings.save(guildId, settings);
    await this.log(guildId, actorId, 'Unlock', request.channelIds.join(','), `${request.channelIds.length} channels`);
    return { channelIds: request.channelIds };
  }

  async setSlowmode(guildId: string, actorId: string | null, request: SlowmodeRequest): Promise<{ channelId: string; seconds: number }> {
    await this.api.updateChannel(request.channelId, { rate_limit_per_user: request.seconds });
    await this.updateSlowmodeSetting(guildId, request.channelId, request.seconds);
    await this.log(guildId, actorId, 'Slowmode', request.channelId, `${request.seconds}s`);
    return { channelId: request.channelId, seconds: request.seconds };
  }

  async massSlowmode(guildId: string, actorId: string | null, seconds: number): Promise<{ channelIds: string[] }> {
    const channels = await this.api.getGuildChannels(guildId);
    const textChannels = channels.filter((channel) => channel.type === 0);
    for (const channel of textChannels) {
      await this.api.updateChannel(channel.id, { rate_limit_per_user: seconds });
    }
    for (const channel of textChannels) {
      await this.updateSlowmodeSetting(guildId, channel.id, seconds);
    }
    await this.log(guildId, actorId, 'Mass slowmode', null, `${textChannels.length} channels, ${seconds}s`);
    return { channelIds: textChannels.map((channel) => channel.id) };
  }

  async issueWarning(
    guildId: string,
    actorId: string | null,
    request: WarningRequest,
  ): Promise<{ warningId: number; warningCount: number; autoTimedOut: boolean }> {
    const warning = await this.repos.warnings.insert({
      guildId,
      userId: request.userId,
      reason: request.reason,
      warnedBy: actorId ?? 'system',
    });
    const warningCount = await this.repos.warnings.countForUser(guildId, request.userId);
    const settings = await this.repos.settings.get(guildId);
    let autoTimedOut = false;

    if (
      request.autoTimeout &&
      settings.autoTimeoutThreshold !== null &&
      warningCount >= settings.autoTimeoutThreshold &&
      settings.autoTimeoutDurationSeconds !== null
    ) {
      const until = new Date(Date.now() + settings.autoTimeoutDurationSeconds * 1000).toISOString();
      await this.api.timeoutMember(guildId, request.userId, until, 'Automatic timeout after warnings');
      autoTimedOut = true;
    }

    await this.log(
      guildId,
      actorId,
      autoTimedOut ? 'Warning (auto-timeout)' : 'Warning',
      request.userId,
      request.reason,
    );
    return { warningId: warning.id, warningCount, autoTimedOut };
  }

  async listWarnings(guildId: string) {
    return this.repos.warnings.listByGuild(guildId);
  }

  static assertChannelBelongsToGuild(channels: DiscordChannel[], channelId: string): DiscordChannel {
    const channel = channels.find((candidate) => candidate.id === channelId);
    if (!channel) throw AppError.notFound(`Channel ${channelId} is not part of this server.`);
    return channel;
  }

  private async updateSlowmodeSetting(guildId: string, channelId: string, seconds: number): Promise<void> {
    const settings = await this.repos.settings.get(guildId);
    if (seconds === 0) delete settings.slowmodeSecondsByChannel[channelId];
    else settings.slowmodeSecondsByChannel[channelId] = seconds;
    await this.repos.settings.save(guildId, settings);
  }

  private async log(
    guildId: string,
    actorId: string | null,
    action: string,
    targetId: string | null,
    detail: string | null,
  ): Promise<void> {
    await this.moderationLog.record({ guildId, action, actorId, targetId, detail, success: true });
  }
}
