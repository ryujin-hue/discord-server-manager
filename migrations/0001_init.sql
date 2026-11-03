-- 0001_init.sql
-- Port of backend/src/db/database.ts (better-sqlite3 schema) to Cloudflare D1.
-- Every statement is idempotent so the migration can be re-applied safely.

CREATE TABLE IF NOT EXISTS guild_settings (
  guild_id    TEXT PRIMARY KEY,
  payload     TEXT NOT NULL,
  updated_at  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS warnings (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  guild_id    TEXT NOT NULL,
  user_id     TEXT NOT NULL,
  reason      TEXT NOT NULL,
  warned_by   TEXT NOT NULL,
  created_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_warnings_guild ON warnings (guild_id, created_at DESC);

CREATE TABLE IF NOT EXISTS scheduled_announcements (
  id            TEXT PRIMARY KEY,
  guild_id      TEXT NOT NULL,
  channel_id    TEXT NOT NULL,
  content       TEXT NOT NULL,
  scheduled_at  TEXT NOT NULL,
  created_by    TEXT NOT NULL,
  status        TEXT NOT NULL,
  sent_at       TEXT,
  error         TEXT
);
CREATE INDEX IF NOT EXISTS idx_scheduled_guild ON scheduled_announcements (guild_id, scheduled_at);

CREATE TABLE IF NOT EXISTS member_snapshots (
  guild_id       TEXT NOT NULL,
  day            TEXT NOT NULL,
  member_count   INTEGER NOT NULL,
  online_count   INTEGER NOT NULL,
  channel_count  INTEGER NOT NULL,
  PRIMARY KEY (guild_id, day)
);

CREATE TABLE IF NOT EXISTS guild_invites (
  guild_id    TEXT NOT NULL,
  code        TEXT NOT NULL,
  uses        INTEGER NOT NULL,
  inviter_id  TEXT,
  channel_id  TEXT,
  created_at  TEXT NOT NULL,
  PRIMARY KEY (guild_id, code)
);

CREATE TABLE IF NOT EXISTS invite_joins (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  guild_id     TEXT NOT NULL,
  member_id    TEXT NOT NULL,
  invite_code  TEXT,
  inviter_id   TEXT,
  joined_at    TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_invite_joins_guild ON invite_joins (guild_id, joined_at DESC);

CREATE TABLE IF NOT EXISTS moderation_log (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  guild_id    TEXT NOT NULL,
  action      TEXT NOT NULL,
  actor_id    TEXT,
  target_id   TEXT,
  detail      TEXT,
  created_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_moderation_log_guild ON moderation_log (guild_id, created_at DESC);

CREATE TABLE IF NOT EXISTS lockdown_overwrites (
  guild_id            TEXT NOT NULL,
  channel_id          TEXT NOT NULL,
  previous_overwrite  TEXT NOT NULL,
  created_at          TEXT NOT NULL,
  PRIMARY KEY (guild_id, channel_id)
);

CREATE TABLE IF NOT EXISTS known_guilds (
  guild_id       TEXT PRIMARY KEY,
  first_seen_at  TEXT NOT NULL
);
