# Pulse Frontend

Flutter frontend for Pulse.

## Main screens

- landing dashboard
- real-time news
- fear and greed
- market page

## Run

```powershell
flutter pub get
flutter run -d chrome
```

Run with explicit production API:

```powershell
flutter run -d chrome --dart-define=PULSE_API_BASE_URL=https://news-summarizer.bum2432.workers.dev
```

## Release builds

App Bundle:

```powershell
flutter build appbundle --release --dart-define=PULSE_API_BASE_URL=https://news-summarizer.bum2432.workers.dev
```

APK:

```powershell
flutter build apk --release --dart-define=PULSE_API_BASE_URL=https://news-summarizer.bum2432.workers.dev
```

## Important files

- `lib/main.dart`: app entry
- `lib/screens/landing_screen.dart`: landing dashboard
- `lib/screens/home_screen.dart`: real-time news
- `lib/screens/fear_greed_page.dart`: fear and greed
- `lib/screens/market_page.dart`: market page
- `lib/services/api_service.dart`: API client

## Notes

- API base URL can be injected via `PULSE_API_BASE_URL`.
- Thumbnails use the shared `NetworkThumbnail` widget.
- Mobile root back behavior is handled separately on the landing screen.
