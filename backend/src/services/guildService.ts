import { z } from 'zod';
import type { DiscordApi } from '../discord/api.js';
import type { SnapshotRepository } from '../db/repositories.js';
import { AppError } from '../errors.js';
import type { ModerationLogService } from './moderationLogService.js';

export const VERIFICATION_LEVELS = [0, 1, 2, 3, 4] as const;
export const VERIFICATION_LEVEL_NAMES = [
  'None',
  'Low',
  'Medium',
  'High',
  'Highest',
] as const;

export const verificationRequestSchema = z.object({
  level: z.union([
    z.literal(0),
    z.literal(1),
    z.literal(2),
    z.literal(3),
    z.literal(4),
  ]),
});
export type VerificationRequest = z.infer<typeof verificationRequestSchema>;

export type ServerOverview = {
  guildId: string;
  name: string;
  iconUrl: string | null;
  memberCount: number | null;
  approximateMemberCount: number | null;
  onlineCount: number | null;
  channelCount: number;
  textChannelCount: number;
  categoryCount: number;
  voiceChannelCount: number;
  botPresent: boolean;
  botMemberCount: number | null;
  verificationLevel: number;
  verificationLevelName: string;
};

export class GuildService {
  constructor(
    private readonly api: DiscordApi,
    private readonly snapshots: SnapshotRepository,
    private readonly moderationLog: ModerationLogService,
  ) {}

  async getOverview(guildId: string, botUserId: string): Promise<ServerOverview> {
    const guild = await this.api.getGuild(guildId, true);
    const channels = await this.api.getGuildChannels(guildId);

    const botPresent = await this.checkBotPresence(guildId, botUserId);

    const verificationLevel = guild.verification_level ?? 0;
    return {
      guildId,
      name: guild.name,
      iconUrl: guild.icon ? `https://cdn.discordapp.com/icons/${guild.id}/${guild.icon}.png` : null,
      memberCount: guild.member_count ?? null,
      approximateMemberCount: guild.approximate_member_count ?? null,
      onlineCount: guild.approximate_presence_count ?? null,
      channelCount: channels.length,
      textChannelCount: channels.filter((channel) => channel.type === 0).length,
      categoryCount: channels.filter((channel) => channel.type === 4).length,
      voiceChannelCount: channels.filter((channel) => channel.type === 2).length,
      botPresent,
      botMemberCount: guild.member_count ?? null,
      verificationLevel,
      verificationLevelName: VERIFICATION_LEVEL_NAMES[verificationLevel] ?? 'Unknown',
    };
  }

  private async checkBotPresence(guildId: string, botUserId: string): Promise<boolean> {
    try {
      const member = await this.api.getGuildMember(guildId, botUserId);
      return member.user?.id === botUserId;
    } catch {
      return false;
    }
  }

  async setVerificationLevel(
    guildId: string,
    actorId: string | null,
    request: VerificationRequest,
  ) {
    const guild = await this.api.updateGuild(guildId, { verification_level: request.level });
    await this.moderationLog.record({
      guildId,
      action: 'Verification level changed',
      actorId,
      targetId: null,
      detail: VERIFICATION_LEVEL_NAMES[request.level] ?? String(request.level),
      success: true,
    });
    return {
      verificationLevel: guild.verification_level ?? request.level,
      verificationLevelName:
        VERIFICATION_LEVEL_NAMES[guild.verification_level ?? request.level] ?? 'Unknown',
    };
  }

  /** Records today's member, presence and channel counts for the insights chart. */
  async collectSnapshot(guildId: string): Promise<void> {
    const guild = await this.api.getGuild(guildId, true);
    const channels = await this.api.getGuildChannels(guildId);
    const day = new Date().toISOString().slice(0, 10);
    this.snapshots.upsert({
      guildId,
      day,
      memberCount: guild.approximate_member_count ?? guild.member_count ?? 0,
      onlineCount: guild.approximate_presence_count ?? 0,
      channelCount: channels.length,
    });
  }

  listInsights(guildId: string) {
    return this.snapshots.list(guildId);
  }

  async requireGuildExists(guildId: string): Promise<void> {
    const guild = await this.api.getGuild(guildId, false);
    if (!guild.id) {
      throw AppError.notFound(`Server ${guildId} was not found.`);
    }
  }
}
