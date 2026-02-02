# Anonymous Chat Mobile App (Unified v2 + v3)

This repository includes a **single production-ready mobile app generator** that merges:
- **v2 logic & navigation** (matching, chat, settings, socket, storage)
- **v3 UI/UX** (branding, Lottie animations, gradients, micro-interactions)

The result is created by the `finalize_mobile_app.sh` script.

## Quick Start

```bash
./finalize_mobile_app.sh
```

This will generate a new React Native CLI app named `AnonymousChatApp` in the repo root.

## Environment Configuration

The app uses **react-native-config** and reads values from `.env`:

```
API_URL=http://localhost:3000
TERMS_URL=https://example.com/terms
SOCKET_PING_INTERVAL=5000
SOCKET_BACKOFF_MAX_MS=15000
MAINTENANCE_MESSAGE=We are currently performing maintenance. Please check back soon.
```

You can copy `.env.example` to `.env` and update as needed.

## Asset Structure

The app scaffolds a clear `/assets` structure at the app root:

```
/assets
  /fonts
    PLACEHOLDER.txt
  /images
    placeholder.png
  /lottie
    placeholder.json
```

Replace placeholders with production assets as they become available.

## iOS Build Instructions

```bash
cd AnonymousChatApp
npm install
cd ios && pod install && cd ..

npm run ios
```

## Android Build Instructions

```bash
cd AnonymousChatApp
npm install

npm run android
```

## Notes for Mobile Team

- Socket service handles **Ping/Pong**, **exponential backoff**, and listens for **Maintenance Mode** signals.
- Chat rendering uses **FlashList** with optimized text/image bubbles (FastImage) and message delivery states.
- All URLs are centralized in `src/config/Config.ts` and sourced from `.env`.
- Fonts are linked via `react-native.config.js` once real font files are added.
