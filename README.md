# NewsTV

> A cross-platform live news streaming client built with Flutter — watch HLS streams from any device, on any screen.

**Platform:** Android · Web  
**Version:** 1.0.0  
**Stack:** Flutter 3 · Dart · media_kit · Provider · chewie

---

## What Is It?

NewsTV is a live TV aggregation client that ingests a list of news channel streams (loaded remotely with a local fallback) and plays them back via HLS. It's designed to work across screen types — phones, tablets, and web browsers — and supports keyboard, TV remote, and touch navigation without changing a line of configuration.

The primary engineering goals were a clean provider/repository separation, resilient channel loading, and a transparent debugging experience for web deployments where CORS adds complexity.

---

## Architecture

### Data Flow

```
[Remote channels.json]
        │
        ▼ (HTTP fetch)
[ChannelRepository] ──► fallback on failure ──► [Bundled channels.json]
        │
        ▼
[ChannelProvider]  (Provider state layer)
        │
        ▼
[PlayerScreen]  ──► media_kit / chewie playback engine
        │
        ▼
[User]
```

No live network calls are made at startup. The repository fetches the channel list asynchronously; if the remote fetch fails for any reason, the app falls back to the bundled `channels.json` silently — zero downtime.

---

### Provider / Repository Pattern

Startup logic is fully decoupled from the UI:

- `ChannelRepository` owns all data access — remote fetch, local fallback, JSON parsing.
- `ChannelProvider` holds UI state — current channel, playback status, loading flags.
- Screens are purely reactive; they never call network code directly.

This makes the entire data layer testable with mock repositories, without launching the app.

```bash
flutter test   # runs against mock channel data, no network needed
```

---

### Resilient Channel Loading

```dart
Future<List<Channel>> loadChannels() async {
  try {
    final response = await http.get(Uri.parse(remoteUrl));
    if (response.statusCode == 200) {
      return _parse(response.body);
    }
  } catch (_) {
    // silently fall through to bundled data
  }
  final bundled = await rootBundle.loadString('channels.json');
  return _parse(bundled);
}
```

The app always has channels. Network failure is not a crash condition.

---

### Multi-Platform Playback

NewsTV uses two playback engines in parallel — the right one is selected per platform:

| Platform | Engine | Why |
|---|---|---|
| Android | `media_kit` + `media_kit_video` | Full HLS support, hardware decode |
| Web | `video_player_web` + `chewie` | Browser-compatible, no native libs needed |

---

### Web Debugging & CORS Proxy

CORS is the primary obstacle for HLS streams in a browser. NewsTV ships with a built-in solution: a debug panel (visible in debug builds only) that exposes the raw stream URL, the active playback URL, and a **toggle to enable/disable a CORS proxy** — without restarting the app.

This makes diagnosing cross-origin failures fast:

```
Debug Panel
├── Raw channel URL
├── Active playback URL (with or without proxy prefix)
├── Stream source metadata
└── [Toggle] Web CORS proxy: ON / OFF
```

The debug panel is compiled out of production builds automatically.

---

### Navigation

Controls are designed for all input types simultaneously — no platform-specific code required:

| Input | Action |
|---|---|
| Swipe left / right | Previous / next channel |
| Double-tap | Toggle mute |
| Keyboard arrows | Channel navigation |
| TV remote D-pad | Full navigation support |
| On-screen buttons | Play/pause, mute, retry, guide |

---

### Engineering Commitments

| Decision | Why |
|---|---|
| Repository + Provider separation | Business logic is testable independently of Flutter's widget tree |
| Bundled `channels.json` fallback | The app always has content — network failure degrades gracefully |
| Dual playback engines (media_kit / chewie) | Best-in-class HLS support on each target platform |
| Debug panel in debug builds only | Diagnostic tooling ships with the code, not with the product |
| Shared preferences for last channel | Session state is persisted — users return to where they left off |

---

## Getting Started

### Run on Android

```bash
flutter pub get
flutter run
```

### Run on Web (Chrome)

```bash
flutter run -d chrome
```

Open the in-app **Debug** panel (debug builds only) to inspect the active stream URL and toggle the CORS proxy.

### Verify

```bash
flutter analyze
flutter test
flutter build web
```

---

## Dependencies

| Package | Purpose |
|---|---|
| `media_kit ^1.2.6` | Core media playback engine |
| `media_kit_video ^2.0.1` | Video rendering for native targets |
| `media_kit_libs_video ^1.0.7` | Native media libraries |
| `video_player ^2.11.1` | Flutter video player |
| `video_player_web ^2.4.0` | Web-compatible video playback |
| `chewie ^1.14.0` | Player UI controls wrapper |
| `provider ^6.1.5` | State management |
| `http ^1.6.0` | Remote channel list fetching |
| `shared_preferences ^2.5.5` | Last-channel persistence |

---

## Project Structure

```
lib/
├── main.dart
├── providers/
│   └── channel_provider.dart    # UI state: current channel, loading, errors
├── repositories/
│   └── channel_repository.dart  # Data access: remote fetch + local fallback
├── models/
│   └── channel.dart             # Channel domain model
└── screens/
    ├── player_screen.dart        # Main playback UI + controls
    └── guide_screen.dart         # Channel list / guide overlay
channels.json                     # Bundled fallback channel list
assets/
```

---

## License

MIT — see `LICENSE` for details.
