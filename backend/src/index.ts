import { loadConfig } from './config.js';
import { buildApp } from './app.js';
import { DiscordApi } from './discord/api.js';
import { DiscordRestClient } from './discord/rest.js';
import { DiscordGatewayContext, GatewayService } from './gateway/service.js';
import { KnownGuildRepository } from './db/repositories.js';
import { Scheduler } from './scheduler/index.js';

async function main(): Promise<void> {
  const config = loadConfig();
  const restClient = new DiscordRestClient({
    token: config.discordBotToken,
    userAgent: 'DiscordServerManager/1.0 (backend)',
  });
  const api = new DiscordApi(restClient);

  let gatewayStatus: { connected: boolean; error?: string } = {
    connected: false,
    error: 'gateway_disabled',
  };

  const built = buildApp({
    config,
    gateway: { getStatus: () => gatewayStatus },
  });

  const botUser = await api.getCurrentUser();

  if (config.gatewayEnabled) {
    const context = new DiscordGatewayContext(
      api,
      built.settings,
      built.engagement,
      built.moderationLog,
    );
    const gateway = new GatewayService(config.discordBotToken, context);
    try {
      await gateway.start();
      gatewayStatus = gateway.getStatus();
    } catch (error) {
      gatewayStatus = gateway.getStatus();
      built.app.log.error({ err: error }, 'gateway failed to start');
    }
  }

  const knownGuilds = new KnownGuildRepository(built.database);
  const scheduler = new Scheduler(built.engagement, built.guildService, knownGuilds);
  scheduler.start();

  await built.app.listen({ port: config.port, host: '0.0.0.0' });
  built.app.log.info(
    { port: config.port, botUserId: botUser.id, gatewayEnabled: config.gatewayEnabled },
    'backend started',
  );

  const shutdown = async (signal: string): Promise<void> => {
    built.app.log.info({ signal }, 'shutting down');
    scheduler.stop();
    await built.app.close();
    built.database.close();
    process.exit(0);
  };

  process.on('SIGINT', () => {
    void shutdown('SIGINT');
  });
  process.on('SIGTERM', () => {
    void shutdown('SIGTERM');
  });
}

main().catch((error: unknown) => {
  console.error('Backend failed to start:', error);
  process.exit(1);
});
