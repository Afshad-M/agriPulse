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

- **50 farmers** across nine Sri Lankan districts, in two separate
  components (no route connects them — see below): the original
  **12 farmers** in Dambulla/Nuwara Eliya/Kandy/Matale, plus **38 more**
  spread across Jaffna, Anuradhapura, Badulla, Ratnapura and Galle. Names,
  phone numbers, and harvest quantities are invented for this demo; place
  names (districts, hub/market towns) are real.
- **7 crops** with an illustrative shelf-life lookup (not a `models.jac`
  field, just reference data for scoring): tomato 72h, beans 48h, leafy
  greens 24h, carrot 120h, onion 480h, chili 96h, cabbage 168h.
- **9 hubs**, each with an illustrative `capacity_kg`.
- **7 markets** (Dambulla Economic Centre, Colombo Manning Market, Kandy
  Market, Jaffna Market, Anuradhapura Economic Centre, Badulla Economic
  Centre, Galle Market), each with an illustrative aggregate `demand_kg`
  (still a single cap, not per-crop) and, since the real loader landed, a
  per-crop `prices` dict (LKR/kg) pulled from `SEED_MARKET_RECORDS` — see
  "Additive `models.jac` fields" below.
- **9 trucks** (1000–2600kg capacity, ~95–110 LKR/km) with invented plate
  numbers.
- A **hand-written** hub↔hub and hub→market distance/hours matrix
  (`SEED_HUB_ROUTES`, `SEED_HUB_MARKET_ROUTES`) — not from any maps API.
  **Deliberately two disconnected components**: the original 4 hubs/3
  markets have no route to/from the 5 new hubs/4 new markets, and vice
  versa. This is a merge-engine constraint, not a geography one —
  `logic.jac`'s merge only ever pairs two baseline routes bound for the
  same `market_id`, so keeping the new hubs shipping only to the new
  markets means the original 12-farmer merge/breakdown demo (below)
  computes byte-for-byte the same as before the expansion.
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

## The real replan (`logic.jac` / `api.jac`) — `truck_breakdown`

`replan_on_event()` is real for `event.type == "truck_breakdown"`; every
other type (`road_closed`, `price_crash`, `new_harvest`, or anything else
unrecognised) returns a valid, unchanged result with an empty `diff` and
`diff.notes = "Event type <type> is not handled yet"` — never a crash,
never a changed plan. This is plain deterministic code
(`logic.apply_replan_event()` / `apply_truck_breakdown_event()`) — the LLM
is not involved (the `explain`/`farmer_message` LLM upgrade is a later
block; this block's `explanation` and `messages` are deterministic
templates, `isFallback=True`).

- **Always rebuilds from a fresh merge.** Every `truck_breakdown` call
  re-runs `run_merge_routes()` first (ignoring whatever `Plan` nodes were
  left over from an earlier call) and only then applies the event. This is
  why calling the exact same event twice gives identical output — nothing
  from a previous replan call's reassignments/removals carries over, only
  the truck's own `status` does (see below).
- **`Truck.status`** (`models.jac`, additive, default `"available"`) is
  the only piece of replan state that persists across calls: a
  `truck_breakdown` event sets the named truck's `status` to `"broken"`
  directly on its graph node. `load_seed()` resets it, since it rebuilds
  every `Truck` node from scratch from `data.jac`'s `SEED_TRUCKS` — it does
  **not** get reset by another replan call (re-merging doesn't touch
  `Truck.status`).
- **Validation, never a crash.** A missing or unknown `truckId` (including
  a string that isn't even a valid id, e.g. not a UUID) returns an empty
  `diff` with a plain-language note (`"Truck <id> does not exist."` /
  `"Truck breakdown event is missing a truckId."`) and leaves the plan
  untouched — no merge is re-run, no `Truck.status` is touched. A valid
  `truckId` that simply isn't serving any current route still gets marked
  `"broken"` (it is a real truck breaking down, in service or not), but
  produces an empty diff too (`"Truck <plate> broke down but was not
  serving any route."`).
- **One truck, one route, for replan purposes.** Baseline/merge treat
  trucks as a reusable pool (see above); replan does not — once the
  broken truck's routes are pulled off, a truck already carrying another
  current route is never considered "free" for a reassignment or for
  topping up spare capacity. This is a deliberate, replan-only tightening
  of the baseline/merge assumption, not a correction of it.
- **Per-route resolution, in sorted route-id order.** For every route the
  broken truck was serving (processed in ascending `id` order, so output
  is deterministic when more than one route is affected):
  1. **Replacement truck** — `logic.pick_replacement_truck(route_kg,
     free_trucks)` (a deliberate stub, see its `TODO` in `logic.jac`:
     smallest fitting `capacityKg`, lowest id on a tie, `None` if nothing
     fits) picks from every truck that is `status == "available"` and not
     already carrying another current route. On success the route is
     rebuilt on the new truck with a **new id `x1`, `x2`, ...** (never
     reusing the old id — `x` marks "created by replan", same spirit as
     `m1`/`m2` marking "created by merge"), logged as one
     `diff.reassigned` entry `{routeId: <new x-id>, fromTruckId:
     <broken>, toTruckId: <new>}`, with the old id in
     `removedRouteIds` and the new id in `addedRouteIds`. Distance/hours
     are unchanged (same hubs/market path, so the leg is identical — only
     the truck changed); `truckCost` is recomputed as the new truck's
     `costPerKm × distanceKm`; spoilage/income are unaffected by *which*
     truck carries the same cargo over the same route at the same elapsed
     time, so they're recomputed from the same formula and come out equal
     — all four are run back through `_score_route_from_leg()` (the helper
     `_try_merge()` also uses) rather than special-cased, so a future
     change to that formula automatically applies here too.
  2. **Attach to another route (fallback)** — if no replacement truck
     fits, `logic._try_attach_to_existing_route()` looks (sorted by id,
     first fit wins) for another **current** route that shares the
     orphan's `marketId` and whose *own* truck has spare `capacityKg` for
     the combined load. Unlike step 1, the target route keeps its own id
     and truck — it just gains the orphan's farmers/hubs, and its
     distance/hours/spoilage/income/truckCost are recomputed the same way
     (union of hubs via `HubRoute`, same leg-scoring helper). The orphan's
     old id is removed; nothing is added (the surviving route's id didn't
     change).
  3. **Unserved (last resort)** — if neither works, the route is dropped:
     its id goes in `removedRouteIds`, nothing is added, and
     `diff.notes` names every unserved farmer by id and kg so the UI/tests
     can show exactly who lost pickup and why.
- **`score.agent`** after a `truck_breakdown` is the same kg-weighted
  `spoilagePct` / summed `income`/`truckCost` shape as `merge_routes()`,
  computed from the plan actually left standing after the event (not the
  pre-event merged plan). `score.baseline` is always a fresh
  `compute_baseline()` — unaffected by any event, same as `merge_routes()`.
- **`explanation`** is a deterministic sentence built from the real diff,
  e.g. `"Truck WP CAB-1001 broke down. Route m1 (5 farmers, 880 kg) moved
  to truck CP CAB-1500. No farmers are unserved. Spoilage rose by 0.8
  points."` — one clause per affected route (moved / attached / removed),
  then an unserved-farmer count, then the aggregate spoilage delta
  (pre-event merged plan vs. post-event plan).
- **`messages`** has one `Message` per farmer who was on an affected
  route, using a fixed per-language (`en`/`si`/`ta`), per-outcome
  (reassigned/attached/unserved) template
  (`logic.BREAKDOWN_MESSAGE_TEMPLATES`), always `isFallback=True` — this is
  the deterministic version; a later block swaps these for
  `llm.farmer_message()`. The Sinhala/Tamil text is machine-drafted, same
  caveat as `llm.jac`'s `FARMER_MESSAGE_FALLBACKS`: have a native speaker
  sanity-check before the demo.
- **Demo scenario** (`data.jac`'s `DEMO_BREAKDOWN_SCENARIO`): breaking `WP
  CAB-1001` (the 1000kg truck, after the 5-farmer merge demo put all 880kg
  on it) should land on step 1 above once `pick_replacement_truck` is
  implemented — `CP CAB-1500`/`MH CAB-2000` are both big enough.

## Known gaps / open items for the team

- `models.jac`'s `Harvest` node still has no edge linking it to its
  `Farmer` or `Hub` — the loader and `compute_baseline()` both rely on the
  documented convention that `[root-->][?:Farmer]` and
  `[root-->][?:Harvest]` come back in the same creation order as
  `SEED_FARMERS`/`SEED_HARVESTS` (parallel lists), verified by the "every
  harvest appears in exactly one route" test. A real edge would be more
  robust if the convention ever becomes hard to keep in sync.
- `logic.pick_best_merge()` is implemented (no longer a stub) — real
  merges now happen, so `merge_routes()`'s `agent` score beats its
  `baseline`.
- `logic.pick_replacement_truck()` is the current deliberate stub (always
  returns `None`) — until it's implemented, every `truck_breakdown`
  reassignment attempt falls through to the attach-to-existing-route
  fallback or, failing that, drops the route as unserved. Several tests in
  `logic.test.jac`/`api.test.jac` are EXPECTED to fail until it's
  implemented (documented inline at each one, same pattern
  `pick_best_merge` used to follow).
- This was validated locally with the `jac` CLI available in this
  environment; if that differs from the version the team standardised on
  (per the playbook's 9:15 version-match step), re-run `jac check` against
  the agreed version before merging.
