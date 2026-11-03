import { z } from 'zod';
import type { DiscordApi, DiscordChannel, DiscordGuildMember, DiscordRole } from '../discord/api.js';
import { AppError } from '../errors.js';
import type { ModerationLogService } from './moderationLogService.js';

export const roleRequestSchema = z.object({
  name: z.string().min(1).max(100),
  color: z.number().int().min(0).max(0xffffff).optional(),
  permissions: z.string().optional(),
  hoist: z.boolean().optional(),
  mentionable: z.boolean().optional(),
});
export type RoleRequest = z.infer<typeof roleRequestSchema>;

export const rolePatchSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  color: z.number().int().min(0).max(0xffffff).nullable().optional(),
  permissions: z.string().optional(),
  hoist: z.boolean().optional(),
  mentionable: z.boolean().optional(),
});
export type RolePatch = z.infer<typeof rolePatchSchema>;

export const channelRequestSchema = z.object({
  name: z.string().min(1).max(100),
  type: z.number().int().min(0).max(15),
  parentId: z.string().nullable().optional(),
  topic: z.string().max(1024).nullable().optional(),
  rateLimitPerUser: z.number().int().min(0).max(21_600).nullable().optional(),
  position: z.number().int().optional(),
});
export type ChannelRequest = z.infer<typeof channelRequestSchema>;

export const channelPatchSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  parentId: z.string().nullable().optional(),
  topic: z.string().max(1024).nullable().optional(),
  rateLimitPerUser: z.number().int().min(0).max(21_600).nullable().optional(),
  position: z.number().int().optional(),
});
export type ChannelPatch = z.infer<typeof channelPatchSchema>;

export const overwriteRequestSchema = z.object({
  type: z.number().int().min(0).max(3),
  allow: z.string(),
  deny: z.string(),
});
export type OverwriteRequest = z.infer<typeof overwriteRequestSchema>;

export type PermissionInspection = {
  memberId: string;
  channelId: string;
  permissions: string;
};

export class AccessService {
  constructor(
    private readonly api: DiscordApi,
    private readonly moderationLog: ModerationLogService,
  ) {}

  async listRoles(guildId: string): Promise<DiscordRole[]> {
    return this.api.getGuildRoles(guildId);
  }

  async createRole(guildId: string, actorId: string | null, request: RoleRequest) {
    const body: Record<string, unknown> = { name: request.name };
    if (request.color !== undefined) body['color'] = request.color;
    if (request.permissions !== undefined) body['permissions'] = request.permissions;
    if (request.hoist !== undefined) body['hoist'] = request.hoist;
    if (request.mentionable !== undefined) body['mentionable'] = request.mentionable;
    const role = await this.api.createGuildRole(guildId, body);
    await this.moderationLog.record({
      guildId,
      action: 'Role created',
      actorId,
      targetId: role.id,
      detail: role.name,
      success: true,
    });
    return role;
  }

  async updateRole(guildId: string, actorId: string | null, roleId: string, patch: RolePatch) {
    const body: Record<string, unknown> = {};
    if (patch.name !== undefined) body['name'] = patch.name;
    if (patch.color !== undefined) body['color'] = patch.color;
    if (patch.permissions !== undefined) body['permissions'] = patch.permissions;
    if (patch.hoist !== undefined) body['hoist'] = patch.hoist;
    if (patch.mentionable !== undefined) body['mentionable'] = patch.mentionable;
    const role = await this.api.updateGuildRole(guildId, roleId, body);
    await this.moderationLog.record({
      guildId,
      action: 'Role updated',
      actorId,
      targetId: role.id,
      detail: role.name,
      success: true,
    });
    return role;
  }

  async deleteRole(guildId: string, actorId: string | null, roleId: string) {
    await this.api.deleteGuildRole(guildId, roleId);
    await this.moderationLog.record({
      guildId,
      action: 'Role deleted',
      actorId,
      targetId: roleId,
      detail: null,
      success: true,
    });
    return { roleId };
  }

  async listMembers(guildId: string, limit = 100, after?: string): Promise<DiscordGuildMember[]> {
    return this.api.listGuildMembers(guildId, limit, after);
  }

  async getMember(guildId: string, userId: string): Promise<DiscordGuildMember> {
    return this.api.getGuildMember(guildId, userId);
  }

  /** Effective permissions of a member in a channel, computed by Discord. */
  async inspectMemberPermissions(
    guildId: string,
    channelId: string,
    memberId: string,
  ): Promise<PermissionInspection> {
    const channels = await this.api.getGuildChannels(guildId);
    if (!channels.some((channel) => channel.id === channelId)) {
      throw AppError.notFound(`Channel ${channelId} is not part of this server.`);
    }
    const permissions = await this.api.getMemberChannelPermissions(guildId, channelId, memberId);
    return { memberId, channelId, permissions };
  }

  async listMessages(guildId: string, channelId: string, limit: number) {
    const channels = await this.api.getGuildChannels(guildId);
    if (!channels.some((channel) => channel.id === channelId)) {
      throw AppError.notFound(`Channel ${channelId} is not part of this server.`);
    }
    const messages = await this.api.getRecentMessages(channelId, limit);
    return messages.map((message) => ({
      id: message.id,
      timestamp: message.timestamp,
      authorId: message.author?.id ?? null,
      authorName: message.author?.username ?? null,
      content: message.content ?? '',
    }));
  }

  async listChannels(guildId: string): Promise<DiscordChannel[]> {
    return this.api.getGuildChannels(guildId);
  }

  async createChannel(guildId: string, actorId: string | null, request: ChannelRequest) {
    const body: Record<string, unknown> = { name: request.name, type: request.type };
    if (request.parentId !== undefined) body['parent_id'] = request.parentId;
    if (request.topic !== undefined) body['topic'] = request.topic;
    if (request.rateLimitPerUser !== undefined) {
      body['rate_limit_per_user'] = request.rateLimitPerUser;
    }
    if (request.position !== undefined) body['position'] = request.position;
    const channel = await this.api.createGuildChannel(guildId, body);
    await this.moderationLog.record({
      guildId,
      action: 'Channel created',
      actorId,
      targetId: channel.id,
      detail: channel.name ?? null,
      success: true,
    });
    return channel;
  }

  async updateChannel(
    guildId: string,
    actorId: string | null,
    channelId: string,
    patch: ChannelPatch,
  ) {
    const body: Record<string, unknown> = {};
    if (patch.name !== undefined) body['name'] = patch.name;
    if (patch.parentId !== undefined) body['parent_id'] = patch.parentId;
    if (patch.topic !== undefined) body['topic'] = patch.topic;
    if (patch.rateLimitPerUser !== undefined) {
      body['rate_limit_per_user'] = patch.rateLimitPerUser;
    }
    if (patch.position !== undefined) body['position'] = patch.position;
    const channel = await this.api.updateChannel(channelId, body);
    await this.moderationLog.record({
      guildId,
      action: 'Channel updated',
      actorId,
      targetId: channelId,
      detail: channel.name ?? null,
      success: true,
    });
    return channel;
  }

  async deleteChannel(guildId: string, actorId: string | null, channelId: string) {
    await this.api.deleteChannel(channelId);
    await this.moderationLog.record({
      guildId,
      action: 'Channel deleted',
      actorId,
      targetId: channelId,
      detail: null,
      success: true,
    });
    return { channelId };
  }

  async createOverwrite(
    guildId: string,
    actorId: string | null,
    channelId: string,
    targetId: string,
    request: OverwriteRequest,
  ) {
    await this.api.updateChannelOverwrite(channelId, targetId, {
      type: request.type,
      allow: request.allow,
      deny: request.deny,
    });
    await this.moderationLog.record({
      guildId,
      action: 'Permission overwrite created',
      actorId,
      targetId: `${channelId}/${targetId}`,
      detail: null,
      success: true,
    });
    return { channelId, targetId };
  }

  async deleteOverwrite(guildId: string, actorId: string | null, channelId: string, targetId: string) {
    await this.api.deleteChannelOverwrite(channelId, targetId);
    await this.moderationLog.record({
      guildId,
      action: 'Permission overwrite deleted',
      actorId,
      targetId: `${channelId}/${targetId}`,
      detail: null,
      success: true,
    });
    return { channelId, targetId };
  }
}
