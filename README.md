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

`mockups/` contains the original clickable HTML references
(`dashboard_mockup.html`, `progress_map.html`) that `05_DESIGN.md` and
`04_PHASES.md` are derived from — open them directly for anything not
fully captured in writing.

`ml/` holds the crash-detection pipeline — see `ml/README.md`. It runs
end-to-end on synthetic data today; Phase 1 (real data) is in progress.

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
run in parallel, doesn't block hardware work). Don't start building the
Fleet-Ops Dashboard (Phase 5 — spec exists in `05_DESIGN.md` §3, but it's
not built) or polish the companion app UI beyond what's already mocked
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
