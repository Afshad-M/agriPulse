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
- **`score.agent` equals `score.baseline`** for now — there is no
  separate agent computation yet (task-scoped; `merge_routes` will
  eventually produce a different `agent` score).

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

## Known gaps / open items for the team

- `models.jac`'s `Harvest` node still has no edge linking it to its
  `Farmer` or `Hub` — the loader and `compute_baseline()` both rely on the
  documented convention that `[root-->][?:Farmer]` and
  `[root-->][?:Harvest]` come back in the same creation order as
  `SEED_FARMERS`/`SEED_HARVESTS` (parallel lists), verified by the "every
  harvest appears in exactly one route" test. A real edge would be more
  robust if the convention ever becomes hard to keep in sync.
- `merge_routes()` and `replan_on_event()` are still the fixed STUB
  placeholder seed — `score.agent` will stay equal to `score.baseline`
  until a real merge computation exists.
- This was validated locally with the `jac` CLI available in this
  environment; if that differs from the version the team standardised on
  (per the playbook's 9:15 version-match step), re-run `jac check` against
  the agreed version before merging.
