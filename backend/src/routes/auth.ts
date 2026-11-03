import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { AppError } from '../errors.js';

const CALLBACK_ALLOWED_PARAMS = ['code', 'state', 'error', 'error_description'] as const;

const querySchema = z.record(z.string(), z.string().optional());

export type AuthRouteOptions = {
  publicBaseUrl: string;
  mobileCallbackScheme: string;
};

/**
 * OAuth2 redirect target for the mobile app. Discord calls this URL with the
 * authorization code; the backend forwards only whitelisted parameters to the
 * app's custom scheme.
 */
export function registerAuthRoutes(app: FastifyInstance, options: AuthRouteOptions): void {
  app.get('/auth/mobile-callback', async (request, reply) => {
    const parsed = querySchema.safeParse(request.query ?? {});
    if (!parsed.success) {
      throw AppError.validation('The callback query could not be parsed.');
    }

    const query = parsed.data;
    const forwarded = new URLSearchParams();
    for (const name of CALLBACK_ALLOWED_PARAMS) {
      const value = query[name];
      if (typeof value === 'string' && value.length > 0) {
        forwarded.set(name, value);
      }
    }

    const target = new URL(`${options.mobileCallbackScheme}://oauth2/callback`);
    const forwardedQuery = forwarded.toString();
    if (forwardedQuery.length > 0) {
      target.search = forwardedQuery;
    }

    return reply.redirect(target.toString(), 302);
  });

  app.get('/auth/mobile-callback/config', () => ({
    data: {
      redirectUri: `${options.publicBaseUrl}/auth/mobile-callback`,
      callbackScheme: options.mobileCallbackScheme,
    },
  }));
}
