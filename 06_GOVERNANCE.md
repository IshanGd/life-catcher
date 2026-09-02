# Smart Helmet — Data Governance & Consent

This document exists because this product collects data that can affect a
driver's livelihood (safety scores, alcohol-screen results, location
history) and sits at the center of a B2B2C sale — the buyer (a platform,
fleet, or insurer) is not the person the data is about (the driver). That
asymmetry is exactly where trust breaks if it isn't handled deliberately.
Nothing in this file is built or shipped yet — it's a policy spec to
resolve **before** the first pilot contract is signed (see `04_PHASES.md`
critical path item #5), not a retrospective compliance checklist.

## 1. The core tension, stated plainly

The entire go-to-market strategy (`01_REQUIREMENTS.md` §4.5) leans on a
driver-welfare narrative — this product exists because platforms are under
pressure to visibly invest in driver safety. If a driver's first real-world
experience of this product is disciplinary (a bad safety score used against
them, an alcohol-sensor flag reported without their knowledge, a
coaching-log entry that turns into a deactivation), the welfare narrative
inverts into a surveillance narrative. That's not just an ethical problem —
it's the fastest way to kill the exact B2B2C pitch this project depends on.
Every rule below traces back to keeping that inversion from happening.

## 2. Coaching tool, not a disciplinary tool [OPEN — must be co-designed with first pilot partner]

**Default position, pending pilot partner agreement:** a driver's safety
score, event history, and pre-ride check results may be used by a fleet
ops manager for **coaching only** — visibility, conversation, and support —
not as an automated or semi-automated input to deactivation, pay reduction,
or disciplinary action, unless a separate, explicit, written policy says
otherwise and the driver has been told that policy exists.

This is why `05_DESIGN.md` §3.1 specifies a **`ManagerNoteLog`** (a coaching
note a manager can append) rather than a status/flag field a system could
later interpret as a disciplinary trigger — the distinction needs to be
structural in the product, not just written in a policy document that
nobody reads.

**What must happen before this can be finalized:** this is explicitly a
question to resolve *with* the first pilot partner, not one this project
can answer unilaterally — the partner's own HR/ops policies and any
platform-driver contractual terms are part of the answer. Do not let "we'll
figure it out during the pilot" stand in for a resolved answer; put it in
the pilot contract.

## 3. Alcohol-sensor data — framing and handling

Carried forward from `01_REQUIREMENTS.md` §5 and `02_ARCHITECTURE.md`
ADR-5, restated here because it's a governance rule as much as a technical
one:

- The MQ-3 reading is an ethanol-vapor screen, never described as a legal
  breathalyzer or BAC measurement, in any user-facing string, report, or
  pitch material.
- On a threshold exceedance, the event is flagged to the driver's own app
  **with the driver's knowledge** — never silently reported to a
  platform/fleet backend without the driver seeing the same flag at the
  same time.
- The helmet must never cut, gate, or delay vehicle ignition, under any
  circumstance (`03_RULES.md` §1) — this keeps the hardware out of
  vehicle-control liability entirely and is non-negotiable.
- If a platform integration reports this event to a backend for a
  human/policy decision (e.g. temporarily blocking "go online" status),
  that reporting must be disclosed to the driver as part of their consent
  (§5), not discovered after the fact.

## 4. The continuous data flywheel — consent requirement

`02_ARCHITECTURE.md` ADR-6 establishes that every SOS confirm/cancel
interaction is captured and fed back into ML retraining. This is a
**second, separate consent** from the core safety-feature consent a driver
gives to use the product at all:

- A driver must be told, in plain language, that their confirm/cancel
  interactions (and the sensor data around them) are used to improve the
  crash-detection model over time.
- This should be opt-in where feasible, or at minimum a clearly disclosed
  condition of use — not bundled silently into a generic terms-of-service
  acceptance.
- Do not wire the flywheel pipeline live in production before this consent
  flow exists (`02_ARCHITECTURE.md` ADR-6, `03_RULES.md` §1).

## 5. Third-party data sharing — a separate consent path per consumer

Every new consumer of driver data beyond the driver's own app needs its own
row in the access-model table (`02_ARCHITECTURE.md` §7) **and** its own
consent basis:

| Consumer | Data shared | Consent basis needed |
|---|---|---|
| Fleet ops manager (own fleet) | Aggregate + per-driver drill-down | Covered by employment/contractor relationship + platform's own driver terms — confirm with pilot partner's legal counsel, don't assume |
| Insurer claims processor | Single confirmed incident, on a specific claim | Covered by the insurance policy/claims process — scoped to the specific incident only, not standing access to a driver's full history |
| Customer support | Device health only | Covered by product support terms — narrowest scope, lowest sensitivity |
| **Future: hazard-mapping product** (`01_REQUIREMENTS.md` §4.5) | Aggregated, location-tagged event data to a municipality/planner/other insurer | **Not yet covered by anything.** This is location-derived behavioral data going to a party the driver has no direct relationship with. Requires its own explicit disclosure and likely a separate opt-in before this product is built — do not treat existing consent as covering it. |

## 6. Regulatory baseline

- Treat India's Digital Personal Data Protection Act (DPDP Act, 2023) as
  the compliance floor for anything collected here — consent, purpose
  limitation, and data minimization principles apply directly to location
  and biometric-adjacent (alcohol-screen) data. This needs a proper legal
  review before pilot launch, not just this document — flag this
  explicitly to the human rather than treating this file as sufficient
  compliance work.
- Confirm early whether retrofitting electronics onto a BIS/ISI-certified
  helmet shell (India's mandatory helmet certification) requires
  re-certification of the combined unit. This is a manufacturing/compliance
  timeline item if so, not a footnote — raise it during Phase 2 (physical
  prototype), not after.

## 7. What Claude Code must do with this file

- Do not build or wire live any feature listed as requiring consent above
  until the corresponding consent flow exists. Flag the gap and stop,
  rather than shipping the feature with a "TODO: add consent" comment.
- Do not treat this document as legal sign-off. It's a policy spec for
  engineering and product decisions — actual legal review (DPDP Act
  compliance, BIS/ISI certification, platform-specific contractual terms)
  is a separate, human-owned workstream this file should point to, not
  substitute for.
- Keep §2's "coaching not disciplinary" default in mind whenever building
  anything under `01_REQUIREMENTS.md` §4.4 or `05_DESIGN.md` §3.1 — if a
  requested feature would let a fleet/platform act on a driver's score
  automatically, flag the conflict with this document rather than building
  it.
