# Smart Helmet — Design Spec

This spec was originally written as reverse-derived from a v0.1 clickable
mockup (`docs/mockups/dashboard_mockup.html`, `docs/mockups/progress_map.html`).
**Correction (2026-09): that mockup does not exist in this repository** —
checked via `git log` across all history, nothing at `docs/mockups/` or
`mockups/` was ever committed. Do not try to "read it directly"; this
written spec (plus `app/` for the driver screens, built directly from it)
is the actual source of truth going forward.

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

## 3. Screen inventory — Fleet-Ops Dashboard

No clickable mockup exists yet (unlike the driver app), but this dashboard
now has a full spec below — build against this rather than free-designing.
Reuse the design tokens in §1 for visual consistency with the driver app,
but this is a **web dashboard**, not a phone screen: wider layouts, tables,
and filters are appropriate here in a way they aren't in the driver app.

This is not one screen — it's three role-scoped views over one dataset,
matching the access model in `02_ARCHITECTURE.md` §7 and the personas in
`01_REQUIREMENTS.md` §3. Do not build a single undifferentiated admin view;
a user's login determines which of the three below they land on.

### 3.1 Fleet Ops Manager view

**Overview screen (landing page for this role):**
1. **Fleet summary strip** — four-across stat cards, one per metric family
   from `01_REQUIREMENTS.md` §4.4: aggregate safety score (fleet average +
   trend arrow), compliance rate (helmet-wear % + pre-ride-checks-completed
   %), risk (harsh-events per 100km, fleet-wide), device health (% of
   fleet with a healthy battery/recent sync). Same visual language as the
   driver app's stat tiles — color-coded, icon + number + label — so
   someone who has also seen the driver app recognizes the pattern.
2. **Driver table** — sortable/filterable list of every driver in the
   fleet: name, current safety score, trend, helmet-wear rate, last sync,
   battery, and a flag icon for anything needing attention (declining
   score, failed pre-ride check, low battery, stale sync). This is the
   "which drivers/regions need intervention" surface — sorting by score
   ascending or by "flagged" should be the default/most obvious action.
3. **Fleet trend chart** — same 7-day-style trend as the driver app's
   Trends tab, but averaged across the fleet, with the option to overlay
   a specific driver's line for comparison.

**Driver drill-down screen** (reached by clicking a row in the driver
table):
- Renders **the same components as the driver's own Home/Trends/Alerts
  screens** (§2.1–2.3) — safety score ring, status pills, recent events
  including cancelled/false-positives, weekly trend, harsh-event
  breakdown. This is a deliberate design choice: a fleet manager having a
  coaching conversation should be looking at numbers the driver themselves
  recognizes from their own app, not a differently-computed summary.
- One addition not in the driver app: a **manager note/action log** — a
  simple text log a manager can append to (e.g. "spoke with driver
  8/14, discussed harsh braking on MG Road route"). This is intentionally
  a coaching-log field, not a disciplinary/status field — see
  `06_GOVERNANCE.md` for why that distinction matters and must be
  preserved in the UI copy, not just internal policy.

### 3.2 Insurer Claims Processor view

A narrower, purpose-built screen — not a cut-down version of the fleet
manager's view:

1. **Incident lookup** — search/filter by device ID, date range, or driver
   ID (whatever identifier the insurer's claim references).
2. **Incident detail card**, for one confirmed (non-cancelled) crash event
   only:
   - Timestamp, GPS coordinates (map pin), severity score
   - **Sensor fusion trail** — which sensors confirmed the event (e.g.
     "MPU6050 + piezo," per ADR-4) — this is the credibility feature that
     differentiates this from a self-reported claim
   - SOS status: sent / cancelled, and if cancelled, by whom and how
     quickly
   - An explicit "Export for claim #___" action producing a shareable
     record
3. **No safety score, no event history beyond the single incident, no
   other drivers' data** — enforced at the API layer per
   `02_ARCHITECTURE.md` §7, not just left off this screen's design.

### 3.3 Customer Support view

The narrowest view, and the simplest to design:

1. **Device lookup** — search by device ID or paired driver.
2. **Device health card** — reuses the exact `DeviceHealthCard` component
   from the driver app's Profile tab (§2.4): battery, last sync, firmware
   version, alcohol sensor calibration age.
3. Nothing else on this screen. No score, no events, no location history —
   support doesn't need it to do their job, and the access model in
   `02_ARCHITECTURE.md` §7 should make it structurally impossible for this
   view to request it.

### 3.4 Shared elements across all three views

- Use the same color tokens (§1) and typography as the driver app.
- Every view needs a persistent "logged in as: [role] · [fleet/insurer
  name]" indicator — given three different personas share infrastructure,
  it should never be ambiguous which scope a user is currently in.
- None of these three views should be extensible into a fourth "sees
  everything" role. If a new persona is identified later, it gets its own
  row in the access-model table (`02_ARCHITECTURE.md` §7) and its own
  scoped view — not elevated permissions on an existing one.

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
- [ ] `DeviceHealthCard` — shared between driver app Profile tab and Fleet-Ops support view
- [ ] `BottomNav` — 4-tab (Home/Trends/Alerts/Profile), driver app only

**Fleet-Ops Dashboard additions:**
- [ ] `FleetSummaryStrip` — 4-across aggregate stat cards
- [ ] `DriverTable` — sortable/filterable, with flag indicators
- [ ] `FleetTrendChart` — fleet-average trend with optional per-driver overlay
- [ ] `DriverDrillDown` — composes the driver-app components (§3.1) plus a `ManagerNoteLog`
- [ ] `IncidentLookup` + `IncidentDetailCard` — insurer claims view, includes a `SensorFusionTrail` display
- [ ] `DeviceLookup` — support view entry point
- [ ] `RoleScopeIndicator` — persistent "logged in as" banner across all three Fleet-Ops views

## 5. What NOT to change without checking with the human first

- The amber/dark palette — it's a deliberate, already-reviewed direction,
  not a placeholder.
- The inclusion of cancelled/false-positive events in the visible feed —
  removing them to make the product "look" more accurate would misrepresent
  real performance to drivers, fleets, and insurers alike.
- The 4-tab structure — it's been mocked and reviewed on both iOS and
  Android chrome; don't add a 5th tab without confirming it belongs there
  over nesting it inside an existing tab.
- The three-way split of the Fleet-Ops Dashboard (§3) — don't collapse it
  into a single admin view "for simplicity." The split exists because the
  three personas have genuinely different access needs (see
  `02_ARCHITECTURE.md` §7), not because of a UI preference.
- The `ManagerNoteLog` framing as a coaching log, not a disciplinary/status
  field — this is a governance-driven wording choice (`06_GOVERNANCE.md`),
  not a copy-editing detail.
