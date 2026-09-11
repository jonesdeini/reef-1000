# Reverse-engineered Apex Fusion API reference

None of this is documented anywhere official — found by probing the live
API. `apexfusion.com`, all endpoints require the session cookies from
`FusionAuthenticator#authenticate`. See `CLAUDE.md` for how this feeds into
the app's own architecture and safety principles.

- `GET /api/apex/:controller_id` — live status snapshot. `status.inputs` /
  `status.outputs` / `config.modules`. On this tank: Trident probe `did`
  prefix is `10_` (`10_0`=alk aka display name `Alkx10`, `10_1`=ca,
  `10_2`=mg), main pH probe is `base_pH`. The kalk stirrer's dosing pump is
  output `ID 16`, `name: "kalkStirPump"`, `type: "outlet"` — found by
  grepping the live outputs list, not guessed.
- **The Trident's calibration date is in the live status payload after
  all** — found 2026-09-10 by re-grepping the full payload instead of just
  its top-level fields. It's nested inside the hardware block for the
  Trident module: `status.modules[]` where `abaddr: 10` /
  `hwtype: "TRI"` (this is the same module whose `config.modules[]`
  counterpart is named `TRI_10`), under `.extra.lastCal` — a Unix epoch
  **seconds** timestamp (e.g. `1788470668` → 2026-09-03 21:24:28 UTC).
  **Confirmed against our own persisted data, not just decoded in
  isolation:** the two `Measurement`s straddling that exact timestamp are
  6 seconds apart (21:24:23 → 21:24:29) and show a stark value
  discontinuity, 8.5 → 8.13 dKH — and the live `targetAlk` in
  `config.modules` right now reads 8.13, matching the post-cal value
  exactly. This is almost certainly the origin of the already-documented
  "Sept 3 calibration/reagent-change artifact." Same object also carries
  `.extra.resetTime`, an array of up to 5 epoch timestamps (unused slots
  hold the epoch placeholder `820454400` / 1996-01-01, not `0` or `null`)
  — likely a reagent-reset log: the *writable* counterpart,
  `config.modules[]` (`TRI_10`) `.extra.reset`, is also exactly 5
  booleans, a structural match beyond just the date coincidence. Softer
  confirmation here too: the two later non-placeholder `resetTime` values
  (2026-09-01 02:08:06, 2026-09-03 13:05:14) both straddle a reading gap
  of ~204 min, vs. the ~174.6 min median gap across the full history —
  +17%, consistent with (not proof of) an extra re-prime step. The
  earliest slot (2026-08-25 18:19:11, right at the start of the real
  incident window) can't be checked this way — it's *before* our own
  history starts. Which of the 5 `reset` slots maps to which physical
  reagent (alk/ca/mg have their own separate 3-element `newReagent`
  array, so it isn't simply "one slot per reagent") is still unconfirmed
  — don't build against `resetTime` specifically until that's pinned
  down, but `lastCal` itself is solid. **Attempted to pin the slot
  mapping down further (2026-09-10) using our own DB** (which only goes
  back to 2026-09-03, so only the Sept 3 event is checkable — Aug 25 and
  Sept 1 predate our own history): at the exact `lastCal` instant,
  `alk`/`ca`/`mg` **all three** landed simultaneously on values matching
  `targetAlk`/`targetCa`/`targetMg` exactly (8.13/443/1325). Calibration
  is a whole-instrument event, not per-probe — this one event can't
  isolate which `reset` slot moved, since all three metrics moved
  together. **Asked the user directly (2026-09-10) what actually happened
  on Sept 3, rather than guessing further from data alone:** they change
  one reagent bottle at a time, and confirmed the Sept 3 13:05:14
  `resetTime` corresponds to swapping **Ca reagent B**, followed
  separately ~8h later by a manual calibration (the whole-instrument
  `cal`/`lastCal` event above — a distinct, occasional action, not run on
  every reagent swap, which is why it explains the simultaneous
  alk/ca/mg shift without contradicting `reset` being per-reagent). This
  pins one concrete (event, slot-affected) data point, but not which of
  the 5 array indices moved — no live before/after diff was captured, only
  the timestamp. **Reagent-count hypothesis corrected (2026-09-12), sourced
  externally rather than guessed:** Neptune's own Trident reagent
  documentation confirms the instrument uses exactly **3 reagent types —
  Reagent A (alk), Reagent B (ca), Reagent C (mg), one bottle installed per
  type** (A gets replaced monthly since alk is tested far more often; a
  2-month kit ships 2 A refills for that reason, not because 2 are
  installed at once). This retires the earlier "alk=1, ca=2(A/B), mg=2(A/B),
  1+2+2=5" guess — it was wrong, and also *retroactively confirms* the Sept
  3 event: "Ca reagent B" was never a slot label, it's just "the reagent-B
  bottle, which does Ca," fully consistent with this mapping. `newReagent`
  being exactly 3 booleans now reads cleanly as `[A, B, C]` =
  `[alk, ca, mg]`.
- **Reagent-attention signal found, and the slot-4/slot-3 mapping
  confirmed (2026-09-12)**, via a real before/after diff bracketing an
  actual Alk (Reagent A) swap+reset+prime, ~4h45m apart. The Trident
  module block (`status.modules[]`, `hwtype: "TRI"`) looked like this:

  ```json
  // before, 2026-09-12 13:32:15Z
  "extra": {
    "errorCode": 2,
    "lastCal": 1788470668,
    "resetTime": [820454400, 820454400, 1788228486, 1788440714, 1787681951],
    "levels": [389.8, 2871.1, 159.01, 175.01, 11.79]
  }

  // after, 2026-09-12 18:16:47Z
  "extra": {
    "errorCode": 0,
    "lastCal": 1788470668,
    "resetTime": [820454400, 820454400, 1788228486, 1788440714, 1789226787],
    "levels": [389.8, 2893.3, 154.94, 171.1, 242.75]
  }
  ```

  Three things moved together:
  - `errorCode`: **2 → 0**. This is the answer to "does the Trident say a
    reagent needs changing" — a nonzero `errorCode` on the Trident module
    is a real candidate for that signal, cleared by the swap+reset+prime.
    Only one nonzero value (`2`) observed so far; don't assume other
    nonzero values mean the same thing without more data points.
  - The previously-undocumented `.extra.levels` array (5 floats) —
    flagged right before the change with `levels[4]` at a clear outlier
    (`11.79`) — became `242.75` after. That jump from near-empty to
    242.75 lines up almost exactly with Neptune's own spec of "at least
    240 alkalinity tests" per reagent kit. **Confirms `levels[4]` = Alk
    (Reagent A) remaining tests/volume**, and that it being nearly
    depleted is almost certainly both the cause of the `errorCode` and
    the reason the swap was due. The other three real slots (1–3) moved
    slightly (±4–22, ordinary test-consumption drift over 4h45m of
    normal Ca/Mg testing, not swap-related); slot 0 didn't move at all
    across the whole window.
  - `resetTime[4]` got a fresh timestamp (2026-09-12 15:26:27 UTC, i.e.
    right when the reset was triggered), and the *previous* value it
    replaced was the long-standing Aug 25 18:19:11 entry — right at the
    start of the documented incident window, now read as **the prior Alk
    reagent swap**. Combined with the already-confirmed Sept 3 (slot 3 =
    Ca/Reagent B), **slot 4 = Alk/Reagent A**.
  - This also **retires the "rolling log of last 5 events" theory**
    floated after the pre-change capture — a true recency-ordered log
    wouldn't have left the array out of chronological order the way it
    already was (Aug 25 sat in slot 4, despite being older than the
    Sept 1/Sept 3 entries in slots 2/3). Better-supported theory now:
    **5 fixed slots, one per distinct reset-action type**, each stamped
    only when that specific action fires — slot 3 = Ca, slot 4 = Alk,
    slots 0/1 never fired in our whole observed history, slot 2 (Sept 1)
    still unidentified (plausibly Mg/Reagent C, unconfirmed — no known
    single-Mg-swap event to correlate against yet).
- `GET /api/apex/:controller_id/ilog?days=N` — continuous sensor history
  (~10-min interval): pH, temp, ORP, conductivity, output amps/watts/volts.
  Capped around 1000 entries (`days=7` hits it). **Does not include Trident
  results** (alk/ca/mg) — confirmed empty across a full 7-day pull.
- `GET /api/apex/:controller_id/tlog?days=N` — the actual Trident
  test-result history (alk/ca/mg). Entries: `{date, did, value,
  confidence}`. `days` is hard-capped at exactly 7 (`days=8` through at
  least `days=29` all return 400 — verified, not a soft/entry-count cap
  like `ilog`'s). Trident's *automatic* tests run roughly every 3h on this
  tank (~8x/day) on a fixed local wall-clock schedule (confirmed
  2026-09-21 against the Fusion app's own "Trident Schedule" dialog:
  00:00, 03:00, 06:00, 09:00, 12:00, 15:00, 18:00, 21:00 Eastern) — the
  `:19`/`:09`-past jitter is normal completion latency on top of that
  fixed schedule. User also triggers **manual** tests periodically
  (normal, expected, not an anomaly) — these land off the fixed grid and
  are indistinguishable from automatic ones in the data (see
  `CLAUDE.md`'s `ApexScrapeJob` entry), so an off-schedule reading alone
  isn't evidence of anything unusual. Each reading carries a `confidence`
  score.
  **Real distribution, all 175 alk readings on prod, checked 2026-09-16:**
  min `0.9444`, max `0.9996`, avg `0.9805`; 42/175 below `0.97`, 2/175
  below `0.95`, **none below `0.90`**. It has real spread, not a constant —
  but no confirmed relationship to whether the alk value itself is
  trustworthy (see `CLAUDE.md`'s safety-principles caveat).
- Both `ilog` and `tlog` are GET-only (POST returns 405) and require the
  `days` query param specifically by name — `start`/`end`/`from`/`to`/`date`
  all 400.
- **`status` entries have both `did` and `name`; `ilog` entries have only
  `did`.** The live snapshot is the only place a `did` (e.g. `4_P3`) is
  linked to its human-readable name (e.g. `kalkStirPumpA`) — needed for
  `OutletPowerProbeResolver` to resolve by name instead of hardcoding.
- **Every outlet gets an auto-generated amps/watts probe pair** from Apex's
  power modules regardless of what's plugged in — naming convention is
  `"#{outlet_name}A"`/`"#{outlet_name}W"` (e.g. `kalkStirPumpA`/`...W`,
  `RO_TO_DI_6A`/`...W`). Not something anyone configures; automatic.
- **Not yet found:** the write/control endpoint for toggling an outlet.
