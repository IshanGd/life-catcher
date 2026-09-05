# Smart Helmet — companion app (Phase 4)

Driver-facing Flutter app, built against the screen spec in
[`../05_DESIGN.md`](../05_DESIGN.md). No mockup existed anywhere in this
repo when Phase 4 started (checked — `mockups/`/`app/` had never been
committed), so this **is** that first UI pass: real Flutter code from the
start, backed by sample data through the same seam a real BLE backend will
use later, rather than a throwaway HTML prototype.

## Layout

```
app/
├── lib/
│   ├── main.dart
│   ├── theme/          # colors.dart, typography.dart, app_theme.dart -- 05_DESIGN.md §1 tokens
│   ├── models/         # HelmetStatus, DriverEvent, TrendPoint, DriverProfile, DeviceHealth,
│   │                   # SosEvent, SosDispatch, GeoLocation
│   ├── logic/          # framework-agnostic, host-tested pure Dart (mirrors firmware/src/core/):
│   │                   # RideBehaviorScorer, FatigueNudgeEngine, SosRelay
│   ├── services/       # HelmetDataService (the seam) + MockHelmetDataService (sample data);
│   │                   # LocationProvider, SosTransport (the SOS relay's hardware seams)
│   ├── widgets/         # the component checklist from 05_DESIGN.md §4, plus SosDispatchBanner
│   └── screens/        # Home, Trends, Alerts, Profile + RootShell (bottom nav, owns SosRelay)
└── test/
```

`HelmetDataService` (`lib/services/helmet_data_service.dart`) is the single
seam per `02_ARCHITECTURE.md` §5: every screen consumes it, never a
concrete data source directly. The remaining Phase 4 work is writing a
`BleHelmetDataService` implementation of the same interface — no screen
file should need to change when that lands.

## Build / run

```bash
flutter pub get
flutter analyze
flutter test
```

**Web preview, debug mode (`flutter run -d web-server`) is currently
broken in this Flutter version** (3.47.2): the browser requests
`main.dart.js` and gets back `index.html` with a `text/html` MIME type,
which Chrome's strict MIME checking refuses to execute
(`Refused to execute script ... MIME type ('text/html')`). Don't spend time
re-debugging this — build for release and serve the static output instead:

```bash
flutter build web
python -m http.server 5960 --directory build/web
```

`.claude/launch.json` at the repo root has a `smart-helmet-app-web` config
that does exactly this (serves `build/web` on port 5960) — run
`flutter build web` first, then `preview_start` with that config name.
Re-run `flutter build web` after any code change; the static server won't
pick up edits on its own.

## What's real vs. sample

Every screen is real, data-driven Flutter code. What's behind it:

| Data | Source |
|---|---|
| Screen layout, components, theming | Real — matches `05_DESIGN.md` §1/§2 |
| Safety score, weekly trend, Trends-tab harsh-event breakdown | **Real computation** — `lib/logic/ride_behavior_scorer.dart`, fed by sample per-day harsh-event rates (`MockHelmetDataService._weeklyRideInputs`). Weights are PROVISIONAL, not fitted to real fleet data. |
| Fatigue watch card, "break suggested in" countdown, fatigue-nudge Alerts entries | **Real computation** — `lib/logic/fatigue_nudge_engine.dart`, fed by a simulated continuous-riding clock. Threshold (3h) is PROVISIONAL. |
| `HelmetStatus`'s remaining fields (helmet worn, pre-ride, BLE link, battery) | `MockHelmetDataService` — sample values |
| Alert history (aside from live fatigue nudges + SOS outcomes), compliance, profile, device health | `MockHelmetDataService` — static sample data |
| SOS relay dispatch logic (locating → data+SMS channels → sent/failed), the live status banner, logging the outcome to Alerts | **Real** — `lib/logic/sos_relay.dart` + `lib/widgets/sos_dispatch_banner.dart`, wired in `RootShell` |
| The SOS *trigger* itself, GPS fixes, SMS/data sending | Simulated — `MockHelmetDataService.triggerTestSos()` (Profile screen's "Self-test" section), `MockLocationProvider`, `MockSosTransport` |

`RideBehaviorScorer`, `FatigueNudgeEngine`, and `SosRelay` are all
framework-agnostic pure Dart (no Flutter imports) so they're unit-tested
directly (`test/ride_behavior_scorer_test.dart`,
`test/fatigue_nudge_engine_test.dart`, `test/sos_relay_test.dart`) and can
be re-tuned or fed real telemetry/hardware later without touching a screen.

None of this is wired to the Phase 2 firmware's real BLE contract yet —
that requires the physical hardware bring-up (`firmware/docs/WIRING.md`)
to exist first, per `04_PHASES.md` Phase 4. The SOS relay's own logic
(`SosRelay`) doesn't change when that lands — only
`watchConfirmedSosEvents()`'s implementation, and `LocationProvider` /
`SosTransport` on a real mobile build (`geolocator` for GPS; a native SMS
plugin or backend gateway for data/SMS — neither is buildable from this
web-only environment).
