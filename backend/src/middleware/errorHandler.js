/* eslint-disable no-unused-vars */

/** 404 handler for unknown routes. */
export function notFound(req, res) {
  res.status(404).json({ error: { code: 'NOT_FOUND', message: 'Route not found.' } });
}

/**
 * Central error handler. Never leaks secrets or stack traces to the client;
 * maps known error codes to friendly messages.
 */
export function errorHandler(err, req, res, _next) {
  const code = err?.code || 'INTERNAL';

  const map = {
    NOT_CONFIGURED: [503, 'Server is not configured.'],
    TOKEN_FAILED: [502, 'Could not create a translation session token.'],
  };

  const [status, message] = map[code] || [500, 'Unexpected server error.'];

  // Log a sanitized message server-side only (no tokens, no keys, no stack to client).
  console.error('[error]', code, '-', sanitize(err?.message));

  res.status(status).json({ error: { code, message } });
}

function sanitize(message = '') {
  return String(message)
    .replace(/AIza[0-9A-Za-z\-_]+/g, '[redacted]')
    .replace(/AQ\.[0-9A-Za-z\-_.]+/g, '[redacted]');
}
