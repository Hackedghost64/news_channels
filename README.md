# News TV

Flutter live news TV app with remote-friendly navigation, improved playback controls, and a safer web debugging flow.

## What changed

- Better navigation for keyboard, TV remotes, and touch.
- Player controls for play/pause, mute, retry, previous/next channel, and guide access.
- Swipe and double-tap gestures to switch channels.
- Remote channel loading with automatic fallback to bundled `channels.json`.
- Debug panel in debug builds with raw URL, playback URL, source info, and a web proxy toggle for Chrome troubleshooting.
- Testable provider/repository structure instead of hard-wiring live network calls into startup.

## Run

```bash
flutter pub get
flutter run
```

For Chrome debugging:

```bash
flutter run -d chrome
```

Open the in-app `Debug` panel in debug mode to inspect the active stream URL and switch the web CORS proxy on or off.

## Verification

```bash
flutter analyze
flutter test
flutter build web
```
