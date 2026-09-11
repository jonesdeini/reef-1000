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
  `Measurement`. Scheduled via `config/recurring.yml`
  (`"0 1,4,7,10,13,16,19,22 * * *"`), an hour after each expected Trident
  test. **This cron string is written in, and must run in, local time**
  (`config.time_zone = 'Eastern Time (US & Canada)'` in
  `config/application.rb`, which Solid Queue's recurring schedule inherits
  automatically) — the Trident's own onboard *automatic* test schedule is
  itself anchored to local wall-clock time (00:00/03:00/06:00/.../21:00
  Eastern, set in the Fusion app's "Trident Schedule" dialog), not UTC, so
  this has to match or the buffer is meaningless. Typical completion
  latency for a scheduled test (test start → result logged) is well under
  1h — a 1h buffer comfortably catches it.
- **User also triggers manual, out-of-cycle Trident tests periodically** —
  this is expected, normal operation, not an error condition. A manual
  test shows up in `tlog` exactly like an automatic one (same `{date, did,
  value, confidence}` shape — the raw API has no field distinguishing
  manual from scheduled), landing off the fixed 3h grid and often within
  ~100min of the previous reading. Don't treat an off-schedule reading as
  itself evidence of a problem, and don't assume every close-together pair
  of readings is Trident behavior worth modeling — check whether a manual
  test explains it first.
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
- The `confidence` field on Trident readings (see below) has no confirmed
  mechanism behind it — we know it varies (`0.9444`–`0.9996` across all 175
  real alk readings on prod, checked 2026-09-16), not what it measures or
  whether a lower value predicts a less trustworthy alk value. A naive
  `CONFIDENCE_FLOOR = 0.9` gate (an early `AlkWatchdogService` draft) was
  checked against that same real data and never fired even once. Treat
  "gate decisions on confidence" as an open question, not a settled
  principle, until there's real evidence behind it — see the confidence
  distribution and the retest-on-low-confidence investigation below.
- Check reading *staleness* relative to the ~3h Trident test cadence before
  acting on it — Apex's `link.when` timestamp has been observed lagging by
  months in one field, so "the API responded 200" isn't the same as "this
  data is current." **Built:** `AlkWatchdogService#stale?` against
  `Rails.application.config.x.apex.alk_staleness_threshold`
  (`APEX_ALK_STALENESS_THRESHOLD_HOURS`, default **2h**). Given normal
  freshness is bounded under 1h (see `ApexScrapeJob`'s schedule/latency
  numbers above), a single missed scrape mathematically pushes the
  last-known reading's age to 3.33-4h by the next cycle (one 3h gap plus
  under 1h of normal freshness) — 2h is the tightest threshold that still
  catches every single-missed-scrape case without ever false-triggering on
  real operation. Re-derive from real completion-latency data (not a
  round-number guess) if the schedule ever changes.
- Keep a hard ceiling independent of decision-logic correctness — e.g. the
  pump should never be allowed to stay in the "on" state for more than N
  hours without a fresh confirming reading, regardless of what the decision
  code thinks it's doing.
- Test the parsing/mapping boundary against real captured payloads (see
  below), not idealized JSON.

**Config, not database-backed settings.** Apex credentials and
tank-specific identifiers (controller ID, kalk pump output name, the alk
slope/r_squared/staleness decision thresholds) belong in
`Rails.application.config.x.apex`-style config (env-var backed, see
`config/application.rb`), not a settings UI or DB table. This project
intentionally does not support multiple users/tanks/tenants — don't build
toward that.

**Solid Queue runs on its own `queue` database**, separate from `primary`
(`config/database.yml`), rather than sharing one database — this was a
deliberate choice (Solid Queue's own recommended default) partly because
the project also has a local-k8s deployment goal, and running app + queue as
genuinely separate databases is more representative infra to build against.
Whether that becomes one Postgres instance with two databases or two
separate Postgres deployments in k8s is an open question, explicitly
deferred until the k8s work itself.

## Apex Fusion API

The full reverse-engineered API reference (endpoints, Trident field
mapping, the reagent-slot-mapping investigation, confidence-field
distribution) lives in `docs/apex-api.md` — read it before touching any
Apex integration code. Kept separate from this file because it's grown
into its own dense knowledge base that isn't relevant to most other work
in this repo.

Real numbers observed 2026-08-18: alk trended down over ~36h (8.01 → 7.66 →
7.60 dKH).

**A fixed `TARGET_DKH`/`DEADBAND` threshold was the original plan; superseded
before shipping by trend-based detection instead.** The Trident's own onboard
`targetAlk: 8.5` config (`config.modules`, `TRI_10`) remains deliberately
unreconciled either way — our decision logic doesn't depend on the Trident's
internal target.

**`AlkWatchdogService`'s first pass fits a least-squares regression
(`LeastSquaresRegression`) over the lookback window's readings each run,
persists it as a `Trend` (slope/r_squared, thresholds grounded in
`docs/alk-trend-detection.md`'s real incident numbers), and `SusCalculator`
scores the last 3 trends — a real trend signal, not a single-reading
threshold check, but still a deliberately narrow first cut.** User's actual
manual process factors in more than one reading and the tank's pH; the next
evolution being discussed (2026-09-10, not yet built):

- **A richer points-based scoring model.** `SusCalculator` already scores
  points-based rather than a rigid if/else chain (34 points per rising
  trend among the last 3, sus at ≥100), but only on that one signal. A
  richer version — weighing magnitude of rise, whether the pump's been on
  during the window as a confidence boost, duration of a sustained
  low/high reading, tiered rather than binary output — is still a future
  idea, not built. Fits cleanly on top of the existing "actions are the
  verdict, no separate reason field" design whenever it happens — a
  scored decision just emits whichever action type its tier calls for.
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
- **"Does the Trident retest itself on low confidence" — weaker than
  previously written, not fully ruled out.** The only real support was 2
  instances of two alk tests landing under 100 min apart, both during the
  Aug 25→26 incident window (Aug 25 19:20→20:03, Aug 26 00:36→01:10).
  User manually triggers out-of-cycle tests periodically (see
  `ApexScrapeJob` above) and believes they likely ran one during that
  window — since a manual test is indistinguishable from an automatic one
  in the data, that's a simpler explanation than the Trident reacting to
  its own confidence score, though not confirmed either way. Still
  open, still don't design anything around it — but lean further toward
  "explained by a manual test" than before.
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
**Keep this checkout on `main`.** `main` is what `build_and_push` actually
builds images from, so the compose file needs to match whatever's really
deployed; checking out `develop` there to test something ahead of a
promotion is tempting but leaves the compose config and the running image
able to drift out of sync with each other.

**Deploy is poll-based, not push-triggered, by deliberate choice:**
`.github/workflows/ci.yml`'s `build_and_push` job builds and pushes the app
image to GHCR (`ghcr.io/jonesdeini/reef-1000:latest`) on every push to
`main`, gated on the existing `scan_ruby`/`lint`/`test` jobs passing first.
An `updater` service in `docker-compose.yml` — a plain `docker:cli` image
looping `docker compose pull --quiet web jobs postgres && docker compose up
-d web jobs postgres` every 5 min, with `docker.sock` mounted — polls GHCR
and recreates `web`/`jobs`/`postgres` when a new image actually lands.
**Deliberately scoped to those three services, never itself** — targeting
the whole compose file would let `updater` try to recreate its own running
container mid-loop. `docker compose up -d` only recreates a container
whose pulled image digest changed, so this is a safe no-op most of the
time.

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
