import { z } from 'zod';
import type { DiscordApi } from '../discord/api';
import type { Repositories, ScheduledAnnouncement } from '../db';
import type { ModerationLogService } from './moderationLog';

export const scheduleAnnouncementSchema = z.object({
  channelId: z.string().min(1),
  content: z.string().min(1).max(2000),
  scheduledAt: z.string().datetime({ offset: true }),
});
export type ScheduleAnnouncementRequest = z.infer<typeof scheduleAnnouncementSchema>;

export type InviteSummary = {
  code: string; uses: number; inviterId: string | null;
  channelId: string | null; createdAt: string; joins: number;
};
export type InviteJoinSummary = {
  memberId: string; inviteCode: string | null; inviterId: string | null; joinedAt: string;
};

export class EngagementService {
  constructor(
    private readonly api: DiscordApi,
    private readonly repos: Repositories,
    private readonly moderationLog: ModerationLogService,
  ) {}

  async schedule(
    guildId: string,
    actorId: string | null,
    request: ScheduleAnnouncementRequest,
  ): Promise<ScheduledAnnouncement> {
    const scheduledAt = new Date(request.scheduledAt);
    if (Number.isNaN(scheduledAt.getTime())) throw new Error('Invalid schedule timestamp.');

    const announcement: ScheduledAnnouncement = {
      id: crypto.randomUUID(),
      guildId,
      channelId: request.channelId,
      content: request.content,
      scheduledAt: scheduledAt.toISOString(),
      createdBy: actorId ?? 'system',
      status: 'pending',
      sentAt: null,
      error: null,
    };
    await this.repos.announcements.insert(announcement);
    await this.moderationLog.record({
      guildId, action: 'Announcement scheduled', actorId,
      targetId: request.channelId, detail: announcement.scheduledAt, success: true,
    });
    return announcement;
  }

  async list(guildId: string): Promise<ScheduledAnnouncement[]> {
    return this.repos.announcements.listByGuild(guildId);
  }

  async cancel(guildId: string, actorId: string | null, announcementId: string) {
    await this.repos.announcements.updateStatus(announcementId, 'cancelled', null);
    await this.moderationLog.record({
      guildId, action: 'Announcement cancelled', actorId,
      targetId: announcementId, detail: null, success: true,
    });
    return { announcementId, status: 'cancelled' as const };
  }

  async sendAnnouncement(announcement: ScheduledAnnouncement): Promise<boolean> {
    try {
      await this.api.sendChannelMessage(announcement.channelId, { content: announcement.content });
      await this.repos.announcements.updateStatus(announcement.id, 'sent', null);
      return true;
    } catch (error) {
      await this.repos.announcements.updateStatus(
        announcement.id,
        'failed',
        error instanceof Error ? error.message : 'Unknown error',
      );
      return false;
    }
  }

  async pendingAnnouncements(): Promise<ScheduledAnnouncement[]> {
    return this.repos.announcements.listPending();
  }

  async refreshInvites(guildId: string): Promise<void> {
    const invites = await this.api.listGuildInvites(guildId);
    for (const invite of invites) {
      await this.repos.invites.upsert({
        guildId,
        code: invite.code,
        uses: invite.uses,
        inviterId: invite.inviter?.id ?? null,
        channelId: invite.channel_id ?? null,
        createdAt: invite.created_at ?? new Date().toISOString(),
      });
    }
  }

  async listInvites(guildId: string): Promise<InviteSummary[]> {
    const joins = await this.repos.invites.listJoinsByGuild(guildId);
    const invites = await this.repos.invites.listByGuild(guildId);
    return invites.map((invite) => ({
      code: invite.code,
      uses: invite.uses,
      inviterId: invite.inviterId,
      channelId: invite.channelId,
      createdAt: invite.createdAt,
      joins: joins.filter((join) => join.inviteCode === invite.code).length,
    }));
  }

  async listJoins(guildId: string): Promise<InviteJoinSummary[]> {
    const joins = await this.repos.invites.listJoinsByGuild(guildId);
    return joins.map((join) => ({
      memberId: join.memberId,
      inviteCode: join.inviteCode,
      inviterId: join.inviterId,
      joinedAt: join.joinedAt,
    }));
  }

  async recordJoin(input: {
    guildId: string; memberId: string; inviteCode: string | null; inviterId: string | null;
  }): Promise<void> {
    await this.repos.invites.recordJoin({ ...input, joinedAt: new Date().toISOString() });
  }
}
