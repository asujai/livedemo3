import { pathToFileURL } from 'node:url';
import express from 'express';
import cors from 'cors';

import { config, isConfigured, corsOrigins } from './config.js';
import { tokenRateLimit } from './middleware/rateLimit.js';
import { liveTokenRouter } from './routes/liveToken.js';
import { notFound, errorHandler } from './middleware/errorHandler.js';

export function createApp() {
  const app = express();

  app.use(cors({ origin: corsOrigins() }));
  app.use(express.json({ limit: '16kb' }));

  // Health check — no auth, no rate limit.
  app.get('/health', (req, res) => {
    res.json({ ok: true });
  });

  // Token API (rate limited).
  app.use('/api', tokenRateLimit, liveTokenRouter);

  app.use(notFound);
  app.use(errorHandler);

  return app;
}

// Only start a server when run directly (not when imported by tests).
const isMain =
  process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href;

if (isMain) {
  const app = createApp();
  app.listen(config.port, () => {
    console.log(`Tilo Translate backend listening on http://localhost:${config.port}`);
    if (!isConfigured()) {
      console.warn(
        '⚠  GEMINI_API_KEY is not set. /health works, but /api/live-token will return 503.\n' +
          '   Copy backend/.env.example to backend/.env and set GEMINI_API_KEY.',
      );
    }
  });
}
