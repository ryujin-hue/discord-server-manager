import type { FastifyInstance, FastifyRequest } from 'fastify';
import { z } from 'zod';
import type { DiscordApi } from '../discord/api.js';
import type { AccessGuard } from '../services/accessGuard.js';
import type { ModerationService } from '../services/moderationService.js';
import type { AutoModService } from '../services/automodService.js';
import type { AccessService } from '../services/accessService.js';
import type { EngagementService } from '../services/engagementService.js';
import type { ToolService } from '../services/toolService.js';
import type { GuildService } from '../services/guildService.js';
import type {
  GuildSettings,
  LockdownRepository,
  SettingsRepository,
} from '../db/repositories.js';
import { AppError } from '../errors.js';
import { mapDiscordError } from '../discord/rest.js';
import { autoModRuleRequestSchema } from '../services/automodService.js';
import {
  banRequestSchema,
  kickRequestSchema,
  lockdownRequestSchema,
  purgeRequestSchema,
  slowmodeRequestSchema,
  timeoutRequestSchema,
  unlockRequestSchema,
  warningRequestSchema,
} from '../services/moderationService.js';
import {
  channelPatchSchema,
  channelRequestSchema,
  overwriteRequestSchema,
  rolePatchSchema,
  roleRequestSchema,
} from '../services/accessService.js';
import { scheduleAnnouncementSchema } from '../services/engagementService.js';
import {
  emojiPatchSchema,
  emojiRequestSchema,
  stickerPatchSchema,
  stickerRequestSchema,
  backupDocumentSchema,
} from '../services/toolService.js';
import { verificationRequestSchema } from '../services/guildService.js';

export type GatewayStatusProvider = {
  getStatus(): { connected: boolean; error?: string };
};

export type GuildRouteDeps = {
  guard: AccessGuard;
  api: DiscordApi;
  moderation: ModerationService;
  automod: AutoModService;
  access: AccessService;
  engagement: EngagementService;
  tools: ToolService;
  guildService: GuildService;
  settings: SettingsRepository;
  locks: LockdownRepository;
  gateway: GatewayStatusProvider;
  botUserId: string;
};

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

function parse<T>(schema: z.ZodType<T>, value: unknown): T {
  const result = schema.safeParse(value);
  if (!result.success) {
    const message = result.error.issues
      .map((issue) => `${issue.path.join('.') || 'body'}: ${issue.message}`)
      .join('; ');
    throw AppError.validation(message);
  }
  return result.data;
}

function guildId(request: FastifyRequest): string {
  return parse(guildIdParams, request.params).id;
}

export function registerGuildRoutes(app: FastifyInstance, deps: GuildRouteDeps): void {
  const { guard, api, moderation, automod, access, engagement, tools, guildService, settings } =
    deps;

  const requireAccess = async (request: FastifyRequest, id: string) => {
    const accessResult = await guard.requireGuild(request.headers.authorization, id);
    request.log.info(
      { action: 'guild.access', guildId: id, userId: accessResult.callerId ?? 'unknown' },
      'guild access granted',
    );
    return accessResult;
  };

  app.get('/guilds/:id/status', async (request) => {
    const id = guildId(request);
    await requireAccess(request, id);
    const overview = await guildService.getOverview(id, deps.botUserId);
    return {
      data: {
        guildId: id,
        botPresent: overview.botPresent,
        verificationLevel: overview.verificationLevel,
        gateway: deps.gateway.getStatus(),
      },
    };
  });

  app.get('/guilds/:id/overview', async (request) => {
    const id = guildId(request);
    await requireAccess(request, id);
    const overview = await guildService.getOverview(id, deps.botUserId);
    return { data: { ...overview, gateway: deps.gateway.getStatus() } };
  });

  app.get('/guilds/:id/verification', async (request) => {
    const id = guildId(request);
    await requireAccess(request, id);
    const overview = await guildService.getOverview(id, deps.botUserId);
    return {
      data: {
        verificationLevel: overview.verificationLevel,
        verificationLevelName: overview.verificationLevelName,
      },
    };
  });

  app.put('/guilds/:id/verification', async (request) => {
    const id = guildId(request);
    const accessResult = await requireAccess(request, id);
    const body = parse(verificationRequestSchema, request.body);
    const result = await guildService.setVerificationLevel(id, accessResult.callerId, body);
    return { data: result };
  });

  app.get('/guilds/:id/insights', async (request) => {
    const id = guildId(request);
    await requireAccess(request, id);
    return { data: { points: guildService.listInsights(id) } };
  });

  app.post('/guilds/:id/moderation/ban', async (request) => {
    const id = guildId(request);
    const accessResult = await requireAccess(request, id);
    const body = parse(banRequestSchema, request.body);
    const result = await moderation.ban(id, accessResult.callerId, body);
    return { data: result };
  });

  app.post('/guilds/:id/moderation/unban', async (request) => {
    const id = guildId(request);
    const accessResult = await requireAccess(request, id);
    const body = parse(z.object({ userId: z.string().min(1) }), request.body);
    const result = await moderation.unban(id, accessResult.callerId, body.userId);
    return { data: result };
  });

  app.post('/guilds/:id/moderation/kick', async (request) => {
    const id = guildId(request);
    const accessResult = await requireAccess(request, id);
    const body = parse(kickRequestSchema, request.body);
    const result = await moderation.kick(id, accessResult.callerId, body);
    return { data: result };
  });

  app.post('/guilds/:id/moderation/timeout', async (request) => {
    const id = guildId(request);
    const accessResult = await requireAccess(request, id);
    const body = parse(timeoutRequestSchema, request.body);
    const result = await moderation.timeout(id, accessResult.callerId, body);
    return { data: result };
  });

  app.post('/guilds/:id/moderation/clear-timeout', async (request) => {
    const id = guildId(request);
    const accessResult = await requireAccess(request, id);
    const body = parse(z.object({ userId: z.string().min(1) }), request.body);
    const result = await moderation.clearTimeout(id, accessResult.callerId, body.userId);
    return { data: result };
  });

  app.post('/guilds/:id/moderation/purge', async (request) => {
    const id = guildId(request);
    const accessResult = await requireAccess(request, id);
    const body = parse(purgeRequestSchema, request.body);
    const result = await moderation.purge(id, accessResult.callerId, body);
    return { data: result };
  });

  app.post('/guilds/:id/moderation/lockdown', async (request) => {
    const id = guildId(request);
    const accessResult = await requireAccess(request, id);
    const body = parse(lockdownRequestSchema, request.body);
    const result = await moderation.lockdown(id, accessResult.callerId, body, deps.locks);
    return { data: result };
  });

  app.post('/guilds/:id/moderation/unlock', async (request) => {
    const id = guildId(request);
    const accessResult = await requireAccess(request, id);
    const body = parse(unlockRequestSchema, request.body);
    const result = await moderation.unlock(id, accessResult.callerId, body, deps.locks);
    return { data: result };
  });

  app.post('/guilds/:id/moderation/slowmode', async (request) => {
    const id = guildId(request);
    const accessResult = await requireAccess(request, id);
    const body = parse(slowmodeRequestSchema, request.body);
    const result = await moderation.setSlowmode(id, accessResult.callerId, body);
    return { data: result };
  });

  app.post('/guilds/:id/moderation/mass-slowmode', async (request) => {
    const id = guildId(request);
    const accessResult = await requireAccess(request, id);
    const body = parse(z.object({ seconds: z.number().int().min(0).max(21_600) }), request.body);
    const result = await moderation.massSlowmode(id, accessResult.callerId, body.seconds);
    return { data: result };
  });

  app.get('/guilds/:id/moderation/warnings', async (request) => {
    const id = guildId(request);
    await requireAccess(request, id);
    return { data: { warnings: moderation.listWarnings(id) } };
  });

  app.post('/guilds/:id/moderation/warnings', async (request) => {
    const id = guildId(request);
    const accessResult = await requireAccess(request, id);
    const body = parse(warningRequestSchema, request.body);
    const result = await moderation.issueWarning(id, accessResult.callerId, body);
    return { data: result };
  });

  app.get('/guilds/:id/automod/rules', async (request) => {
    const id = guildId(request);
    await requireAccess(request, id);
    return { data: { rules: await automod.list(id) } };
  });

  app.post('/guilds/:id/automod/rules', async (request) => {
    const id = guildId(request);
    const accessResult = await requireAccess(request, id);
    const body = parse(autoModRuleRequestSchema, request.body);
    const rule = await automod.create(id, accessResult.callerId, body);
    return { data: { rule } };
  });

  app.patch('/guilds/:id/automod/rules/:ruleId', async (request) => {
    const id = guildId(request);
    const accessResult = await requireAccess(request, id);
    const params = parse(z.object({ id: z.string().min(1), ruleId: z.string().min(1) }), request.params);
    const body = parse(autoModRuleRequestSchema, request.body);
    const rule = await automod.update(id, accessResult.callerId, params.ruleId, body);
    return { data: { rule } };
  });

  app.delete('/guilds/:id/automod/rules/:ruleId', async (request) => {
    const id = guildId(request);
    const accessResult = await requireAccess(request, id);
    const params = parse(z.object({ id: z.string().min(1), ruleId: z.string().min(1) }), request.params);
    const result = await automod.remove(id, accessResult.callerId, params.ruleId);
    return { data: result };
  });

  app.get('/guilds/:id/roles', async (request) => {
    const id = guildId(request);
    await requireAccess(request, id);
    return { data: { roles: await access.listRoles(id) } };
  });

  app.post('/guilds/:id/roles', async (request) => {
    const id = guildId(request);
    const accessResult = await requireAccess(request, id);
    const body = parse(roleRequestSchema, request.body);
    const role = await access.createRole(id, accessResult.callerId, body);
    return { data: { role } };
  });

  app.patch('/guilds/:id/roles/:roleId', async (request) => {
    const id = guildId(request);
    const accessResult = await requireAccess(request, id);
    const params = parse(z.object({ id: z.string().min(1), roleId: z.string().min(1) }), request.params);
    const body = parse(rolePatchSchema, request.body);
    const role = await access.updateRole(id, accessResult.callerId, params.roleId, body);
    return { data: { role } };
  });

  app.delete('/guilds/:id/roles/:roleId', async (request) => {
    const id = guildId(request);
    const accessResult = await requireAccess(request, id);
    const params = parse(z.object({ id: z.string().min(1), roleId: z.string().min(1) }), request.params);
    const result = await access.deleteRole(id, accessResult.callerId, params.roleId);
    return { data: result };
  });

  app.get('/guilds/:id/members', async (request) => {
    const id = guildId(request);
    await requireAccess(request, id);
    const query = parse(
      z.object({ limit: z.coerce.number().int().min(1).max(1000).default(100), after: z.string().optional() }),
      request.query,
    );
    return { data: { members: await access.listMembers(id, query.limit, query.after) } };
  });

  app.get('/guilds/:id/members/:userId', async (request) => {
    const id = guildId(request);
    await requireAccess(request, id);
    const params = parse(z.object({ id: z.string().min(1), userId: z.string().min(1) }), request.params);
    const member = await access.getMember(id, params.userId);
    return { data: { member } };
  });

  app.get('/guilds/:id/members/:userId/permissions', async (request) => {
    const id = guildId(request);
    await requireAccess(request, id);
    const params = parse(z.object({ id: z.string().min(1), userId: z.string().min(1) }), request.params);
    const query = parse(memberPermissionsQuerySchema, request.query);
    const inspection = await access.inspectMemberPermissions(id, query.channelId, params.userId);
    return { data: { inspection } };
  });

  app.get('/guilds/:id/channels', async (request) => {
    const id = guildId(request);
    await requireAccess(request, id);
    return { data: { channels: await access.listChannels(id) } };
  });

  app.get('/guilds/:id/channels/:channelId/messages', async (request) => {
    const id = guildId(request);
    await requireAccess(request, id);
    const params = parse(
      z.object({ id: z.string().min(1), channelId: z.string().min(1) }),
      request.params,
    );
    const query = parse(
      z.object({ limit: z.coerce.number().int().min(1).max(100).default(50) }),
      request.query,
    );
    const messages = await access.listMessages(id, params.channelId, query.limit);
    return { data: { messages } };
  });

  app.post('/guilds/:id/channels', async (request) => {
    const id = guildId(request);
    const accessResult = await requireAccess(request, id);
    const body = parse(channelRequestSchema, request.body);
    const channel = await access.createChannel(id, accessResult.callerId, body);
    return { data: { channel } };
  });

  app.patch('/guilds/:id/channels/:channelId', async (request) => {
    const id = guildId(request);
    const accessResult = await requireAccess(request, id);
    const params = parse(z.object({ id: z.string().min(1), channelId: z.string().min(1) }), request.params);
    const body = parse(channelPatchSchema, request.body);
    const channel = await access.updateChannel(id, accessResult.callerId, params.channelId, body);
    return { data: { channel } };
  });

  app.delete('/guilds/:id/channels/:channelId', async (request) => {
    const id = guildId(request);
    const accessResult = await requireAccess(request, id);
    const params = parse(z.object({ id: z.string().min(1), channelId: z.string().min(1) }), request.params);
    const result = await access.deleteChannel(id, accessResult.callerId, params.channelId);
    return { data: result };
  });

  app.put('/guilds/:id/channels/:channelId/overwrites/:targetId', async (request) => {
    const id = guildId(request);
    const accessResult = await requireAccess(request, id);
    const params = parse(
      z.object({ id: z.string().min(1), channelId: z.string().min(1), targetId: z.string().min(1) }),
      request.params,
    );
    const body = parse(overwriteRequestSchema, request.body);
    const result = await access.createOverwrite(
      id,
      accessResult.callerId,
      params.channelId,
      params.targetId,
      body,
    );
    return { data: result };
  });

  app.delete('/guilds/:id/channels/:channelId/overwrites/:targetId', async (request) => {
    const id = guildId(request);
    const accessResult = await requireAccess(request, id);
    const params = parse(
      z.object({ id: z.string().min(1), channelId: z.string().min(1), targetId: z.string().min(1) }),
      request.params,
    );
    const result = await access.deleteOverwrite(id, accessResult.callerId, params.channelId, params.targetId);
    return { data: result };
  });

  app.get('/guilds/:id/engagement/announcements', async (request) => {
    const id = guildId(request);
    await requireAccess(request, id);
    return { data: { announcements: engagement.list(id) } };
  });

  app.post('/guilds/:id/engagement/announcements', async (request) => {
    const id = guildId(request);
    const accessResult = await requireAccess(request, id);
    const body = parse(scheduleAnnouncementSchema, request.body);
    const announcement = await engagement.schedule(id, accessResult.callerId, body);
    return { data: { announcement } };
  });

  app.post('/guilds/:id/engagement/announcements/:announcementId/cancel', async (request) => {
    const id = guildId(request);
    const accessResult = await requireAccess(request, id);
    const params = parse(
      z.object({ id: z.string().min(1), announcementId: z.string().min(1) }),
      request.params,
    );
    const result = engagement.cancel(id, accessResult.callerId, params.announcementId);
    return { data: result };
  });

  app.get('/guilds/:id/engagement/invites', async (request) => {
    const id = guildId(request);
    await requireAccess(request, id);
    return { data: { invites: engagement.listInvites(id) } };
  });

  app.get('/guilds/:id/engagement/joins', async (request) => {
    const id = guildId(request);
    await requireAccess(request, id);
    return { data: { joins: engagement.listJoins(id) } };
  });

  app.post('/guilds/:id/engagement/reaction-role', async (request) => {
    const id = guildId(request);
    await requireAccess(request, id);
    const body = parse(reactionRoleRequestSchema, request.body);
    const message = await api.sendChannelMessage(body.channelId, {
      content: body.content,
      allowed_mentions: { parse: [] },
    });
    for (const binding of body.bindings) {
      await api.addOwnReaction(body.channelId, message.id, binding.emoji);
    }
    const current = settings.get(id);
    current.reactionRoles = [
      ...current.reactionRoles.filter((entry) => entry.messageId !== message.id),
      ...body.bindings.map((binding) => ({
        messageId: message.id,
        emoji: binding.emoji,
        roleId: binding.roleId,
      })),
    ];
    settings.save(id, current);
    return { data: { messageId: message.id, bindings: body.bindings } };
  });

  app.post('/guilds/:id/engagement/button-role', async (request) => {
    const id = guildId(request);
    await requireAccess(request, id);
    const body = parse(buttonRoleRequestSchema, request.body);
    const message = await api.sendChannelMessage(body.channelId, {
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
    return { data: { messageId: message.id } };
  });

  app.get('/guilds/:id/tools/emojis', async (request) => {
    const id = guildId(request);
    await requireAccess(request, id);
    return { data: { emojis: await tools.listEmojis(id) } };
  });

  app.post('/guilds/:id/tools/emojis', async (request) => {
    const id = guildId(request);
    const accessResult = await requireAccess(request, id);
    const body = parse(emojiRequestSchema, request.body);
    const emoji = await tools.createEmoji(id, accessResult.callerId, body);
    return { data: { emoji } };
  });

  app.patch('/guilds/:id/tools/emojis/:emojiId', async (request) => {
    const id = guildId(request);
    const accessResult = await requireAccess(request, id);
    const params = parse(z.object({ id: z.string().min(1), emojiId: z.string().min(1) }), request.params);
    const body = parse(emojiPatchSchema, request.body);
    const emoji = await tools.updateEmoji(id, accessResult.callerId, params.emojiId, body);
    return { data: { emoji } };
  });

  app.delete('/guilds/:id/tools/emojis/:emojiId', async (request) => {
    const id = guildId(request);
    const accessResult = await requireAccess(request, id);
    const params = parse(z.object({ id: z.string().min(1), emojiId: z.string().min(1) }), request.params);
    const result = await tools.deleteEmoji(id, accessResult.callerId, params.emojiId);
    return { data: result };
  });

  app.get('/guilds/:id/tools/stickers', async (request) => {
    const id = guildId(request);
    await requireAccess(request, id);
    return { data: { stickers: await tools.listStickers(id) } };
  });

  app.post('/guilds/:id/tools/stickers', async (request) => {
    const id = guildId(request);
    const accessResult = await requireAccess(request, id);
    const body = parse(stickerRequestSchema, request.body);
    const sticker = await tools.createSticker(id, accessResult.callerId, body);
    return { data: { sticker } };
  });

  app.patch('/guilds/:id/tools/stickers/:stickerId', async (request) => {
    const id = guildId(request);
    const accessResult = await requireAccess(request, id);
    const params = parse(z.object({ id: z.string().min(1), stickerId: z.string().min(1) }), request.params);
    const body = parse(stickerPatchSchema, request.body);
    const sticker = await tools.updateSticker(id, accessResult.callerId, params.stickerId, body);
    return { data: { sticker } };
  });

  app.delete('/guilds/:id/tools/stickers/:stickerId', async (request) => {
    const id = guildId(request);
    const accessResult = await requireAccess(request, id);
    const params = parse(z.object({ id: z.string().min(1), stickerId: z.string().min(1) }), request.params);
    const result = await tools.deleteSticker(id, accessResult.callerId, params.stickerId);
    return { data: result };
  });

  app.get('/guilds/:id/tools/audit-log', async (request) => {
    const id = guildId(request);
    await requireAccess(request, id);
    const query = parse(z.object({ limit: z.coerce.number().int().min(1).max(100).default(50) }), request.query);
    return { data: { entries: await tools.readAuditLog(id, query.limit) } };
  });

  app.get('/guilds/:id/tools/backup', async (request) => {
    const id = guildId(request);
    await requireAccess(request, id);
    const backup = await tools.exportBackup(id);
    return { data: { backup } };
  });

  app.post('/guilds/:id/tools/backup/restore', async (request) => {
    const id = guildId(request);
    const accessResult = await requireAccess(request, id);
    const body = parse(z.object({ backup: backupDocumentSchema }), request.body);
    const result = await tools.importBackup(id, accessResult.callerId, body.backup);
    return { data: { result } };
  });

  app.get('/guilds/:id/settings', async (request) => {
    const id = guildId(request);
    await requireAccess(request, id);
    return { data: { settings: settings.get(id) } };
  });

  app.put('/guilds/:id/settings', async (request) => {
    const id = guildId(request);
    await requireAccess(request, id);
    const patch = parse(settingsPatchSchema, request.body);
    const current = settings.get(id);
    const merged: GuildSettings = { ...current };
    for (const [key, value] of Object.entries(patch)) {
      if (value !== undefined) {
        Object.assign(merged, { [key]: value });
      }
    }
    settings.save(id, merged);
    return { data: { settings: merged } };
  });
}

export { mapDiscordError };
