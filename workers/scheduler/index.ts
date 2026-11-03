/**
 * Cloudflare Cron Worker — scheduled announcements & daily snapshots.
 *
 * Replaces backend/src/scheduler/index.ts (which used Node setInterval).
 * Cron Triggers call `scheduled()` on a fixed cadence; durable state lives in
 * D1 so the snapshot interval survives across invocations.
 *
 * Limitation: invite/join attribution that depended on live Gateway invite
 * create/delete events is NOT replicated here — there is no webhook equivalent.
 * See docs/cloudflare-migration.md for details.
 */

import { createRepositories } from '../../functions/_lib/db';
import { DiscordApi } from '../../functions/_lib/discord/api';
import { DiscordRestClient } from '../../functions/_lib/discord/rest';
import { EngagementService } from '../../functions/_lib/services/engagement';
import { GuildService } from '../../functions/_lib/services/guild';
import { ModerationLogService } from '../../functions/_lib/services/moderationLog';
import { requireBotToken, type Env } from '../../functions/_lib/env';

const SNAPSHOT_INTERVAL_MS = 6 * 60 * 60 * 1000;

export default {
  async scheduled(_controller: ScheduledController, env: Env, ctx: ExecutionContext): Promise<void> {
    await ctx.waitUntil(runSchedulerTick(env));
  },

  // Reuse the same entry point for manual `wrangler triggers` / HTTP debug calls.
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed.' }), {
        status: 405,
        headers: { 'Content-Type': 'application/json' },
      });
    }
    await runSchedulerTick(env);
    return new Response(JSON.stringify({ data: { ok: true } }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  },
} satisfies ExportedHandler<Env>;

async function runSchedulerTick(env: Env): Promise<void> {
  const now = Date.now();
  const db = env.DB;
  const repos = createRepositories(db);
  const httpClient = new DiscordRestClient({
    token: requireBotToken(env),
    userAgent: 'XAXServerManager/1.0 (cloudflare-cron)',
  });
  const api = new DiscordApi(httpClient);
  const moderationLog = new ModerationLogService(api, repos);
  const engagement = new EngagementService(api, repos, moderationLog);
  const guildService = new GuildService(api, repos, moderationLog);

  /* ---- 1. Send due announcements ---- */
  const pending = await engagement.pendingAnnouncements();
  for (const announcement of pending) {
    if (Date.parse(announcement.scheduledAt) > now) continue;
    try {
      await engagement.sendAnnouncement(announcement);
    } catch {
      // A single failed announcement should not abort the whole tick.
    }
  }

  /* ---- 2. Collect member snapshots (at most once per SNAPSHOT_INTERVAL_MS) ---- */
  const lastSnapshotRow = await db
    .prepare('SELECT value FROM cron_state WHERE key = ?')
    .bind('last_snapshot_at')
    .first<{ value: string }>();
  const lastSnapshotAt = lastSnapshotRow ? Number(lastSnapshotRow.value) : 0;

  if (lastSnapshotAt === 0 || now - lastSnapshotAt >= SNAPSHOT_INTERVAL_MS) {
    const guildIds = await repos.knownGuilds.list();
    for (const guildId of guildIds) {
      try {
        await guildService.collectSnapshot(guildId);
      } catch {
        // Skip inaccessible guilds; retry next round.
      }
    }
    await db
      .prepare(
        `INSERT INTO cron_state (key, value, updated_at) VALUES (?, ?, ?)
         ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at`,
      )
      .bind('last_snapshot_at', now.toString(), new Date().toISOString())
      .run();
  }
}
