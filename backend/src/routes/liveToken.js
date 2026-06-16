import { Router } from 'express';
import { isConfigured } from '../config.js';
import { createLiveToken } from '../services/geminiTokenService.js';

export const liveTokenRouter = Router();

const VALID_DIRECTIONS = new Set(['A_TO_B', 'B_TO_A']);
// Loose BCP-47 sanity check (e.g. tr, en, pt-BR, zh-Hans). Not exhaustive.
const LANG_RE = /^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})*$/;

/**
 * POST /api/live-token
 * Body: { sourceLanguageCode, targetLanguageCode, direction }
 * Returns a short-lived Gemini Live token locked to the target language.
 */
liveTokenRouter.post('/live-token', async (req, res, next) => {
  try {
    const { sourceLanguageCode, targetLanguageCode, direction } = req.body ?? {};

    if (!isConfigured()) {
      return res.status(503).json({
        error: {
          code: 'NOT_CONFIGURED',
          message: 'Server is missing its API key. Set GEMINI_API_KEY in backend/.env.',
        },
      });
    }

    const errors = [];
    if (!LANG_RE.test(String(sourceLanguageCode || ''))) errors.push('sourceLanguageCode');
    if (!LANG_RE.test(String(targetLanguageCode || ''))) errors.push('targetLanguageCode');
    if (!VALID_DIRECTIONS.has(direction)) errors.push('direction');
    if (sourceLanguageCode && targetLanguageCode && sourceLanguageCode === targetLanguageCode) {
      return res.status(400).json({
        error: { code: 'SAME_LANGUAGE', message: 'Source and target languages must differ.' },
      });
    }
    if (errors.length) {
      return res.status(400).json({
        error: { code: 'INVALID_BODY', message: `Invalid or missing fields: ${errors.join(', ')}` },
      });
    }

    const result = await createLiveToken({ targetLanguageCode });
    return res.json(result);
  } catch (err) {
    return next(err);
  }
});
