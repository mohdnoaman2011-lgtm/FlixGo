# FlixGo
Flutter app + small Node server for downloading videos/audio via yt-dlp.

## Server
Requires Node 18+, yt-dlp, ffmpeg.

    cd server && npm start

Env vars: PORT, PUBLIC_URL, FILES_DIR, MAX_JOBS, YTDLP_BIN, ALLOWED_HOSTS.

## App
    flutter pub get
    flutter run --dart-define=FLIXGO_API_BASE_URL=https://your-api.example.com

Android emulator default: http://10.0.2.2:8787 (needs cleartext enabled for debug builds).