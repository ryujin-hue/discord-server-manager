import type { DiscordApi } from '../discord/api.js';
import type { ModerationLogRepository } from '../db/repositories.js';
import type { SettingsRepository } from '../db/repositories.js';

export type ModerationLogEntry = {
  guildId: string;
  action: string;
  actorId: string | null;
  targetId: string | null;
  detail: string | null;
  success: boolean;
};

const EMBED_COLORS = {
  success: 0x57f287,
  failure: 0xed4245,
} as const;

/**
 * Persists every moderation action and mirrors it into the configured
 * moderation log channel, including failed automatic actions.
 */
export class ModerationLogService {
  constructor(
    private readonly api: DiscordApi,
    private readonly logs: ModerationLogRepository,
    private readonly settings: SettingsRepository,
  ) {}

  async record(entry: ModerationLogEntry): Promise<void> {
    this.logs.insert({
      guildId: entry.guildId,
      action: entry.action,
      actorId: entry.actorId,
      targetId: entry.targetId,
      detail: entry.detail,
    });

    const channelId = this.settings.get(entry.guildId).moderationLogChannelId;
    if (!channelId) {
      return;
    }

    const title = entry.success ? entry.action : `${entry.action} failed`;
    const fields = [
      { name: 'Actor', value: entry.actorId ?? 'Unknown', inline: true },
      { name: 'Target', value: entry.targetId ?? 'None', inline: true },
    ];
    if (entry.detail) {
      fields.push({ name: 'Details', value: entry.detail, inline: false });
    }

    try {
      await this.api.sendChannelMessage(channelId, {
        embeds: [
          {
            title,
            color: entry.success ? EMBED_COLORS.success : EMBED_COLORS.failure,
            fields,
            timestamp: new Date().toISOString(),
          },
        ],
      });
    } catch {
      // The log channel may have been deleted or the bot may lack Send Messages.
      // Losing the Discord mirror must never fail the action that triggered it.
    }
  }
}
