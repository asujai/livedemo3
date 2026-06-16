import rateLimit from 'express-rate-limit';

/**
 * Basic per-IP rate limiting for the token endpoint. Tokens cost money to mint,
 * so we keep this deliberately tight for the MVP.
 */
export const tokenRateLimit = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 30, // 30 token requests / minute / IP
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: { code: 'RATE_LIMITED', message: 'Too many requests. Please slow down.' } },
});
