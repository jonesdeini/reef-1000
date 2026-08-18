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
- `ApexStatusService` — pulls the live controller status snapshot.
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
- **Not yet found:** the write/control endpoint for toggling an outlet.

Real numbers observed 2026-08-18: alk trended down over ~36h (8.01 → 7.66 →
7.60 dKH). Not yet resolved / explicitly undecided — don't invent an answer:
- **Target/band values.** User's stated target is 8 dKH; the Trident's own
  onboard config (`config.modules`, `TRI_10`) has `targetAlk: 8.5` — flagged
  discrepancy, not reconciled (probably doesn't matter since our decision
  logic is independent of the Trident's internal target).
- **The decision logic is explicitly not a simple threshold.** User's actual
  manual process factors in the last ~3 readings (trend, not just current
  value) and the tank's pH — not finalized as an algorithm yet. Trident's
  spec'd accuracy is ±0.2 dKH; user's observed real-world noise is closer to
  ±0.4 — relevant to picking a deadband, not yet decided.
- Whether `ilog`'s free pH/temp history gets used for the pH-trend part of
  the decision is plausible but undecided.

## Running locally

- Apex credentials live in a local `.env` (gitignored, never commit):
  `APEX_FUSION_USERNAME`, `APEX_FUSION_PASSWORD`, `APEX_CONTROLLER_ID`.
- Two Postgres databases required (`primary` + `queue`,
  `config/database.yml`) — `bin/rails db:prepare` sets both up.
