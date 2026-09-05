# Smart Helmet — Project Docs

Spec set for Claude Code (or any agent/dev) to start building against. Read
in this order:

1. **[01_REQUIREMENTS.md](01_REQUIREMENTS.md)** — what the product must do,
   for whom, and why. Non-functional requirements, success metrics, open
   risks.
2. **[02_ARCHITECTURE.md](02_ARCHITECTURE.md)** — system design, locked
   architecture decisions (ADRs) and the reasoning behind them, repo layout,
   BLE data contract.
3. **[03_RULES.md](03_RULES.md)** — guardrails for an AI coding agent
   working in this repo: what needs human sign-off, safety-critical
   engineering rules, definition of done.
4. **[04_PHASES.md](04_PHASES.md)** — current status per component, the
   critical path, and the phase-by-phase build plan with exit criteria.
5. **[05_DESIGN.md](05_DESIGN.md)** — design tokens, screen-by-screen UI
   spec for both the driver companion app (derived from the existing
   mockup) and the Fleet-Ops Dashboard (three role-scoped views: fleet ops
   manager, insurer claims processor, customer support), component
   checklist.
6. **[06_GOVERNANCE.md](06_GOVERNANCE.md)** — data-use and consent policy:
   coaching-vs-disciplinary use of driver data, alcohol-sensor data
   handling, consent requirements for the ML retraining flywheel and any
   third-party data sharing. Must be resolved with the first pilot partner
   before that pilot's contract is signed.

**Note (2026-09):** `05_DESIGN.md` and `04_PHASES.md` both refer to a
`mockups/` folder (`dashboard_mockup.html`, `progress_map.html`) as the
visual source of truth for the driver app. That folder has never existed
in this repository — checked via `git log` across all history. Treat
`05_DESIGN.md`'s written spec as the actual source of truth; `app/` (below)
is the first real implementation of it, built directly rather than from a
mockup that doesn't exist here.

`ml/` holds the crash-detection pipeline — see `ml/README.md`. It runs
end-to-end on synthetic and real (DAMOTO) data; Phase 1's exit criterion is
met (with caveats — see `ml/README.md` §Results).

`firmware/` holds the ESP32 prototype firmware — see `firmware/README.md`.
The safety-critical core (SOS state machine, fusion gate, BLE schema,
Phase 3 alcohol pre-ride check) is written and host-unit-tested, and
compiles clean for the real ESP32 target too; Phase 2 physical bring-up is
still pending — no hardware assembled yet.

`app/` holds the driver companion app (Flutter, Phase 4) — see
`app/README.md`. The four screens in `05_DESIGN.md` §2 are built and
running against sample data through a `HelmetDataService` seam; wiring
that seam to the real BLE pipeline is blocked on the Phase 2 hardware
bring-up above.

## Source material

These docs synthesize (and should be kept consistent with):
- Project overview and feature-categorization docs (market research, BOM,
  competitive landscape)
- The crash-detection ML pipeline, now in `ml/` per `02_ARCHITECTURE.md`'s
  layout (`generate_synthetic_data.py`, `features.py`, `train_model.py`,
  `schema.py`, `loaders/`, `tests/`, and its own `README.md`)
- The dashboard and progress-map HTML mockups in `mockups/`

## If you're an agent starting fresh here

Start at Phase 1 in `04_PHASES.md` (real crash-detection data) or Phase 2
(physical prototype) — those are the critical path, alongside drafting the
governance policy in `06_GOVERNANCE.md` with the first pilot partner (can
run in parallel, doesn't block hardware work). Phase 4's UI shell (`app/`)
already exists against sample data; don't start building the Fleet-Ops
Dashboard (Phase 5 — spec exists in `05_DESIGN.md` §3, but it's not built)
until Phases 1–2 land, and don't let any Fleet-Ops feature that exposes a
driver's score go live before `06_GOVERNANCE.md` §2 is resolved. See
`04_PHASES.md` §"Sequencing notes" for the full reasoning.

## Two dashboards, four personas, never a fifth

Worth internalizing before touching any UI code: this product has exactly
two dashboards (the driver's companion app, and the Fleet-Ops Dashboard)
serving exactly four personas (driver, fleet ops manager, insurer claims
processor, customer support) — see `01_REQUIREMENTS.md` §3. Passengers are
not a user of anything here; that's a different product built on different
data. Don't add a fifth persona or collapse the three Fleet-Ops views into
one "admin" login without updating the access model in
`02_ARCHITECTURE.md` §7 first.
