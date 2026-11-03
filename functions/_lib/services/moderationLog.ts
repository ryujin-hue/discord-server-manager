import type { DiscordApi } from '../discord/api';
import type { Repositories } from '../db';

export type ModerationLogEntry = {
  guildId: string;
  action: string;
  actorId: string | null;
  targetId: string | null;
  detail: string | null;
  success: boolean;
};

const EMBED_COLORS = { success: 0x57f287, failure: 0xed4245 } as const;

/** Persists every moderation action and mirrors it into the configured channel. */
export class ModerationLogService {
  constructor(private readonly api: DiscordApi, private readonly repos: Repositories) {}

  async record(entry: ModerationLogEntry): Promise<void> {
    await this.repos.moderationLog.insert({
      guildId: entry.guildId,
      action: entry.action,
      actorId: entry.actorId,
      targetId: entry.targetId,
      detail: entry.detail,
    });

    const settings = await this.repos.settings.get(entry.guildId);
    const channelId = settings.moderationLogChannelId;
    if (!channelId) return;

    const fields: { name: string; value: string; inline: boolean }[] = [
      { name: 'Actor', value: entry.actorId ?? 'Unknown', inline: true },
      { name: 'Target', value: entry.targetId ?? 'None', inline: true },
    ];
    if (entry.detail) fields.push({ name: 'Details', value: entry.detail, inline: false });

    try {
      await this.api.sendChannelMessage(channelId, {
        embeds: [
          {
            title: entry.success ? entry.action : `${entry.action} failed`,
            color: entry.success ? EMBED_COLORS.success : EMBED_COLORS.failure,
            fields,
            timestamp: new Date().toISOString(),
          },
        ],
      });
    } catch {
      // Losing the Discord mirror must never fail the action that triggered it.
    }
  }
}
