import {
  Client,
  GatewayIntentBits,
  MessageFlags,
  Partials,
  type Guild,
  type GuildMember,
  type PartialGuildMember,
  type Invite,
  type MessageReaction,
  type PartialMessageReaction,
  type PartialUser,
  type User,
  type ButtonInteraction,
} from 'discord.js';
import type { DiscordApi } from '../discord/api.js';
import type { EngagementService } from '../services/engagementService.js';
import type { ModerationLogService } from '../services/moderationLogService.js';
import type { SettingsRepository } from '../db/repositories.js';
import type { GuildSettings } from '../db/repositories.js';
import {
  handleInteraction,
  handleMemberAdded,
  handleMemberRemoved,
  handleReactionAdded,
  handleReactionRemoved,
} from './handlers.js';
import type {
  GatewayContext,
  GatewaySendOptions,
  InviteSnapshot,
  InteractionEvent,
  MemberJoinedEvent,
  MemberLeftEvent,
  ReactionEvent,
} from './interfaces.js';

export type GatewayStatus = {
  connected: boolean;
  error?: string;
};

const PRIVILEGED_INTENT_ERROR = 'privileged_intent_disabled';

export class DiscordGatewayContext implements GatewayContext {
  private readonly inviteSnapshots = new Map<string, InviteSnapshot[]>();

  constructor(
    private readonly api: DiscordApi,
    private readonly settings: SettingsRepository,
    private readonly engagement: EngagementService,
    private readonly moderationLog: ModerationLogService,
  ) {}

  getSettings(guildId: string): GuildSettings {
    return this.settings.get(guildId);
  }

  saveSettings(guildId: string, settings: GuildSettings): void {
    this.settings.save(guildId, settings);
  }

  async sendMessage(
    channelId: string,
    content: string,
    options?: GatewaySendOptions,
  ): Promise<void> {
    await this.api.sendChannelMessage(channelId, {
      content,
      ...(options?.allowedMentions
        ? { allowed_mentions: options.allowedMentions }
        : {}),
    });
  }

  async addMemberRole(guildId: string, userId: string, roleId: string): Promise<void> {
    await this.api.addMemberRole(guildId, userId, roleId);
  }

  async removeMemberRole(guildId: string, userId: string, roleId: string): Promise<void> {
    await this.api.removeMemberRole(guildId, userId, roleId);
  }

  async getMemberRoleIds(guildId: string, userId: string): Promise<string[]> {
    const member = await this.api.getGuildMember(guildId, userId);
    return member.roles;
  }

  getInviteSnapshot(guildId: string): InviteSnapshot[] {
    return this.inviteSnapshots.get(guildId) ?? [];
  }

  updateInviteSnapshot(guildId: string, invites: InviteSnapshot[]): void {
    this.inviteSnapshots.set(guildId, invites);
  }

  async refreshInviteSnapshot(guildId: string): Promise<InviteSnapshot[]> {
    const invites = await this.api.listGuildInvites(guildId);
    const snapshots = invites.map((invite) => ({
      code: invite.code,
      uses: invite.uses,
      inviterId: invite.inviter?.id ?? null,
    }));
    this.inviteSnapshots.set(guildId, snapshots);
    return snapshots;
  }

  recordJoin(input: {
    guildId: string;
    memberId: string;
    inviteCode: string | null;
    inviterId: string | null;
  }): void {
    this.engagement.recordJoin(input);
  }

  async reportFailure(input: {
    guildId: string;
    action: string;
    targetId: string | null;
    detail: string;
  }): Promise<void> {
    await this.moderationLog.record({
      guildId: input.guildId,
      action: input.action,
      actorId: null,
      targetId: input.targetId,
      detail: input.detail,
      success: false,
    });
  }
}

export class GatewayService {
  private readonly client: Client;
  private readonly context: DiscordGatewayContext;
  private status: GatewayStatus = { connected: false };

  constructor(
    private readonly botToken: string,
    context: DiscordGatewayContext,
  ) {
    this.context = context;
    this.client = new Client({
      intents: [
        GatewayIntentBits.Guilds,
        GatewayIntentBits.GuildMembers,
        GatewayIntentBits.GuildMessageReactions,
        GatewayIntentBits.GuildInvites,
      ],
      partials: [Partials.Message, Partials.Channel, Partials.Reaction],
    });
    this.registerHandlers();
  }

  getStatus(): GatewayStatus {
    return { ...this.status };
  }

  async start(): Promise<void> {
    try {
      await this.client.login(this.botToken);
      this.status = { connected: true };
    } catch (error) {
      this.status = {
        connected: false,
        error: isPrivilegedIntentError(error) ? PRIVILEGED_INTENT_ERROR : 'gateway_login_failed',
      };
      throw error;
    }
  }

  async stop(): Promise<void> {
    await this.client.destroy();
    this.status = { connected: false };
  }

  private registerHandlers(): void {
    this.client.once('ready', () => {
      this.status = { connected: true };
      void this.cacheInvites();
    });

    this.client.on('error', (error: Error) => {
      this.status = {
        connected: false,
        error: isPrivilegedIntentError(error) ? PRIVILEGED_INTENT_ERROR : 'gateway_error',
      };
    });

    this.client.on('guildMemberAdd', (member: GuildMember | PartialGuildMember) => {
      void this.onMemberAdded(member);
    });

    this.client.on('guildMemberRemove', (member: GuildMember | PartialGuildMember) => {
      void this.onMemberRemoved(member);
    });

    this.client.on('messageReactionAdd', (reaction, user) => {
      void this.onReactionChanged(reaction, user, true);
    });

    this.client.on('messageReactionRemove', (reaction, user) => {
      void this.onReactionChanged(reaction, user, false);
    });

    this.client.on('interactionCreate', (interaction) => {
      void this.onInteraction(interaction);
    });

    this.client.on('inviteCreate', (invite: Invite) => {
      void this.onInviteCreate(invite);
    });

    this.client.on('inviteDelete', (invite: Invite) => {
      void this.onInviteDelete(invite);
    });
  }

  private async cacheInvites(): Promise<void> {
    for (const guild of this.client.guilds.cache.values()) {
      try {
        await this.context.refreshInviteSnapshot(guild.id);
      } catch {
        // The bot may lack permission to read invites of this guild.
      }
    }
  }

  private async onMemberAdded(member: GuildMember | PartialGuildMember): Promise<void> {
    const event: MemberJoinedEvent = {
      guildId: member.guild.id,
      guildName: member.guild.name,
      userId: member.id,
      username: member.user?.username ?? 'Unknown',
      displayName: member.displayName || member.user?.username || 'Unknown',
      memberCount: member.guild.memberCount,
    };
    await handleMemberAdded(this.context, event);
  }

  private async onMemberRemoved(member: GuildMember | PartialGuildMember): Promise<void> {
    const event: MemberLeftEvent = {
      guildId: member.guild.id,
      guildName: member.guild.name,
      userId: member.id,
      username: member.user?.username ?? 'Unknown',
      displayName: member.displayName || member.user?.username || 'Unknown',
      memberCount: member.guild.memberCount,
    };
    await handleMemberRemoved(this.context, event);
  }

  private async onReactionChanged(
    reaction: MessageReaction | PartialMessageReaction,
    user: User | PartialUser,
    added: boolean,
  ): Promise<void> {
    const guildId = reaction.message.guildId;
    if (!guildId) {
      return;
    }
    const event: ReactionEvent = {
      guildId,
      channelId: reaction.message.channelId ?? '',
      messageId: reaction.message.id,
      emoji: reaction.emoji.name ?? reaction.emoji.id ?? '',
      userId: user.id,
    };
    if (added) {
      await handleReactionAdded(this.context, event);
    } else {
      await handleReactionRemoved(this.context, event);
    }
  }

  private async onInteraction(interaction: unknown): Promise<void> {
    if (!isButtonInteraction(interaction)) {
      return;
    }
    const guildId = interaction.guildId;
    if (!guildId) {
      return;
    }
    const event: InteractionEvent = {
      guildId,
      customId: interaction.customId,
      userId: interaction.user.id,
      reply: async (message: string, options?: { ephemeral?: boolean }) => {
        await interaction.reply({
          content: message,
          flags: options?.ephemeral ? MessageFlags.Ephemeral : undefined,
        });
      },
    };
    await handleInteraction(this.context, event);
  }

  private onInviteCreate(invite: Invite): void {
    const guildId = invite.guild?.id;
    if (!guildId) {
      return;
    }
    const snapshots = this.context.getInviteSnapshot(guildId).filter(
      (candidate) => candidate.code !== invite.code,
    );
    snapshots.push({
      code: invite.code,
      uses: invite.uses ?? 0,
      inviterId: invite.inviter?.id ?? null,
    });
    this.context.updateInviteSnapshot(guildId, snapshots);
  }

  private onInviteDelete(invite: Invite): void {
    const guildId = invite.guild?.id;
    if (!guildId) {
      return;
    }
    const snapshots = this.context
      .getInviteSnapshot(guildId)
      .filter((candidate) => candidate.code !== invite.code);
    this.context.updateInviteSnapshot(guildId, snapshots);
  }
}

function isButtonInteraction(value: unknown): value is ButtonInteraction {
  return (
    typeof value === 'object' &&
    value !== null &&
    'customId' in value &&
    'user' in value &&
    'reply' in value
  );
}

export function isPrivilegedIntentError(error: unknown): boolean {
  if (typeof error !== 'object' || error === null) {
    return false;
  }
  const candidate = error as { code?: unknown; message?: unknown };
  if (candidate.code === 4014) {
    return true;
  }
  const message = typeof candidate.message === 'string' ? candidate.message.toLowerCase() : '';
  return message.includes('disallowed intents') || message.includes('privileged');
}

export type { GatewayContext, Guild };
