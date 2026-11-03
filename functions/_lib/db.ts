/**
 * Cloudflare D1 repositories.
 *
 * Port of backend/src/db/repositories.ts. Every method became async because D1
 * is a network-bound API (no synchronous better-sqlite3 on Workers). All
 * statements are parameterized with .bind() and all SQL is identical in shape
 * to the original schema (migrations/0001_init.sql).
 */

export type ReactionRoleBinding = { messageId: string; emoji: string; roleId: string };

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
  id: number; guildId: string; userId: string; reason: string; warnedBy: string; createdAt: string;
};
export type ScheduledAnnouncement = {
  id: string; guildId: string; channelId: string; content: string; scheduledAt: string;
  createdBy: string; status: 'pending' | 'sent' | 'failed' | 'cancelled';
  sentAt: string | null; error: string | null;
};
export type MemberSnapshot = {
  guildId: string; day: string; memberCount: number; onlineCount: number; channelCount: number;
};
export type GuildInviteRecord = {
  guildId: string; code: string; uses: number; inviterId: string | null;
  channelId: string | null; createdAt: string;
};
export type InviteJoinRecord = {
  id: number; guildId: string; memberId: string; inviteCode: string | null;
  inviterId: string | null; joinedAt: string;
};
export type ModerationLogRecord = {
  id: number; guildId: string; action: string; actorId: string | null;
  targetId: string | null; detail: string | null; createdAt: string;
};
export type LockedOverwrite = {
  guildId: string; channelId: string; previousOverwrite: string; createdAt: string;
};

type Row = Record<string, unknown>;

function str(row: Row, key: string): string {
  const value = row[key];
  return typeof value === 'string' ? value : '';
}
function nullableStr(row: Row, key: string): string | null {
  const value = row[key];
  return typeof value === 'string' ? value : null;
}
function num(row: Row, key: string): number {
  const value = row[key];
  return typeof value === 'number' ? value : Number(value ?? 0);
}

export class SettingsRepository {
  constructor(private readonly db: D1Database) {}

  async get(guildId: string): Promise<GuildSettings> {
    const row = await this.db
      .prepare('SELECT payload FROM guild_settings WHERE guild_id = ?')
      .bind(guildId)
      .first<Row>();
    if (!row) return structuredClone(defaultGuildSettings);
    const stored = JSON.parse(str(row, 'payload')) as Partial<GuildSettings>;
    return { ...structuredClone(defaultGuildSettings), ...stored };
  }

  async save(guildId: string, settings: GuildSettings): Promise<GuildSettings> {
    await this.db
      .prepare(
        `INSERT INTO guild_settings (guild_id, payload, updated_at)
         VALUES (?, ?, ?)
         ON CONFLICT (guild_id) DO UPDATE SET payload = excluded.payload, updated_at = excluded.updated_at`,
      )
      .bind(guildId, JSON.stringify(settings), new Date().toISOString())
      .run();
    return settings;
  }
}

export class WarningRepository {
  constructor(private readonly db: D1Database) {}

  async insert(input: { guildId: string; userId: string; reason: string; warnedBy: string }): Promise<WarningRecord> {
    const createdAt = new Date().toISOString();
    const result = await this.db
      .prepare(
        `INSERT INTO warnings (guild_id, user_id, reason, warned_by, created_at)
         VALUES (?, ?, ?, ?, ?)`,
      )
      .bind(input.guildId, input.userId, input.reason, input.warnedBy, createdAt)
      .run();
    return {
      id: Number(result.meta?.last_row_id ?? 0),
      guildId: input.guildId,
      userId: input.userId,
      reason: input.reason,
      warnedBy: input.warnedBy,
      createdAt,
    };
  }

  async listByGuild(guildId: string, limit = 100): Promise<WarningRecord[]> {
    const { results } = await this.db
      .prepare(
        `SELECT id, guild_id, user_id, reason, warned_by, created_at
         FROM warnings WHERE guild_id = ? ORDER BY created_at DESC LIMIT ?`,
      )
      .bind(guildId, limit)
      .all<Row>();
    return (results ?? []).map((row) => ({
      id: num(row, 'id'),
      guildId: str(row, 'guild_id'),
      userId: str(row, 'user_id'),
      reason: str(row, 'reason'),
      warnedBy: str(row, 'warned_by'),
      createdAt: str(row, 'created_at'),
    }));
  }

  async countForUser(guildId: string, userId: string): Promise<number> {
    const row = await this.db
      .prepare('SELECT COUNT(*) AS count FROM warnings WHERE guild_id = ? AND user_id = ?')
      .bind(guildId, userId)
      .first<Row>();
    return row ? num(row, 'count') : 0;
  }
}

const announcementColumns =
  'id, guild_id, channel_id, content, scheduled_at, created_by, status, sent_at, error';

export class AnnouncementRepository {
  constructor(private readonly db: D1Database) {}

  async insert(a: ScheduledAnnouncement): Promise<ScheduledAnnouncement> {
    await this.db
      .prepare(
        `INSERT INTO scheduled_announcements
           (id, guild_id, channel_id, content, scheduled_at, created_by, status, sent_at, error)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(a.id, a.guildId, a.channelId, a.content, a.scheduledAt, a.createdBy, a.status, a.sentAt, a.error)
      .run();
    return a;
  }

  async updateStatus(id: string, status: ScheduledAnnouncement['status'], error: string | null): Promise<void> {
    await this.db
      .prepare(
        `UPDATE scheduled_announcements
         SET status = ?, error = ?, sent_at = CASE WHEN ? = 'sent' THEN ? ELSE sent_at END
         WHERE id = ?`,
      )
      .bind(status, error, status, new Date().toISOString(), id)
      .run();
  }

  private map(row: Row): ScheduledAnnouncement {
    return {
      id: str(row, 'id'),
      guildId: str(row, 'guild_id'),
      channelId: str(row, 'channel_id'),
      content: str(row, 'content'),
      scheduledAt: str(row, 'scheduled_at'),
      createdBy: str(row, 'created_by'),
      status: str(row, 'status') as ScheduledAnnouncement['status'],
      sentAt: nullableStr(row, 'sent_at'),
      error: nullableStr(row, 'error'),
    };
  }

  async listByGuild(guildId: string): Promise<ScheduledAnnouncement[]> {
    const { results } = await this.db
      .prepare(`SELECT ${announcementColumns} FROM scheduled_announcements WHERE guild_id = ? ORDER BY scheduled_at ASC`)
      .bind(guildId)
      .all<Row>();
    return (results ?? []).map((row) => this.map(row));
  }

  async listPending(): Promise<ScheduledAnnouncement[]> {
    const { results } = await this.db
      .prepare(`SELECT ${announcementColumns} FROM scheduled_announcements WHERE status = 'pending' ORDER BY scheduled_at ASC`)
      .all<Row>();
    return (results ?? []).map((row) => this.map(row));
  }
}

export class SnapshotRepository {
  constructor(private readonly db: D1Database) {}

  async upsert(s: MemberSnapshot): Promise<void> {
    await this.db
      .prepare(
        `INSERT INTO member_snapshots (guild_id, day, member_count, online_count, channel_count)
         VALUES (?, ?, ?, ?, ?)
         ON CONFLICT (guild_id, day) DO UPDATE SET
           member_count = excluded.member_count,
           online_count = excluded.online_count,
           channel_count = excluded.channel_count`,
      )
      .bind(s.guildId, s.day, s.memberCount, s.onlineCount, s.channelCount)
      .run();
  }

  async list(guildId: string, limit = 30): Promise<MemberSnapshot[]> {
    const { results } = await this.db
      .prepare(
        `SELECT guild_id, day, member_count, online_count, channel_count
         FROM member_snapshots WHERE guild_id = ? ORDER BY day DESC LIMIT ?`,
      )
      .bind(guildId, limit)
      .all<Row>();
    return (results ?? [])
      .map((row) => ({
        guildId: str(row, 'guild_id'),
        day: str(row, 'day'),
        memberCount: num(row, 'member_count'),
        onlineCount: num(row, 'online_count'),
        channelCount: num(row, 'channel_count'),
      }))
      .reverse();
  }
}

export class InviteRepository {
  constructor(private readonly db: D1Database) {}

  async upsert(invite: GuildInviteRecord): Promise<void> {
    await this.db
      .prepare(
        `INSERT INTO guild_invites (guild_id, code, uses, inviter_id, channel_id, created_at)
         VALUES (?, ?, ?, ?, ?, ?)
         ON CONFLICT (guild_id, code) DO UPDATE SET
           uses = excluded.uses, inviter_id = excluded.inviter_id, channel_id = excluded.channel_id`,
      )
      .bind(invite.guildId, invite.code, invite.uses, invite.inviterId, invite.channelId, invite.createdAt)
      .run();
  }

  async remove(guildId: string, code: string): Promise<void> {
    await this.db.prepare('DELETE FROM guild_invites WHERE guild_id = ? AND code = ?').bind(guildId, code).run();
  }

  async listByGuild(guildId: string): Promise<GuildInviteRecord[]> {
    const { results } = await this.db
      .prepare(
        `SELECT guild_id, code, uses, inviter_id, channel_id, created_at
         FROM guild_invites WHERE guild_id = ? ORDER BY uses DESC`,
      )
      .bind(guildId)
      .all<Row>();
    return (results ?? []).map((row) => ({
      guildId: str(row, 'guild_id'),
      code: str(row, 'code'),
      uses: num(row, 'uses'),
      inviterId: nullableStr(row, 'inviter_id'),
      channelId: nullableStr(row, 'channel_id'),
      createdAt: str(row, 'created_at'),
    }));
  }

  async recordJoin(join: {
    guildId: string; memberId: string; inviteCode: string | null;
    inviterId: string | null; joinedAt: string;
  }): Promise<void> {
    await this.db
      .prepare(
        `INSERT INTO invite_joins (guild_id, member_id, invite_code, inviter_id, joined_at)
         VALUES (?, ?, ?, ?, ?)`,
      )
      .bind(join.guildId, join.memberId, join.inviteCode, join.inviterId, join.joinedAt)
      .run();
  }

  async listJoinsByGuild(guildId: string, limit = 200): Promise<InviteJoinRecord[]> {
    const { results } = await this.db
      .prepare(
        `SELECT id, guild_id, member_id, invite_code, inviter_id, joined_at
         FROM invite_joins WHERE guild_id = ? ORDER BY joined_at DESC LIMIT ?`,
      )
      .bind(guildId, limit)
      .all<Row>();
    return (results ?? []).map((row) => ({
      id: num(row, 'id'),
      guildId: str(row, 'guild_id'),
      memberId: str(row, 'member_id'),
      inviteCode: nullableStr(row, 'invite_code'),
      inviterId: nullableStr(row, 'inviter_id'),
      joinedAt: str(row, 'joined_at'),
    }));
  }
}

export class ModerationLogRepository {
  constructor(private readonly db: D1Database) {}

  async insert(entry: {
    guildId: string; action: string; actorId: string | null;
    targetId: string | null; detail: string | null;
  }): Promise<void> {
    await this.db
      .prepare(
        `INSERT INTO moderation_log (guild_id, action, actor_id, target_id, detail, created_at)
         VALUES (?, ?, ?, ?, ?, ?)`,
      )
      .bind(entry.guildId, entry.action, entry.actorId, entry.targetId, entry.detail, new Date().toISOString())
      .run();
  }

  async listByGuild(guildId: string, limit = 100): Promise<ModerationLogRecord[]> {
    const { results } = await this.db
      .prepare(
        `SELECT id, guild_id, action, actor_id, target_id, detail, created_at
         FROM moderation_log WHERE guild_id = ? ORDER BY created_at DESC LIMIT ?`,
      )
      .bind(guildId, limit)
      .all<Row>();
    return (results ?? []).map((row) => ({
      id: num(row, 'id'),
      guildId: str(row, 'guild_id'),
      action: str(row, 'action'),
      actorId: nullableStr(row, 'actor_id'),
      targetId: nullableStr(row, 'target_id'),
      detail: nullableStr(row, 'detail'),
      createdAt: str(row, 'created_at'),
    }));
  }
}

export class LockdownRepository {
  constructor(private readonly db: D1Database) {}

  async save(entry: LockedOverwrite): Promise<void> {
    await this.db
      .prepare(
        `INSERT INTO lockdown_overwrites (guild_id, channel_id, previous_overwrite, created_at)
         VALUES (?, ?, ?, ?)
         ON CONFLICT (guild_id, channel_id) DO UPDATE SET
           previous_overwrite = excluded.previous_overwrite, created_at = excluded.created_at`,
      )
      .bind(entry.guildId, entry.channelId, entry.previousOverwrite, entry.createdAt)
      .run();
  }

  async remove(guildId: string, channelId: string): Promise<void> {
    await this.db
      .prepare('DELETE FROM lockdown_overwrites WHERE guild_id = ? AND channel_id = ?')
      .bind(guildId, channelId)
      .run();
  }

  async list(guildId: string): Promise<LockedOverwrite[]> {
    const { results } = await this.db
      .prepare(
        `SELECT guild_id, channel_id, previous_overwrite, created_at
         FROM lockdown_overwrites WHERE guild_id = ?`,
      )
      .bind(guildId)
      .all<Row>();
    return (results ?? []).map((row) => ({
      guildId: str(row, 'guild_id'),
      channelId: str(row, 'channel_id'),
      previousOverwrite: str(row, 'previous_overwrite'),
      createdAt: str(row, 'created_at'),
    }));
  }
}

export class KnownGuildRepository {
  constructor(private readonly db: D1Database) {}

  async remember(guildIds: readonly string[]): Promise<void> {
    if (guildIds.length === 0) return;
    const now = new Date().toISOString();
    const statement = this.db.prepare(
      `INSERT INTO known_guilds (guild_id, first_seen_at) VALUES (?, ?)
       ON CONFLICT (guild_id) DO NOTHING`,
    );
    await this.db.batch(guildIds.map((guildId) => statement.bind(guildId, now)));
  }

  async list(): Promise<string[]> {
    const { results } = await this.db.prepare('SELECT guild_id FROM known_guilds').all<Row>();
    return (results ?? []).map((row) => str(row, 'guild_id'));
  }
}

export interface Repositories {
  settings: SettingsRepository;
  warnings: WarningRepository;
  announcements: AnnouncementRepository;
  snapshots: SnapshotRepository;
  invites: InviteRepository;
  moderationLog: ModerationLogRepository;
  lockdowns: LockdownRepository;
  knownGuilds: KnownGuildRepository;
}

export function createRepositories(db: D1Database): Repositories {
  return {
    settings: new SettingsRepository(db),
    warnings: new WarningRepository(db),
    announcements: new AnnouncementRepository(db),
    snapshots: new SnapshotRepository(db),
    invites: new InviteRepository(db),
    moderationLog: new ModerationLogRepository(db),
    lockdowns: new LockdownRepository(db),
    knownGuilds: new KnownGuildRepository(db),
  };
}
