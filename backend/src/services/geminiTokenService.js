import { GoogleGenAI } from '@google/genai';
import { config, isConfigured } from '../config.js';

/**
 * Gemini Live Translate model used for the whole app.
 * (Bare model id — no "models/" prefix, matching the ephemeral-token docs.)
 */
export const LIVE_TRANSLATE_MODEL = 'gemini-3.5-live-translate-preview';

// Ephemeral tokens are only supported on the v1alpha Developer API surface.
const API_VERSION = 'v1alpha';

let _client = null;

/** Lazily build the client so a missing key never crashes module import. */
function client() {
  if (!isConfigured()) {
    const err = new Error('GEMINI_API_KEY is not configured on the server.');
    err.code = 'NOT_CONFIGURED';
    throw err;
  }
  if (!_client) {
    _client = new GoogleGenAI({
      apiKey: config.geminiApiKey,
      httpOptions: { apiVersion: API_VERSION },
    });
  }
  return _client;
}

/**
 * Build the Live config we want to LOCK into the ephemeral token.
 * The mobile client will still send its own setup at connect time, but with a
 * Constrained connection it cannot exceed what the token allows.
 */
function buildConstraintConfig(targetLanguageCode) {
  return {
    responseModalities: ['AUDIO'],
    inputAudioTranscription: {},
    outputAudioTranscription: {},
    translationConfig: {
      targetLanguageCode,
      echoTargetLanguage: false,
    },
  };
}

/**
 * Create a short-lived (ephemeral) Live API token locked to one translation
 * direction. Returns only what the client needs — never the API key.
 *
 * @param {{ targetLanguageCode: string }} params
 * @returns {Promise<{token: string, model: string, expiresAt: string, targetLanguageCode: string}>}
 */
export async function createLiveToken({ targetLanguageCode }) {
  const ai = client();

  const expireTime = new Date(
    Date.now() + config.tokenExpireMinutes * 60 * 1000,
  ).toISOString();
  const newSessionExpireTime = new Date(
    Date.now() + config.tokenNewSessionMinutes * 60 * 1000,
  ).toISOString();

  const baseCreate = {
    uses: config.tokenUses,
    expireTime,
    newSessionExpireTime,
    httpOptions: { apiVersion: API_VERSION },
  };

  let token;
  try {
    // Preferred: lock the full translate config into the token.
    token = await ai.authTokens.create({
      config: {
        ...baseCreate,
        liveConnectConstraints: {
          model: LIVE_TRANSLATE_MODEL,
          config: buildConstraintConfig(targetLanguageCode),
        },
      },
    });
  } catch (err) {
    // The translate model / translationConfig are preview features; the
    // constraints validator may reject unknown fields. Fall back to a minimal
    // lock (model + audio response) so the demo still works. The client sends
    // the full setup (translationConfig, transcription) at connect time.
    console.warn(
      '[token] Full constraint lock rejected, retrying with minimal lock:',
      sanitize(err.message),
    );
    token = await ai.authTokens.create({
      config: {
        ...baseCreate,
        liveConnectConstraints: {
          model: LIVE_TRANSLATE_MODEL,
          config: { responseModalities: ['AUDIO'] },
        },
      },
    });
  }

  if (!token?.name) {
    const err = new Error('Token service did not return a token name.');
    err.code = 'TOKEN_FAILED';
    throw err;
  }

  return {
    token: token.name, // value the client passes as ?access_token=
    model: LIVE_TRANSLATE_MODEL,
    expiresAt: expireTime,
    targetLanguageCode,
  };
}

/** Strip anything that looks like a key/token from a message before logging. */
function sanitize(message = '') {
  return String(message)
    .replace(/AIza[0-9A-Za-z\-_]+/g, '[redacted]')
    .replace(/AQ\.[0-9A-Za-z\-_.]+/g, '[redacted]');
}
