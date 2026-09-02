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
   spec derived from the existing mockup, component checklist.

`mockups/` contains the original clickable HTML references
(`dashboard_mockup.html`, `progress_map.html`) that `05_DESIGN.md` and
`04_PHASES.md` are derived from — open them directly for anything not
fully captured in writing.

## Source material

These docs synthesize (and should be kept consistent with):
- Project overview and feature-categorization docs (market research, BOM,
  competitive landscape)
- The existing ML pipeline (`generate_synthetic_data.py`, `features.py`,
  `train_model.py`, and its own `README.md`) — kept in `ml/` once this repo
  is assembled per `02_ARCHITECTURE.md`'s layout
- The dashboard and progress-map HTML mockups in `mockups/`

## If you're an agent starting fresh here

Start at Phase 1 in `04_PHASES.md` (real crash-detection data) or Phase 2
(physical prototype) — those are the critical path. Don't start on the
fleet dashboard (Phase 5) or polish the companion app UI beyond what's
already mocked until those land. See `04_PHASES.md` §"Sequencing notes" for
the full reasoning.
