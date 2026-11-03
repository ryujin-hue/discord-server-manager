import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, describe, expect, it } from 'vitest';
import { openDatabase } from '../src/db/database.js';
import {
  AnnouncementRepository,
  InviteRepository,
  KnownGuildRepository,
  SettingsRepository,
  SnapshotRepository,
} from '../src/db/repositories.js';
import { DiscordApi } from '../src/discord/api.js';
import { EngagementService } from '../src/services/engagementService.js';
import { GuildService } from '../src/services/guildService.js';
import { ModerationLogService } from '../src/services/moderationLogService.js';
import { ModerationLogRepository } from '../src/db/repositories.js';
import { Scheduler } from '../src/scheduler/index.js';
import { FakeDiscordHttp } from './helpers.js';

const directories: string[] = [];

afterEach(() => {
  for (const directory of directories.splice(0)) {
    rmSync(directory, { recursive: true, force: true });
  }
});

function createServices(dbPath: string) {
  const database = openDatabase(dbPath);
  const http = new FakeDiscordHttp();
  const api = new DiscordApi(http);
  const settings = new SettingsRepository(database);
  const announcements = new AnnouncementRepository(database);
  const invites = new InviteRepository(database);
  const snapshots = new SnapshotRepository(database);
  const logs = new ModerationLogRepository(database);
  const moderationLog = new ModerationLogService(api, logs, settings);
  const engagement = new EngagementService(api, announcements, invites, moderationLog);
  const guildService = new GuildService(api, snapshots, moderationLog);
  const knownGuilds = new KnownGuildRepository(database);
  return { database, http, api, settings, engagement, guildService, knownGuilds };
}

describe('Scheduler', () => {
  it('sends an announcement that came due', async () => {
    const { database, http, engagement, guildService, knownGuilds } = createServices(':memory:');
    http.on('POST', /^\/channels\/channel-1\/messages$/, () => ({ id: 'message-1' }));

    await engagement.schedule('guild-1', 'user-1', {
      channelId: 'channel-1',
      content: 'Hello',
      scheduledAt: new Date(Date.now() - 1000).toISOString(),
    });

    const scheduler = new Scheduler(engagement, guildService, knownGuilds, { intervalMs: 10 });
    await scheduler.tick();

    expect(http.callsTo('POST', '/channels/channel-1/messages')).toHaveLength(1);
    expect(engagement.pendingAnnouncements()).toHaveLength(0);
    database.close();
  });

  it('keeps a pending announcement across a restart and sends it after the restart', async () => {
    const directory = mkdtempSync(join(tmpdir(), 'dsm-scheduler-'));
    directories.push(directory);
    const dbPath = join(directory, 'app.sqlite');

    const first = createServices(dbPath);
    first.http.on('POST', /^\/channels\/channel-1\/messages$/, () => ({ id: 'message-1' }));

    await first.engagement.schedule('guild-1', 'user-1', {
      channelId: 'channel-1',
      content: 'Survives restart',
      scheduledAt: new Date(Date.now() - 1000).toISOString(),
    });
    expect(first.engagement.pendingAnnouncements()).toHaveLength(1);
    first.database.close();

    const second = createServices(dbPath);
    second.http.on('POST', /^\/channels\/channel-1\/messages$/, () => ({ id: 'message-2' }));

    expect(second.engagement.pendingAnnouncements()).toHaveLength(1);

    const scheduler = new Scheduler(second.engagement, second.guildService, second.knownGuilds, {
      intervalMs: 10,
    });
    await scheduler.tick();

    expect(second.http.callsTo('POST', '/channels/channel-1/messages')).toHaveLength(1);
    expect(second.engagement.pendingAnnouncements()).toHaveLength(0);
    second.database.close();
  });

  it('does not send an announcement that is not due yet', async () => {
    const { database, http, engagement, guildService, knownGuilds } = createServices(':memory:');
    http.on('POST', /^\/channels\/channel-1\/messages$/, () => ({ id: 'message-1' }));

    await engagement.schedule('guild-1', 'user-1', {
      channelId: 'channel-1',
      content: 'Later',
      scheduledAt: new Date(Date.now() + 3_600_000).toISOString(),
    });

    const scheduler = new Scheduler(engagement, guildService, knownGuilds, { intervalMs: 10 });
    await scheduler.tick();

    expect(http.callsTo('POST', '/channels/channel-1/messages')).toHaveLength(0);
    expect(engagement.pendingAnnouncements()).toHaveLength(1);
    database.close();
  });

  it('records a failed send instead of throwing', async () => {
    const { database, http, engagement, guildService, knownGuilds } = createServices(':memory:');
    http.on('POST', /^\/channels\/channel-1\/messages$/, () => {
      throw new Error('Missing Permissions');
    });

    await engagement.schedule('guild-1', 'user-1', {
      channelId: 'channel-1',
      content: 'Doomed',
      scheduledAt: new Date(Date.now() - 1000).toISOString(),
    });

    const scheduler = new Scheduler(engagement, guildService, knownGuilds, { intervalMs: 10 });
    await scheduler.tick();

    expect(engagement.list('guild-1')[0]?.status).toBe('failed');
    database.close();
  });

  it('collects a daily snapshot for every known guild', async () => {
    const { database, http, engagement, guildService, knownGuilds } = createServices(':memory:');
    http.on('GET', /^\/guilds\/guild-1$/, () => ({
      id: 'guild-1',
      name: 'Test Guild',
      approximate_member_count: 42,
      approximate_presence_count: 7,
    }));
    http.on('GET', /^\/guilds\/guild-1\/channels$/, () => []);
    knownGuilds.remember(['guild-1']);

    const scheduler = new Scheduler(engagement, guildService, knownGuilds, { intervalMs: 10 });
    await scheduler.tick();

    const points = guildService.listInsights('guild-1');
    expect(points).toHaveLength(1);
    expect(points[0]?.memberCount).toBe(42);
    database.close();
  });
});
