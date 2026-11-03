import type { SqliteDatabase } from './database.js';

export type ReactionRoleBinding = {
  messageId: string;
  emoji: string;
  roleId: string;
};

export type GuildSettings = {
  welcomeEnabled: boolean;
  welcomeChannelId: string | null;
  welcomeMessage: string;
  goodbyeEnabled: boolean;
  goodbyeChannelId: string | null;
  goodbyeMessage: string;
  autoRoleIds: string[];
  reactionRoles: ReactionRoleBinding[];
  moderationLogChannelId: string | null;
  autoTimeoutThreshold: number | null;
  autoTimeoutDurationSeconds: number | null;
  slowmodeSecondsByChannel: Record<string, number>;
  lockedChannelIds: string[];
};

export const defaultGuildSettings: GuildSettings = {
  welcomeEnabled: false,
  welcomeChannelId: null,
  welcomeMessage: 'Welcome {user} to {server}!',
  goodbyeEnabled: false,
  goodbyeChannelId: null,
  goodbyeMessage: '{user} left {server}. We are now {memberCount} members.',
  autoRoleIds: [],
  reactionRoles: [],
  moderationLogChannelId: null,
  autoTimeoutThreshold: null,
  autoTimeoutDurationSeconds: null,
  slowmodeSecondsByChannel: {},
  lockedChannelIds: [],
};

export type WarningRecord = {
  id: number;
  guildId: string;
  userId: string;
  reason: string;
  warnedBy: string;
  createdAt: string;
};

export type ScheduledAnnouncement = {
  id: string;
  guildId: string;
  channelId: string;
  content: string;
  scheduledAt: string;
  createdBy: string;
  status: 'pending' | 'sent' | 'failed' | 'cancelled';
  sentAt: string | null;
  error: string | null;
};

export type MemberSnapshot = {
  guildId: string;
  day: string;
  memberCount: number;
  onlineCount: number;
  channelCount: number;
};

export type GuildInviteRecord = {
  guildId: string;
  code: string;
  uses: number;
  inviterId: string | null;
  channelId: string | null;
  createdAt: string;
};

export type InviteJoinRecord = {
  id: number;
  guildId: string;
  memberId: string;
  inviteCode: string | null;
  inviterId: string | null;
  joinedAt: string;
};

export type ModerationLogRecord = {
  id: number;
  guildId: string;
  action: string;
  actorId: string | null;
  targetId: string | null;
  detail: string | null;
  createdAt: string;
};

export type LockedOverwrite = {
  guildId: string;
  channelId: string;
  previousOverwrite: string;
  createdAt: string;
};

export class SettingsRepository {
  constructor(private readonly database: SqliteDatabase) {}

  get(guildId: string): GuildSettings {
    const row = this.database
      .prepare('SELECT payload FROM guild_settings WHERE guild_id = ?')
      .get(guildId) as { payload: string } | undefined;
    if (!row) {
      return structuredClone(defaultGuildSettings);
    }
    return { ...structuredClone(defaultGuildSettings), ...(JSON.parse(row.payload) as GuildSettings) };
  }

  save(guildId: string, settings: GuildSettings): GuildSettings {
    this.database
      .prepare(
        `INSERT INTO guild_settings (guild_id, payload, updated_at)
         VALUES (?, ?, ?)
         ON CONFLICT (guild_id) DO UPDATE SET payload = excluded.payload, updated_at = excluded.updated_at`,
      )
      .run(guildId, JSON.stringify(settings), new Date().toISOString());
    return settings;
  }
}

export class WarningRepository {
  constructor(private readonly database: SqliteDatabase) {}

  insert(input: {
    guildId: string;
    userId: string;
    reason: string;
    warnedBy: string;
  }): WarningRecord {
    const createdAt = new Date().toISOString();
    const result = this.database
      .prepare(
        `INSERT INTO warnings (guild_id, user_id, reason, warned_by, created_at)
         VALUES (?, ?, ?, ?, ?)`,
      )
      .run(input.guildId, input.userId, input.reason, input.warnedBy, createdAt);
    return {
      id: Number(result.lastInsertRowid),
      guildId: input.guildId,
      userId: input.userId,
      reason: input.reason,
      warnedBy: input.warnedBy,
      createdAt,
    };
  }

  listByGuild(guildId: string, limit = 100): WarningRecord[] {
    const rows = this.database
      .prepare(
        `SELECT id, guild_id, user_id, reason, warned_by, created_at
         FROM warnings WHERE guild_id = ? ORDER BY created_at DESC LIMIT ?`,
      )
      .all(guildId, limit) as {
      id: number;
      guild_id: string;
      user_id: string;
      reason: string;
      warned_by: string;
      created_at: string;
    }[];
    return rows.map((row) => ({
      id: row.id,
      guildId: row.guild_id,
      userId: row.user_id,
      reason: row.reason,
      warnedBy: row.warned_by,
      createdAt: row.created_at,
    }));
  }

  countForUser(guildId: string, userId: string): number {
    const row = this.database
      .prepare('SELECT COUNT(*) AS count FROM warnings WHERE guild_id = ? AND user_id = ?')
      .get(guildId, userId) as { count: number };
    return row.count;
  }
}

export class AnnouncementRepository {
  constructor(private readonly database: SqliteDatabase) {}

  insert(announcement: ScheduledAnnouncement): ScheduledAnnouncement {
    this.database
      .prepare(
        `INSERT INTO scheduled_announcements
           (id, guild_id, channel_id, content, scheduled_at, created_by, status, sent_at, error)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .run(
        announcement.id,
        announcement.guildId,
        announcement.channelId,
        announcement.content,
        announcement.scheduledAt,
        announcement.createdBy,
        announcement.status,
        announcement.sentAt,
        announcement.error,
      );
    return announcement;
  }

  updateStatus(id: string, status: ScheduledAnnouncement['status'], error: string | null): void {
    this.database
      .prepare(
        `UPDATE scheduled_announcements
         SET status = ?, error = ?, sent_at = CASE WHEN ? = 'sent' THEN ? ELSE sent_at END
         WHERE id = ?`,
      )
      .run(status, error, status, new Date().toISOString(), id);
  }

  listByGuild(guildId: string): ScheduledAnnouncement[] {
    const rows = this.database
      .prepare(
        `SELECT id, guild_id, channel_id, content, scheduled_at, created_by, status, sent_at, error
         FROM scheduled_announcements WHERE guild_id = ? ORDER BY scheduled_at ASC`,
      )
      .all(guildId) as {
      id: string;
      guild_id: string;
      channel_id: string;
      content: string;
      scheduled_at: string;
      created_by: string;
      status: ScheduledAnnouncement['status'];
      sent_at: string | null;
      error: string | null;
    }[];
    return rows.map((row) => ({
      id: row.id,
      guildId: row.guild_id,
      channelId: row.channel_id,
      content: row.content,
      scheduledAt: row.scheduled_at,
      createdBy: row.created_by,
      status: row.status,
      sentAt: row.sent_at,
      error: row.error,
    }));
  }

  listPending(): ScheduledAnnouncement[] {
    const rows = this.database
      .prepare(
        `SELECT id, guild_id, channel_id, content, scheduled_at, created_by, status, sent_at, error
         FROM scheduled_announcements WHERE status = 'pending' ORDER BY scheduled_at ASC`,
      )
      .all() as {
      id: string;
      guild_id: string;
      channel_id: string;
      content: string;
      scheduled_at: string;
      created_by: string;
      status: ScheduledAnnouncement['status'];
      sent_at: string | null;
      error: string | null;
    }[];
    return rows.map((row) => ({
      id: row.id,
      guildId: row.guild_id,
      channelId: row.channel_id,
      content: row.content,
      scheduledAt: row.scheduled_at,
      createdBy: row.created_by,
      status: row.status,
      sentAt: row.sent_at,
      error: row.error,
    }));
  }
}

export class SnapshotRepository {
  constructor(private readonly database: SqliteDatabase) {}

  upsert(snapshot: MemberSnapshot): void {
    this.database
      .prepare(
        `INSERT INTO member_snapshots (guild_id, day, member_count, online_count, channel_count)
         VALUES (?, ?, ?, ?, ?)
         ON CONFLICT (guild_id, day) DO UPDATE SET
           member_count = excluded.member_count,
           online_count = excluded.online_count,
           channel_count = excluded.channel_count`,
      )
      .run(
        snapshot.guildId,
        snapshot.day,
        snapshot.memberCount,
        snapshot.onlineCount,
        snapshot.channelCount,
      );
  }

  list(guildId: string, limit = 30): MemberSnapshot[] {
    const rows = this.database
      .prepare(
        `SELECT guild_id, day, member_count, online_count, channel_count
         FROM member_snapshots WHERE guild_id = ? ORDER BY day DESC LIMIT ?`,
      )
      .all(guildId, limit) as {
      guild_id: string;
      day: string;
      member_count: number;
      online_count: number;
      channel_count: number;
    }[];
    return rows
      .map((row) => ({
        guildId: row.guild_id,
        day: row.day,
        memberCount: row.member_count,
        onlineCount: row.online_count,
        channelCount: row.channel_count,
      }))
      .reverse();
  }
}

export class InviteRepository {
  constructor(private readonly database: SqliteDatabase) {}

  upsert(invite: GuildInviteRecord): void {
    this.database
      .prepare(
        `INSERT INTO guild_invites (guild_id, code, uses, inviter_id, channel_id, created_at)
         VALUES (?, ?, ?, ?, ?, ?)
         ON CONFLICT (guild_id, code) DO UPDATE SET
           uses = excluded.uses,
           inviter_id = excluded.inviter_id,
           channel_id = excluded.channel_id`,
      )
      .run(invite.guildId, invite.code, invite.uses, invite.inviterId, invite.channelId, invite.createdAt);
  }

  remove(guildId: string, code: string): void {
    this.database.prepare('DELETE FROM guild_invites WHERE guild_id = ? AND code = ?').run(guildId, code);
  }

  listByGuild(guildId: string): GuildInviteRecord[] {
    const rows = this.database
      .prepare(
        `SELECT guild_id, code, uses, inviter_id, channel_id, created_at
         FROM guild_invites WHERE guild_id = ? ORDER BY uses DESC`,
      )
      .all(guildId) as {
      guild_id: string;
      code: string;
      uses: number;
      inviter_id: string | null;
      channel_id: string | null;
      created_at: string;
    }[];
    return rows.map((row) => ({
      guildId: row.guild_id,
      code: row.code,
      uses: row.uses,
      inviterId: row.inviter_id,
      channelId: row.channel_id,
      createdAt: row.created_at,
    }));
  }

  recordJoin(join: {
    guildId: string;
    memberId: string;
    inviteCode: string | null;
    inviterId: string | null;
    joinedAt: string;
  }): void {
    this.database
      .prepare(
        `INSERT INTO invite_joins (guild_id, member_id, invite_code, inviter_id, joined_at)
         VALUES (?, ?, ?, ?, ?)`,
      )
      .run(join.guildId, join.memberId, join.inviteCode, join.inviterId, join.joinedAt);
  }

  listJoinsByGuild(guildId: string, limit = 200): InviteJoinRecord[] {
    const rows = this.database
      .prepare(
        `SELECT id, guild_id, member_id, invite_code, inviter_id, joined_at
         FROM invite_joins WHERE guild_id = ? ORDER BY joined_at DESC LIMIT ?`,
      )
      .all(guildId, limit) as {
      id: number;
      guild_id: string;
      member_id: string;
      invite_code: string | null;
      inviter_id: string | null;
      joined_at: string;
    }[];
    return rows.map((row) => ({
      id: row.id,
      guildId: row.guild_id,
      memberId: row.member_id,
      inviteCode: row.invite_code,
      inviterId: row.inviter_id,
      joinedAt: row.joined_at,
    }));
  }
}

export class ModerationLogRepository {
  constructor(private readonly database: SqliteDatabase) {}

  insert(entry: {
    guildId: string;
    action: string;
    actorId: string | null;
    targetId: string | null;
    detail: string | null;
  }): void {
    this.database
      .prepare(
        `INSERT INTO moderation_log (guild_id, action, actor_id, target_id, detail, created_at)
         VALUES (?, ?, ?, ?, ?, ?)`,
      )
      .run(
        entry.guildId,
        entry.action,
        entry.actorId,
        entry.targetId,
        entry.detail,
        new Date().toISOString(),
      );
  }

  listByGuild(guildId: string, limit = 100): ModerationLogRecord[] {
    const rows = this.database
      .prepare(
        `SELECT id, guild_id, action, actor_id, target_id, detail, created_at
         FROM moderation_log WHERE guild_id = ? ORDER BY created_at DESC LIMIT ?`,
      )
      .all(guildId, limit) as {
      id: number;
      guild_id: string;
      action: string;
      actor_id: string | null;
      target_id: string | null;
      detail: string | null;
      created_at: string;
    }[];
    return rows.map((row) => ({
      id: row.id,
      guildId: row.guild_id,
      action: row.action,
      actorId: row.actor_id,
      targetId: row.target_id,
      detail: row.detail,
      createdAt: row.created_at,
    }));
  }
}

export class LockdownRepository {
  constructor(private readonly database: SqliteDatabase) {}

  save(entry: LockedOverwrite): void {
    this.database
      .prepare(
        `INSERT INTO lockdown_overwrites (guild_id, channel_id, previous_overwrite, created_at)
         VALUES (?, ?, ?, ?)
         ON CONFLICT (guild_id, channel_id) DO UPDATE SET
           previous_overwrite = excluded.previous_overwrite,
           created_at = excluded.created_at`,
      )
      .run(entry.guildId, entry.channelId, entry.previousOverwrite, entry.createdAt);
  }

  remove(guildId: string, channelId: string): void {
    this.database
      .prepare('DELETE FROM lockdown_overwrites WHERE guild_id = ? AND channel_id = ?')
      .run(guildId, channelId);
  }

  list(guildId: string): LockedOverwrite[] {
    const rows = this.database
      .prepare(
        `SELECT guild_id, channel_id, previous_overwrite, created_at
         FROM lockdown_overwrites WHERE guild_id = ?`,
      )
      .all(guildId) as {
      guild_id: string;
      channel_id: string;
      previous_overwrite: string;
      created_at: string;
    }[];
    return rows.map((row) => ({
      guildId: row.guild_id,
      channelId: row.channel_id,
      previousOverwrite: row.previous_overwrite,
      createdAt: row.created_at,
    }));
  }
}

export class KnownGuildRepository {
  constructor(private readonly database: SqliteDatabase) {}

  remember(guildIds: readonly string[]): void {
    const now = new Date().toISOString();
    const statement = this.database.prepare(
      `INSERT INTO known_guilds (guild_id, first_seen_at) VALUES (?, ?)
       ON CONFLICT (guild_id) DO NOTHING`,
    );
    for (const guildId of guildIds) {
      statement.run(guildId, now);
    }
  }

  list(): string[] {
    const rows = this.database.prepare('SELECT guild_id FROM known_guilds').all() as {
      guild_id: string;
    }[];
    return rows.map((row) => row.guild_id);
  }
}
