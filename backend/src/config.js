import dotenv from 'dotenv';

dotenv.config();

function num(name, fallback) {
  const raw = process.env[name];
  if (raw === undefined || raw.trim() === '') return fallback;
  const parsed = Number(raw);
  return Number.isFinite(parsed) ? parsed : fallback;
}

export const config = {
  port: num('PORT', 8787),
  geminiApiKey: (process.env.GEMINI_API_KEY || '').trim(),
  corsOrigin: (process.env.CORS_ORIGIN || '*').trim(),

  // Token tuning
  tokenExpireMinutes: num('TOKEN_EXPIRE_MINUTES', 30),
  tokenNewSessionMinutes: num('TOKEN_NEW_SESSION_MINUTES', 2),
  tokenUses: num('TOKEN_USES', 1),
};

/** True when the server has the secret it needs to mint tokens. */
export function isConfigured() {
  return config.geminiApiKey.length > 0;
}

/** Parsed CORS origin list; `*` means allow any. */
export function corsOrigins() {
  if (config.corsOrigin === '*') return '*';
  return config.corsOrigin
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean);
}
