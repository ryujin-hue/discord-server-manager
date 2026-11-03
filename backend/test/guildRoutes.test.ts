import { beforeEach, describe, expect, it } from 'vitest';
import { buildApp } from '../src/app.js';
import { DiscordApiError } from '../src/discord/rest.js';
import { FakeDiscordHttp, guildPayload, testConfig } from './helpers.js';

const AUTH = { authorization: 'Bearer user-token' };

function createHarness(): { http: FakeDiscordHttp; built: ReturnType<typeof buildApp> } {
  const http = new FakeDiscordHttp();
  http.on('GET', /^\/users\/@me\/guilds$/, () => [guildPayload()]);
  const built = buildApp({ config: testConfig(), httpClient: http, botUserId: 'bot-1' });
  return { http, built };
}

describe('REST actions with a mocked Discord', () => {
  let http: FakeDiscordHttp;
  let built: ReturnType<typeof buildApp>;

  beforeEach(() => {
    ({ http, built } = createHarness());
    http.on('GET', /^\/guilds\/guild-1$/, () => guildPayload());
    http.on('GET', /^\/guilds\/guild-1\/channels$/, () => [
      { id: 'channel-1', type: 0, name: 'general', position: 0, rate_limit_per_user: 0 },
      { id: 'category-1', type: 4, name: 'Category', position: 0 },
    ]);
    http.on('GET', /^\/guilds\/guild-1\/roles$/, () => [
      { id: 'role-1', name: 'Member', permissions: '0', position: 1, color: 0 },
    ]);
    http.on('GET', /^\/guilds\/guild-1\/members\/bot-1$/, () => ({
      user: { id: 'bot-1', username: 'Bot' },
      roles: [],
    }));
  });

  it('returns the overview with counts', async () => {
    const response = await built.app.inject({
      method: 'GET',
      url: '/guilds/guild-1/overview',
      headers: AUTH,
    });

    expect(response.statusCode).toBe(200);
    const body = response.json() as { data: Record<string, unknown> };
    expect(body.data['approximateMemberCount']).toBe(120);
    expect(body.data['onlineCount']).toBe(30);
    expect(body.data['channelCount']).toBe(2);
    expect(body.data['botPresent']).toBe(true);
  });

  it('reports the gateway status', async () => {
    const response = await built.app.inject({
      method: 'GET',
      url: '/guilds/guild-1/status',
      headers: AUTH,
    });

    expect(response.statusCode).toBe(200);
    const body = response.json() as { data: { gateway: { connected: boolean } } };
    expect(body.data.gateway.connected).toBe(false);
  });

  it('bans a member', async () => {
    http.on('PUT', /^\/guilds\/guild-1\/bans\/user-9$/, () => undefined);

    const response = await built.app.inject({
      method: 'POST',
      url: '/guilds/guild-1/moderation/ban',
      headers: AUTH,
      payload: { userId: 'user-9', reason: 'spam', deleteMessageSeconds: 0, confirm: true },
    });

    expect(response.statusCode).toBe(200);
    const call = http.callsTo('PUT', '/guilds/guild-1/bans/user-9')[0];
    expect(call?.body).toMatchObject({ delete_message_seconds: 0, reason: 'spam' });
  });

  it('refuses a destructive action without confirm', async () => {
    const response = await built.app.inject({
      method: 'POST',
      url: '/guilds/guild-1/moderation/ban',
      headers: AUTH,
      payload: { userId: 'user-9', confirm: false },
    });

    expect(response.statusCode).toBe(400);
    expect(response.json()).toMatchObject({ error: { code: 'validation_failed' } });
    expect(http.callsTo('PUT', '/bans')).toHaveLength(0);
  });

  it('kicks a member', async () => {
    http.on('DELETE', /^\/guilds\/guild-1\/members\/user-9$/, () => undefined);

    const response = await built.app.inject({
      method: 'POST',
      url: '/guilds/guild-1/moderation/kick',
      headers: AUTH,
      payload: { userId: 'user-9', reason: 'spam', confirm: true },
    });

    expect(response.statusCode).toBe(200);
    expect(http.callsTo('DELETE', '/guilds/guild-1/members/user-9')).toHaveLength(1);
  });

  it('times out a member', async () => {
    http.on('PATCH', /^\/guilds\/guild-1\/members\/user-9$/, () => undefined);

    const response = await built.app.inject({
      method: 'POST',
      url: '/guilds/guild-1/moderation/timeout',
      headers: AUTH,
      payload: { userId: 'user-9', durationSeconds: 600, confirm: true },
    });

    expect(response.statusCode).toBe(200);
    const call = http.callsTo('PATCH', '/guilds/guild-1/members/user-9')[0];
    expect((call?.body as { communication_disabled_until: string }).communication_disabled_until)
      .toBeTruthy();
  });

  it('purges between 2 and 100 messages only', async () => {
    http.on('POST', /^\/channels\/channel-1\/messages\/bulk-delete$/, () => undefined);

    const tooFew = await built.app.inject({
      method: 'POST',
      url: '/guilds/guild-1/moderation/purge',
      headers: AUTH,
      payload: { channelId: 'channel-1', messageIds: ['m1'], confirm: true },
    });
    expect(tooFew.statusCode).toBe(400);

    const tooMany = await built.app.inject({
      method: 'POST',
      url: '/guilds/guild-1/moderation/purge',
      headers: AUTH,
      payload: {
        channelId: 'channel-1',
        messageIds: Array.from({ length: 101 }, (_unused, index) => `m${index}`),
        confirm: true,
      },
    });
    expect(tooMany.statusCode).toBe(400);

    const ok = await built.app.inject({
      method: 'POST',
      url: '/guilds/guild-1/moderation/purge',
      headers: AUTH,
      payload: { channelId: 'channel-1', messageIds: ['m1', 'm2'], confirm: true },
    });
    expect(ok.statusCode).toBe(200);
    expect(http.callsTo('POST', 'bulk-delete')[0]?.body).toEqual({ messages: ['m1', 'm2'] });
  });

  it('locks a channel and restores the previous overwrite on unlock', async () => {
    http.on('GET', /^\/channels\/channel-1$/, () => ({
      id: 'channel-1',
      type: 0,
      name: 'general',
      permission_overwrites: [{ id: '@everyone', type: 0, allow: '1024', deny: '0' }],
    }));
    http.on('PUT', /^\/channels\/channel-1\/permissions\/@everyone$/, () => undefined);
    http.on('DELETE', /^\/channels\/channel-1\/permissions\/@everyone$/, () => undefined);

    const lock = await built.app.inject({
      method: 'POST',
      url: '/guilds/guild-1/moderation/lockdown',
      headers: AUTH,
      payload: { channelIds: ['channel-1'], confirm: true },
    });
    expect(lock.statusCode).toBe(200);
    const lockCall = http.callsTo('PUT', '/channels/channel-1/permissions/@everyone')[0];
    expect(lockCall?.body).toMatchObject({ deny: '2112', allow: '0' });

    const unlock = await built.app.inject({
      method: 'POST',
      url: '/guilds/guild-1/moderation/unlock',
      headers: AUTH,
      payload: { channelIds: ['channel-1'], confirm: true },
    });
    expect(unlock.statusCode).toBe(200);
    const restore = http.callsTo('PUT', '/channels/channel-1/permissions/@everyone')[1];
    expect(restore?.body).toMatchObject({ allow: '1024', deny: '0' });
  });

  it('applies slowmode to a single channel and to the whole guild', async () => {
    http.on('PATCH', /^\/channels\/channel-1$/, () => ({
      id: 'channel-1',
      type: 0,
      name: 'general',
      rate_limit_per_user: 30,
    }));

    const single = await built.app.inject({
      method: 'POST',
      url: '/guilds/guild-1/moderation/slowmode',
      headers: AUTH,
      payload: { channelId: 'channel-1', seconds: 30 },
    });
    expect(single.statusCode).toBe(200);

    const mass = await built.app.inject({
      method: 'POST',
      url: '/guilds/guild-1/moderation/mass-slowmode',
      headers: AUTH,
      payload: { seconds: 10 },
    });
    expect(mass.statusCode).toBe(200);
    expect(mass.json()).toMatchObject({ data: { channelIds: ['channel-1'] } });
  });

  it('issues a warning and stores it', async () => {
    const response = await built.app.inject({
      method: 'POST',
      url: '/guilds/guild-1/moderation/warnings',
      headers: AUTH,
      payload: { userId: 'user-9', reason: 'be nice', autoTimeout: false },
    });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toMatchObject({ data: { warningCount: 1, autoTimedOut: false } });

    const list = await built.app.inject({
      method: 'GET',
      url: '/guilds/guild-1/moderation/warnings',
      headers: AUTH,
    });
    const body = list.json() as { data: { warnings: { reason: string }[] } };
    expect(body.data.warnings[0]?.reason).toBe('be nice');
  });

  it('creates, lists and deletes an auto-mod rule', async () => {
    const created: Record<string, unknown>[] = [];
    http.on('GET', /^\/guilds\/guild-1\/auto-moderation\/rules$/, () => created);
    http.on('POST', /^\/guilds\/guild-1\/auto-moderation\/rules$/, (call) => {
      const body = call.body as Record<string, unknown>;
      const rule = {
        id: 'rule-1',
        name: body['name'],
        enabled: body['enabled'],
        trigger_metadata: body['trigger_metadata'],
        actions: body['actions'],
      };
      created.push(rule);
      return rule;
    });
    http.on('DELETE', /^\/guilds\/guild-1\/auto-moderation\/rules\/rule-1$/, () => undefined);

    const create = await built.app.inject({
      method: 'POST',
      url: '/guilds/guild-1/automod/rules',
      headers: AUTH,
      payload: { name: 'Links', kind: 'regex', regexPatterns: ['https?://\\S+'] },
    });
    expect(create.statusCode).toBe(200);

    const createCall = http.callsTo('POST', '/auto-moderation/rules')[0];
    const metadata = (createCall?.body as { trigger_metadata: Record<string, unknown> })
      .trigger_metadata;
    expect(metadata['regex_patterns']).toEqual(['https?://\\S+']);

    const list = await built.app.inject({
      method: 'GET',
      url: '/guilds/guild-1/automod/rules',
      headers: AUTH,
    });
    expect((list.json() as { data: { rules: unknown[] } }).data.rules).toHaveLength(1);

    const remove = await built.app.inject({
      method: 'DELETE',
      url: '/guilds/guild-1/automod/rules/rule-1',
      headers: AUTH,
    });
    expect(remove.statusCode).toBe(200);
  });

  it('changes the verification level', async () => {
    http.on('PATCH', /^\/guilds\/guild-1$/, () => guildPayload({ verification_level: 3 }));

    const response = await built.app.inject({
      method: 'PUT',
      url: '/guilds/guild-1/verification',
      headers: AUTH,
      payload: { level: 3 },
    });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toMatchObject({
      data: { verificationLevel: 3, verificationLevelName: 'High' },
    });
  });

  it('creates, updates and deletes roles', async () => {
    http.on('POST', /^\/guilds\/guild-1\/roles$/, () => ({
      id: 'role-2',
      name: 'Moderator',
      permissions: '0',
      position: 2,
      color: 0,
    }));
    http.on('PATCH', /^\/guilds\/guild-1\/roles\/role-2$/, () => ({
      id: 'role-2',
      name: 'Mods',
      permissions: '8',
      position: 2,
      color: 0,
    }));
    http.on('DELETE', /^\/guilds\/guild-1\/roles\/role-2$/, () => undefined);

    const create = await built.app.inject({
      method: 'POST',
      url: '/guilds/guild-1/roles',
      headers: AUTH,
      payload: { name: 'Moderator' },
    });
    expect(create.statusCode).toBe(200);

    const update = await built.app.inject({
      method: 'PATCH',
      url: '/guilds/guild-1/roles/role-2',
      headers: AUTH,
      payload: { name: 'Mods' },
    });
    expect(update.statusCode).toBe(200);

    const remove = await built.app.inject({
      method: 'DELETE',
      url: '/guilds/guild-1/roles/role-2',
      headers: AUTH,
    });
    expect(remove.statusCode).toBe(200);
  });

  it('inspects member permissions in a channel', async () => {
    http.on(
      'GET',
      /^\/guilds\/guild-1\/channels\/channel-1\/permissions\/user-9$/,
      () => ({ permissions: '2052' }),
    );

    const response = await built.app.inject({
      method: 'GET',
      url: '/guilds/guild-1/members/user-9/permissions?channelId=channel-1',
      headers: AUTH,
    });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toMatchObject({
      data: { inspection: { permissions: '2052', channelId: 'channel-1' } },
    });
  });

  it('creates and deletes channels and overwrites', async () => {
    http.on('POST', /^\/guilds\/guild-1\/channels$/, () => ({
      id: 'channel-2',
      type: 0,
      name: 'news',
    }));
    http.on('DELETE', /^\/channels\/channel-2$/, () => undefined);
    http.on('PUT', /^\/channels\/channel-2\/permissions\/role-1$/, () => undefined);
    http.on('DELETE', /^\/channels\/channel-2\/permissions\/role-1$/, () => undefined);

    const create = await built.app.inject({
      method: 'POST',
      url: '/guilds/guild-1/channels',
      headers: AUTH,
      payload: { name: 'news', type: 0 },
    });
    expect(create.statusCode).toBe(200);

    const overwrite = await built.app.inject({
      method: 'PUT',
      url: '/guilds/guild-1/channels/channel-2/overwrites/role-1',
      headers: AUTH,
      payload: { type: 0, allow: '2048', deny: '0' },
    });
    expect(overwrite.statusCode).toBe(200);

    const removeOverwrite = await built.app.inject({
      method: 'DELETE',
      url: '/guilds/guild-1/channels/channel-2/overwrites/role-1',
      headers: AUTH,
    });
    expect(removeOverwrite.statusCode).toBe(200);

    const remove = await built.app.inject({
      method: 'DELETE',
      url: '/guilds/guild-1/channels/channel-2',
      headers: AUTH,
    });
    expect(remove.statusCode).toBe(200);
  });

  it('schedules an announcement and lists it', async () => {
    const schedule = await built.app.inject({
      method: 'POST',
      url: '/guilds/guild-1/engagement/announcements',
      headers: AUTH,
      payload: {
        channelId: 'channel-1',
        content: 'Server restart in 10 minutes',
        scheduledAt: '2030-01-01T00:00:00.000Z',
      },
    });
    expect(schedule.statusCode).toBe(200);

    const list = await built.app.inject({
      method: 'GET',
      url: '/guilds/guild-1/engagement/announcements',
      headers: AUTH,
    });
    const body = list.json() as { data: { announcements: { content: string }[] } };
    expect(body.data.announcements[0]?.content).toBe('Server restart in 10 minutes');
  });

  it('posts a reaction-role message and stores the bindings', async () => {
    http.on('POST', /^\/channels\/channel-1\/messages$/, () => ({ id: 'message-1' }));
    http.on('PUT', /^\/channels\/channel-1\/messages\/message-1\/reactions\//, () => undefined);

    const response = await built.app.inject({
      method: 'POST',
      url: '/guilds/guild-1/engagement/reaction-role',
      headers: AUTH,
      payload: {
        channelId: 'channel-1',
        content: 'React for role',
        bindings: [{ emoji: '👍', roleId: 'role-1' }],
      },
    });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toMatchObject({ data: { messageId: 'message-1' } });

    const settings = await built.app.inject({
      method: 'GET',
      url: '/guilds/guild-1/settings',
      headers: AUTH,
    });
    const body = settings.json() as { data: { settings: { reactionRoles: unknown[] } } };
    expect(body.data.settings.reactionRoles).toEqual([
      { messageId: 'message-1', emoji: '👍', roleId: 'role-1' },
    ]);
  });

  it('posts a button-role message with a role custom id', async () => {
    http.on('POST', /^\/channels\/channel-1\/messages$/, () => ({ id: 'message-2' }));

    const response = await built.app.inject({
      method: 'POST',
      url: '/guilds/guild-1/engagement/button-role',
      headers: AUTH,
      payload: {
        channelId: 'channel-1',
        content: 'Pick a role',
        buttons: [{ roleId: 'role-1', label: 'Member' }],
      },
    });

    expect(response.statusCode).toBe(200);
    const call = http.callsTo('POST', '/channels/channel-1/messages')[0];
    const components = (call?.body as { components: { components: { custom_id: string }[] }[] })
      .components;
    expect(components[0]?.components[0]?.custom_id).toBe('role:role-1');
  });

  it('manages emojis and stickers', async () => {
    http.on('GET', /^\/guilds\/guild-1\/emojis$/, () => []);
    http.on('POST', /^\/guilds\/guild-1\/emojis$/, () => ({
      id: 'emoji-1',
      name: 'wave',
      roles: [],
    }));
    http.on('DELETE', /^\/guilds\/guild-1\/emojis\/emoji-1$/, () => undefined);
    http.on('GET', /^\/guilds\/guild-1\/stickers$/, () => []);
    http.on('POST', /^\/guilds\/guild-1\/stickers$/, () => ({
      id: 'sticker-1',
      name: 'blob',
      description: 'a blob',
      tags: 'blob',
    }));
    http.on('DELETE', /^\/guilds\/guild-1\/stickers\/sticker-1$/, () => undefined);

    const emoji = await built.app.inject({
      method: 'POST',
      url: '/guilds/guild-1/tools/emojis',
      headers: AUTH,
      payload: { name: 'wave', image: 'data:image/png;base64,AAAA' },
    });
    expect(emoji.statusCode).toBe(200);

    const sticker = await built.app.inject({
      method: 'POST',
      url: '/guilds/guild-1/tools/stickers',
      headers: AUTH,
      payload: {
        name: 'blob',
        description: 'a blob',
        tags: 'blob',
        image: 'data:image/png;base64,AAAA',
      },
    });
    expect(sticker.statusCode).toBe(200);

    const emojiRemove = await built.app.inject({
      method: 'DELETE',
      url: '/guilds/guild-1/tools/emojis/emoji-1',
      headers: AUTH,
    });
    expect(emojiRemove.statusCode).toBe(200);

    const stickerRemove = await built.app.inject({
      method: 'DELETE',
      url: '/guilds/guild-1/tools/stickers/sticker-1',
      headers: AUTH,
    });
    expect(stickerRemove.statusCode).toBe(200);
  });

  it('reads the audit log', async () => {
    http.on('GET', /^\/guilds\/guild-1\/audit-logs$/, () => ({
      audit_log_entries: [
        {
          id: '1',
          action_type: 12,
          target_id: 'user-9',
          user_id: 'bot-1',
          reason: 'spam',
          created_at: '2026-01-01T00:00:00.000Z',
        },
      ],
    }));

    const response = await built.app.inject({
      method: 'GET',
      url: '/guilds/guild-1/tools/audit-log',
      headers: AUTH,
    });

    expect(response.statusCode).toBe(200);
    const body = response.json() as { data: { entries: { targetId: string }[] } };
    expect(body.data.entries[0]?.targetId).toBe('user-9');
  });

  it('exports a backup and restores only missing items', async () => {
    http.on('GET', /^\/guilds\/guild-1\/channels$/, () => [
      { id: 'channel-1', type: 0, name: 'general', position: 0 },
    ]);
    http.on('POST', /^\/guilds\/guild-1\/channels$/, (call) => ({
      id: 'channel-9',
      type: (call.body as { type: number }).type,
      name: (call.body as { name: string }).name,
    }));

    const backup = await built.app.inject({
      method: 'GET',
      url: '/guilds/guild-1/tools/backup',
      headers: AUTH,
    });
    expect(backup.statusCode).toBe(200);
    const document = (backup.json() as { data: { backup: Record<string, unknown> } }).data.backup;

    const restore = await built.app.inject({
      method: 'POST',
      url: '/guilds/guild-1/tools/backup/restore',
      headers: AUTH,
      payload: {
        backup: {
          ...document,
          channels: [
            {
              name: 'general',
              type: 0,
              topic: null,
              rateLimitPerUser: null,
              categoryName: null,
              overwrites: [],
            },
            {
              name: 'archive',
              type: 0,
              topic: null,
              rateLimitPerUser: null,
              categoryName: null,
              overwrites: [],
            },
          ],
        },
      },
    });

    expect(restore.statusCode).toBe(200);
    const body = restore.json() as {
      data: { result: { createdChannels: string[]; skippedChannels: string[] } };
    };
    expect(body.data.result.skippedChannels).toEqual(['general']);
    expect(body.data.result.createdChannels).toEqual(['archive']);
  });

  it('surfaces the real Discord error code and message', async () => {
    http.on('PUT', /^\/guilds\/guild-1\/bans\/user-9$/, () => {
      throw new DiscordApiError({
        status: 403,
        message: 'Missing Permissions',
        code: 50013,
      });
    });

    const response = await built.app.inject({
      method: 'POST',
      url: '/guilds/guild-1/moderation/ban',
      headers: AUTH,
      payload: { userId: 'user-9', confirm: true },
    });

    expect(response.statusCode).toBe(403);
    expect(response.json()).toMatchObject({
      error: { code: 'forbidden', message: 'Missing Permissions', discordCode: 50013 },
    });
  });

  it('returns 429 with retryAfter when Discord rate limits the backend', async () => {
    http.on('PUT', /^\/guilds\/guild-1\/bans\/user-9$/, () => {
      throw new DiscordApiError({
        status: 429,
        message: 'Discord rate limit exceeded.',
        retryAfter: 7,
      });
    });

    const response = await built.app.inject({
      method: 'POST',
      url: '/guilds/guild-1/moderation/ban',
      headers: AUTH,
      payload: { userId: 'user-9', confirm: true },
    });

    expect(response.statusCode).toBe(429);
    expect(response.json()).toMatchObject({
      error: { code: 'rate_limited', retryAfter: 7 },
    });
  });
});
