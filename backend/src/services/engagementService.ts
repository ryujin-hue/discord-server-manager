import { randomUUID } from 'node:crypto';
import { z } from 'zod';
import type { DiscordApi } from '../discord/api.js';
import type {
  AnnouncementRepository,
  InviteRepository,
  ScheduledAnnouncement,
} from '../db/repositories.js';
import type { ModerationLogService } from './moderationLogService.js';

export const scheduleAnnouncementSchema = z.object({
  channelId: z.string().min(1),
  content: z.string().min(1).max(2000),
  scheduledAt: z.string().datetime({ offset: true }),
});
export type ScheduleAnnouncementRequest = z.infer<typeof scheduleAnnouncementSchema>;

export type InviteSummary = {
  code: string;
  uses: number;
  inviterId: string | null;
  channelId: string | null;
  createdAt: string;
  joins: number;
};

export type InviteJoinSummary = {
  memberId: string;
  inviteCode: string | null;
  inviterId: string | null;
  joinedAt: string;
};

export class EngagementService {
  constructor(
    private readonly api: DiscordApi,
    private readonly announcements: AnnouncementRepository,
    private readonly invites: InviteRepository,
    private readonly moderationLog: ModerationLogService,
  ) {}

  async schedule(
    guildId: string,
    actorId: string | null,
    request: ScheduleAnnouncementRequest,
  ): Promise<ScheduledAnnouncement> {
    const scheduledAt = new Date(request.scheduledAt);
    if (Number.isNaN(scheduledAt.getTime())) {
      throw new Error('Invalid schedule timestamp.');
    }
    const announcement: ScheduledAnnouncement = {
      id: randomUUID(),
      guildId,
      channelId: request.channelId,
      content: request.content,
      scheduledAt: scheduledAt.toISOString(),
      createdBy: actorId ?? 'system',
      status: 'pending',
      sentAt: null,
      error: null,
    };
    this.announcements.insert(announcement);
    await this.moderationLog.record({
      guildId,
      action: 'Announcement scheduled',
      actorId,
      targetId: request.channelId,
      detail: announcement.scheduledAt,
      success: true,
    });
    return announcement;
  }

  list(guildId: string): ScheduledAnnouncement[] {
    return this.announcements.listByGuild(guildId);
  }

  cancel(guildId: string, actorId: string | null, announcementId: string) {
    this.announcements.updateStatus(announcementId, 'cancelled', null);
    void this.moderationLog.record({
      guildId,
      action: 'Announcement cancelled',
      actorId,
      targetId: announcementId,
      detail: null,
      success: true,
    });
    return { announcementId, status: 'cancelled' as const };
  }

  /** Sends a due announcement. Returns false when the send failed. */
  async sendAnnouncement(announcement: ScheduledAnnouncement): Promise<boolean> {
    try {
      await this.api.sendChannelMessage(announcement.channelId, { content: announcement.content });
      this.announcements.updateStatus(announcement.id, 'sent', null);
      return true;
    } catch (error) {
      this.announcements.updateStatus(
        announcement.id,
        'failed',
        error instanceof Error ? error.message : 'Unknown error',
      );
      return false;
    }
  }

  pendingAnnouncements(): ScheduledAnnouncement[] {
    return this.announcements.listPending();
  }

  /** Refreshes the cached invite list of a guild from Discord. */
  async refreshInvites(guildId: string): Promise<void> {
    const invites = await this.api.listGuildInvites(guildId);
    for (const invite of invites) {
      this.invites.upsert({
        guildId,
        code: invite.code,
        uses: invite.uses,
        inviterId: invite.inviter?.id ?? null,
        channelId: invite.channel_id ?? null,
        createdAt: invite.created_at ?? new Date().toISOString(),
      });
    }
  }

  listInvites(guildId: string): InviteSummary[] {
    const joins = this.invites.listJoinsByGuild(guildId);
    return this.invites.listByGuild(guildId).map((invite) => ({
      code: invite.code,
      uses: invite.uses,
      inviterId: invite.inviterId,
      channelId: invite.channelId,
      createdAt: invite.createdAt,
      joins: joins.filter((join) => join.inviteCode === invite.code).length,
    }));
  }

  listJoins(guildId: string): InviteJoinSummary[] {
    return this.invites.listJoinsByGuild(guildId).map((join) => ({
      memberId: join.memberId,
      inviteCode: join.inviteCode,
      inviterId: join.inviterId,
      joinedAt: join.joinedAt,
    }));
  }

  recordJoin(input: {
    guildId: string;
    memberId: string;
    inviteCode: string | null;
    inviterId: string | null;
  }): void {
    this.invites.recordJoin({ ...input, joinedAt: new Date().toISOString() });
  }
}
