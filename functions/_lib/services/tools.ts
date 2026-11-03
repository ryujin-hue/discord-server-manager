import { z } from 'zod';
import type { DiscordApi, DiscordChannel, DiscordEmoji, DiscordRole, DiscordSticker } from '../discord/api';
import type { ModerationLogService } from './moderationLog';

export const emojiRequestSchema = z.object({
  name: z.string().min(2).max(32),
  image: z.string().min(1),
  roles: z.array(z.string().min(1)).default([]),
});
export const emojiPatchSchema = z.object({
  name: z.string().min(2).max(32).optional(),
  roles: z.array(z.string().min(1)).optional(),
});
export const stickerRequestSchema = z.object({
  name: z.string().min(2).max(30),
  description: z.string().max(2048).default(''),
  tags: z.string().min(1),
  image: z.string().min(1),
});
export const stickerPatchSchema = z.object({
  name: z.string().min(2).max(30).optional(),
  description: z.string().max(2048).optional(),
  tags: z.string().optional(),
});

export const backupRoleSchema = z.object({
  name: z.string().min(1),
  color: z.number().int().min(0),
  permissions: z.string(),
  hoist: z.boolean(),
  mentionable: z.boolean(),
  position: z.number().int(),
});
export const backupOverwriteSchema = z.object({
  targetId: z.string().min(1),
  targetType: z.number().int().min(0).max(3),
  allow: z.string(),
  deny: z.string(),
});
export const backupChannelSchema = z.object({
  name: z.string().min(1),
  type: z.number().int(),
  topic: z.string().nullable(),
  rateLimitPerUser: z.number().int().nullable(),
  categoryName: z.string().nullable(),
  overwrites: z.array(backupOverwriteSchema).default([]),
});
export const backupCategorySchema = z.object({
  name: z.string().min(1),
  position: z.number().int(),
});
export const backupDocumentSchema = z.object({
  version: z.literal(1),
  guildId: z.string(),
  guildName: z.string(),
  exportedAt: z.string(),
  roles: z.array(backupRoleSchema),
  categories: z.array(backupCategorySchema),
  channels: z.array(backupChannelSchema),
});
export type BackupDocument = z.infer<typeof backupDocumentSchema>;

export type EmojiRequest = z.infer<typeof emojiRequestSchema>;
export type EmojiPatch = z.infer<typeof emojiPatchSchema>;
export type StickerRequest = z.infer<typeof stickerRequestSchema>;
export type StickerPatch = z.infer<typeof stickerPatchSchema>;
export type BackupImportResult = {
  createdRoles: string[]; createdCategories: string[]; createdChannels: string[];
  skippedRoles: string[]; skippedCategories: string[]; skippedChannels: string[];
};

export class ToolService {
  constructor(private readonly api: DiscordApi, private readonly moderationLog: ModerationLogService) {}

  async listEmojis(guildId: string): Promise<DiscordEmoji[]> {
    return this.api.listGuildEmojis(guildId);
  }

  async createEmoji(guildId: string, actorId: string | null, request: EmojiRequest) {
    const emoji = await this.api.createGuildEmoji(guildId, {
      name: request.name, image: request.image, roles: request.roles,
    });
    await this.log(guildId, actorId, 'Emoji created', emoji.id, emoji.name ?? null);
    return emoji;
  }

  async updateEmoji(guildId: string, actorId: string | null, emojiId: string, patch: EmojiPatch) {
    const body: Record<string, unknown> = {};
    if (patch.name !== undefined) body.name = patch.name;
    if (patch.roles !== undefined) body.roles = patch.roles;
    const emoji = await this.api.updateGuildEmoji(guildId, emojiId, body);
    await this.log(guildId, actorId, 'Emoji updated', emoji.id, emoji.name ?? null);
    return emoji;
  }

  async deleteEmoji(guildId: string, actorId: string | null, emojiId: string) {
    await this.api.deleteGuildEmoji(guildId, emojiId);
    await this.log(guildId, actorId, 'Emoji deleted', emojiId, null);
    return { emojiId };
  }

  async listStickers(guildId: string): Promise<DiscordSticker[]> {
    return this.api.listGuildStickers(guildId);
  }

  async createSticker(guildId: string, actorId: string | null, request: StickerRequest) {
    const sticker = await this.api.createGuildSticker(guildId, {
      name: request.name, description: request.description, tags: request.tags, image: request.image,
    });
    await this.log(guildId, actorId, 'Sticker created', sticker.id, sticker.name);
    return sticker;
  }

  async updateSticker(guildId: string, actorId: string | null, stickerId: string, patch: StickerPatch) {
    const body: Record<string, unknown> = {};
    if (patch.name !== undefined) body.name = patch.name;
    if (patch.description !== undefined) body.description = patch.description;
    if (patch.tags !== undefined) body.tags = patch.tags;
    const sticker = await this.api.updateGuildSticker(guildId, stickerId, body);
    await this.log(guildId, actorId, 'Sticker updated', sticker.id, sticker.name);
    return sticker;
  }

  async deleteSticker(guildId: string, actorId: string | null, stickerId: string) {
    await this.api.deleteGuildSticker(guildId, stickerId);
    await this.log(guildId, actorId, 'Sticker deleted', stickerId, null);
    return { stickerId };
  }

  async readAuditLog(guildId: string, limit = 50) {
    const log = await this.api.getAuditLog(guildId, limit);
    return (log.audit_log_entries ?? []).map((entry) => ({
      id: entry.id,
      actionType: entry.action_type,
      targetId: entry.target_id ?? null,
      userId: entry.user_id ?? null,
      reason: entry.reason ?? null,
      createdAt: entry.created_at,
    }));
  }

  async exportBackup(guildId: string): Promise<BackupDocument> {
    const [guild, roles, channels] = await Promise.all([
      this.api.getGuild(guildId, false),
      this.api.getGuildRoles(guildId),
      this.api.getGuildChannels(guildId),
    ]);
    const categories = channels.filter((channel) => channel.type === 4);
    const categoryNames = new Map(categories.map((category) => [category.id, category.name ?? '']));

    return {
      version: 1,
      guildId,
      guildName: guild.name,
      exportedAt: new Date().toISOString(),
      roles: roles
        .filter((role) => role.name !== '@everyone')
        .map((role) => ({
          name: role.name, color: role.color, permissions: role.permissions,
          hoist: role.hoist ?? false, mentionable: role.mentionable ?? false, position: role.position,
        })),
      categories: categories.map((category) => ({ name: category.name ?? '', position: category.position ?? 0 })),
      channels: channels
        .filter((channel) => channel.type !== 4)
        .map((channel) => ({
          name: channel.name ?? '',
          type: channel.type,
          topic: null,
          rateLimitPerUser: channel.rate_limit_per_user ?? null,
          categoryName: channel.parent_id ? (categoryNames.get(channel.parent_id) ?? null) : null,
          overwrites: (channel.permission_overwrites ?? []).map((overwrite) => ({
            targetId: overwrite.id, targetType: overwrite.type, allow: overwrite.allow, deny: overwrite.deny,
          })),
        })),
    };
  }

  /** Restores a backup. Only missing items are created; restoring twice is safe. */
  async importBackup(guildId: string, actorId: string | null, document: BackupDocument): Promise<BackupImportResult> {
    const result: BackupImportResult = {
      createdRoles: [], createdCategories: [], createdChannels: [],
      skippedRoles: [], skippedCategories: [], skippedChannels: [],
    };

    const existingRoles: DiscordRole[] = await this.api.getGuildRoles(guildId);
    const roleNames = new Set(existingRoles.map((role) => role.name));
    for (const role of document.roles) {
      if (roleNames.has(role.name)) {
        result.skippedRoles.push(role.name);
        continue;
      }
      const created = await this.api.createGuildRole(guildId, {
        name: role.name, color: role.color, permissions: role.permissions,
        hoist: role.hoist, mentionable: role.mentionable,
      });
      roleNames.add(role.name);
      result.createdRoles.push(created.name);
    }

    const existingChannels: DiscordChannel[] = await this.api.getGuildChannels(guildId);
    const categoryNames = new Set(
      existingChannels.filter((channel) => channel.type === 4).map((channel) => channel.name ?? ''),
    );
    const categoryIds = new Map<string, string>();
    for (const category of document.categories) {
      if (categoryNames.has(category.name)) {
        result.skippedCategories.push(category.name);
        continue;
      }
      const created = await this.api.createGuildChannel(guildId, {
        name: category.name, type: 4, position: category.position,
      });
      categoryNames.add(category.name);
      categoryIds.set(category.name, created.id);
      result.createdCategories.push(created.name ?? category.name);
    }

    const channelNames = new Set(existingChannels.map((channel) => channel.name ?? ''));
    for (const channel of document.channels) {
      if (channelNames.has(channel.name)) {
        result.skippedChannels.push(channel.name);
        continue;
      }
      const parentId =
        channel.categoryName === null
          ? undefined
          : (categoryIds.get(channel.categoryName) ??
            existingChannels.find(
              (candidate) => candidate.type === 4 && candidate.name === channel.categoryName,
            )?.id);
      const created = await this.api.createGuildChannel(guildId, {
        name: channel.name,
        type: channel.type,
        ...(parentId === undefined ? {} : { parent_id: parentId }),
        ...(channel.topic === null ? {} : { topic: channel.topic }),
        ...(channel.rateLimitPerUser === null ? {} : { rate_limit_per_user: channel.rateLimitPerUser }),
      });
      channelNames.add(channel.name);
      result.createdChannels.push(created.name ?? channel.name);

      for (const overwrite of channel.overwrites) {
        await this.api.updateChannelOverwrite(created.id, overwrite.targetId, {
          type: overwrite.targetType, allow: overwrite.allow, deny: overwrite.deny,
        });
      }
    }

    await this.moderationLog.record({
      guildId, action: 'Backup imported', actorId, targetId: null,
      detail: `${result.createdRoles.length} roles, ${result.createdCategories.length} categories, ${result.createdChannels.length} channels`,
      success: true,
    });
    return result;
  }

  private async log(
    guildId: string, actorId: string | null, action: string, targetId: string | null, detail: string | null,
  ): Promise<void> {
    await this.moderationLog.record({ guildId, action, actorId, targetId, detail, success: true });
  }
}
