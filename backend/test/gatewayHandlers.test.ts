import { describe, expect, it } from 'vitest';
import {
  attributeInvite,
  handleInteraction,
  handleMemberAdded,
  handleMemberRemoved,
  handleReactionAdded,
  handleReactionRemoved,
} from '../src/gateway/handlers.js';
import type {
  GatewayContext,
  GatewaySendOptions,
  InviteSnapshot,
  InteractionEvent,
} from '../src/gateway/interfaces.js';
import { defaultGuildSettings, type GuildSettings } from '../src/db/repositories.js';

type SentMessage = {
  channelId: string;
  content: string;
  options: GatewaySendOptions | undefined;
};

class FakeContext implements GatewayContext {
  settings: GuildSettings = structuredClone(defaultGuildSettings);
  readonly sent: SentMessage[] = [];
  readonly addedRoles: { userId: string; roleId: string }[] = [];
  readonly removedRoles: { userId: string; roleId: string }[] = [];
  readonly failures: { action: string; detail: string }[] = [];
  readonly joins: { memberId: string; inviteCode: string | null; inviterId: string | null }[] = [];
  memberRoles: string[] = [];
  invites: InviteSnapshot[] = [];
  currentInvites: InviteSnapshot[] | null = null;
  addRoleError: Error | null = null;

  getSettings(): GuildSettings {
    return this.settings;
  }

  saveSettings(_guildId: string, settings: GuildSettings): void {
    this.settings = settings;
  }

  async sendMessage(
    channelId: string,
    content: string,
    options?: GatewaySendOptions,
  ): Promise<void> {
    this.sent.push({ channelId, content, options });
  }

  async addMemberRole(_guildId: string, userId: string, roleId: string): Promise<void> {
    if (this.addRoleError) {
      throw this.addRoleError;
    }
    this.addedRoles.push({ userId, roleId });
  }

  async removeMemberRole(_guildId: string, userId: string, roleId: string): Promise<void> {
    this.removedRoles.push({ userId, roleId });
  }

  async getMemberRoleIds(): Promise<string[]> {
    return this.memberRoles;
  }

  getInviteSnapshot(): InviteSnapshot[] {
    return this.invites;
  }

  async refreshInviteSnapshot(): Promise<InviteSnapshot[]> {
    return this.currentInvites ?? this.invites;
  }

  recordJoin(input: {
    guildId: string;
    memberId: string;
    inviteCode: string | null;
    inviterId: string | null;
  }): void {
    this.joins.push({
      memberId: input.memberId,
      inviteCode: input.inviteCode,
      inviterId: input.inviterId,
    });
  }

  async reportFailure(input: { guildId: string; action: string; targetId: string | null; detail: string }): Promise<void> {
    this.failures.push({ action: input.action, detail: input.detail });
  }

  updateInviteSnapshot(_guildId: string, invites: InviteSnapshot[]): void {
    this.invites = invites;
  }
}

describe('gateway handlers', () => {
  it('sends the welcome message with the placeholders filled in', async () => {
    const context = new FakeContext();
    context.settings.welcomeEnabled = true;
    context.settings.welcomeChannelId = 'channel-1';
    context.settings.welcomeMessage = 'Welcome {user} to {server}, we are {memberCount} members';

    await handleMemberAdded(context, {
      guildId: 'guild-1',
      guildName: 'Test Guild',
      userId: 'user-1',
      username: 'ada',
      displayName: 'Ada',
      memberCount: 12,
    });

    expect(context.sent).toHaveLength(1);
    expect(context.sent[0]?.channelId).toBe('channel-1');
    expect(context.sent[0]?.content).toBe('Welcome Ada to Test Guild, we are 12 members');
  });

  it('limits the welcome mentions to the joining user', async () => {
    const context = new FakeContext();
    context.settings.welcomeEnabled = true;
    context.settings.welcomeChannelId = 'channel-1';

    await handleMemberAdded(context, {
      guildId: 'guild-1',
      guildName: 'Test Guild',
      userId: 'user-1',
      username: 'ada',
      displayName: 'Ada',
      memberCount: 1,
    });

    expect(context.sent[0]?.options?.allowedMentions).toEqual({ users: ['user-1'] });
  });

  it('does not send a welcome message when it is disabled', async () => {
    const context = new FakeContext();
    await handleMemberAdded(context, {
      guildId: 'guild-1',
      guildName: 'Test Guild',
      userId: 'user-1',
      username: 'ada',
      displayName: 'Ada',
      memberCount: 1,
    });
    expect(context.sent).toHaveLength(0);
  });

  it('adds the configured auto-roles', async () => {
    const context = new FakeContext();
    context.settings.autoRoleIds = ['role-1', 'role-2'];

    await handleMemberAdded(context, {
      guildId: 'guild-1',
      guildName: 'Test Guild',
      userId: 'user-1',
      username: 'ada',
      displayName: 'Ada',
      memberCount: 1,
    });

    expect(context.addedRoles).toEqual([
      { userId: 'user-1', roleId: 'role-1' },
      { userId: 'user-1', roleId: 'role-2' },
    ]);
  });

  it('reports an auto-role failure to the moderation log', async () => {
    const context = new FakeContext();
    context.settings.autoRoleIds = ['role-1'];
    context.addRoleError = new Error('50013: Missing Permissions');

    await handleMemberAdded(context, {
      guildId: 'guild-1',
      guildName: 'Test Guild',
      userId: 'user-1',
      username: 'ada',
      displayName: 'Ada',
      memberCount: 1,
    });

    expect(context.failures).toHaveLength(1);
    expect(context.failures[0]?.action).toBe('Auto-role');
    expect(context.failures[0]?.detail).toContain('Missing Permissions');
  });

  it('sends the goodbye message', async () => {
    const context = new FakeContext();
    context.settings.goodbyeEnabled = true;
    context.settings.goodbyeChannelId = 'channel-2';
    context.settings.goodbyeMessage = '{user} left {server}';

    await handleMemberRemoved(context, {
      guildId: 'guild-1',
      guildName: 'Test Guild',
      userId: 'user-1',
      username: 'ada',
      displayName: 'Ada',
      memberCount: 10,
    });

    expect(context.sent[0]?.content).toBe('Ada left Test Guild');
  });

  it('grants and revokes a reaction role', async () => {
    const context = new FakeContext();
    context.settings.reactionRoles = [{ messageId: 'message-1', emoji: '👍', roleId: 'role-9' }];

    await handleReactionAdded(context, {
      guildId: 'guild-1',
      channelId: 'channel-1',
      messageId: 'message-1',
      emoji: '👍',
      userId: 'user-1',
    });
    await handleReactionRemoved(context, {
      guildId: 'guild-1',
      channelId: 'channel-1',
      messageId: 'message-1',
      emoji: '👍',
      userId: 'user-1',
    });

    expect(context.addedRoles).toEqual([{ userId: 'user-1', roleId: 'role-9' }]);
    expect(context.removedRoles).toEqual([{ userId: 'user-1', roleId: 'role-9' }]);
  });

  it('ignores a reaction that is not bound to a role', async () => {
    const context = new FakeContext();
    context.settings.reactionRoles = [{ messageId: 'message-1', emoji: '👍', roleId: 'role-9' }];

    await handleReactionAdded(context, {
      guildId: 'guild-1',
      channelId: 'channel-1',
      messageId: 'message-2',
      emoji: '👍',
      userId: 'user-1',
    });

    expect(context.addedRoles).toHaveLength(0);
  });

  it('toggles a button role and replies ephemerally', async () => {
    const context = new FakeContext();
    const replies: { message: string; ephemeral: boolean | undefined }[] = [];
    const event: InteractionEvent = {
      guildId: 'guild-1',
      customId: 'role:role-9',
      userId: 'user-1',
      reply: async (message, options) => {
        replies.push({ message, ephemeral: options?.ephemeral });
      },
    };

    await handleInteraction(context, event);
    expect(context.addedRoles).toEqual([{ userId: 'user-1', roleId: 'role-9' }]);
    expect(replies[0]).toEqual({ message: 'Role granted.', ephemeral: true });

    context.memberRoles = ['role-9'];
    await handleInteraction(context, event);
    expect(context.removedRoles).toEqual([{ userId: 'user-1', roleId: 'role-9' }]);
    expect(replies[1]).toEqual({ message: 'Role removed.', ephemeral: true });
  });

  it('ignores an interaction that is not a role button', async () => {
    const context = new FakeContext();
    const replies: string[] = [];
    await handleInteraction(context, {
      guildId: 'guild-1',
      customId: 'other:thing',
      userId: 'user-1',
      reply: async (message) => {
        replies.push(message);
      },
    });
    expect(context.addedRoles).toHaveLength(0);
    expect(replies).toHaveLength(0);
  });

  it('attributes a join to the invite that gained uses', async () => {
    const context = new FakeContext();
    context.invites = [
      { code: 'aaa', uses: 4, inviterId: 'inviter-1' },
      { code: 'bbb', uses: 9, inviterId: 'inviter-2' },
    ];
    context.currentInvites = [
      { code: 'aaa', uses: 5, inviterId: 'inviter-1' },
      { code: 'bbb', uses: 9, inviterId: 'inviter-2' },
    ];

    await handleMemberAdded(context, {
      guildId: 'guild-1',
      guildName: 'Test Guild',
      userId: 'user-1',
      username: 'ada',
      displayName: 'Ada',
      memberCount: 1,
    });

    expect(context.joins).toEqual([
      { memberId: 'user-1', inviteCode: 'aaa', inviterId: 'inviter-1' },
    ]);
  });

  it('leaves a join unattributed when no invite gained uses', async () => {
    const context = new FakeContext();
    context.invites = [{ code: 'aaa', uses: 4, inviterId: 'inviter-1' }];

    await handleMemberAdded(context, {
      guildId: 'guild-1',
      guildName: 'Test Guild',
      userId: 'user-1',
      username: 'ada',
      displayName: 'Ada',
      memberCount: 1,
    });

    expect(context.joins).toEqual([
      { memberId: 'user-1', inviteCode: null, inviterId: null },
    ]);
  });
});

describe('attributeInvite', () => {
  it('picks the invite with the largest increase', () => {
    const attributed = attributeInvite(
      [
        { code: 'aaa', uses: 1, inviterId: null },
        { code: 'bbb', uses: 5, inviterId: null },
      ],
      [
        { code: 'aaa', uses: 2, inviterId: 'x' },
        { code: 'bbb', uses: 5, inviterId: null },
      ],
    );
    expect(attributed?.code).toBe('aaa');
  });

  it('returns null when nothing changed', () => {
    const attributed = attributeInvite(
      [{ code: 'aaa', uses: 1, inviterId: null }],
      [{ code: 'aaa', uses: 1, inviterId: null }],
    );
    expect(attributed).toBeNull();
  });
});
