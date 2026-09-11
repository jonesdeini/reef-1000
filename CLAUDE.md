# reef-1000

Rails 8 app for automating parts of running a reef fish tank, built around a
Neptune Apex reef controller (accessed via the Apex Fusion cloud API, since
there's no direct local network access to the controller from where this
runs).

## Current scope

The near-term goal is narrow and concrete: **read the Trident's alkalinity
measurement and turn a kalkwasser stirrer's dosing pump on/off in response.**
Everything here should be built as plain scheduled/background jobs
(Solid Queue), not as an LLM-driven agent — favor simple, well-tested,
explicit logic over anything clever. If a design choice is between "the
simple thing" and "the impressive-looking thing," prefer simple; the
counter-pull is to also avoid *under*-building (e.g. hardcoding a value that
obviously wants to be config) — aim for tasteful middle ground, not either
extreme.

## Architecture

**Apex integration** (`app/services/`):
- `FusionAuthenticator` — logs into Apex Fusion (CSRF token dance + cookies).
- `ApexClient` — shared HTTP-fetch base (auth cookies, base URL) so each
  endpoint client isn't repeating the same five lines.
- `ApexStatusService` — live status snapshot. Only used today to resolve the
  kalk pump's power-probe `did`s by name (see `OutletPowerProbeResolver`
  below) — not for any reading value itself.
- `TridentLogService` / `IntervalLogService` — `tlog`/`ilog` history pulls.
- `TridentMeasurementImporter` — parses `tlog`'s flat array into `Measurement`
  rows (alk/ca/mg), via the shared `MeasurementWriter`.
- `IntervalMeasurementImporter` — parses `ilog`'s per-timestamp `inputs`
  array. Ships with `base_pH` mapped by default; `ApexScrapeJob` merges in
  the kalk pump's amps/watts `did`s (resolved fresh each run, see below) as
  `extra_probe_metrics`.
- `OutletPowerProbeResolver` — resolves an outlet's amps/watts `did`s by
  *name* (`"#{output_name}A"`/`"...W"`) against the live status snapshot,
  rather than hardcoding a `did`. This matters because Apex auto-generates
  an amps/watts probe pair for every outlet regardless of what's plugged in
  — `4_P3`/`4_P11` are artifacts of this tank's current wiring, not stable
  identifiers, and `ilog` entries only carry bare `did`s (no `name`), so the
  live status snapshot is the only place the two are linked.
- `ApexScrapeJob` — the actual recurring unit: pulls `tlog` + `ilog` +
  (for probe resolution only) `status`, imports everything into
  `Measurement`. Scheduled via `config/recurring.yml`, an hour after each
  expected Trident test.
- Outlet **write** control (turning `kalkStirPump` on/off) is not
  implemented yet — the request shape hasn't been captured. Don't guess at
  it; it needs a devtools capture of a manual toggle in the Fusion UI.

**Data flow (planned):**
1. A recurring Solid Queue task scrapes Apex on a cadence matched to the
   Trident's own test cycle (~every 3h, not hourly — see reference data
   below) and persists new readings into our own table.
2. On success, the scrape job enqueues a decision job as its last step —
   this is a plain sequential call (`DecisionJob.perform_later`), not an
   `after_perform` callback and not two independently-scheduled jobs. The
   Trident doesn't test on a clean wall-clock cadence, so a decision job on
   its own independent timer risks running against stale/no-new data;
   chaining after a successful scrape avoids that race. If the scrape job
   raises, the decision job is never enqueued — no extra guarding needed.
3. The decision logic itself should be a plain, independently-callable unit
   (not something only reachable via the job) — this is what enables manual
   on-demand runs, a dry-run mode (compute the decision, log it, skip the
   actual outlet call), and backtesting against historical readings later.
   None of that requires the *production* trigger to be decoupled from the
   scrape — see above.

**Why we persist our own reading history** (rather than only querying Apex
live): testability (decision logic can run against fixtures, no HTTP
stubbing required), an audit trail (reading → decision → action, genuinely
useful for a system that's actually dosing a real tank), and because Apex's
own history is capped — `tlog` (see below) hard-caps at exactly 7 days
(`days=8` already 400s). Anything longer-term (trend analysis, backtesting a
policy change against a month of data) has to come from our own copy.

**Safety principles for the decision boundary** — this system can dose a
real tank, so the seam between "raw Apex response" and "decision logic" is
the highest-stakes part of the codebase:
- Ambiguous/missing/out-of-plausible-range data must resolve to **no-op**,
  never to an action. An action requires an affirmatively good signal.
- Use the `confidence` field on Trident readings (see below) — don't let a
  low-confidence reading trigger a state change on its own.
- Check reading *staleness* relative to the ~3h Trident test cadence before
  acting on it — Apex's `link.when` timestamp has been observed lagging by
  months in one field, so "the API responded 200" isn't the same as "this
  data is current."
- Keep a hard ceiling independent of decision-logic correctness — e.g. the
  pump should never be allowed to stay in the "on" state for more than N
  hours without a fresh confirming reading, regardless of what the decision
  code thinks it's doing.
- Test the parsing/mapping boundary against real captured payloads (see
  below), not idealized JSON.

**Config, not database-backed settings.** Apex credentials and
tank-specific identifiers (controller ID, kalk pump output name, alk
target/band) belong in `Rails.application.config.x.apex`-style config
(env-var backed, see `config/application.rb`), not a settings UI or DB
table. This project intentionally does not support multiple
users/tanks/tenants — don't build toward that.

**Solid Queue runs on its own `queue` database**, separate from `primary`
(`config/database.yml`), rather than sharing one database — this was a
deliberate choice (Solid Queue's own recommended default) partly because
the project also has a local-k8s deployment goal, and running app + queue as
genuinely separate databases is more representative infra to build against.
Whether that becomes one Postgres instance with two databases or two
separate Postgres deployments in k8s is an open question, explicitly
deferred until the k8s work itself.

## Reverse-engineered Apex Fusion API reference

None of this is documented anywhere official — found by probing the live
API. `apexfusion.com`, all endpoints require the session cookies from
`FusionAuthenticator#authenticate`.

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
  the timestamp. Plausible **unverified hypothesis**: Trident alk tests
  use 1 reagent bottle, ca and mg each use 2 (A/B) — 1+2+2=5, matching the
  array length — but this is recalled general Trident hardware knowledge,
  not something confirmed against this app's own captured data. Building
  a real index-to-reagent map needs either a live devtools capture of the
  array during a future reset action, or triangulating several more
  known single-reagent-change events the way this one was resolved.
- `GET /api/apex/:controller_id/ilog?days=N` — continuous sensor history
  (~10-min interval): pH, temp, ORP, conductivity, output amps/watts/volts.
  Capped around 1000 entries (`days=7` hits it). **Does not include Trident
  results** (alk/ca/mg) — confirmed empty across a full 7-day pull.
- `GET /api/apex/:controller_id/tlog?days=N` — the actual Trident
  test-result history (alk/ca/mg). Entries: `{date, did, value,
  confidence}`. `days` is hard-capped at exactly 7 (`days=8` through at
  least `days=29` all return 400 — verified, not a soft/entry-count cap
  like `ilog`'s). Trident tests run roughly every 3h on this tank (~8x/day),
  not on a fixed wall-clock schedule (observed timestamps land at `:19`,
  `:09` past variable hours). Each reading carries a `confidence` score
  (observed range ~0.94–0.99).
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

Real numbers observed 2026-08-18: alk trended down over ~36h (8.01 → 7.66 →
7.60 dKH).

**Target/band values — now decided.** `TARGET_DKH = 8.0`, `DEADBAND = 0.4`
(`AlkWatchdogService`), cross-checked against 14+ days of production alk
history rather than the Trident's own onboard `targetAlk: 8.5` config
(`config.modules`, `TRI_10`) — that discrepancy is deliberately unreconciled,
our decision logic doesn't depend on the Trident's internal target.

**`AlkWatchdogService`'s first pass is a deliberately simple single-reading
threshold check — this is known to be a temporary, narrow first cut, not the
intended final design.** User's actual manual process factors in more than
one reading and the tank's pH; the next evolution being discussed
(2026-09-10, not yet built):

- **A points-based scoring model** ("sus calculator") rather than a rigid
  if/else chain — score several independent signals (magnitude of rise,
  trend across ≥3 points, whether the pump's been on during the window as a
  confidence boost, duration of a sustained low/high reading) and sum them
  into a tiered response, rather than one rule producing one verdict. Fits
  cleanly on top of the existing "actions are the verdict, no separate
  reason field" design — a scored decision just emits whichever action type
  its tier calls for.
- **A real negative result, not a guess:** a naive "alk rose >0.4 dKH over
  6h" rule was checked against the real Aug 25→27 incident data and found
  too marginal to trust — the actual observed rise was 0.42, only barely
  past the naive threshold, and the Trident's own spec'd accuracy is ±0.2 —
  a signal that close to 2x the instrument's own noise floor isn't a
  confident basis for action alone.
- **A third action type, not just off/none: requesting an out-of-cycle
  Trident test.** When a signal is ambiguous/marginal rather than clearly
  actionable, "ask the Trident to retest sooner" (rather than immediately
  acting on weak data, or silently waiting up to ~3h for whatever the next
  scheduled reading happens to be) gets a confident decision sooner. This
  needs a **new, not-yet-found Apex write capability** — triggering an
  on-demand Trident test — a separate unknown from the outlet-toggle
  endpoint, never reverse-engineered, don't assume it exists without
  checking.
- **Investigated (2026-09-10), inconclusive — "does the Trident retest
  itself on low confidence" hypothesis, still just n=2.** Full history
  (133 readings, Aug 25 → today) has 7 instances of two alk tests landing
  under 100 min apart (normal cadence: median 174.6 min). The original 2
  (both during the real incident: Aug 25 19:20→20:03, confidence 0.9637→
  0.9879; Aug 26 00:36→01:10, confidence 0.9741→0.9933) still cleanly fit
  "a lower-confidence reading is followed shortly by a meaningfully
  higher-confidence one." The other 5 don't add support — they cluster
  entirely inside the Sept 3 window already flagged above as a likely
  reagent/calibration event, not ordinary operation, and *within* that
  cluster the pattern is inconsistent (one instance is a *high*-confidence
  0.9882 reading triggering an early retest; another is two readings 6
  seconds apart with zero confidence change). Net: real pattern in the 2
  original instances, not strengthened by the wider search — treat as
  still-open, not confirmed, and don't design anything around it yet.
- pH comes from `ilog` (`IntervalMeasurementImporter`) rather than the live
  status snapshot, so pH history is already being captured — this was an
  open question, now resolved and built, but not yet factored into any
  decision logic.
- **LLS (level sensor) for the RODI reservoir feeding the kalk stirrer —
  not built yet, sensor isn't physically in place.** User has one LLS,
  currently in the sump (`did` `5_P3`, name `TZ_LLS` as of 2026-08-18) but
  too much splashing there for a clean reading; plans to move it to the RODI
  reservoir that feeds the kalk stirrer. An empty reservoir is a real reason
  *not* to run the pump (dry-running it), so this is a genuine decision
  input, not just a nice-to-have. Moving the sensor doesn't change its
  `did` (that's tied to the module port, not what it's measuring) but will
  likely come with a rename in the Apex UI to reflect the new job — so this
  should follow the exact same pattern as `OutletPowerProbeResolver`:
  resolve by a configured name against the live status snapshot, never
  hardcode the `did`. Hold off building this until the physical move
  actually happens — no way to verify units/plausible ranges (what "empty
  reservoir" reads as) against a sensor that isn't there yet.

## Running locally

- Apex credentials/config live in a local `.env` (gitignored, never commit):
  `APEX_FUSION_USERNAME`, `APEX_FUSION_PASSWORD`, `APEX_CONTROLLER_ID`,
  `APEX_KALK_PUMP_OUTPUT_NAME`.
- Two Postgres databases required (`primary` + `queue`,
  `config/database.yml`) — `bin/rails db:prepare` sets both up.

## Deploying

Runs on a home Unraid box via `docker-compose.yml` (single Postgres container
holding both the `primary` and `queue` databases as separate logical DBs —
same "defer the two-instance split to actual k8s work" reasoning as the
Solid Queue database choice above), managed through the Compose Manager
Plus plugin using its "Indirect Path" option pointing at this repo checked
out on the array (not the plugin's own default projects folder, which lives
on the boot USB, not the array — no room/durability for a real app there).

**Deploy is poll-based, not push-triggered, by deliberate choice:**
`.github/workflows/ci.yml`'s `build_and_push` job builds and pushes the app
image to GHCR (`ghcr.io/jonesdeini/reef-1000:latest`) on every push to
`main`, gated on the existing `scan_ruby`/`lint`/`test` jobs passing first.
An `updater` service in `docker-compose.yml` — a plain `docker:cli` image
looping `docker compose pull && docker compose up -d` every 5 min, with
`docker.sock` mounted — polls GHCR and recreates `web`/`jobs`/`postgres`
when a new image actually lands. `docker compose up -d` only recreates a
container whose pulled image digest changed, so this is a safe no-op most
of the time.

Rejected alternatives, and why:
- **Self-hosted GitHub Actions runner on the box**, triggered instantly on
  push — would give GitHub Actions (any workflow run, any dependency in it)
  local execution access to the NAS. Poll-based means the box only ever
  does an outbound `docker pull`; GitHub never executes anything on it.
- **Kamal**, deploying over SSH from CI — doesn't avoid the same tradeoff,
  just reshapes it: a GitHub-hosted runner still needs a path *into* the
  LAN to reach the box's SSH port (open port, or a VPN tunnel like the
  Tailscale GitHub Action), which is new exposure/infra either way. It's
  also push-only with no polling/auto-update mode of its own, so it doesn't
  even address the same need.
- **Watchtower**, used originally for the polling piece — upstream
  (`containrrr/watchtower`) was archived Dec 2025, maintainers explicitly
  declined to endorse any fork ("a few of the active forks... are full of
  AI slop"), and its last image predates the Docker Engine API version
  running on this box. `docker.sock` access is unavoidable for anything
  that restarts containers on a schedule, whether that's a container or a
  host cron job — the actual problem was trusting a third party's
  unmaintained code with that access, not the access itself. `updater` is
  the same few lines we'd have needed anyway, just ours instead of a
  fork's.

Neither the box nor the deploy needs any inbound access or port-forwarding
— everything is the box reaching out (`docker pull` from GHCR), same trust
level as any container image update.

GHCR package visibility isn't assumed to be public — `docker login ghcr.io`
once on the Unraid host (a PAT with `read:packages`) covers both the
initial `docker compose up` pull and the `updater` service's ongoing
polling, and works the same whether the package ends up public or private.
