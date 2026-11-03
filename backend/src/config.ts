import { z } from 'zod';

const booleanFromString = z
  .union([z.literal('true'), z.literal('false'), z.boolean()])
  .transform((value) => value === true || value === 'true');

const envSchema = z.object({
  DISCORD_CLIENT_ID: z.string().min(1),
  DISCORD_BOT_TOKEN: z.string().min(1),
  PUBLIC_BASE_URL: z.string().url(),
  GATEWAY_ENABLED: booleanFromString.default(false),
  PORT: z.coerce.number().int().min(1).max(65535).default(8080),
  DB_PATH: z.string().min(1).default('./data/app.sqlite'),
});

export type BackendConfig = {
  discordClientId: string;
  discordBotToken: string;
  publicBaseUrl: string;
  gatewayEnabled: boolean;
  port: number;
  dbPath: string;
};

export function loadConfig(env: NodeJS.ProcessEnv = process.env): BackendConfig {
  const parsed = envSchema.safeParse(env);
  if (!parsed.success) {
    const details = parsed.error.issues
      .map((issue) => `${issue.path.join('.') || 'env'}: ${issue.message}`)
      .join('; ');
    throw new Error(`Invalid backend configuration: ${details}`);
  }
  return {
    discordClientId: parsed.data.DISCORD_CLIENT_ID,
    discordBotToken: parsed.data.DISCORD_BOT_TOKEN,
    publicBaseUrl: parsed.data.PUBLIC_BASE_URL.replace(/\/+$/, ''),
    gatewayEnabled: parsed.data.GATEWAY_ENABLED,
    port: parsed.data.PORT,
    dbPath: parsed.data.DB_PATH,
  };
}
