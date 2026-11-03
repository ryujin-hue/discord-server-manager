import { z } from 'zod';
import type { DiscordApi, DiscordAutoModRule } from '../discord/api.js';
import type { ModerationLogService } from './moderationLogService.js';

export const AUTO_MOD_EVENT_TYPE_MESSAGE_SEND = 1;
export const AUTO_MOD_TRIGGER_KEYWORD = 1;
export const AUTO_MOD_TRIGGER_SPAM = 2;
export const AUTO_MOD_TRIGGER_KEYWORD_PRESET = 3;
export const AUTO_MOD_TRIGGER_MENTION_SPAM = 4;
export const AUTO_MOD_ACTION_BLOCK_MESSAGE = 1;
export const AUTO_MOD_ACTION_SEND_ALERT_MESSAGE = 2;

export const autoModRuleRequestSchema = z
  .object({
    name: z.string().min(1).max(150),
    kind: z.enum(['keyword', 'regex', 'spam', 'mention_spam', 'keyword_preset']),
    keywords: z.array(z.string().min(1)).default([]),
    regexPatterns: z.array(z.string().min(1)).default([]),
    presets: z.array(z.enum(['profanity', 'sexual_content', 'slurs'])).default([]),
    mentionTotalLimit: z.number().int().min(1).max(100).default(5),
    allowList: z.array(z.string().min(1)).default([]),
    alertChannelId: z.string().min(1).nullable().default(null),
    customMessage: z.string().max(150).nullable().default(null),
    enabled: z.boolean().default(true),
    exemptRoleIds: z.array(z.string().min(1)).default([]),
    exemptChannelIds: z.array(z.string().min(1)).default([]),
  })
  .superRefine((value, ctx) => {
    if (value.kind === 'keyword' && value.keywords.length === 0) {
      ctx.addIssue({ code: 'custom', path: ['keywords'], message: 'Keyword rules need at least one keyword.' });
    }
    if (value.kind === 'regex' && value.regexPatterns.length === 0) {
      ctx.addIssue({
        code: 'custom',
        path: ['regexPatterns'],
        message: 'Regex rules need at least one pattern.',
      });
    }
    if (value.kind === 'keyword_preset' && value.presets.length === 0) {
      ctx.addIssue({ code: 'custom', path: ['presets'], message: 'Preset rules need at least one preset.' });
    }
  });

export type AutoModRuleRequest = z.infer<typeof autoModRuleRequestSchema>;

export type AutoModRuleSummary = {
  id: string;
  name: string;
  enabled: boolean;
  kind: string;
  keywords: string[];
  regexPatterns: string[];
  presets: string[];
  mentionTotalLimit: number | null;
  allowList: string[];
  alertChannelId: string | null;
  exemptRoleIds: string[];
  exemptChannelIds: string[];
};

export class AutoModService {
  constructor(
    private readonly api: DiscordApi,
    private readonly moderationLog: ModerationLogService,
  ) {}

  async list(guildId: string): Promise<AutoModRuleSummary[]> {
    const rules = await this.api.listAutoModRules(guildId);
    return rules.map((rule) => this.summarize(rule));
  }

  async create(guildId: string, actorId: string | null, request: AutoModRuleRequest) {
    const body = this.toDiscordBody(request);
    const rule = await this.api.createAutoModRule(guildId, body);
    await this.moderationLog.record({
      guildId,
      action: 'AutoMod rule created',
      actorId,
      targetId: rule.id,
      detail: request.name,
      success: true,
    });
    return this.summarize(rule);
  }

  async update(guildId: string, actorId: string | null, ruleId: string, request: AutoModRuleRequest) {
    const rule = await this.api.updateAutoModRule(guildId, ruleId, this.toDiscordBody(request));
    await this.moderationLog.record({
      guildId,
      action: 'AutoMod rule updated',
      actorId,
      targetId: rule.id,
      detail: request.name,
      success: true,
    });
    return this.summarize(rule);
  }

  async remove(guildId: string, actorId: string | null, ruleId: string) {
    await this.api.deleteAutoModRule(guildId, ruleId);
    await this.moderationLog.record({
      guildId,
      action: 'AutoMod rule deleted',
      actorId,
      targetId: ruleId,
      detail: null,
      success: true,
    });
    return { ruleId };
  }

  private toDiscordBody(request: AutoModRuleRequest): Record<string, unknown> {
    const triggerMetadata: Record<string, unknown> = {};
    if (request.kind === 'keyword') {
      triggerMetadata.keyword_filter = request.keywords;
    } else if (request.kind === 'regex') {
      triggerMetadata.regex_patterns = request.regexPatterns;
    } else if (request.kind === 'spam') {
      triggerMetadata.mention_total_limit = request.mentionTotalLimit;
    } else if (request.kind === 'mention_spam') {
      triggerMetadata.mention_total_limit = request.mentionTotalLimit;
    }

    const actions: Record<string, unknown>[] = [
      { type: AUTO_MOD_ACTION_BLOCK_MESSAGE, metadata: {} },
    ];
    if (request.alertChannelId) {
      actions.push({
        type: AUTO_MOD_ACTION_SEND_ALERT_MESSAGE,
        metadata: {
          channel_id: request.alertChannelId,
          ...(request.customMessage ? { custom_message: request.customMessage } : {}),
        },
      });
    }

    return {
      name: request.name,
      event_type: AUTO_MOD_EVENT_TYPE_MESSAGE_SEND,
      trigger_type:
        request.kind === 'keyword'
          ? AUTO_MOD_TRIGGER_KEYWORD
          : request.kind === 'regex'
            ? AUTO_MOD_TRIGGER_KEYWORD
            : request.kind === 'spam'
              ? AUTO_MOD_TRIGGER_SPAM
              : request.kind === 'mention_spam'
                ? AUTO_MOD_TRIGGER_MENTION_SPAM
                : AUTO_MOD_TRIGGER_KEYWORD_PRESET,
      trigger_metadata: {
        ...triggerMetadata,
        ...(request.allowList.length > 0 ? { allow_list: request.allowList } : {}),
      },
      actions,
      enabled: request.enabled,
      exempt_roles: request.exemptRoleIds,
      exempt_channels: request.exemptChannelIds,
    };
  }

  private summarize(rule: DiscordAutoModRule): AutoModRuleSummary {
    const metadata = rule.trigger_metadata ?? {};
    const keywords = Array.isArray(metadata['keyword_filter'])
      ? (metadata['keyword_filter'] as string[])
      : [];
    const regexPatterns = Array.isArray(metadata['regex_patterns'])
      ? (metadata['regex_patterns'] as string[])
      : [];
    const presets = Array.isArray(metadata['presets']) ? (metadata['presets'] as string[]) : [];
    const allowList = Array.isArray(metadata['allow_list'])
      ? (metadata['allow_list'] as string[])
      : [];
    const mentionTotalLimit =
      typeof metadata['mention_total_limit'] === 'number' ? metadata['mention_total_limit'] : null;

    const alertAction = (rule.actions ?? []).find(
      (action) => action['type'] === AUTO_MOD_ACTION_SEND_ALERT_MESSAGE,
    );
    const alertMetadata = alertAction?.['metadata'] as
      | { channel_id?: unknown; custom_message?: unknown }
      | undefined;

    let kind = 'keyword';
    if (regexPatterns.length > 0) {
      kind = 'regex';
    } else if (mentionTotalLimit !== null) {
      kind = 'mention_spam';
    } else if (presets.length > 0) {
      kind = 'preset';
    }

    return {
      id: rule.id,
      name: rule.name,
      enabled: rule.enabled ?? true,
      kind,
      keywords,
      regexPatterns,
      presets,
      mentionTotalLimit,
      allowList,
      alertChannelId:
        typeof alertMetadata?.channel_id === 'string' ? alertMetadata.channel_id : null,
      exemptRoleIds: [],
      exemptChannelIds: [],
    };
  }
}
