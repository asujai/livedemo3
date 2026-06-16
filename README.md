# Tilo Translate

Two-way **live speech translation** app for places that need fast communication
with foreign customers — hotels, receptions, restaurants, shops, clinics.

Staff picks two languages and holds one of two big push-to-talk buttons:

- **Button A**: staff speaks → guest hears the translation.
- **Button B**: guest speaks → staff hears the translation.

Direction is decided **only** by which button is held (no automatic detection).

> **Build status — Fully Functional Live Translate.** The app connects to a secure
> token server, requests short-lived ephemeral tokens, and opens a direct
> bi-directional Gemini Live WebSocket using the device's microphone for real-time
> translation and audio playback.


## Architecture

```
Flutter mobile app  ──POST /api/live-token──►  Node.js backend  ──►  Gemini API
   (no API key)      ◄──── short-lived token ───   (.env key)

Later stage:
Flutter app ──wss .../BidiGenerateContentConstrained?access_token=<token>──► Gemini Live
```

- The **Gemini API key lives only in the backend `.env`** and never reaches the app.
- The app asks the backend for a **short-lived ephemeral token** per direction.
- That token (not the key) is later used to open the Gemini Live WebSocket.

## Repository layout

```
.
├── backend/                 # Node.js token server (see backend/README.md)
└── lib/                     # Flutter app
    ├── main.dart / app.dart
    ├── core/                # config, language list, errors
    └── features/translator/
        ├── data/            # token API + settings/conversation storage (live); WS/audio (stubs)
        ├── domain/          # language, message, direction, session, settings, flow-state
        └── presentation/    # controller, screen, settings, picker, PTT button, bubbles, status
```

## 1) Backend setup

```bash
cd backend
cp .env.example .env        # PowerShell: Copy-Item .env.example .env
npm install
npm run dev
```

Put your Gemini key in `backend/.env`:

```
GEMINI_API_KEY=your_key_here
PORT=8787
```

Verify:

```bash
curl http://localhost:8787/health        # -> {"ok":true}
```

See **[backend/README.md](backend/README.md)** for endpoint details.

## 2) Flutter setup

Flutter isn't pre-generated with native folders in this skeleton. First time:

```bash
flutter create .            # generates android/ ios/ etc. WITHOUT touching lib/
flutter pub get
flutter run --dart-define=TOKEN_SERVER_URL=http://10.0.2.2:8787
```

### Token server URL

The app reads the backend URL from a build-time define (and, later, the Settings
screen). See `lib/core/config/app_config.dart`.

| Where you run        | TOKEN_SERVER_URL                          | Why                                            |
| -------------------- | ----------------------------------------- | ---------------------------------------------- |
| **Android emulator** | `http://10.0.2.2:8787`                    | `10.0.2.2` is the emulator's alias for your PC |
| **Physical device**  | `http://<your-PC-LAN-IP>:8787`            | Phone and PC must be on the same Wi-Fi         |
| **Production**       | `https://your-backend.example.com`        | HTTPS required                                 |

Find your LAN IP on Windows: `ipconfig` → IPv4 Address (e.g. `192.168.1.20`),
then:

```bash
flutter run --dart-define=TOKEN_SERVER_URL=http://192.168.1.20:8787
```

## Where to put the API key

Only in **`backend/.env`** as `GEMINI_API_KEY`. It is git-ignored and never sent
to the app. Do **not** put any key in the Flutter project.

## Tests

```bash
flutter test                 # includes the LiveTokenApi client test
```

(Backend is exercised via `curl` against `/health` and `/api/live-token`.)

## Proje Durumu ve Riskler

Uygulama; gerçek WebSocket bağlantısı, cihaz mikrofonundan PCM ses kaydı ve PCM ses oynatma (playback) entegrasyonuna sahip tam işlevsel bir Canlı Çeviri uygulamasıdır. 
Kalan potansiyel riskler ve dikkat edilmesi gerekenler:
- **Token Constraints**: Gemini Live Translate için hedef dil kısıtlaması token üzerinde kilitlenmektedir. Fallback (geri çekilme) mekanizması güvenlik ve doğru çeviri amacıyla kaldırılmıştır; API kısıtlamalarının sunucu tarafından tam olarak kabul edilmesi zorunludur.
- **Ağ ve İzinler**: Fiziksel cihaz ile test yapılırken lokal LAN bağlantısı için gereken izinlerin verilmiş olması ve bilgisayarın LAN IP adresinin doğru yapılandırılması gereklidir.

## Çalıştırma Komutları

### 1) Android Emülatör
Emülatörün bilgisayarınızdaki backend servisine (localhost:8787) erişebilmesi için `10.0.2.2` IP'sini kullanın:
```bash
flutter run --dart-define=TOKEN_SERVER_URL=http://10.0.2.2:8787
```

### 2) Fiziksel Android Cihaz (Debug/Geliştirme)
Aynı Wi-Fi ağına bağlıyken bilgisayarınızın yerel LAN IP'sini (örn: `192.168.1.17`) kullanın:
```bash
flutter run -d <CIHAZ_ID> --dart-define=TOKEN_SERVER_URL=http://192.168.1.17:8787
```
*(Not: AndroidManifest.xml içerisinde cleartext izinleri debug ortamı için aktif edilmiştir.)*

### 3) Production (Canlı Dağıtım)
Canlı ortamda backend sunucunuzun güvenli HTTPS protokolüne sahip olması zorunludur:
```bash
flutter run --release --dart-define=TOKEN_SERVER_URL=https://api.yourdomain.com
```
