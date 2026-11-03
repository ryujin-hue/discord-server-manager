import { describe, expect, it } from 'vitest';
import { buildApp } from '../src/app.js';
import { DiscordApi } from '../src/discord/api.js';
import { AccessGuard } from '../src/services/accessGuard.js';
import { DiscordApiError } from '../src/discord/rest.js';
import { FakeDiscordHttp, guildPayload, testConfig } from './helpers.js';

describe('AccessGuard', () => {
  const build = (http: FakeDiscordHttp) => {
    const api = new DiscordApi(http);
    return new AccessGuard(api, 60_000);
  };

  it('rejects a request without an Authorization header with 401', async () => {
    const http = new FakeDiscordHttp();
    const guard = build(http);

    await expect(guard.requireGuild(undefined, 'guild-1')).rejects.toMatchObject({
      code: 'unauthorized',
      statusCode: 401,
    });
  });

  it('rejects a malformed Authorization header with 401', async () => {
    const http = new FakeDiscordHttp();
    const guard = build(http);

    await expect(guard.requireGuild('Basic abc', 'guild-1')).rejects.toMatchObject({
      code: 'unauthorized',
    });
  });

  it('maps an invalid token from Discord to 401', async () => {
    const http = new FakeDiscordHttp();
    http.on('GET', /^\/users\/@me\/guilds$/, () => {
      throw new DiscordApiError({
        status: 401,
        message: '401: Unauthorized',
        code: 0,
      });
    });
    const guard = build(http);

    await expect(guard.requireGuild('Bearer bad-token', 'guild-1')).rejects.toMatchObject({
      code: 'unauthorized',
      statusCode: 401,
    });
  });

  it('returns 403 when the user does not administer the guild', async () => {
    const http = new FakeDiscordHttp();
    http.on('GET', /^\/users\/@me\/guilds$/, () => [
      guildPayload({ id: 'other-guild', owner: false, permissions: '1024' }),
    ]);
    const guard = build(http);

    await expect(guard.requireGuild('Bearer token', 'guild-1')).rejects.toMatchObject({
      code: 'forbidden',
      statusCode: 403,
    });
  });

  it('returns 403 when the member lacks ADMINISTRATOR and MANAGE_GUILD', async () => {
    const http = new FakeDiscordHttp();
    http.on('GET', /^\/users\/@me\/guilds$/, () => [
      guildPayload({ owner: false, permissions: '1024' }),
    ]);
    const guard = build(http);

    await expect(guard.requireGuild('Bearer token', 'guild-1')).rejects.toMatchObject({
      code: 'forbidden',
      statusCode: 403,
    });
  });

  it('accepts a member with MANAGE_GUILD', async () => {
    const http = new FakeDiscordHttp();
    http.on('GET', /^\/users\/@me\/guilds$/, () => [
      guildPayload({ owner: false, permissions: '32' }),
    ]);
    const guard = build(http);

    const access = await guard.requireGuild('Bearer token', 'guild-1');
    expect(access.guildId).toBe('guild-1');
  });

  it('accepts the guild owner even without any permission bit', async () => {
    const http = new FakeDiscordHttp();
    http.on('GET', /^\/users\/@me\/guilds$/, () => [
      guildPayload({ owner: true, permissions: '0' }),
    ]);
    const guard = build(http);

    const access = await guard.requireGuild('Bearer token', 'guild-1');
    expect(access.guild.id).toBe('guild-1');
  });

  it('follows the after parameter until a page has fewer than 200 guilds', async () => {
    const http = new FakeDiscordHttp();
    http.on('GET', /^\/users\/@me\/guilds$/, (call) => {
      const after = call.query?.['after'];
      if (after === undefined) {
        return Array.from({ length: 200 }, (_unused, index) =>
          guildPayload({ id: `guild-${index}`, owner: index === 199 }),
        );
      }
      return [guildPayload({ id: 'guild-200', owner: true })];
    });
    const guard = build(http);

    const access = await guard.requireGuild('Bearer token', 'guild-200');
    expect(access.guildId).toBe('guild-200');
    expect(http.callsTo('GET', '/users/@me/guilds')).toHaveLength(2);
    expect(http.calls[1]?.query?.['after']).toBe('guild-199');
  });

  it('caches the guild list for 60 seconds and never stores the token', async () => {
    const http = new FakeDiscordHttp();
    http.on('GET', /^\/users\/@me\/guilds$/, () => [guildPayload()]);
    const guard = build(http);

    await guard.requireGuild('Bearer token', 'guild-1');
    await guard.requireGuild('Bearer token', 'guild-1');

    expect(http.callsTo('GET', '/users/@me/guilds')).toHaveLength(1);
  });
});

describe('guild routes guard', () => {
  it('answers 401 without a bearer token', async () => {
    const http = new FakeDiscordHttp();
    const built = buildApp({ config: testConfig(), httpClient: http });

    const response = await built.app.inject({
      method: 'GET',
      url: '/guilds/guild-1/overview',
    });

    expect(response.statusCode).toBe(401);
    expect(response.json()).toMatchObject({ error: { code: 'unauthorized' } });
  });

  it('answers 403 when the caller does not administer the guild', async () => {
    const http = new FakeDiscordHttp();
    http.on('GET', /^\/users\/@me\/guilds$/, () => [
      guildPayload({ owner: false, permissions: '1024' }),
    ]);
    const built = buildApp({ config: testConfig(), httpClient: http });

    const response = await built.app.inject({
      method: 'GET',
      url: '/guilds/guild-1/overview',
      headers: { authorization: 'Bearer token' },
    });

    expect(response.statusCode).toBe(403);
    expect(response.json()).toMatchObject({ error: { code: 'forbidden' } });
  });
});
