# Tilo Translate — Backend (token server)

Tiny Node.js service whose only job is to mint **short-lived Gemini Live API
tokens** so the mobile app never has to hold the Gemini API key.

## Requirements

- Node.js 20+ (tested on 24)
- A Gemini API key from Google AI Studio

## Setup

```bash
cd backend
cp .env.example .env        # Windows PowerShell: Copy-Item .env.example .env
npm install
npm run dev                 # auto-restart; use "npm start" for plain run
```

Then set `GEMINI_API_KEY` inside `.env`.

## Environment (`.env`)

| Variable                    | Required | Default | Purpose                                            |
| --------------------------- | -------- | ------- | -------------------------------------------------- |
| `GEMINI_API_KEY`            | yes      | —       | Server-side Gemini key. **Never** ships to mobile. |
| `PORT`                      | no       | `8787`  | Listen port.                                       |
| `CORS_ORIGIN`               | no       | `*`     | Comma-separated origins, or `*` for any (dev).     |
| `TOKEN_EXPIRE_MINUTES`      | no       | `30`    | Total token lifetime.                              |
| `TOKEN_NEW_SESSION_MINUTES` | no       | `2`     | Window to start a new Live session.                |
| `TOKEN_USES`                | no       | `1`     | Sessions a token may initiate.                     |

## Endpoints

### `GET /health`

```json
{ "ok": true }
```

### `POST /api/live-token`

Request:

```json
{ "sourceLanguageCode": "tr", "targetLanguageCode": "en", "direction": "A_TO_B" }
```

Response:

```json
{
  "token": "...",
  "model": "gemini-3.5-live-translate-preview",
  "expiresAt": "2026-06-15T12:00:00.000Z",
  "targetLanguageCode": "en"
}
```

The `token` is a Gemini **ephemeral token** (`token.name`). The mobile app passes
it as `?access_token=` when opening the Live WebSocket — see the root README.

## How the token is locked

We call `authTokens.create()` (SDK: `@google/genai`, API version `v1alpha`) and
lock these into the token via `liveConnectConstraints`:

- model `gemini-3.5-live-translate-preview`
- `responseModalities: ["AUDIO"]`
- `inputAudioTranscription: {}` / `outputAudioTranscription: {}`
- `translationConfig: { targetLanguageCode, echoTargetLanguage: false }`

Because the translate model + `translationConfig` are preview fields, if the
constraints validator rejects them the service falls back to a minimal lock
(model + audio) and the client supplies the full setup at connect time.

## Security notes

- API key lives only in `.env` (git-ignored). Never returned in responses.
- Tokens and keys are never logged (messages are sanitized).
- Per-IP rate limiting (30 req/min) on `/api`.
- CORS controlled by `CORS_ORIGIN`.

**Production TODO:** enforce HTTPS, add device/business auth (e.g. a PIN or device
key for hotel demos) before handing out tokens.
