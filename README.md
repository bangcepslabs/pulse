# Pulse

Pulse is an AI-powered news dashboard focused on real-time news, market signals, fear-and-greed data, and trend discovery.

## Repository layout

- `frontend/`: Flutter app and web frontend
- `cloudflare-worker/`: production API, news ingestion, market data, trend aggregation
- `docs/`: public GitHub Pages documents
- `backend/`: legacy Python/FastAPI experimental backend

## Production architecture

Current production backend entrypoint:

- `cloudflare-worker/src/index_naver.js`

Main product areas:

- main dashboard
- real-time news
- AI briefing
- breaking news timeline
- market overview and FX
- popular movers
- fear and greed pages
- market data APIs

## Repository

- GitHub: `https://github.com/bangcepslabs/pulse`

## Public documents

GitHub Pages documents live in `docs/`.

- index: `docs/index.html`
- privacy policy: `docs/privacy.html`

Expected GitHub Pages URLs:

- `https://bangcepslabs.github.io/pulse/`
- `https://bangcepslabs.github.io/pulse/privacy.html`

## Run frontend locally

```powershell
cd frontend
flutter pub get
flutter run -d chrome
```

Override API base URL:

```powershell
flutter run -d chrome --dart-define=PULSE_API_BASE_URL=https://news-summarizer.bum2432.workers.dev
```

## Android release build

App Bundle:

```powershell
cd frontend
flutter build appbundle --release --dart-define=PULSE_API_BASE_URL=https://news-summarizer.bum2432.workers.dev
```

APK:

```powershell
cd frontend
flutter build apk --release --dart-define=PULSE_API_BASE_URL=https://news-summarizer.bum2432.workers.dev
```

Outputs:

- `frontend/build/app/outputs/bundle/release/app-release.aab`
- `frontend/build/app/outputs/flutter-apk/app-release.apk`

## Cloudflare Worker deploy

```powershell
cd cloudflare-worker
npm install
wrangler deploy
```

Required secrets and vars typically include:

- `GROQ_API_KEY`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `NAVER_CLIENT_ID`
- `NAVER_CLIENT_SECRET`
- `SCHEDULER_SECRET`

## Main API base

- `https://news-summarizer.bum2432.workers.dev`

Representative endpoints:

- `GET /api/trends`
- `GET /api/trends/keywords`
- `GET /api/trends/rising`
- `GET /api/trends/sentiment`
- `GET /api/trend/timeline`
- `GET /api/news/search`
- `GET /api/news/by-keyword`
- `GET /api/market-data`
- `GET /api/chart-data`
- `GET /api/fear-greed/stock`
- `GET /api/fear-greed/crypto`

## Notes

- The frontend supports API base URL injection through `String.fromEnvironment`.
- Thumbnails are normalized to `https` only and rendered through a shared fallback widget.
- Public GET APIs in the worker include lightweight rate limiting.
- On mobile, the landing screen uses a double-back-to-exit pattern.

## Release checklist

Before store release, verify:

- Android signing config
- `versionCode` and `versionName`
- GitHub Pages privacy URL is public
- dark mode, back navigation, external links, and thumbnail fallback on a real device

## Legacy note

`backend/` is not the current production path. It is kept as a legacy or experimental implementation.
