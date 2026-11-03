/**
 * Application error taxonomy. Every failure that reaches a client is mapped to
 * `{ error: { code, message, discordCode?, retryAfter? } }` by the error handler.
 */
export type AppErrorCode =
  | 'unauthorized'
  | 'forbidden'
  | 'not_found'
  | 'validation_failed'
  | 'conflict'
  | 'rate_limited'
  | 'upstream_error'
  | 'gateway_unavailable'
  | 'internal_error';

export class AppError extends Error {
  readonly code: AppErrorCode;
  readonly statusCode: number;
  readonly discordCode: number | undefined;
  readonly retryAfter: number | undefined;

  constructor(options: {
    code: AppErrorCode;
    statusCode: number;
    message: string;
    discordCode?: number | undefined;
    retryAfter?: number | undefined;
  }) {
    super(options.message);
    this.name = 'AppError';
    this.code = options.code;
    this.statusCode = options.statusCode;
    this.discordCode = options.discordCode;
    this.retryAfter = options.retryAfter;
  }

  static unauthorized(message = 'Missing or invalid access token.', discordCode?: number): AppError {
    return new AppError({ code: 'unauthorized', statusCode: 401, message, discordCode });
  }

  static forbidden(message = 'You do not have permission to perform this action.', discordCode?: number): AppError {
    return new AppError({ code: 'forbidden', statusCode: 403, message, discordCode });
  }

  static notFound(message = 'Resource not found.', discordCode?: number): AppError {
    return new AppError({ code: 'not_found', statusCode: 404, message, discordCode });
  }

  static validation(message: string): AppError {
    return new AppError({ code: 'validation_failed', statusCode: 400, message });
  }

  static conflict(message: string): AppError {
    return new AppError({ code: 'conflict', statusCode: 409, message });
  }

  static rateLimited(message: string, retryAfter: number): AppError {
    return new AppError({ code: 'rate_limited', statusCode: 429, message, retryAfter });
  }

  static upstream(message: string, discordCode?: number): AppError {
    return new AppError({ code: 'upstream_error', statusCode: 502, message, discordCode });
  }

  static gatewayUnavailable(message: string): AppError {
    return new AppError({ code: 'gateway_unavailable', statusCode: 503, message });
  }

  static internal(message = 'Unexpected internal error.'): AppError {
    return new AppError({ code: 'internal_error', statusCode: 500, message });
  }
}
