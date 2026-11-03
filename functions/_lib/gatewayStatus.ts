import type { Env } from './env';

/**
 * On Cloudflare Pages there is no persistent Gateway WebSocket, so we report a
 * fixed status. When `GATEWAY_ADVERTISE_UNAVAILABLE` is truthy the Flutter app
 * surfaces the limitation honestly instead of pretending a connection exists.
 *
 * The one Gateway feature that IS available — button-role interactions — is
 * served by the /interactions endpoint, not by a live socket.
 */
export function gatewayStatus(env: Env): { connected: boolean; unavailable: boolean; error?: string } {
  const advertiseUnavailable = Boolean(env.GATEWAY_ADVERTISE_UNAVAILABLE ?? '');
  if (advertiseUnavailable) {
    return {
      connected: false,
      unavailable: true,
      error:
        'Live Gateway events (welcome/goodbye, reaction roles, invite tracking) are not available on the Cloudflare backend. Button-role interactions work via the /interactions endpoint.',
    };
  }
  return { connected: false, unavailable: false };
}
