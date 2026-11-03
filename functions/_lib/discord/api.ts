import { z } from 'zod';
import type { DiscordHttpClient } from './rest';

const permissionLike = z.union([z.string(), z.number()]);

export const userSchema = z.object({
  id: z.string(),
  username: z.string(),
  global_name: z.string().nullable().optional(),
  avatar: z.string().nullable().optional(),
  discriminator: z.string().optional(),
  bot: z.boolean().optional(),
});
export type DiscordUser = z.infer<typeof userSchema>;

export const guildSchema = z.object({
  id: z.string(),
  name: z.string(),
  icon: z.string().nullable().optional(),
  owner: z.boolean().optional(),
  owner_id: z.string().optional(),
  permissions: permissionLike.optional(),
  member_count: z.number().optional(),
  approximate_member_count: z.number().optional(),
  approximate_presence_count: z.number().optional(),
  verification_level: z.number().optional(),
  features: z.array(z.string()).optional(),
});
export type DiscordGuild = z.infer<typeof guildSchema>;

export const userGuildSchema = z.object({
  id: z.string(),
  name: z.string(),
  icon: z.string().nullable().optional(),
  owner: z.boolean(),
  owner_id: z.string().optional(),
  permissions: permissionLike,
  approximate_member_count: z.number().optional(),
  approximate_presence_count: z.number().optional(),
});
export type DiscordUserGuild = z.infer<typeof userGuildSchema>;

export const channelSchema = z.object({
  id: z.string(),
  type: z.number(),
  name: z.string().nullable().optional(),
  position: z.number().optional(),
  parent_id: z.string().nullable().optional(),
  rate_limit_per_user: z.number().nullable().optional(),
  permission_overwrites: z
    .array(
      z.object({
        id: z.string(),
        type: z.number(),
        allow: z.string(),
        deny: z.string(),
      }),
    )
    .optional(),
});
export type DiscordChannel = z.infer<typeof channelSchema>;

export const roleSchema = z.object({
  id: z.string(),
  name: z.string(),
  permissions: z.string(),
  position: z.number(),
  color: z.number(),
  hoist: z.boolean().optional(),
  mentionable: z.boolean().optional(),
});
export type DiscordRole = z.infer<typeof roleSchema>;

export const guildMemberSchema = z.object({
  user: userSchema.optional(),
  nick: z.string().nullable().optional(),
  roles: z.array(z.string()),
  joined_at: z.string().optional(),
  pending: z.boolean().optional(),
});
export type DiscordGuildMember = z.infer<typeof guildMemberSchema>;

export const emojiSchema = z.object({
  id: z.string(),
  name: z.string().nullable().optional(),
  roles: z.array(z.string()).optional(),
  require_colons: z.boolean().optional(),
  managed: z.boolean().optional(),
  animated: z.boolean().optional(),
  available: z.boolean().optional(),
});
export type DiscordEmoji = z.infer<typeof emojiSchema>;

export const stickerSchema = z.object({
  id: z.string(),
  name: z.string(),
  description: z.string().nullable().optional(),
  tags: z.string().optional(),
  type: z.number().optional(),
  format_type: z.number().optional(),
  guild_id: z.string().optional(),
});
export type DiscordSticker = z.infer<typeof stickerSchema>;

export const inviteSchema = z.object({
  code: z.string(),
  uses: z.number(),
  max_uses: z.number().optional(),
  max_age: z.number().optional(),
  temporary: z.boolean().optional(),
  created_at: z.string().optional(),
  channel_id: z.string().optional(),
  inviter: userSchema.optional(),
  guild_id: z.string().optional(),
});
export type DiscordInvite = z.infer<typeof inviteSchema>;

export const messageSchema = z.object({
  id: z.string(),
  timestamp: z.string(),
  author: userSchema.optional(),
  content: z.string().optional(),
});
export type DiscordMessage = z.infer<typeof messageSchema>;

export const auditLogSchema = z.object({
  audit_log_entries: z
    .array(
      z.object({
        id: z.string(),
        action_type: z.number(),
        target_id: z.string().nullable().optional(),
        user_id: z.string().nullable().optional(),
        reason: z.string().nullable().optional(),
        created_at: z.string(),
      }),
    )
    .optional(),
});
export type DiscordAuditLog = z.infer<typeof auditLogSchema>;

export const autoModRuleSchema = z.object({
  id: z.string(),
  name: z.string(),
  enabled: z.boolean().optional(),
  event_type: z.number().optional(),
  trigger_type: z.number().optional(),
  trigger_metadata: z.record(z.string(), z.unknown()).optional(),
  actions: z.array(z.record(z.string(), z.unknown())).optional(),
});
export type DiscordAutoModRule = z.infer<typeof autoModRuleSchema>;

export type GuildOverwriteInput = {
  id: string;
  type: number;
  allow: string;
  deny: string;
};

export class DiscordApi {
  constructor(private readonly http: DiscordHttpClient) {}

  async getCurrentUser(token?: string): Promise<DiscordUser> {
    const body = await this.http.request<unknown>({
      method: 'GET',
      route: '/users/@me',
      path: '/users/@me',
      ...(token === undefined ? {} : { token }),
    });
    return userSchema.parse(body);
  }

  /** Lists the guilds of the authenticated user, following `after` until a short page. */
  async listUserGuilds(token: string): Promise<DiscordUserGuild[]> {
    const guilds: DiscordUserGuild[] = [];
    let after: string | undefined;
    for (;;) {
      const page = await this.http.request<unknown[]>({
        method: 'GET',
        route: '/users/@me/guilds',
        path: '/users/@me/guilds',
        query: {
          limit: 200,
          with_counts: true,
          ...(after === undefined ? {} : { after }),
        },
        token,
      });
      const parsed = z.array(userGuildSchema).parse(page);
      guilds.push(...parsed);
      if (parsed.length < 200) {
        return guilds;
      }
      const last = parsed[parsed.length - 1];
      if (!last) {
        return guilds;
      }
      after = last.id;
    }
  }

  async getGuild(guildId: string, withCounts = true): Promise<DiscordGuild> {
    const body = await this.http.request<unknown>({
      method: 'GET',
      route: '/guilds/{guild_id}',
      path: `/guilds/${guildId}`,
      majorParams: [guildId],
      query: { with_counts: withCounts },
    });
    return guildSchema.parse(body);
  }

  async updateGuild(guildId: string, body: Record<string, unknown>): Promise<DiscordGuild> {
    const result = await this.http.request<unknown>({
      method: 'PATCH',
      route: '/guilds/{guild_id}',
      path: `/guilds/${guildId}`,
      majorParams: [guildId],
      body,
    });
    return guildSchema.parse(result);
  }

  async getGuildChannels(guildId: string): Promise<DiscordChannel[]> {
    const body = await this.http.request<unknown[]>({
      method: 'GET',
      route: '/guilds/{guild_id}/channels',
      path: `/guilds/${guildId}/channels`,
      majorParams: [guildId],
    });
    return z.array(channelSchema).parse(body);
  }

  async createGuildChannel(
    guildId: string,
    body: Record<string, unknown>,
  ): Promise<DiscordChannel> {
    const result = await this.http.request<unknown>({
      method: 'POST',
      route: '/guilds/{guild_id}/channels',
      path: `/guilds/${guildId}/channels`,
      majorParams: [guildId],
      body,
    });
    return channelSchema.parse(result);
  }

  async updateChannel(channelId: string, body: Record<string, unknown>): Promise<DiscordChannel> {
    const result = await this.http.request<unknown>({
      method: 'PATCH',
      route: '/channels/{channel_id}',
      path: `/channels/${channelId}`,
      majorParams: [channelId],
      body,
    });
    return channelSchema.parse(result);
  }

  async deleteChannel(channelId: string): Promise<void> {
    await this.http.request<void>({
      method: 'DELETE',
      route: '/channels/{channel_id}',
      path: `/channels/${channelId}`,
      majorParams: [channelId],
      parse: 'none',
    });
  }

  async updateChannelOverwrite(
    channelId: string,
    overwriteId: string,
    body: { type?: number; allow?: string; deny?: string },
  ): Promise<void> {
    await this.http.request<void>({
      method: 'PUT',
      route: '/channels/{channel_id}/permissions/{overwrite_id}',
      path: `/channels/${channelId}/permissions/${overwriteId}`,
      majorParams: [channelId, overwriteId],
      body,
      parse: 'none',
    });
  }

  async deleteChannelOverwrite(channelId: string, overwriteId: string): Promise<void> {
    await this.http.request<void>({
      method: 'DELETE',
      route: '/channels/{channel_id}/permissions/{overwrite_id}',
      path: `/channels/${channelId}/permissions/${overwriteId}`,
      majorParams: [channelId, overwriteId],
      parse: 'none',
    });
  }

  async getChannel(channelId: string): Promise<DiscordChannel> {
    const body = await this.http.request<unknown>({
      method: 'GET',
      route: '/channels/{channel_id}',
      path: `/channels/${channelId}`,
      majorParams: [channelId],
    });
    return channelSchema.parse(body);
  }

  async getGuildRoles(guildId: string): Promise<DiscordRole[]> {
    const body = await this.http.request<unknown[]>({
      method: 'GET',
      route: '/guilds/{guild_id}/roles',
      path: `/guilds/${guildId}/roles`,
      majorParams: [guildId],
    });
    return z.array(roleSchema).parse(body);
  }

  async createGuildRole(guildId: string, body: Record<string, unknown>): Promise<DiscordRole> {
    const result = await this.http.request<unknown>({
      method: 'POST',
      route: '/guilds/{guild_id}/roles',
      path: `/guilds/${guildId}/roles`,
      majorParams: [guildId],
      body,
    });
    return roleSchema.parse(result);
  }

  async updateGuildRole(
    guildId: string,
    roleId: string,
    body: Record<string, unknown>,
  ): Promise<DiscordRole> {
    const result = await this.http.request<unknown>({
      method: 'PATCH',
      route: '/guilds/{guild_id}/roles/{role_id}',
      path: `/guilds/${guildId}/roles/${roleId}`,
      majorParams: [guildId, roleId],
      body,
    });
    return roleSchema.parse(result);
  }

  async deleteGuildRole(guildId: string, roleId: string): Promise<void> {
    await this.http.request<void>({
      method: 'DELETE',
      route: '/guilds/{guild_id}/roles/{role_id}',
      path: `/guilds/${guildId}/roles/${roleId}`,
      majorParams: [guildId, roleId],
      parse: 'none',
    });
  }

  async getGuildMember(guildId: string, userId: string): Promise<DiscordGuildMember> {
    const body = await this.http.request<unknown>({
      method: 'GET',
      route: '/guilds/{guild_id}/members/{user_id}',
      path: `/guilds/${guildId}/members/${userId}`,
      majorParams: [guildId, userId],
    });
    return guildMemberSchema.parse(body);
  }

  async listGuildMembers(
    guildId: string,
    limit = 100,
    after?: string,
  ): Promise<DiscordGuildMember[]> {
    const body = await this.http.request<unknown[]>({
      method: 'GET',
      route: '/guilds/{guild_id}/members',
      path: `/guilds/${guildId}/members`,
      majorParams: [guildId],
      query: { limit, ...(after === undefined ? {} : { after }) },
    });
    return z.array(guildMemberSchema).parse(body);
  }

  /** Effective permissions of a member inside a channel, as computed by Discord. */
  async getMemberChannelPermissions(
    guildId: string,
    channelId: string,
    userId: string,
  ): Promise<string> {
    const body = await this.http.request<unknown>({
      method: 'GET',
      route: '/guilds/{guild_id}/channels/{channel_id}/permissions/{user_id}',
      path: `/guilds/${guildId}/channels/${channelId}/permissions/${userId}`,
      majorParams: [guildId, channelId, userId],
    });
    return z.object({ permissions: z.string() }).parse(body).permissions;
  }

  async banMember(
    guildId: string,
    userId: string,
    options: { deleteMessageSeconds: number; reason?: string },
  ): Promise<void> {
    await this.http.request<void>({
      method: 'PUT',
      route: '/guilds/{guild_id}/bans/{user_id}',
      path: `/guilds/${guildId}/bans/${userId}`,
      majorParams: [guildId, userId],
      body: {
        delete_message_seconds: options.deleteMessageSeconds,
        ...(options.reason === undefined ? {} : { reason: options.reason }),
      },
      parse: 'none',
    });
  }

  async unbanMember(guildId: string, userId: string): Promise<void> {
    await this.http.request<void>({
      method: 'DELETE',
      route: '/guilds/{guild_id}/bans/{user_id}',
      path: `/guilds/${guildId}/bans/${userId}`,
      majorParams: [guildId, userId],
      parse: 'none',
    });
  }

  async kickMember(guildId: string, userId: string, reason?: string): Promise<void> {
    await this.http.request<void>({
      method: 'DELETE',
      route: '/guilds/{guild_id}/members/{user_id}',
      path: `/guilds/${guildId}/members/${userId}`,
      majorParams: [guildId, userId],
      body: reason === undefined ? {} : { reason },
      parse: 'none',
    });
  }

  async timeoutMember(
    guildId: string,
    userId: string,
    communicationDisabledUntil: string | null,
    reason?: string,
  ): Promise<void> {
    await this.http.request<void>({
      method: 'PATCH',
      route: '/guilds/{guild_id}/members/{user_id}',
      path: `/guilds/${guildId}/members/${userId}`,
      majorParams: [guildId, userId],
      body: {
        communication_disabled_until: communicationDisabledUntil,
        ...(reason === undefined ? {} : { reason }),
      },
      parse: 'none',
    });
  }

  async bulkDeleteMessages(channelId: string, messageIds: string[]): Promise<void> {
    await this.http.request<void>({
      method: 'POST',
      route: '/channels/{channel_id}/messages/bulk-delete',
      path: `/channels/${channelId}/messages/bulk-delete`,
      majorParams: [channelId],
      body: { messages: messageIds },
      parse: 'none',
    });
  }

  async sendChannelMessage(
    channelId: string,
    body: Record<string, unknown>,
  ): Promise<{ id: string }> {
    const result = await this.http.request<unknown>({
      method: 'POST',
      route: '/channels/{channel_id}/messages',
      path: `/channels/${channelId}/messages`,
      majorParams: [channelId],
      body,
    });
    return z.object({ id: z.string() }).parse(result);
  }

  async addOwnReaction(
    channelId: string,
    messageId: string,
    emoji: string,
  ): Promise<void> {
    await this.http.request<void>({
      method: 'PUT',
      route: '/channels/{channel_id}/messages/{message_id}/reactions/{emoji}/@me',
      path: `/channels/${channelId}/messages/${messageId}/reactions/${encodeURIComponent(emoji)}/@me`,
      majorParams: [channelId, messageId],
      parse: 'none',
    });
  }

  async addMemberRole(guildId: string, userId: string, roleId: string): Promise<void> {
    await this.http.request<void>({
      method: 'PUT',
      route: '/guilds/{guild_id}/members/{user_id}/roles/{role_id}',
      path: `/guilds/${guildId}/members/${userId}/roles/${roleId}`,
      majorParams: [guildId, userId, roleId],
      parse: 'none',
    });
  }

  async removeMemberRole(guildId: string, userId: string, roleId: string): Promise<void> {
    await this.http.request<void>({
      method: 'DELETE',
      route: '/guilds/{guild_id}/members/{user_id}/roles/{role_id}',
      path: `/guilds/${guildId}/members/${userId}/roles/${roleId}`,
      majorParams: [guildId, userId, roleId],
      parse: 'none',
    });
  }

  async listAutoModRules(guildId: string): Promise<DiscordAutoModRule[]> {
    const body = await this.http.request<unknown[]>({
      method: 'GET',
      route: '/guilds/{guild_id}/auto-moderation/rules',
      path: `/guilds/${guildId}/auto-moderation/rules`,
      majorParams: [guildId],
    });
    return z.array(autoModRuleSchema).parse(body);
  }

  async createAutoModRule(guildId: string, body: Record<string, unknown>): Promise<DiscordAutoModRule> {
    const result = await this.http.request<unknown>({
      method: 'POST',
      route: '/guilds/{guild_id}/auto-moderation/rules',
      path: `/guilds/${guildId}/auto-moderation/rules`,
      majorParams: [guildId],
      body,
    });
    return autoModRuleSchema.parse(result);
  }

  async updateAutoModRule(
    guildId: string,
    ruleId: string,
    body: Record<string, unknown>,
  ): Promise<DiscordAutoModRule> {
    const result = await this.http.request<unknown>({
      method: 'PATCH',
      route: '/guilds/{guild_id}/auto-moderation/rules/{rule_id}',
      path: `/guilds/${guildId}/auto-moderation/rules/${ruleId}`,
      majorParams: [guildId, ruleId],
      body,
    });
    return autoModRuleSchema.parse(result);
  }

  async deleteAutoModRule(guildId: string, ruleId: string): Promise<void> {
    await this.http.request<void>({
      method: 'DELETE',
      route: '/guilds/{guild_id}/auto-moderation/rules/{rule_id}',
      path: `/guilds/${guildId}/auto-moderation/rules/${ruleId}`,
      majorParams: [guildId, ruleId],
      parse: 'none',
    });
  }

  async listGuildEmojis(guildId: string): Promise<DiscordEmoji[]> {
    const body = await this.http.request<unknown[]>({
      method: 'GET',
      route: '/guilds/{guild_id}/emojis',
      path: `/guilds/${guildId}/emojis`,
      majorParams: [guildId],
    });
    return z.array(emojiSchema).parse(body);
  }

  async createGuildEmoji(
    guildId: string,
    body: Record<string, unknown>,
  ): Promise<DiscordEmoji> {
    const result = await this.http.request<unknown>({
      method: 'POST',
      route: '/guilds/{guild_id}/emojis',
      path: `/guilds/${guildId}/emojis`,
      majorParams: [guildId],
      body,
    });
    return emojiSchema.parse(result);
  }

  async updateGuildEmoji(
    guildId: string,
    emojiId: string,
    body: Record<string, unknown>,
  ): Promise<DiscordEmoji> {
    const result = await this.http.request<unknown>({
      method: 'PATCH',
      route: '/guilds/{guild_id}/emojis/{emoji_id}',
      path: `/guilds/${guildId}/emojis/${emojiId}`,
      majorParams: [guildId, emojiId],
      body,
    });
    return emojiSchema.parse(result);
  }

  async deleteGuildEmoji(guildId: string, emojiId: string): Promise<void> {
    await this.http.request<void>({
      method: 'DELETE',
      route: '/guilds/{guild_id}/emojis/{emoji_id}',
      path: `/guilds/${guildId}/emojis/${emojiId}`,
      majorParams: [guildId, emojiId],
      parse: 'none',
    });
  }

  async listGuildStickers(guildId: string): Promise<DiscordSticker[]> {
    const body = await this.http.request<unknown[]>({
      method: 'GET',
      route: '/guilds/{guild_id}/stickers',
      path: `/guilds/${guildId}/stickers`,
      majorParams: [guildId],
    });
    return z.array(stickerSchema).parse(body);
  }

  async createGuildSticker(
    guildId: string,
    body: Record<string, unknown>,
  ): Promise<DiscordSticker> {
    const result = await this.http.request<unknown>({
      method: 'POST',
      route: '/guilds/{guild_id}/stickers',
      path: `/guilds/${guildId}/stickers`,
      majorParams: [guildId],
      body,
    });
    return stickerSchema.parse(result);
  }

  async updateGuildSticker(
    guildId: string,
    stickerId: string,
    body: Record<string, unknown>,
  ): Promise<DiscordSticker> {
    const result = await this.http.request<unknown>({
      method: 'PATCH',
      route: '/guilds/{guild_id}/stickers/{sticker_id}',
      path: `/guilds/${guildId}/stickers/${stickerId}`,
      majorParams: [guildId, stickerId],
      body,
    });
    return stickerSchema.parse(result);
  }

  async deleteGuildSticker(guildId: string, stickerId: string): Promise<void> {
    await this.http.request<void>({
      method: 'DELETE',
      route: '/guilds/{guild_id}/stickers/{sticker_id}',
      path: `/guilds/${guildId}/stickers/${stickerId}`,
      majorParams: [guildId, stickerId],
      parse: 'none',
    });
  }

  async getRecentMessages(
    channelId: string,
    limit = 50,
  ): Promise<DiscordMessage[]> {
    const body = await this.http.request<unknown[]>({
      method: 'GET',
      route: '/channels/{channel_id}/messages',
      path: `/channels/${channelId}/messages`,
      majorParams: [channelId],
      query: { limit },
    });
    return z.array(messageSchema).parse(body);
  }

  async getAuditLog(guildId: string, limit = 50): Promise<DiscordAuditLog> {
    const body = await this.http.request<unknown>({
      method: 'GET',
      route: '/guilds/{guild_id}/audit-logs',
      path: `/guilds/${guildId}/audit-logs`,
      majorParams: [guildId],
      query: { limit },
    });
    return auditLogSchema.parse(body);
  }

  async listGuildInvites(guildId: string): Promise<DiscordInvite[]> {
    const body = await this.http.request<unknown[]>({
      method: 'GET',
      route: '/guilds/{guild_id}/invites',
      path: `/guilds/${guildId}/invites`,
      majorParams: [guildId],
    });
    return z.array(inviteSchema).parse(body);
  }

  async createGuildInvite(
    guildId: string,
    body: Record<string, unknown>,
  ): Promise<DiscordInvite> {
    const result = await this.http.request<unknown>({
      method: 'POST',
      route: '/guilds/{guild_id}/invites',
      path: `/guilds/${guildId}/invites`,
      majorParams: [guildId],
      body,
    });
    return inviteSchema.parse(result);
  }
}
