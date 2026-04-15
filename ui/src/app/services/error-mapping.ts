import { HttpErrorResponse } from '@angular/common/http';

export interface DisplayError {
  error: string;
  reason: string;
}

export interface MappedError {
  display: DisplayError;
  statusCode?: number;
}

/**
 * Map a thrown value from an RxJS pipeline or HttpClient into a user-facing
 * error + HTTP status code. Preserves backend error envelopes verbatim and
 * surfaces JS-side exceptions (TypeError, etc.) with their real message so
 * bugs are not silently masked as "An unexpected error occurred".
 */
export function mapError(err: unknown): MappedError {
  if (err instanceof HttpErrorResponse) {
    if (err.status === 0) {
      return {
        display: {
          error: 'network_error',
          reason: 'Cannot reach `/iris-couch/`. Check that the server is running.',
        },
      };
    }
    if (err.error && typeof err.error === 'object' && 'error' in err.error) {
      const body = err.error as { error: string; reason?: string };
      return {
        display: { error: body.error, reason: body.reason ?? '' },
        statusCode: err.status,
      };
    }
    return {
      display: {
        error: err.statusText || 'error',
        reason: typeof err.error === 'string' && err.error.length < 200
          ? err.error
          : `Unexpected response from server (HTTP ${err.status}).`,
      },
      statusCode: err.status,
    };
  }
  if (err instanceof Error) {
    return {
      display: { error: err.name || 'client_error', reason: err.message },
    };
  }
  return {
    display: { error: 'unknown', reason: String(err) },
  };
}
