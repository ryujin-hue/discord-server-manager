import type { GuildSettings } from '../db/repositories.js';

export type GatewaySendOptions = {
  allowedMentions?: {
    users?: string[];
    roles?: string[];
    everyone?: boolean;
  };
};

export type MemberJoinedEvent = {
  guildId: string;
  guildName: string;
  userId: string;
  username: string;
  displayName: string;
  memberCount: number;
};

export type MemberLeftEvent = {
  guildId: string;
  guildName: string;
  userId: string;
  username: string;
  displayName: string;
  memberCount: number;
};

export type ReactionEvent = {
  guildId: string;
  channelId: string;
  messageId: string;
  emoji: string;
  userId: string;
};

export type InteractionEvent = {
  guildId: string;
  customId: string;
  userId: string;
  reply(message: string, options?: { ephemeral?: boolean }): Promise<void>;
};

export type InviteSnapshot = {
  code: string;
  uses: number;
  inviterId: string | null;
};

/**
 * Everything the gateway handlers need from the outside world. The production
 * implementation talks to Discord and SQLite; tests provide fakes.
 */
export interface GatewayContext {
  getSettings(guildId: string): GuildSettings;
  saveSettings(guildId: string, settings: GuildSettings): void;
  sendMessage(
    channelId: string,
    content: string,
    options?: GatewaySendOptions,
  ): Promise<void>;
  addMemberRole(guildId: string, userId: string, roleId: string): Promise<void>;
  removeMemberRole(guildId: string, userId: string, roleId: string): Promise<void>;
  /** Roles the member currently holds, used to toggle button roles. */
  getMemberRoleIds(guildId: string, userId: string): Promise<string[]>;
  /** Previously cached invite usage, used as the baseline for attribution. */
  getInviteSnapshot(guildId: string): InviteSnapshot[];
  /** Refreshes the invite cache and returns the current usage. */
  refreshInviteSnapshot(guildId: string): Promise<InviteSnapshot[]>;
  recordJoin(input: {
    guildId: string;
    memberId: string;
    inviteCode: string | null;
    inviterId: string | null;
  }): void;
  reportFailure(input: {
    guildId: string;
    action: string;
    targetId: string | null;
    detail: string;
  }): Promise<void>;
  updateInviteSnapshot(guildId: string, invites: InviteSnapshot[]): void;
}

export function renderTemplate(
  template: string,
  values: { user: string; server: string; memberCount: number },
): string {
  return template
    .replaceAll('{user}', values.user)
    .replaceAll('{server}', values.server)
    .replaceAll('{memberCount}', String(values.memberCount));
}
