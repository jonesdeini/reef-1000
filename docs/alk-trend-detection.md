# Alk trend detection — design notes (2026-09-10)

Working notes from a design session exploring what replaces
`AlkWatchdogService`'s current single-reading threshold check. Not yet
built — this is the reasoning and the real data behind it, kept in one
place instead of scattered across chat history. See `CLAUDE.md` for the
condensed, curated version of the settled/open points.

## Goal

`AlkWatchdogService`'s first pass (shipped) is deliberately simple: look
at the latest alk reading, compare to `TARGET_DKH ± DEADBAND`. That's
known to be temporary — the user's actual manual process considers a
trend across multiple readings, not just the latest value. This doc is
about what a trend-aware version looks like.

## Signal considered and dropped: pump activity

Originally considered scoring two things together: magnitude/consistency
of the alk rise, and whether the kalk pump had been running during the
window (as a corroborating "confidence boost"). Pump activity was
dropped — the two possible states don't discriminate anything for *this*
decision:

- **Pump on** — the pump being on is normal, expected baseline behavior
  (see `CLAUDE.md`'s "pump on 24/7 is not an anomaly" note). Tells you
  nothing you didn't already expect.
- **Pump off** — if the pump is already off, the specific problem this
  system exists to catch (pump left on too long/wrong drip) structurally
  cannot be happening. There's no "turn it off" action left to consider.

Neither state adds information to the off/none decision. Dropped, not
revisited unless the decision space expands beyond "should the pump be
commanded off."

## Trend detection: least-squares linear regression

- x = hours since window start, y = alk value (dKH).
- **Slope** (dKH/hour) answers "is it trending up," directly, as a real
  rate rather than an arbitrary points score.
- **R²** (how tightly the readings hug the fitted line) is a built-in
  consistency measure — a real sustained rise clusters close to the line;
  noise around a similar average slope produces a messy fit. This
  replaces trying to hand-build a "reward consistency" points system.

### Why not a naive single-delta rule

Tested "alk rose more than 0.4 dKH over 6 hours" against the real
2026-08-25→27 incident. The actual observed rise in a comparable window
was **0.42** — barely past the naive threshold, and the Trident's own
accuracy is spec'd ±0.2 dKH (observed real-world noise closer to ±0.4).
A signal that close to the instrument's own noise floor isn't a confident
basis for action alone. This is why the slope needs to be checked against
a noise-floor-derived significance threshold, not just "is it positive."
**That threshold is not yet picked** — open question.

## Window size: tested 12h and 6h against the real history

Ran sliding-window least-squares fits across the full 133-reading alk
history (2026-08-25 → 2026-09-10 at time of writing), comparing:

- **Incident windows** — those ending during the real Aug 25→27 overdosing
  incident (see `CLAUDE.md`'s "#1 motivating failure mode").
- **Normal windows** — everything from Aug 28 onward.

| window | incident mean slope | incident max slope | overall max slope (whose window) |
|---|---|---|---|
| 12h | 0.0227 dKH/h | 0.0421 dKH/h | 0.1045 dKH/h (Sept 3 calibration event) |
| 6h  | 0.0349 dKH/h | 0.0442 dKH/h | 0.2051 dKH/h (Sept 3 calibration event) |

**Shrinking the window makes separation worse, not better.** At 6h, the
Sept 3 calibration/reagent-change artifact (a ~0.8 dKH jump in under 20
minutes — see `CLAUDE.md`) produces a slope nearly 5x the real incident's
own max, with a *higher* R² (0.882) than any genuine incident window ever
reaches. This isn't a tuning problem — a sharp, concentrated artifact will
always out-slope a gradual real climb, at any window width, because
that's structurally what "sharp" means relative to "gradual." 12h was
kept as the working window width (≈4 Trident readings, enough for a real
fit, tighter than the existing 24h `AlkWatchdogService` window) — the
window-width choice doesn't solve the calibration-artifact problem either
way, see below.

## The calibration/reagent confound

**Important framing correction made mid-session:** slope isn't "wrong"
here. Both the real incident and the Sept 3 calibration event *were*
genuinely trending up in the raw numbers during their respective windows
— that's just true, and slope correctly says so for both. The actual
problem is a data-quality one, not a trend-detection one: a reading
contaminated by a calibration event shouldn't be feeding the trend math
at all. Asking slope/R² to also solve "was this trend real or an
artifact" was asking one piece of math to do two jobs.

**The fix belongs upstream, as an input filter, not inside the
regression.** Found (2026-09-10): the calibration date *is* in the `GET
/api/apex/:controller_id` live status payload this app already uses — the
earlier "not present" check only grepped top-level fields and missed it
nested inside the Trident's hardware block, `status.modules[]` where
`abaddr: 10`, at `.extra.lastCal` (Unix epoch seconds). **Confirmed
against our own persisted data**, not just decoded in isolation: the two
`Measurement`s immediately straddling that timestamp are 6 seconds apart
and jump 8.5 → 8.13 dKH, and the live `targetAlk` config value right now
is 8.13 — matches the post-cal reading exactly. This is almost certainly
the actual mechanism behind the Sept 3 artifact: not two ordinary
readings 20 minutes apart drifting sharply, but a discontinuity from the
calibration itself. See `CLAUDE.md`'s API reference for the full shape,
including `.extra.resetTime` — likely a reagent-reset log (its writable
counterpart, `config.modules[]` `.extra.reset`, is also exactly 5
booleans long, a real structural match). Its 3 real (non-placeholder)
values land suspiciously close to both the real incident's start (Aug 25)
and the Sept 3 artifact; the two checkable ones (not Aug 25, which
predates our own history) each straddle a ~204 min reading gap vs. a
~174.6 min median — softer, but consistent, corroboration.

**One slot now has a confirmed real-world event behind it.** Asked the
user directly rather than continuing to infer from data: the Sept 3
13:05:14 `resetTime` was a **Ca reagent B** swap, with a separate manual
calibration (`cal`/`lastCal`) run ~8h later — calibration is occasional
and whole-instrument (a single flag, not per-reagent), which is why it
moved alk/ca/mg together without that contradicting `reset` being
per-reagent-bottle. Which of the 5 array *indices* corresponds to that
event is still unknown (no live before/after diff was captured, only the
timestamp) — see `CLAUDE.md` for the full reasoning and an unverified
hypothesis about the 1+2+2=5 reagent-bottle-count structure.

**Still open:** no filter has actually been wired into the trend math yet
— this is a found and confirmed data source, not a built feature. Needs:
(1) deciding how close to `lastCal` a `tlog` reading has to be to get
excluded/flagged, grounded in real data rather than picked by feel — the
6-second-apart pair found here is a good concrete starting example — and
(2) figuring out what `resetTime`'s slots actually mean before leaning on
it for anything.

## A third action, not just off/none: request an out-of-cycle Trident test

When a signal is ambiguous — not confidently trending, not confidently
noise — forcing a binary off/none decision wastes the ambiguity. A
genuine third option: ask the Trident to retest sooner, rather than
either acting on a marginal signal or silently waiting up to ~3h for
whatever the next regularly-scheduled reading happens to be. Fits the
existing architecture with zero schema change — `Decision#action` is
already free-form jsonb, so `{'trident' => 'test_now'}` sits alongside
`{'pump' => 'off'}` without any new column. **Needs a new, not-yet-found
Apex write capability** (triggering an on-demand test) — a separate
unknown from the outlet-toggle endpoint, never reverse-engineered.

## Side investigation: does the Trident retest itself on low confidence?

Prompted by noticing extra tests in the incident window. Checked against
the full 133-reading history (7 total instances of two tests landing
under 100 minutes apart, against a normal median gap of ~175 min):

- The original 2 instances (both during the real incident) cleanly fit
  "a lower-confidence reading is followed shortly by a meaningfully
  higher-confidence one" (0.9637→0.9879, 0.9741→0.9933).
- The other 5 cluster entirely inside the Sept 3 calibration-event window
  and don't strengthen the pattern — one is a *high*-confidence reading
  (0.9882) triggering an early retest (contradicts the hypothesis), one
  is two readings 6 seconds apart with zero confidence change.

**Conclusion: still just n=2, not strengthened by the wider search.**
Real pattern in those two instances, not confirmed as a general
mechanism. Don't design anything around this yet.

## Open questions, not yet decided

1. The noise-floor-derived significance threshold for "is this slope
   confident enough" — not picked, needs to be grounded in the ±0.2
   spec'd / ±0.4 observed numbers rather than chosen by feel.
2. What (if anything) is needed beyond calibration-date filtering to
   separate a real gradual climb from a sharp artifact, if that filter
   alone turns out to be insufficient — one candidate floated but not
   tested: largest single-step delta as a fraction of total window rise
   (high for an artifact, low for a real climb).
3. Whether/how the "request a Trident retest" action gets built at all
   depends on finding that write endpoint first — not scheduled, no
   devtools capture done yet.
