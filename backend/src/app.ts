import Fastify, { type FastifyInstance } from 'fastify';
import cors from '@fastify/cors';
import { z } from 'zod';
import type { BackendConfig } from './config.js';
import { AppError } from './errors.js';
import { DiscordApiError, DiscordRestClient, mapDiscordError, type DiscordHttpClient } from './discord/rest.js';
import { DiscordApi } from './discord/api.js';
import { openDatabase, type SqliteDatabase } from './db/database.js';
import {
  AnnouncementRepository,
  InviteRepository,
  KnownGuildRepository,
  LockdownRepository,
  ModerationLogRepository,
  SettingsRepository,
  SnapshotRepository,
  WarningRepository,
} from './db/repositories.js';
import { AccessGuard } from './services/accessGuard.js';
import { ModerationLogService } from './services/moderationLogService.js';
import { ModerationService } from './services/moderationService.js';
import { AutoModService } from './services/automodService.js';
import { AccessService } from './services/accessService.js';
import { EngagementService } from './services/engagementService.js';
import { ToolService } from './services/toolService.js';
import { GuildService } from './services/guildService.js';
import { registerAuthRoutes } from './routes/auth.js';
import { registerGuildRoutes, type GatewayStatusProvider } from './routes/guilds.js';

export type BuildAppOptions = {
  config: BackendConfig;
  database?: SqliteDatabase;
  httpClient?: DiscordHttpClient;
  gateway?: GatewayStatusProvider;
  botUserId?: string;
};

export type BuiltApp = {
  app: FastifyInstance;
  api: DiscordApi;
  guard: AccessGuard;
  settings: SettingsRepository;
  locks: LockdownRepository;
  engagement: EngagementService;
  guildService: GuildService;
  moderationLog: ModerationLogService;
  database: SqliteDatabase;
};

const idleGateway: GatewayStatusProvider = {
  getStatus: () => ({ connected: false, error: 'gateway_disabled' }),
};

export function buildApp(options: BuildAppOptions): BuiltApp {
  const { config } = options;
  const database = options.database ?? openDatabase(config.dbPath);
  const httpClient =
    options.httpClient ??
    new DiscordRestClient({
      token: config.discordBotToken,
      userAgent: 'DiscordServerManager/1.0 (backend)',
    });
  const api = new DiscordApi(httpClient);

  const settingsRepository = new SettingsRepository(database);
  const warningRepository = new WarningRepository(database);
  const announcementRepository = new AnnouncementRepository(database);
  const snapshotRepository = new SnapshotRepository(database);
  const inviteRepository = new InviteRepository(database);
  const moderationLogRepository = new ModerationLogRepository(database);
  const lockdownRepository = new LockdownRepository(database);
  const knownGuildRepository = new KnownGuildRepository(database);

  const moderationLogService = new ModerationLogService(
    api,
    moderationLogRepository,
    settingsRepository,
  );
  const guard = new AccessGuard(api, 60_000, knownGuildRepository);
  const moderationService = new ModerationService(
    api,
    settingsRepository,
    warningRepository,
    moderationLogService,
  );
  const automodService = new AutoModService(api, moderationLogService);
  const accessService = new AccessService(api, moderationLogService);
  const engagementService = new EngagementService(
    api,
    announcementRepository,
    inviteRepository,
    moderationLogService,
  );
  const toolService = new ToolService(api, moderationLogService);
  const guildService = new GuildService(api, snapshotRepository, moderationLogService);

  const app = Fastify({
    logger: {
      level: process.env['LOG_LEVEL'] ?? 'info',
      redact: ['req.headers.authorization', 'req.headers.cookie'],
    },
  });

  app.setErrorHandler((error, request, reply) => {
    if (error instanceof AppError) {
      return reply.status(error.statusCode).send({
        error: {
          code: error.code,
          message: error.message,
          ...(error.discordCode === undefined ? {} : { discordCode: error.discordCode }),
          ...(error.retryAfter === undefined ? {} : { retryAfter: error.retryAfter }),
        },
      });
    }
    if (error instanceof DiscordApiError) {
      const mapped = mapDiscordError(error);
      return reply.status(mapped.statusCode).send({
        error: {
          code: mapped.code,
          message: mapped.message,
          ...(mapped.discordCode === undefined ? {} : { discordCode: mapped.discordCode }),
          ...(mapped.retryAfter === undefined ? {} : { retryAfter: mapped.retryAfter }),
        },
      });
    }
    if (error instanceof z.ZodError) {
      return reply.status(400).send({
        error: {
          code: 'validation_failed',
          message: error.issues.map((issue) => issue.message).join('; '),
        },
      });
    }
    request.log.error({ err: error }, 'unhandled error');
    return reply.status(500).send({
      error: { code: 'internal_error', message: 'Unexpected internal error.' },
    });
  });

  app.setNotFoundHandler((request, reply) => {
    return reply.status(404).send({
      error: { code: 'not_found', message: `Route ${request.method} ${request.url} does not exist.` },
    });
  });

  void app.register(cors, {
    origin: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  });

  app.get('/health', () => ({
    data: {
      status: 'ok',
      gateway: (options.gateway ?? idleGateway).getStatus(),
    },
  }));

  registerAuthRoutes(app, {
    publicBaseUrl: config.publicBaseUrl,
    mobileCallbackScheme: 'my-discord-manager',
  });

  registerGuildRoutes(app, {
    guard,
    api,
    moderation: moderationService,
    automod: automodService,
    access: accessService,
    engagement: engagementService,
    tools: toolService,
    guildService,
    settings: settingsRepository,
    locks: lockdownRepository,
    gateway: options.gateway ?? idleGateway,
    botUserId: options.botUserId ?? 'unknown',
  });

  return {
    app,
    api,
    guard,
    settings: settingsRepository,
    locks: lockdownRepository,
    engagement: engagementService,
    guildService,
    moderationLog: moderationLogService,
    database,
  };
}
