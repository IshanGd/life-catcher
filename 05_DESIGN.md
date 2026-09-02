# Smart Helmet — Design Spec

This spec is reverse-derived from the existing v0.1 clickable mockup
(`docs/mockups/dashboard_mockup.html`) and the companion progress-tracking
view (`docs/mockups/progress_map.html`), so Claude Code can rebuild these as
real, data-backed screens without guessing at the design intent. Treat the
mockup HTML as the visual source of truth for anything not written out
below — read it directly before implementing a screen.

## 1. Design system

### Color tokens (dark theme, from the mockup's CSS variables)

```css
--bg-app:      #0E1116
--bg-page:     #0A0C10
--surface:     #171B21
--surface-2:   #1E242C
--surface-3:   #252C36
--amber:       #FFB020   /* primary accent — warnings, key stats, eyebrow labels */
--amber-dim:   rgba(255,176,32,0.14)
--red:         #FF5C5C   /* alerts, critical severity, danger states */
--red-dim:     rgba(255,92,92,0.14)
--green:       #35C48C   /* success, "connected", "worn", improving trend */
--green-dim:   rgba(53,196,140,0.14)
--blue:        #4FA8FF   /* informational, secondary accent */
--blue-dim:    rgba(79,168,255,0.14)
--text-1:      #F2F4F7   /* primary text */
--text-2:      #98A1B0   /* secondary text */
--text-3:      #5C6472   /* faint/meta text */
--border:      #262C35
--border-soft: #1D222A
```

**Note for implementers coming from the earlier Flutter prototype:** this
palette (amber-led, dark) is the current source of truth and differs from
any earlier teal-accent theme built before this mockup existed. Rebuild the
Flutter theme file to match these tokens exactly rather than reconciling the
two — the mockup is newer and reflects the actual product direction (gig-
driver B2B2C, not the original hobbyist framing).

### Typography

- **Space Grotesk** (500/600/700) — headings, large numeric stats (safety
  score, dashboard counters). Distinctive, slightly technical feel.
- **Inter** (400/500/600/700) — body text, UI copy.
- **IBM Plex Mono** (400/500/600) — eyebrow labels, tags, device IDs,
  anything meant to read as "system/telemetry" rather than prose (e.g.
  "PROJECT REVIEW — V0.1 MOCKUP", status tags like "DESIGN"/"VALIDATED").

### Visual language

- Subtle radial gradient washes (amber top-left, blue bottom-right) over the
  page background — keeps the dark theme from feeling flat without
  introducing decoration that competes with data.
- Rounded surfaces throughout (14–20px radius), 1px borders in `--border`,
  no heavy drop shadows except on the phone frame itself.
- Status is always color + icon + text together, never color alone (accessibility
  — also matches this project's own "explicit alcohol-sensor framing" instinct:
  don't let a UI color imply more certainty than the underlying signal has).

## 2. Screen inventory — Companion App (driver-facing)

Built once as a shared design, shown on both iOS and Android chrome in the
mockup — implement as a single Flutter/cross-platform codebase, not two
native apps, per `02_ARCHITECTURE.md`.

Bottom navigation (4 tabs, matches mockup):

| Tab | Icon | Screen |
|---|---|---|
| Home | ⌂ | Dashboard — see below |
| Trends | 📈 | Risk/behavior trends over time |
| Alerts | 🔔 | Full alert history |
| Profile | ◍ | Driver profile + device health |

### 2.1 Home (dashboard)

Top to bottom, exactly as mocked:

1. **Greeting header:** "Good morning, {driver name}" + avatar initials +
   current shift state line, e.g. "Shift active · 2h 14m · {platform name}".
2. **Safety Score — Today:** large circular/ring stat, score out of 100,
   with a delta line ("▲ 5 pts vs. yesterday"). This is the single most
   prominent element on the screen.
3. **Status row (3 pills):** Helmet (Worn/Not worn), Pre-ride (Passed/
   Failed/Pending), BLE Link (Connected/Disconnected) — each an icon + label
   + state, color-coded per §1.
4. **Risk trend — 7 days:** compact trend indicator (score + "▲ improving"
   / "▼ declining") with a "Details" link through to the Trends tab.
5. **Recent events:** short list (3 items in the mock) of the most recent
   alerts, each with an icon, one-line description, timestamp, and location
   where relevant (e.g. "Harsh braking detected · 09:14 AM · MG Road").
   Includes cancelled/false-positive events shown honestly, not hidden
   (e.g. "Impact alert — cancelled by driver · false positive, pothole") —
   this transparency is intentional, don't design it away later.
6. **Fatigue watch:** continuous-shift-duration readout with a break
   suggestion countdown ("1h 50m continuous · Break suggested in 1h 10m").

### 2.2 Trends

1. **Weekly risk score:** 7-day (M–S) chart of safety score.
2. **Harsh events / 100km:** breakdown by type — harsh braking, harsh
   acceleration, cornering anomalies — each as a rate, not a raw count
   (normalizing by distance is intentional; don't regress to raw counts).
3. **Compliance — 7 days:** helmet wear rate (%) and pre-ride checks
   completed (fraction, e.g. "14/14").

### 2.3 Alerts

Full reverse-chronological list of every logged event, each row: icon
(⚠/✕/✓/🔵), label, and a relative-or-dated timestamp. Event types seen in
the mock, for reference: harsh braking, impact alert (incl. cancelled),
pre-ride check passed, firmware synced, fatigue nudge sent, panic-button
self-test. This list is the audit trail — every event type in
`02_ARCHITECTURE.md` §4's BLE contract should have a corresponding row
style here, including cancelled ones.

### 2.4 Profile

1. **Driver profile card:** name, avatar initials, platform (e.g. Rapido),
   vehicle type, device ID, pairing status, emergency contact status
   (Set ✓ / Not set).
2. **Device health card:** battery %, last sync (relative time), firmware
   version, alcohol sensor calibration age (relative time — surfacing
   calibration recency here is a deliberate trust signal, keep it even
   once this becomes a settings-heavy screen).

## 3. Screen inventory — Fleet-Ops Dashboard (not yet designed)

No mockup exists yet. When designing it, reuse the same design tokens
(§1) for visual consistency with the driver app, and structure around the
five metric families already defined in `01_REQUIREMENTS.md` §4.4: safety,
compliance, risk, fatigue, device health — aggregated per-fleet with
per-driver drill-down. Do not invent a different metric taxonomy; extend
this one if a gap is found, and update `01_REQUIREMENTS.md` in the same
change.

## 4. Component checklist (for implementation)

Mapping mockup elements to buildable components:

- [ ] `SafetyScoreRing` — circular 0–100 gauge with delta indicator
- [ ] `StatusPill` — icon + label + state, 3-across row
- [ ] `TrendSummary` — compact score + direction indicator + "Details" link
- [ ] `EventListItem` — icon + label + timestamp (+ optional location),
      must support a visually distinct "cancelled/false-positive" state
- [ ] `FatigueWatchCard` — duration readout + countdown-to-break-suggestion
- [ ] `WeeklyTrendChart` — 7-day line/bar chart
- [ ] `RateBreakdownList` — labeled rate rows (events per 100km)
- [ ] `ComplianceStatRow` — percentage/fraction stat pairs
- [ ] `DriverProfileCard`
- [ ] `DeviceHealthCard`
- [ ] `BottomNav` — 4-tab (Home/Trends/Alerts/Profile)

## 5. What NOT to change without checking with the human first

- The amber/dark palette — it's a deliberate, already-reviewed direction,
  not a placeholder.
- The inclusion of cancelled/false-positive events in the visible feed —
  removing them to make the product "look" more accurate would misrepresent
  real performance to drivers, fleets, and insurers alike.
- The 4-tab structure — it's been mocked and reviewed on both iOS and
  Android chrome; don't add a 5th tab without confirming it belongs there
  over nesting it inside an existing tab.
