/**
 * Pages Functions catch-all entry point.
 *
 * A single `onRequest` handles every API route under `/`, which mirrors the
 * original Fastify router in backend/src/routes/*.ts. Cloudflare Pages routes
 * static assets first, so only unmatched paths reach this function.
 */

import { createContext, type AppContext } from './_lib/context';
import type { Env } from './_lib/env';
import { corsHeaders, errorResponse, notFound, ok, parse, readJson, withHeaders } from './_lib/http';
import { handleAuthorize, handleCallbackConfig, handleInteractions, handleMobileCallback } from './_lib/auth';
import { z } from 'zod';
import { autoModRuleRequestSchema } from './_lib/services/automod';
import {
  banRequestSchema,
  kickRequestSchema,
  lockdownRequestSchema,
  purgeRequestSchema,
  slowmodeRequestSchema,
  timeoutRequestSchema,
  unlockRequestSchema,
  warningRequestSchema,
} from './_lib/services/moderation';
import {
  channelPatchSchema,
  channelRequestSchema,
  overwriteRequestSchema,
  rolePatchSchema,
  roleRequestSchema,
} from './_lib/services/access';
import { scheduleAnnouncementSchema } from './_lib/services/engagement';
import {
  backupDocumentSchema,
  emojiPatchSchema,
  emojiRequestSchema,
  stickerPatchSchema,
  stickerRequestSchema,
} from './_lib/services/tools';
import { verificationRequestSchema } from './_lib/services/guild';
import { gatewayStatus } from './_lib/gatewayStatus';

export const onRequest: PagesFunction<Env> = async (context): Promise<Response> => {
  const env = context.env as Env;
  const request = context.request;
  const ctx = createContext({ env, request });
  const cors = corsHeaders(env, request);

  try {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: cors });
    }

    const url = new URL(request.url);
    const method = request.method;
    const path = url.pathname;

    const response = await route(ctx, method, path, url, request);
    return withHeaders(response, cors);
  } catch (error) {
    return withHeaders(errorResponse(error, cors), cors);
  }
};

async function route(
  ctx: AppContext,
  method: string,
  path: string,
  url: URL,
  request: Request,
): Promise<Response> {
  /* ---- Health ---- */
  if (path === '/health' && method === 'GET') {
    return ok({
      status: 'ok',
      platform: 'cloudflare-pages',
      gateway: gatewayStatus(ctx.env),
      botConfigured: Boolean(ctx.env.DISCORD_BOT_TOKEN ?? ''),
      interactionsConfigured: Boolean(ctx.env.DISCORD_PUBLIC_KEY ?? ''),
    });
  }

  /* ---- Auth ---- */
  if (path === '/auth/authorize' && method === 'GET') return handleAuthorize(ctx);
  if (path === '/auth/mobile-callback' && method === 'GET') return handleMobileCallback(ctx);
  if (path === '/auth/mobile-callback/config' && method === 'GET') return handleCallbackConfig(ctx);

  /* ---- Interactions ---- */
  if (path === '/interactions' && method === 'POST') return handleInteractions(ctx);

  /* ---- Guild API ---- */
  if (path.startsWith('/guilds/')) return guildRoutes(ctx, method, path, url, request);

  return notFound(method, path);
}

/* -------------------------------------------------------------------------- */
/* Guild routes — port of backend/src/routes/guilds.ts                         */
/* -------------------------------------------------------------------------- */

const guildIdParams = z.object({ id: z.string().min(1) });

const reactionRoleRequestSchema = z.object({
  channelId: z.string().min(1),
  content: z.string().max(2000).default(''),
  bindings: z
    .array(z.object({ emoji: z.string().min(1), roleId: z.string().min(1) }))
    .min(1),
});

const buttonRoleRequestSchema = z.object({
  channelId: z.string().min(1),
  content: z.string().max(2000).default(''),
  buttons: z
    .array(z.object({ roleId: z.string().min(1), label: z.string().min(1).max(80) }))
    .min(1)
    .max(5),
});

const memberPermissionsQuerySchema = z.object({
  channelId: z.string().min(1),
});

const settingsPatchSchema = z.object({
  welcomeEnabled: z.boolean().optional(),
  welcomeChannelId: z.string().nullable().optional(),
  welcomeMessage: z.string().max(500).optional(),
  goodbyeEnabled: z.boolean().optional(),
  goodbyeChannelId: z.string().nullable().optional(),
  goodbyeMessage: z.string().max(500).optional(),
  autoRoleIds: z.array(z.string()).optional(),
  moderationLogChannelId: z.string().nullable().optional(),
  autoTimeoutThreshold: z.number().int().min(1).max(100).nullable().optional(),
  autoTimeoutDurationSeconds: z.number().int().min(60).max(28 * 24 * 3600).nullable().optional(),
});

type RouteParts = { segments: string[] };

function splitPath(path: string): RouteParts {
  return { segments: path.split('/').filter((segment) => segment.length > 0) };
}

/** Requires access to the guild and returns the caller identity. */
async function requireAccess(ctx: AppContext, guildId: string) {
  return ctx.guard.requireGuild(ctx.request.headers.get('Authorization'), guildId);
}

async function guildRoutes(
  ctx: AppContext,
  method: string,
  path: string,
  url: URL,
  request: Request,
): Promise<Response> {
  const { segments } = splitPath(path);
  // segments[0] === 'guilds', segments[1] === guildId
  if (segments[0] !== 'guilds' || segments.length < 2) {
    return notFound(method, path);
  }

  const guildId = parse(guildIdParams, { id: segments[1] }).id;

  // /guilds/:id
  if (segments.length === 2) {
    return notFound(method, path);
  }

  const section = segments[2];

  /* ---- status & overview ---- */
  if (section === 'status' && method === 'GET' && segments.length === 3) {
    await requireAccess(ctx, guildId);
    const overview = await ctx.guild.getOverview(guildId, await ctx.botUserId());
    return ok({
      guildId,
      botPresent: overview.botPresent,
      verificationLevel: overview.verificationLevel,
      gateway: gatewayStatus(ctx.env),
    });
  }

  if (section === 'overview' && method === 'GET' && segments.length === 3) {
    await requireAccess(ctx, guildId);
    const overview = await ctx.guild.getOverview(guildId, await ctx.botUserId());
    return ok({ ...overview, gateway: gatewayStatus(ctx.env) });
  }

  if (section === 'verification' && segments.length === 3) {
    if (method === 'GET') {
      await requireAccess(ctx, guildId);
      const overview = await ctx.guild.getOverview(guildId, await ctx.botUserId());
      return ok({
        verificationLevel: overview.verificationLevel,
        verificationLevelName: overview.verificationLevelName,
      });
    }
    if (method === 'PUT') {
      const accessResult = await requireAccess(ctx, guildId);
      const body = parse(verificationRequestSchema, await readJson(request));
      const result = await ctx.guild.setVerificationLevel(guildId, accessResult.callerId, body);
      return ok(result);
    }
  }

  if (section === 'insights' && method === 'GET' && segments.length === 3) {
    await requireAccess(ctx, guildId);
    return ok({ points: ctx.guild.listInsights(guildId) });
  }

  /* ---- moderation ---- */
  if (section === 'moderation' && segments.length >= 4) {
    const action = segments[3];

    if (action === 'ban' && method === 'POST') {
      const accessResult = await requireAccess(ctx, guildId);
      const body = parse(banRequestSchema, await readJson(request));
      return ok(await ctx.moderation.ban(guildId, accessResult.callerId, body));
    }
    if (action === 'unban' && method === 'POST') {
      const accessResult = await requireAccess(ctx, guildId);
      const body = parse(z.object({ userId: z.string().min(1) }), await readJson(request));
      return ok(await ctx.moderation.unban(guildId, accessResult.callerId, body.userId));
    }
    if (action === 'kick' && method === 'POST') {
      const accessResult = await requireAccess(ctx, guildId);
      const body = parse(kickRequestSchema, await readJson(request));
      return ok(await ctx.moderation.kick(guildId, accessResult.callerId, body));
    }
    if (action === 'timeout' && method === 'POST') {
      const accessResult = await requireAccess(ctx, guildId);
      const body = parse(timeoutRequestSchema, await readJson(request));
      return ok(await ctx.moderation.timeout(guildId, accessResult.callerId, body));
    }
    if (action === 'clear-timeout' && method === 'POST') {
      const accessResult = await requireAccess(ctx, guildId);
      const body = parse(z.object({ userId: z.string().min(1) }), await readJson(request));
      return ok(await ctx.moderation.clearTimeout(guildId, accessResult.callerId, body.userId));
    }
    if (action === 'purge' && method === 'POST') {
      const accessResult = await requireAccess(ctx, guildId);
      const body = parse(purgeRequestSchema, await readJson(request));
      return ok(await ctx.moderation.purge(guildId, accessResult.callerId, body));
    }
    if (action === 'lockdown' && method === 'POST') {
      const accessResult = await requireAccess(ctx, guildId);
      const body = parse(lockdownRequestSchema, await readJson(request));
      return ok(await ctx.moderation.lockdown(guildId, accessResult.callerId, body));
    }
    if (action === 'unlock' && method === 'POST') {
      const accessResult = await requireAccess(ctx, guildId);
      const body = parse(unlockRequestSchema, await readJson(request));
      return ok(await ctx.moderation.unlock(guildId, accessResult.callerId, body));
    }
    if (action === 'slowmode' && method === 'POST') {
      const accessResult = await requireAccess(ctx, guildId);
      const body = parse(slowmodeRequestSchema, await readJson(request));
      return ok(await ctx.moderation.setSlowmode(guildId, accessResult.callerId, body));
    }
    if (action === 'mass-slowmode' && method === 'POST') {
      const accessResult = await requireAccess(ctx, guildId);
      const body = parse(z.object({ seconds: z.number().int().min(0).max(21_600) }), await readJson(request));
      return ok(await ctx.moderation.massSlowmode(guildId, accessResult.callerId, body.seconds));
    }
    if (action === 'warnings' && segments.length === 4) {
      if (method === 'GET') {
        await requireAccess(ctx, guildId);
        return ok({ warnings: await ctx.moderation.listWarnings(guildId) });
      }
      if (method === 'POST') {
        const accessResult = await requireAccess(ctx, guildId);
        const body = parse(warningRequestSchema, await readJson(request));
        return ok(await ctx.moderation.issueWarning(guildId, accessResult.callerId, body));
      }
    }
  }

  /* ---- automod ---- */
  if (section === 'automod' && segments.length >= 4 && segments[3] === 'rules') {
    if (segments.length === 4) {
      if (method === 'GET') {
        await requireAccess(ctx, guildId);
        return ok({ rules: await ctx.automod.list(guildId) });
      }
      if (method === 'POST') {
        const accessResult = await requireAccess(ctx, guildId);
        const body = parse(autoModRuleRequestSchema, await readJson(request));
        const rule = await ctx.automod.create(guildId, accessResult.callerId, body);
        return ok({ rule });
      }
    }
    if (segments.length === 5) {
      const ruleId = segments[4];
      if (method === 'PATCH') {
        const accessResult = await requireAccess(ctx, guildId);
        const body = parse(autoModRuleRequestSchema, await readJson(request));
        const rule = await ctx.automod.update(guildId, accessResult.callerId, ruleId, body);
        return ok({ rule });
      }
      if (method === 'DELETE') {
        const accessResult = await requireAccess(ctx, guildId);
        return ok(await ctx.automod.remove(guildId, accessResult.callerId, ruleId));
      }
    }
  }

  /* ---- roles ---- */
  if (section === 'roles') {
    if (segments.length === 3) {
      if (method === 'GET') {
        await requireAccess(ctx, guildId);
        return ok({ roles: await ctx.access.listRoles(guildId) });
      }
      if (method === 'POST') {
        const accessResult = await requireAccess(ctx, guildId);
        const body = parse(roleRequestSchema, await readJson(request));
        return ok({ role: await ctx.access.createRole(guildId, accessResult.callerId, body) });
      }
    }
    if (segments.length === 4) {
      const roleId = segments[3];
      if (method === 'PATCH') {
        const accessResult = await requireAccess(ctx, guildId);
        const body = parse(rolePatchSchema, await readJson(request));
        return ok({ role: await ctx.access.updateRole(guildId, accessResult.callerId, roleId, body) });
      }
      if (method === 'DELETE') {
        const accessResult = await requireAccess(ctx, guildId);
        return ok(await ctx.access.deleteRole(guildId, accessResult.callerId, roleId));
      }
    }
  }

  /* ---- members ---- */
  if (section === 'members') {
    if (segments.length === 3) {
      if (method === 'GET') {
        await requireAccess(ctx, guildId);
        const query = parse(
          z.object({ limit: z.coerce.number().int().min(1).max(1000).default(100), after: z.string().optional() }),
          Object.fromEntries(url.searchParams.entries()),
        );
        return ok({ members: await ctx.access.listMembers(guildId, query.limit, query.after) });
      }
    }
    if (segments.length === 4) {
      const userId = segments[3];
      if (method === 'GET') {
        await requireAccess(ctx, guildId);
        return ok({ member: await ctx.access.getMember(guildId, userId) });
      }
    }
    if (segments.length === 5 && segments[4] === 'permissions' && method === 'GET') {
      await requireAccess(ctx, guildId);
      const query = parse(memberPermissionsQuerySchema, Object.fromEntries(url.searchParams.entries()));
      const inspection = await ctx.access.inspectMemberPermissions(guildId, query.channelId, segments[3]);
      return ok({ inspection });
    }
  }

  /* ---- channels ---- */
  if (section === 'channels') {
    if (segments.length === 3 && method === 'GET') {
      await requireAccess(ctx, guildId);
      return ok({ channels: await ctx.access.listChannels(guildId) });
    }
    if (segments.length === 3 && method === 'POST') {
      const accessResult = await requireAccess(ctx, guildId);
      const body = parse(channelRequestSchema, await readJson(request));
      return ok({ channel: await ctx.access.createChannel(guildId, accessResult.callerId, body) });
    }
    if (segments.length === 4) {
      const channelId = segments[3];
      if (method === 'PATCH') {
        const accessResult = await requireAccess(ctx, guildId);
        const body = parse(channelPatchSchema, await readJson(request));
        return ok({ channel: await ctx.access.updateChannel(guildId, accessResult.callerId, channelId, body) });
      }
      if (method === 'DELETE') {
        const accessResult = await requireAccess(ctx, guildId);
        return ok(await ctx.access.deleteChannel(guildId, accessResult.callerId, channelId));
      }
    }
    if (segments.length === 5 && segments[4] === 'messages' && method === 'GET') {
      await requireAccess(ctx, guildId);
      const query = parse(
        z.object({ limit: z.coerce.number().int().min(1).max(100).default(50) }),
        Object.fromEntries(url.searchParams.entries()),
      );
      return ok({ messages: await ctx.access.listMessages(guildId, segments[3], query.limit) });
    }
    if (segments.length === 6 && segments[4] === 'overwrites' && method === 'PUT') {
      const accessResult = await requireAccess(ctx, guildId);
      const targetId = segments[5];
      const body = parse(overwriteRequestSchema, await readJson(request));
      return ok(await ctx.access.createOverwrite(guildId, accessResult.callerId, segments[3], targetId, body));
    }
    if (segments.length === 6 && segments[4] === 'overwrites' && method === 'DELETE') {
      const accessResult = await requireAccess(ctx, guildId);
      return ok(await ctx.access.deleteOverwrite(guildId, accessResult.callerId, segments[3], segments[5]));
    }
  }

  /* ---- engagement ---- */
  if (section === 'engagement') {
    if (segments.length === 4 && segments[3] === 'announcements') {
      if (method === 'GET') {
        await requireAccess(ctx, guildId);
        return ok({ announcements: await ctx.engagement.list(guildId) });
      }
      if (method === 'POST') {
        const accessResult = await requireAccess(ctx, guildId);
        const body = parse(scheduleAnnouncementSchema, await readJson(request));
        return ok({ announcement: await ctx.engagement.schedule(guildId, accessResult.callerId, body) });
      }
    }
    if (segments.length === 6 && segments[3] === 'announcements' && segments[5] === 'cancel' && method === 'POST') {
      const accessResult = await requireAccess(ctx, guildId);
      return ok(await ctx.engagement.cancel(guildId, accessResult.callerId, segments[4]));
    }
    if (segments.length === 4 && segments[3] === 'invites' && method === 'GET') {
      await requireAccess(ctx, guildId);
      return ok({ invites: await ctx.engagement.listInvites(guildId) });
    }
    if (segments.length === 4 && segments[3] === 'joins' && method === 'GET') {
      await requireAccess(ctx, guildId);
      return ok({ joins: await ctx.engagement.listJoins(guildId) });
    }
    if (segments.length === 4 && segments[3] === 'reaction-role' && method === 'POST') {
      await requireAccess(ctx, guildId);
      const body = parse(reactionRoleRequestSchema, await readJson(request));
      const message = await ctx.api.sendChannelMessage(body.channelId, {
        content: body.content,
        allowed_mentions: { parse: [] },
      });
      for (const binding of body.bindings) {
        await ctx.api.addOwnReaction(body.channelId, message.id, binding.emoji);
      }
      const current = await ctx.repos.settings.get(guildId);
      current.reactionRoles = [
        ...current.reactionRoles.filter((entry) => entry.messageId !== message.id),
        ...body.bindings.map((binding) => ({
          messageId: message.id,
          emoji: binding.emoji,
          roleId: binding.roleId,
        })),
      ];
      await ctx.repos.settings.save(guildId, current);
      return ok({ messageId: message.id, bindings: body.bindings });
    }
    if (segments.length === 4 && segments[3] === 'button-role' && method === 'POST') {
      await requireAccess(ctx, guildId);
      const body = parse(buttonRoleRequestSchema, await readJson(request));
      const message = await ctx.api.sendChannelMessage(body.channelId, {
        content: body.content,
        components: [
          {
            type: 1,
            components: body.buttons.map((button) => ({
              type: 2,
              style: 1,
              label: button.label,
              custom_id: `role:${button.roleId}`,
            })),
          },
        ],
      });
      return ok({ messageId: message.id });
    }
  }

  /* ---- tools ---- */
  if (section === 'tools') {
    if (segments.length === 4 && segments[3] === 'emojis') {
      if (method === 'GET') {
        await requireAccess(ctx, guildId);
        return ok({ emojis: await ctx.tools.listEmojis(guildId) });
      }
      if (method === 'POST') {
        const accessResult = await requireAccess(ctx, guildId);
        const body = parse(emojiRequestSchema, await readJson(request));
        return ok({ emoji: await ctx.tools.createEmoji(guildId, accessResult.callerId, body) });
      }
    }
    if (segments.length === 5 && segments[3] === 'emojis') {
      const emojiId = segments[4];
      if (method === 'PATCH') {
        const accessResult = await requireAccess(ctx, guildId);
        const body = parse(emojiPatchSchema, await readJson(request));
        return ok({ emoji: await ctx.tools.updateEmoji(guildId, accessResult.callerId, emojiId, body) });
      }
      if (method === 'DELETE') {
        const accessResult = await requireAccess(ctx, guildId);
        return ok(await ctx.tools.deleteEmoji(guildId, accessResult.callerId, emojiId));
      }
    }
    if (segments.length === 4 && segments[3] === 'stickers') {
      if (method === 'GET') {
        await requireAccess(ctx, guildId);
        return ok({ stickers: await ctx.tools.listStickers(guildId) });
      }
      if (method === 'POST') {
        const accessResult = await requireAccess(ctx, guildId);
        const body = parse(stickerRequestSchema, await readJson(request));
        return ok({ sticker: await ctx.tools.createSticker(guildId, accessResult.callerId, body) });
      }
    }
    if (segments.length === 5 && segments[3] === 'stickers') {
      const stickerId = segments[4];
      if (method === 'PATCH') {
        const accessResult = await requireAccess(ctx, guildId);
        const body = parse(stickerPatchSchema, await readJson(request));
        return ok({ sticker: await ctx.tools.updateSticker(guildId, accessResult.callerId, stickerId, body) });
      }
      if (method === 'DELETE') {
        const accessResult = await requireAccess(ctx, guildId);
        return ok(await ctx.tools.deleteSticker(guildId, accessResult.callerId, stickerId));
      }
    }
    if (segments.length === 4 && segments[3] === 'audit-log' && method === 'GET') {
      await requireAccess(ctx, guildId);
      const query = parse(
        z.object({ limit: z.coerce.number().int().min(1).max(100).default(50) }),
        Object.fromEntries(url.searchParams.entries()),
      );
      return ok({ entries: await ctx.tools.readAuditLog(guildId, query.limit) });
    }
    if (segments.length === 4 && segments[3] === 'backup' && method === 'GET') {
      await requireAccess(ctx, guildId);
      return ok({ backup: await ctx.tools.exportBackup(guildId) });
    }
    if (segments.length === 5 && segments[3] === 'backup' && segments[4] === 'restore' && method === 'POST') {
      const accessResult = await requireAccess(ctx, guildId);
      const body = parse(z.object({ backup: backupDocumentSchema }), await readJson(request));
      return ok({ result: await ctx.tools.importBackup(guildId, accessResult.callerId, body.backup) });
    }
  }

  /* ---- settings ---- */
  if (section === 'settings' && segments.length === 3) {
    if (method === 'GET') {
      await requireAccess(ctx, guildId);
      return ok({ settings: await ctx.repos.settings.get(guildId) });
    }
    if (method === 'PUT') {
      await requireAccess(ctx, guildId);
      const patch = parse(settingsPatchSchema, await readJson(request));
      const current = await ctx.repos.settings.get(guildId);
      const merged = { ...current };
      for (const [key, value] of Object.entries(patch)) {
        if (value !== undefined) Object.assign(merged, { [key]: value });
      }
      await ctx.repos.settings.save(guildId, merged);
      return ok({ settings: merged });
    }
  }

  return notFound(method, path);
}
