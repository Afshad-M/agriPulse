# Assumptions (owner: C)

AgriPulse is a hackathon scaffold. **All data is simulated** — there are no
real farmers, hubs, markets, trucks, or deliveries behind any number shown
in the UI.

- Scoring, baseline assignment, route merging, and replanning are
  deterministic code (`logic.jac`). The LLM is never used to compute a
  number.
- The LLM (`llm.jac`) is used only to: parse a farmer's free-text harvest
  report into structured fields (`parse_harvest`), rank candidates
  qualitatively subject to code validation (`prioritize`), draft a
  farmer-facing status message (`farmer_message`), and explain a plan in
  plain language (`explain`). Every one of these falls back to a clearly
  labelled, deterministic message on any model failure or invalid output —
  never a silent guess.
- Distances, travel hours, and hub/market "open" status are placeholder
  seed values (`data.jac`), not real road or market data.

## Seed data specifics (`data.jac`)

- **12 farmers** across four Sri Lankan districts (Dambulla, Nuwara Eliya,
  Kandy, Matale). Names, phone numbers, and harvest quantities are
  invented for this demo.
- **4 crops** with an illustrative shelf-life lookup (not a `models.jac`
  field, just reference data for scoring): tomato 72h, beans 48h, leafy
  greens 24h, carrot 120h.
- **4 hubs**, each with an illustrative `capacity_kg`.
- **3 markets** (Dambulla Economic Centre, Colombo Manning Market, Kandy
  Market), each with an illustrative aggregate `demand_kg` (still a single
  cap, not per-crop) and, since the real loader landed, a per-crop
  `prices` dict (LKR/kg) pulled from `SEED_MARKET_RECORDS` — see "Additive
  `models.jac` fields" below.
- **3 trucks** (1000kg / 1500kg / 2000kg capacity) with invented plate
  numbers.
- A **hand-written** hub↔hub and hub→market distance/hours matrix
  (`SEED_HUB_ROUTES`, `SEED_HUB_MARKET_ROUTES`) — not from any maps API.
- `harvested_at` on each `Harvest` is a simulated relative offset from
  scenario load time (e.g. `"-2h"` = harvested 2 hours before load), not a
  real timestamp.
- A ready-made **5-farmer merge scenario** (`DEMO_MERGE_SCENARIO`): five
  Dambulla tomato farmers, 880kg combined, well within the smallest
  truck's 1000kg capacity — the "five trips become one" demo moment.
- A matching **truck-breakdown scenario** (`DEMO_BREAKDOWN_SCENARIO`) for
  the live re-plan demo moment.

## The real loader and baseline (`api.jac` / `logic.jac`)

`load_seed()` now builds the persisted graph from `data.jac`'s SEED_*
records (wipes and rebuilds every call — same counts, no duplicates), and
`baseline_plan()` computes a real solo-trip plan over it
(`logic.compute_baseline()`). The numbers below are the ONE config place
for the baseline's assumptions (`logic.BaselineAssumptions`, glob `BASELINE`):

- **`waiting_hours = 10.0`** (was `2.0`) — assumed hours a harvest sits at
  its hub before a truck departs with it, added to that hub's travel
  hours to get `elapsed_hours` for `score_cargo`. **Simulated assumption,
  not measured.** Reason for the change: a solo farmer's harvest has to
  wait for a truck to be dispatched just for them (no pooling at
  baseline), so 2 hours understated that wait; 10 hours is a more honest
  stand-in for "nobody else is already going that way."
- **`assumed_farmer_to_hub_km = 8.0`** (new) — a flat farmer-to-hub
  distance added to the hub-to-market leg for `distanceKm`/`truckCost`.
  **Simulated assumption, not measured.** Reason it exists at all:
  `models.jac`'s `DeliversTo` edge (`Farmer --> Hub`) carries no distance
  field, and `data.jac`'s `SEED_FARMER_HUB_LINKS` has no distance either
  — `distanceKm` previously covered only the hub→market leg, understating
  every route's real trip and therefore its `truckCost`. Only
  `distanceKm`/`truckCost` include this leg; `hours`/`elapsed_hours`
  (and therefore spoilage) still use only the hub→market travel time,
  since there is no farmer→hub *travel time* data to add either — flag to
  C if a real farmer→hub distance/time matrix should replace this flat
  number.
- **`default_truck_cost_for_score = 0.0`** — `score_cargo` is always
  called with `truck_cost=0` so its `revenue`/`loss` are the "pure"
  product numbers; the real per-route cost (`PlanInfo.truckCost`) is
  computed separately as `truck.cost_per_km * distanceKm` (now the
  farmer→hub + hub→market distance, see above) and never fed back into
  `score_cargo`.
- **Solo-trip baseline**: every harvest ships alone on the smallest truck
  that still fits its `kg` (by `capacity_kg`, reusable across different
  routes — the baseline does not model one truck being "busy" on another
  route at the same time). If no truck is big enough, the largest
  available truck is used as a fallback (never happens with this seed:
  the biggest harvest is 300kg, the smallest truck is 1000kg).
- **Market choice**: each hub routes to its **fastest** (lowest `hours`)
  `open` `HubMarketRoute` — not cheapest, not shortest by `distanceKm`.
  All seed routes happen to be `open`, so this never excludes one.
- **`readyHour` is always `0.0`** in the real graph: every seeded
  `Harvest.harvested_at` is already in the past (a negative offset, e.g.
  `"-2h"`), so every harvest is ready for pickup immediately when
  `load_seed()` runs.
- **Aggregate `score.baseline.spoilagePct`** is a **kg-weighted** average
  across all baseline routes (`sum(kg_i * spoilagePct_i) / sum(kg_i)`),
  not a plain average of percentages — a route carrying more kg should
  move the aggregate more. `income`/`truckCost` on the aggregate are
  plain sums across routes.
- **`score.agent` equals `score.baseline` for `baseline_plan()` only** —
  that endpoint never merges anything. `merge_routes()` computes a real,
  separate `agent` score from the merged plan (see "The real merge" below).

## The real merge (`logic.jac` / `api.jac`)

`merge_routes()` combines baseline solo routes into shared routes so the
agent score beats the baseline. It always starts from a **fresh**
`compute_baseline()` (which has no side effects, so this is naturally
idempotent) and persists the final merged routes as `Plan` nodes — the
"current plan" a later replan step is meant to read from. The ONE config
place for merge assumptions is `logic.MergedAssumptions` (glob `MERGED`),
next to `BaselineAssumptions`:

- **`MERGED.waiting_hours = 3.0`** — a consolidated truck runs on a fixed
  schedule, so farmers wait *less* than for an ad-hoc solo trip
  (`BASELINE.waiting_hours = 10.0`). **Simulated assumption, not
  measured.** A merged farmer's `elapsed_hours = MERGED.waiting_hours +`
  the merged route's `hours`.
- **Merged route distance/hours** come from real graph data — the union
  of the two routes' `hub_ids` (deduplicated) visited in order via
  `HubRoute` edges, then the shared market via `HubMarketRoute` — never
  an assumed constant. If any leg doesn't exist in the graph, the
  candidate is rejected (no path). `truckCost` is `costPerKm x` that
  combined distance, charged **once** per merged route (not once per
  original route).
- **Candidate rule**: two distinct **current** routes with the same
  `marketId` whose combined harvest `kg` fits some truck's `capacityKg`
  (the smallest one that fits). Routes are a reusable pool (same
  assumption as the baseline — merging does not track a truck being
  "busy" on another route at the same time), consistent with
  `BASELINE`'s solo-trip assumption above.
- **`delta`** = net value of the merged route (`score_cargo`'s summed
  `revenue` across the route's harvests, minus `truckCost`) minus the
  summed net value of the two original routes (using their *already
  computed* baseline net values — not recomputed under `MERGED` numbers).
- **`spoilageChangePts`** = the merged route's `spoilagePct` minus the
  kg-weighted average `spoilagePct` of the two originals (negative =
  improvement).
- Each pass builds every valid candidate, asks `pick_best_merge` for the
  one to apply (deliberately left as a stub — see its `TODO` in
  `logic.jac`), removes the two originals, adds the merged route
  (`m1`, `m2`, ...), and logs one `MergeStep`. Stops when no candidate has
  a positive `delta`, or after as many passes as there were starting
  routes (12, for the real seed) — so it always terminates.
- **`tripsSaved` is always `1`** per candidate — every candidate combines
  exactly 2 routes into 1; 3+-way consolidation happens by a later pass
  merging an already-merged route (`m1`, ...) with another original.

## Additive `models.jac` fields (owner A, for the real loader)

The real loader needed a few fields the original node shape didn't carry.
Each is additive with a default (no rename, no persisted-data break) and
filled in at seed-build time by matching the **same name** between
`data.jac`'s two existing seed shapes (e.g. a `Market`'s `name` string is
identical in `SEED_MARKETS` and `SEED_MARKET_RECORDS`):

- `Farmer.language` ← `SEED_FARMER_RECORDS[i]["language"]`, matched by name.
- `Hub.district` ← `SEED_HUB_RECORDS[i]["district"]`, matched by name.
- `Market.prices` ← `SEED_MARKET_RECORDS[i]["prices"]`, matched by name.
- `Truck.cost_per_km` ← `SEED_TRUCK_RECORDS[i]["costPerKm"]`, matched by
  the truck's `plate` == the record's `name`.
- `Harvest.shelf_life_hours` ← `CROP_SHELF_LIFE_HOURS[crop]` (the lookup
  table already above), not from either SEED_* record shape.
- `Plan`'s additive fields (`route_id`, `truck_id`, `farmer_ids`,
  `hub_ids`, `market_id`, `distance_km`, `hours`, `spoilage_pct`,
  `expected_income`, `truck_cost`) aren't seeded at all — `merge_routes()`
  wipes and rewrites them every call from the current computed plan (see
  "The real merge" above), not from any `data.jac` record.

## Known gaps / open items for the team

- `models.jac`'s `Harvest` node still has no edge linking it to its
  `Farmer` or `Hub` — the loader and `compute_baseline()` both rely on the
  documented convention that `[root-->][?:Farmer]` and
  `[root-->][?:Harvest]` come back in the same creation order as
  `SEED_FARMERS`/`SEED_HARVESTS` (parallel lists), verified by the "every
  harvest appears in exactly one route" test. A real edge would be more
  robust if the convention ever becomes hard to keep in sync.
- `logic.pick_best_merge()` is a deliberate stub (always returns `None`) —
  until it's implemented, `merge_routes()` applies zero merges, so its
  `agent` score equals its `baseline` score and several tests in
  `logic.test.jac`/`api.test.jac` are EXPECTED to fail (documented inline
  at each one). `replan_on_event()` is still the fixed STUB placeholder
  seed, unrelated to this.
- This was validated locally with the `jac` CLI available in this
  environment; if that differs from the version the team standardised on
  (per the playbook's 9:15 version-match step), re-run `jac check` against
  the agreed version before merging.
