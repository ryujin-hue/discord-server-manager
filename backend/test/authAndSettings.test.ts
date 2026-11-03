import { describe, expect, it } from 'vitest';
import { buildApp } from '../src/app.js';
import { FakeDiscordHttp, guildPayload, testConfig } from './helpers.js';

const AUTH = { authorization: 'Bearer user-token' };

describe('auth callback', () => {
  it('forwards only the whitelisted parameters to the mobile scheme', async () => {
    const built = buildApp({ config: testConfig(), httpClient: new FakeDiscordHttp() });

    const response = await built.app.inject({
      method: 'GET',
      url: '/auth/mobile-callback?code=abc&state=xyz&error=access_denied&error_description=denied&secret=leak',
    });

    expect(response.statusCode).toBe(302);
    const location = response.headers['location'];
    expect(location).toBeDefined();
    const target = new URL(location as string);
    expect(target.protocol).toBe('my-discord-manager:');
    expect(target.host).toBe('oauth2');
    expect(target.searchParams.get('code')).toBe('abc');
    expect(target.searchParams.get('state')).toBe('xyz');
    expect(target.searchParams.get('error')).toBe('access_denied');
    expect(target.searchParams.get('error_description')).toBe('denied');
    expect(target.searchParams.get('secret')).toBeNull();
  });

  it('forwards an error callback without a code', async () => {
    const built = buildApp({ config: testConfig(), httpClient: new FakeDiscordHttp() });

    const response = await built.app.inject({
      method: 'GET',
      url: '/auth/mobile-callback?error=access_denied&error_description=The+user+denied',
    });

    expect(response.statusCode).toBe(302);
    const target = new URL(response.headers['location'] as string);
    expect(target.searchParams.get('error')).toBe('access_denied');
    expect(target.searchParams.get('code')).toBeNull();
  });

  it('needs no authorization', async () => {
    const built = buildApp({ config: testConfig(), httpClient: new FakeDiscordHttp() });

    const response = await built.app.inject({
      method: 'GET',
      url: '/auth/mobile-callback?code=abc',
    });

    expect(response.statusCode).toBe(302);
  });
});

describe('settings round trip', () => {
  it('persists the settings that were sent', async () => {
    const http = new FakeDiscordHttp();
    http.on('GET', /^\/users\/@me\/guilds$/, () => [guildPayload()]);
    const built = buildApp({ config: testConfig(), httpClient: http });

    const update = await built.app.inject({
      method: 'PUT',
      url: '/guilds/guild-1/settings',
      headers: AUTH,
      payload: {
        welcomeEnabled: true,
        welcomeChannelId: 'channel-1',
        welcomeMessage: 'Hi {user}',
        autoRoleIds: ['role-1'],
        moderationLogChannelId: 'channel-2',
        autoTimeoutThreshold: 3,
        autoTimeoutDurationSeconds: 600,
      },
    });

    expect(update.statusCode).toBe(200);

    const read = await built.app.inject({
      method: 'GET',
      url: '/guilds/guild-1/settings',
      headers: AUTH,
    });

    const settings = (read.json() as { data: { settings: Record<string, unknown> } }).data.settings;
    expect(settings['welcomeEnabled']).toBe(true);
    expect(settings['welcomeChannelId']).toBe('channel-1');
    expect(settings['welcomeMessage']).toBe('Hi {user}');
    expect(settings['autoRoleIds']).toEqual(['role-1']);
    expect(settings['moderationLogChannelId']).toBe('channel-2');
    expect(settings['autoTimeoutThreshold']).toBe(3);
    expect(settings['autoTimeoutDurationSeconds']).toBe(600);
  });

  it('keeps the values that were not part of the patch', async () => {
    const http = new FakeDiscordHttp();
    http.on('GET', /^\/users\/@me\/guilds$/, () => [guildPayload()]);
    const built = buildApp({ config: testConfig(), httpClient: http });

    await built.app.inject({
      method: 'PUT',
      url: '/guilds/guild-1/settings',
      headers: AUTH,
      payload: { welcomeEnabled: true, welcomeChannelId: 'channel-1' },
    });
    await built.app.inject({
      method: 'PUT',
      url: '/guilds/guild-1/settings',
      headers: AUTH,
      payload: { goodbyeEnabled: true },
    });

    const read = await built.app.inject({
      method: 'GET',
      url: '/guilds/guild-1/settings',
      headers: AUTH,
    });
    const settings = (read.json() as { data: { settings: Record<string, unknown> } }).data.settings;
    expect(settings['welcomeEnabled']).toBe(true);
    expect(settings['welcomeChannelId']).toBe('channel-1');
    expect(settings['goodbyeEnabled']).toBe(true);
  });

  it('rejects an invalid settings body', async () => {
    const http = new FakeDiscordHttp();
    http.on('GET', /^\/users\/@me\/guilds$/, () => [guildPayload()]);
    const built = buildApp({ config: testConfig(), httpClient: http });

    const response = await built.app.inject({
      method: 'PUT',
      url: '/guilds/guild-1/settings',
      headers: AUTH,
      payload: { welcomeEnabled: 'yes' },
    });

    expect(response.statusCode).toBe(400);
    expect(response.json()).toMatchObject({ error: { code: 'validation_failed' } });
  });
});
