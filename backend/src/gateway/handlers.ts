import type {
  GatewayContext,
  InteractionEvent,
  InviteSnapshot,
  MemberJoinedEvent,
  MemberLeftEvent,
  ReactionEvent,
} from './interfaces.js';
import { renderTemplate } from './interfaces.js';

/**
 * Picks the invite that explains a join by comparing the cached usage with the
 * current usage. When no invite gained uses, the join stays unattributed.
 */
export function attributeInvite(
  previous: readonly InviteSnapshot[],
  current: readonly InviteSnapshot[],
): InviteSnapshot | null {
  const before = new Map(previous.map((invite) => [invite.code, invite.uses]));
  let best: InviteSnapshot | null = null;
  let bestDelta = 0;
  for (const invite of current) {
    const delta = invite.uses - (before.get(invite.code) ?? 0);
    if (delta > bestDelta) {
      bestDelta = delta;
      best = invite;
    }
  }
  return best;
}

export async function handleMemberAdded(
  context: GatewayContext,
  event: MemberJoinedEvent,
): Promise<void> {
  const settings = context.getSettings(event.guildId);

  if (settings.welcomeEnabled && settings.welcomeChannelId) {
    const content = renderTemplate(settings.welcomeMessage, {
      user: event.displayName,
      server: event.guildName,
      memberCount: event.memberCount,
    });
    try {
      await context.sendMessage(settings.welcomeChannelId, content, {
        allowedMentions: { users: [event.userId] },
      });
    } catch (error) {
      await context.reportFailure({
        guildId: event.guildId,
        action: 'Welcome message',
        targetId: settings.welcomeChannelId,
        detail: error instanceof Error ? error.message : 'Unknown error',
      });
    }
  }

  for (const roleId of settings.autoRoleIds) {
    try {
      await context.addMemberRole(event.guildId, event.userId, roleId);
    } catch (error) {
      await context.reportFailure({
        guildId: event.guildId,
        action: 'Auto-role',
        targetId: roleId,
        detail: error instanceof Error ? error.message : 'Unknown error',
      });
    }
  }

  try {
    const previous = context.getInviteSnapshot(event.guildId);
    const current = await context.refreshInviteSnapshot(event.guildId);
    const attributed = attributeInvite(previous, current);
    context.recordJoin({
      guildId: event.guildId,
      memberId: event.userId,
      inviteCode: attributed?.code ?? null,
      inviterId: attributed?.inviterId ?? null,
    });
  } catch {
    // Invite tracking is best effort; a failure here must not break onboarding.
  }
}

export async function handleMemberRemoved(
  context: GatewayContext,
  event: MemberLeftEvent,
): Promise<void> {
  const settings = context.getSettings(event.guildId);
  if (!settings.goodbyeEnabled || !settings.goodbyeChannelId) {
    return;
  }
  const content = renderTemplate(settings.goodbyeMessage, {
    user: event.displayName,
    server: event.guildName,
    memberCount: event.memberCount,
  });
  try {
    await context.sendMessage(settings.goodbyeChannelId, content, {
      allowedMentions: { users: [event.userId] },
    });
  } catch (error) {
    await context.reportFailure({
      guildId: event.guildId,
      action: 'Goodbye message',
      targetId: settings.goodbyeChannelId,
      detail: error instanceof Error ? error.message : 'Unknown error',
    });
  }
}

export async function handleReactionAdded(
  context: GatewayContext,
  event: ReactionEvent,
): Promise<void> {
  const settings = context.getSettings(event.guildId);
  const binding = settings.reactionRoles.find(
    (candidate) => candidate.messageId === event.messageId && candidate.emoji === event.emoji,
  );
  if (!binding) {
    return;
  }
  try {
    await context.addMemberRole(event.guildId, event.userId, binding.roleId);
  } catch (error) {
    await context.reportFailure({
      guildId: event.guildId,
      action: 'Reaction role',
      targetId: binding.roleId,
      detail: error instanceof Error ? error.message : 'Unknown error',
    });
  }
}

export async function handleReactionRemoved(
  context: GatewayContext,
  event: ReactionEvent,
): Promise<void> {
  const settings = context.getSettings(event.guildId);
  const binding = settings.reactionRoles.find(
    (candidate) => candidate.messageId === event.messageId && candidate.emoji === event.emoji,
  );
  if (!binding) {
    return;
  }
  try {
    await context.removeMemberRole(event.guildId, event.userId, binding.roleId);
  } catch (error) {
    await context.reportFailure({
      guildId: event.guildId,
      action: 'Reaction role removal',
      targetId: binding.roleId,
      detail: error instanceof Error ? error.message : 'Unknown error',
    });
  }
}

export async function handleInteraction(
  context: GatewayContext,
  event: InteractionEvent,
): Promise<void> {
  const prefix = 'role:';
  if (!event.customId.startsWith(prefix)) {
    return;
  }
  const roleId = event.customId.slice(prefix.length);
  if (roleId === '') {
    return;
  }
  try {
    const memberRoles = await context.getMemberRoleIds(event.guildId, event.userId);
    if (memberRoles.includes(roleId)) {
      await context.removeMemberRole(event.guildId, event.userId, roleId);
      await event.reply('Role removed.', { ephemeral: true });
    } else {
      await context.addMemberRole(event.guildId, event.userId, roleId);
      await event.reply('Role granted.', { ephemeral: true });
    }
  } catch (error) {
    const detail = error instanceof Error ? error.message : 'Unknown error';
    await context.reportFailure({
      guildId: event.guildId,
      action: 'Button role',
      targetId: roleId,
      detail,
    });
    await event.reply(`The role could not be granted: ${detail}`, { ephemeral: true });
  }
}
