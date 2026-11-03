-- 0002_auth_and_jobs.sql
-- State that used to live only in Node process memory. On Workers the process
-- is not persistent, so it must be durable in D1:
--   * single-use OAuth2 state (CSRF + replay protection),
--   * rate-limit counters for sensitive endpoints,
--   * cron bookkeeping (last snapshot run, invite snapshots),
--   * invite usage snapshots for the polling-based invite tracker.
--
-- NO user token, bot token or token hash is ever written to these tables.

CREATE TABLE IF NOT EXISTS auth_states (
  state_hash   TEXT PRIMARY KEY,
  created_at   INTEGER NOT NULL,
  expires_at   INTEGER NOT NULL,
  consumed_at  INTEGER
);

CREATE TABLE IF NOT EXISTS rate_limit_counters (
  bucket_key   TEXT PRIMARY KEY,
  window_start INTEGER NOT NULL,
  count        INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS cron_state (
  key         TEXT PRIMARY KEY,
  value       TEXT NOT NULL,
  updated_at  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS invite_snapshots (
  guild_id    TEXT NOT NULL,
  code        TEXT NOT NULL,
  uses        INTEGER NOT NULL,
  inviter_id  TEXT,
  PRIMARY KEY (guild_id, code)
);
