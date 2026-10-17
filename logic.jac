"""agriPulse - Deterministic Planning Logic (owner: A).

Scoring, baseline assignment, route merging, and replanning. This is plain
deterministic code - it never delegates a numeric computation to an LLM
(see CLAUDE.md and llm.jac). compute_baseline(), run_merge_routes() and
apply_replan_event()'s "truck_breakdown" handling are real; pick_best_merge()
is implemented too. pick_replacement_truck() is a deliberate stub (see its
TODO); score_route and the other replan event types are still stubs until
that work lands.
"""

import from models { Farmer, Harvest, Hub, Market, Truck, Plan, DeliversTo, HubRoute, HubMarketRoute, Assignment }

def score_route(distance_km: float, hours: float, open: bool) -> float {
    # TODO(A): deterministic scoring formula over distance/hours/open.
    return 0.0;
}

obj CargoScore {
    has loss: float,
        revenue: float,
        value: float;
}


def score_cargo(kg: float, price: float, elapsed_hours: float, shelf_life_hours: float, truck_cost: float) -> CargoScore {
    loss = 1.0;
    if shelf_life_hours > 0.0 {
        loss = min(1.0, elapsed_hours / shelf_life_hours);
    }
    revenue = kg * price * (1.0 - loss);
    value = revenue - truck_cost;
    return CargoScore(loss=loss, revenue=revenue, value=value);
}

obj BaselineAssumptions {
    """The ONE place every baseline assumption/magic-number lives.
    See docs/assumptions.md for the written-out rationale for each value."""
    has waiting_hours: float = 10.0,
        default_truck_cost_for_score: float = 0.0,
        assumed_farmer_to_hub_km: float = 8.0;
}

glob BASELINE: BaselineAssumptions = BaselineAssumptions();

obj BaselineRoute {
    """One solo-trip route + its plan numbers, in snake_case engine shape.
    api.jac (A) converts this into the contract's RouteInfo/PlanInfo - this
    type never crosses the wire itself."""
    has id: str,
        truck_id: str,
        farmer_ids: list[str],
        hub_ids: list[str],
        market_id: str,
        distance_km: float,
        hours: float,
        spoilage_pct: float,
        expected_income: float,
        truck_cost: float,
        harvest_ids: list[str] = [];
}

obj MarketRoute {
    has market: Market,
        distance_km: float,
        hours: float;
}

# The hub's fastest (lowest hours) open HubMarketRoute.
def _fastest_open_market_route(hub: Hub) -> MarketRoute {
    markets = [hub ->:HubMarketRoute:open:->];
    edges = [edge hub ->:HubMarketRoute:open:->];
    best_i = 0;
    i = 0;
    for e in edges {
        if e.hours < edges[best_i].hours {
            best_i = i;
        }
        i += 1;
    }
    return MarketRoute(market=markets[best_i], distance_km=edges[best_i].distance_km, hours=edges[best_i].hours);
}

# The lowest-capacity truck that still fits kg; the largest truck if none fit.
def _smallest_fitting_truck(trucks: list[Truck], kg: float) -> Truck {
    by_capacity = sorted(trucks, key=_truck_capacity);
    for t in by_capacity {
        if t.capacity_kg >= kg {
            return t;
        }
    }
    return by_capacity[-1];
}

def _truck_capacity(t: Truck) -> float {
    return t.capacity_kg;
}

# Resolves the Farmer that owns `harvest`: Harvest.farmer_id (set by
# api.jac's seed loader and by the new_harvest handler) when present,
# else the farmer at the SAME POSITION in `farmers` as `harvest` is in
# `harvests` - the original pairing convention (data.jac: "SEED_HARVESTS[i]
# belongs to SEED_FARMERS[i]"), kept as a fallback so fixtures/tests that
# build a Harvest without farmer_id (one harvest per farmer, in creation
# order) keep working unchanged.
def _farmer_for_harvest(harvest: Harvest, harvests: list[Harvest], farmers: list[Farmer]) -> Farmer | None {
    if harvest.farmer_id != "" {
        try {
            f = jobj(harvest.farmer_id);
        } except Exception {
            f = None;
        }
        if f is not None and isinstance(f, Farmer) {
            return f;
        }
    }
    i = 0;
    for h in harvests {
        if jid(h) == jid(harvest) {
            if i < len(farmers) {
                return farmers[i];
            }
            return None;
        }
        i += 1;
    }
    return None;
}

# Every harvest ships SOLO on the smallest truck that fits it. elapsed =
# BASELINE.waiting_hours + the harvest's hub's fastest open hub->market
# travel hours (the farmer->hub leg has no travel-time data anywhere in
# the project, so it is NOT added to elapsed - see docs/assumptions.md).
# score_cargo is called with truck_cost=0 (its `value` field is unused
# here); the real per-route truck cost is costPerKm x distanceKm, where
# distanceKm = BASELINE.assumed_farmer_to_hub_km + the hub->market leg's
# distance_km (models.jac's DeliversTo edge carries no distance field, so
# the farmer->hub leg is a flat assumed constant, not real data - see
# docs/assumptions.md). Reads `root` directly - the graph load_seed()
# built - rather than taking it as parameters, per the function/no-visit
# shape rule in jac-sv-endpoints. Iterates HARVESTS (not farmer<->harvest
# pairs) so a farmer with more than one Harvest (new_harvest) gets one
# baseline route per harvest, each tagged with its own harvest_ids - see
# _farmer_for_harvest above and docs/assumptions.md.
def compute_baseline() -> list[BaselineRoute] {
    farmers = [root -->][?:Farmer];
    harvests = [root -->][?:Harvest];
    trucks = [root -->][?:Truck];

    routes: list[BaselineRoute] = [];
    i = 0;
    for harvest in harvests {
        farmer = _farmer_for_harvest(harvest, harvests, farmers);
        if farmer is None {
            continue;
        }
        hub_list = [farmer ->:DeliversTo:->];
        if len(hub_list) == 0 {
            continue;
        }
        hub = hub_list[0];
        leg = _fastest_open_market_route(hub);
        truck = _smallest_fitting_truck(trucks, harvest.quantity_kg);

        elapsed = BASELINE.waiting_hours + leg.hours;
        price = leg.market.prices.get(harvest.crop, 0.0);
        score = score_cargo(
            harvest.quantity_kg, price, elapsed, harvest.shelf_life_hours,
            BASELINE.default_truck_cost_for_score,
        );
        distance_km = BASELINE.assumed_farmer_to_hub_km + leg.distance_km;
        truck_cost = truck.cost_per_km * distance_km;

        i += 1;
        routes.append(BaselineRoute(
            id=f"r{i}",
            truck_id=jid(truck),
            farmer_ids=[jid(farmer)],
            harvest_ids=[jid(harvest)],
            hub_ids=[jid(hub)],
            market_id=jid(leg.market),
            distance_km=distance_km,
            hours=leg.hours,
            spoilage_pct=score.loss * 100.0,
            expected_income=score.revenue,
            truck_cost=truck_cost,
        ));
    }
    return routes;
}

# ---- Merge engine (owner: A) -----------------------------------------
# Combines baseline solo routes into shared routes so the agent score beats
# the baseline. A plain function, not a walker: it never `visit`s - it
# iterates a list.append()ed by compute_baseline() plus a handful of graph
# reads, so the function/no-visit shape rule in jac-sv-endpoints applies
# (the former `walker MergeRoutes` stub is replaced by run_merge_routes()
# below). See docs/assumptions.md for MERGED.waiting_hours and why it
# differs from BASELINE.waiting_hours.

obj MergedAssumptions {
    """The ONE place every merge assumption/magic-number lives, next to
    BaselineAssumptions. See docs/assumptions.md for the rationale."""
    has waiting_hours: float = 3.0;
}

glob MERGED: MergedAssumptions = MergedAssumptions();

# Field names match CONTRACT v1's MergeStep exactly (stepNo, mergedRouteIds,
# newRouteId, reason) even though this type lives in logic.jac, not api.jac -
# api.jac imports this type directly rather than redeclaring an identical
# one, since logic.jac cannot import api.jac's MergeStep without a circular
# import (api.jac already imports compute_baseline from logic.jac).
obj MergeStepRecord {
    has stepNo: int,
        mergedRouteIds: list[str],
        newRouteId: str,
        reason: str;
}

# Field names match CONTRACT v1's phrasing exactly, per the spec for this type.
obj MergeCandidate {
    has idA: str,
        idB: str,
        delta: float,            # net value of the merged route - summed net value of A and B
        spoilageChangePts: float, # merged spoilagePct - the kg-weighted average of A and B's
        tripsSaved: int;          # always 1 for a pairwise candidate (2 routes -> 1)
}

# TODO(user): return the candidate with the highest positive `delta`; on a
# tie, the one with the lowest (idA, idB) pair when candidates are sorted
# by (idA, idB) - so every run gives identical output. Return None when
# `candidates` is empty or every delta is <= 0.0 (no merge is worth doing).


def pick_best_merge(candidates: list[MergeCandidate]) -> MergeCandidate | None {
    best: MergeCandidate | None = None;
    for c in candidates {
        if c.delta <= 0.0 {
            continue;
        }
        if best is None {
            best = c;
        } elif c.delta > best.delta {
            best = c;
        } elif c.delta == best.delta {
            if c.idA < best.idA or (c.idA == best.idA and c.idB < best.idB) {
                best = c;
            }
        }
    }
    return best;
}

def _net_value(route: BaselineRoute) -> float {
    return route.expected_income - route.truck_cost;
}

def _route_by_id(routes: list[BaselineRoute], route_id: str) -> BaselineRoute | None {
    for r in routes {
        if r.id == route_id {
            return r;
        }
    }
    return None;
}

# harvest jid -> that Harvest. Keyed by harvest id (not farmer id) so a
# farmer with more than one Harvest (new_harvest) is never ambiguous -
# every BaselineRoute carries the exact harvest_ids it was built from.
def _harvest_by_id() -> dict[str, Harvest] {
    out: dict[str, Harvest] = {};
    for h in [root -->][?:Harvest] {
        out[jid(h)] = h;
    }
    return out;
}

def _route_kg(route: BaselineRoute, harvest_by_id: dict[str, Harvest]) -> float {
    total = 0.0;
    for hid in route.harvest_ids {
        total += harvest_by_id[hid].quantity_kg;
    }
    return total;
}

def _smallest_fitting_truck_or_none(trucks: list[Truck], kg: float) -> Truck | None {
    by_capacity = sorted(trucks, key=_truck_capacity);
    for t in by_capacity {
        if t.capacity_kg >= kg {
            return t;
        }
    }
    return None;
}

obj HubLeg {
    has distance_km: float,
        hours: float;
}

# The open HubRoute edge from `a` to `b`, in EITHER direction - data.jac's
# SEED_HUB_ROUTES only lists one direction per pair.
def _directed_hub_leg(a: Hub, b: Hub) -> HubLeg | None {
    targets = [a ->:HubRoute:open:->];
    edges = [edge a ->:HubRoute:open:->];
    k = 0;
    for t in targets {
        if jid(t) == jid(b) {
            return HubLeg(distance_km=edges[k].distance_km, hours=edges[k].hours);
        }
        k += 1;
    }
    return None;
}

def _hub_to_hub_leg(a: Hub, b: Hub) -> HubLeg | None {
    leg = _directed_hub_leg(a, b);
    if leg is not None {
        return leg;
    }
    return _directed_hub_leg(b, a);
}

# The open HubMarketRoute from `hub` to this SPECIFIC `market` (not "any
# fastest market" - the merge must land on the market both candidates share).
def _hub_to_market_leg(hub: Hub, market: Market) -> HubLeg | None {
    targets = [hub ->:HubMarketRoute:open:->];
    edges = [edge hub ->:HubMarketRoute:open:->];
    k = 0;
    for t in targets {
        if jid(t) == jid(market) {
            return HubLeg(distance_km=edges[k].distance_km, hours=edges[k].hours);
        }
        k += 1;
    }
    return None;
}

# Distance/hours for visiting the union of `hub_ids` in order, then
# `market_id`. None if any leg (hub->hub or the final hub->market) doesn't
# exist in the graph - the candidate is then rejected (no path).
def _merged_leg(hub_ids: list[str], market_id: str) -> MarketRoute | None {
    unique_hub_ids: list[str] = [];
    for h in hub_ids {
        if h not in unique_hub_ids {
            unique_hub_ids.append(h);
        }
    }

    total_distance = 0.0;
    total_hours = 0.0;
    i = 0;
    while i < len(unique_hub_ids) - 1 {
        hub_a = jobj(unique_hub_ids[i]);
        hub_b = jobj(unique_hub_ids[i + 1]);
        if hub_a is None or hub_b is None or not isinstance(hub_a, Hub) or not isinstance(hub_b, Hub) {
            return None;
        }
        leg = _hub_to_hub_leg(hub_a, hub_b);
        if leg is None {
            return None;
        }
        total_distance += leg.distance_km;
        total_hours += leg.hours;
        i += 1;
    }

    last_hub = jobj(unique_hub_ids[-1]);
    market = jobj(market_id);
    if last_hub is None or market is None or not isinstance(last_hub, Hub) or not isinstance(market, Market) {
        return None;
    }
    market_leg = _hub_to_market_leg(last_hub, market);
    if market_leg is None {
        return None;
    }
    total_distance += market_leg.distance_km;
    total_hours += market_leg.hours;

    return MarketRoute(market=market, distance_km=total_distance, hours=total_hours);
}

# Shared by _try_merge() and the replan/truck-breakdown engine below: scores
# a route (any farmer_ids + the leg they share + the truck carrying them)
# under MERGED.waiting_hours. Pulled out so reassigning a route to a
# replacement truck (same farmers/hubs/market, different truck) reuses the
# exact same formula as merging two routes, rather than a hand-rolled copy.
obj RouteScore {
    has distance_km: float,
        hours: float,
        spoilage_pct: float,
        expected_income: float,
        truck_cost: float;
}

def _score_route_from_leg(
    harvest_ids: list[str], leg: MarketRoute, truck: Truck, harvest_by_id: dict[str, Harvest],
) -> RouteScore {
    elapsed = MERGED.waiting_hours + leg.hours;
    total_income = 0.0;
    total_kg = 0.0;
    spoiled_kg = 0.0;
    for hid in harvest_ids {
        harvest = harvest_by_id[hid];
        price = leg.market.prices.get(harvest.crop, 0.0);
        score = score_cargo(harvest.quantity_kg, price, elapsed, harvest.shelf_life_hours, 0.0);
        total_income += score.revenue;
        total_kg += harvest.quantity_kg;
        spoiled_kg += harvest.quantity_kg * score.loss;
    }
    spoilage_pct = (spoiled_kg / total_kg * 100.0) if total_kg > 0.0 else 0.0;
    truck_cost = truck.cost_per_km * leg.distance_km;
    return RouteScore(
        distance_km=leg.distance_km, hours=leg.hours, spoilage_pct=spoilage_pct,
        expected_income=total_income, truck_cost=truck_cost,
    );
}

def _dedupe(ids: list[str]) -> list[str] {
    out: list[str] = [];
    for i in ids {
        if i not in out {
            out.append(i);
        }
    }
    return out;
}

# Builds (and scores) the merged route candidate for A+B, or None if no
# truck fits the combined kg or no path connects the union of hubs to the
# shared market. `route_id` is a placeholder during candidate-scoring
# (doesn't affect delta); the real id (m1, m2, ...) is assigned on apply.
def _try_merge(
    a: BaselineRoute, b: BaselineRoute, trucks: list[Truck],
    harvest_by_id: dict[str, Harvest], route_id: str,
) -> BaselineRoute | None {
    combined_farmer_ids = a.farmer_ids + b.farmer_ids;
    combined_harvest_ids = a.harvest_ids + b.harvest_ids;
    combined_hub_ids = a.hub_ids + b.hub_ids;
    combined_kg = _route_kg(a, harvest_by_id) + _route_kg(b, harvest_by_id);

    truck = _smallest_fitting_truck_or_none(trucks, combined_kg);
    if truck is None {
        return None;
    }

    leg = _merged_leg(combined_hub_ids, a.market_id);
    if leg is None {
        return None;
    }

    score = _score_route_from_leg(combined_harvest_ids, leg, truck, harvest_by_id);

    return BaselineRoute(
        id=route_id,
        truck_id=jid(truck),
        farmer_ids=combined_farmer_ids,
        harvest_ids=combined_harvest_ids,
        hub_ids=_dedupe(combined_hub_ids),
        market_id=a.market_id,
        distance_km=score.distance_km,
        hours=score.hours,
        spoilage_pct=score.spoilage_pct,
        expected_income=score.expected_income,
        truck_cost=score.truck_cost,
    );
}

# Every pair of distinct routes sharing a marketId whose combined kg fits
# some available truck. O(n^2) over routes, fine at this seed's scale.
def _build_merge_candidates(
    routes: list[BaselineRoute], trucks: list[Truck], harvest_by_id: dict[str, Harvest],
) -> list[MergeCandidate] {
    candidates: list[MergeCandidate] = [];
    n = len(routes);
    i = 0;
    while i < n {
        j = i + 1;
        while j < n {
            a = routes[i];
            b = routes[j];
            if a.market_id == b.market_id {
                merged = _try_merge(a, b, trucks, harvest_by_id, "");
                if merged is not None {
                    kg_a = _route_kg(a, harvest_by_id);
                    kg_b = _route_kg(b, harvest_by_id);
                    weighted_before = (kg_a * a.spoilage_pct + kg_b * b.spoilage_pct) / (kg_a + kg_b);
                    candidates.append(MergeCandidate(
                        idA=a.id, idB=b.id,
                        delta=_net_value(merged) - (_net_value(a) + _net_value(b)),
                        spoilageChangePts=merged.spoilage_pct - weighted_before,
                        tripsSaved=1,
                    ));
                }
            }
            j += 1;
        }
        i += 1;
    }
    return candidates;
}

def _merge_reason(a: BaselineRoute, b: BaselineRoute, candidate: MergeCandidate) -> str {
    direction = "down" if candidate.spoilageChangePts < 0.0 else "up";
    magnitude = abs(candidate.spoilageChangePts);
    trip_word = "trip" if candidate.tripsSaved == 1 else "trips";
    return (
        f"Combined {a.id} and {b.id} on one truck: saves {candidate.tripsSaved} {trip_word}, "
        + f"spoilage {direction} {magnitude:.1f} points, net value up LKR {candidate.delta:,.0f}"
    );
}

# Wipes and rewrites every Plan node from `routes` - the persisted "current
# plan" a later replan step is meant to read/update (see models.jac).
def _persist_current_plan(routes: list[BaselineRoute]) -> None {
    for p in [root -->][?:Plan] {
        del p;
    }
    for r in routes {
        plan = Plan(
            status="current", route_id=r.id, truck_id=r.truck_id,
            farmer_ids=r.farmer_ids, harvest_ids=r.harvest_ids, hub_ids=r.hub_ids,
            market_id=r.market_id, distance_km=r.distance_km, hours=r.hours,
            spoilage_pct=r.spoilage_pct, expected_income=r.expected_income, truck_cost=r.truck_cost,
        );
        root ++> plan;
        truck = jobj(r.truck_id);
        if truck is not None and isinstance(truck, Truck) {
            truck +>:Assignment():+> plan;
        }
    }
}

# Resets to a fresh baseline (compute_baseline() has no side effects, so
# this is naturally idempotent - calling merge_routes() twice reads the
# same Farmer/Harvest/Hub/Truck graph and runs the same deterministic
# algorithm). Each pass builds candidates, asks pick_best_merge for the
# one to apply, removes the two originals and adds the merged route
# (m1, m2, ...), and logs one MergeStepRecord - until no candidate has a
# positive delta, or after as many passes as there were starting routes.
# The final routes are persisted as the graph's "current plan".
def run_merge_routes() -> list[MergeStepRecord] {
    routes: list[BaselineRoute] = compute_baseline();
    trucks = [root -->][?:Truck];
    harvest_by_id = _harvest_by_id();

    steps: list[MergeStepRecord] = [];
    max_passes = len(routes);
    merge_count = 0;
    pass_no = 0;
    while pass_no < max_passes {
        candidates = _build_merge_candidates(routes, trucks, harvest_by_id);
        best = pick_best_merge(candidates);
        if best is None {
            break;
        }

        route_a = _route_by_id(routes, best.idA);
        route_b = _route_by_id(routes, best.idB);
        if route_a is None or route_b is None {
            break;
        }

        merge_count += 1;
        new_id = f"m{merge_count}";
        merged = _try_merge(route_a, route_b, trucks, harvest_by_id, new_id);
        if merged is None {
            break;
        }

        routes = [r for r in routes if r.id != best.idA and r.id != best.idB];
        routes.append(merged);

        steps.append(MergeStepRecord(
            stepNo=len(steps) + 1,
            mergedRouteIds=[best.idA, best.idB],
            newRouteId=new_id,
            reason=_merge_reason(route_a, route_b, best),
        ));

        pass_no += 1;
    }

    _persist_current_plan(routes);
    return steps;
}

# ---- Replan engine (owner: A) -----------------------------------------
# apply_replan_event() handles disruption events deterministically, the
# same function/no-visit shape as run_merge_routes() above (no walker - see
# its comment). Only "truck_breakdown" is handled for real this round; every
# other type (including unknown ones) is a documented no-op. See
# docs/assumptions.md for the full rules (x1/x2 ids, fallback order,
# "a truck serves one route at a time").
#
# The wire Event/Diff/Reassignment/Message types live in api.jac (CONTRACT
# v1), so this module mirrors them field-for-field under its own names -
# same reason MergeStepRecord mirrors MergeStep above: api.jac already
# imports from logic.jac, so logic.jac importing back from api.jac would be
# circular. api.jac's replan_on_event() converts 1:1.

obj TruckInfo {
    has id: str,
        name: str,
        capacityKg: float,
        costPerKm: float,
        status: str;
}

obj ReassignmentRecord {
    has routeId: str,
        fromTruckId: str,
        toTruckId: str;
}

obj DiffRecord {
    has removedRouteIds: list[str],
        addedRouteIds: list[str],
        reassigned: list[ReassignmentRecord],
        notes: str;
}

obj MessageRecord {
    has farmerId: str,
        farmerName: str,
        language: str,
        text: str,
        isFallback: bool = True;
}

obj ReplanOutcome {
    has diff: DiffRecord,
        explanation: str,
        messages: list[MessageRecord];
}

# TODO(user): return the smallest-capacityKg truck in `free_trucks` whose
# capacityKg is at least route_kg; on an exact capacity tie, the one with
# the lowest id. None if `free_trucks` is empty or nothing in it fits.
# Deliberately left as a stub - see docs/assumptions.md and CLAUDE.md
# (the agent/LLM never computes this kind of number; a human does).


def pick_replacement_truck(route_kg: float, free_trucks: list[TruckInfo]) -> str | None {
    best: TruckInfo | None = None;
    for t in free_trucks {
        if t.capacityKg < route_kg {
            continue;
        }
        if best is None {
            best = t;
        } elif t.capacityKg < best.capacityKg {
            best = t;
        } elif t.capacityKg == best.capacityKg and t.id < best.id {
            best = t;
        }
    }
    if best is None {
        return None;
    }
    return best.id;
}

def _all_trucks() -> list[Truck] {
    return [root -->][?:Truck];
}

def _truck_info(t: Truck) -> TruckInfo {
    return TruckInfo(id=jid(t), name=t.plate, capacityKg=t.capacity_kg, costPerKm=t.cost_per_km, status=t.status);
}

def _route_id_key(r: BaselineRoute) -> str {
    return r.id;
}

def _farmer_name(fid: str) -> str {
    f = jobj(fid);
    if f is not None and isinstance(f, Farmer) {
        return f.name;
    }
    return fid;
}

def _farmer_language(fid: str) -> str {
    f = jobj(fid);
    if f is not None and isinstance(f, Farmer) {
        return f.language;
    }
    return "en";
}

# Reads the Plan nodes run_merge_routes() just persisted back into the
# BaselineRoute shape, so the replan engine can keep operating on the same
# type merge/baseline already use.
def _routes_from_plans() -> list[BaselineRoute] {
    plans = [root -->][?:Plan];
    return [
        BaselineRoute(
            id=p.route_id, truck_id=p.truck_id, farmer_ids=p.farmer_ids, harvest_ids=p.harvest_ids,
            hub_ids=p.hub_ids, market_id=p.market_id, distance_km=p.distance_km, hours=p.hours,
            spoilage_pct=p.spoilage_pct, expected_income=p.expected_income, truck_cost=p.truck_cost,
        )
        for p in plans
    ];
}

# kg-weighted spoilagePct (0-100) across a list of routes - same shape as
# api.jac's _aggregate_score_from_routes, but over BaselineRoute directly
# (no RouteInfo/PlanInfo round-trip needed inside logic.jac).
def _kg_weighted_spoilage(routes: list[BaselineRoute], harvest_by_id: dict[str, Harvest]) -> float {
    total_kg = 0.0;
    spoiled_kg = 0.0;
    for r in routes {
        kg = _route_kg(r, harvest_by_id);
        total_kg += kg;
        spoiled_kg += kg * (r.spoilage_pct / 100.0);
    }
    return (spoiled_kg / total_kg * 100.0) if total_kg > 0.0 else 0.0;
}

# Fallback for a route whose truck broke down with no free replacement:
# try to fold its farmers onto another CURRENT route (sorted by id, first
# fit wins) that already shares its marketId and whose existing truck has
# spare capacity_kg for the combined load. Unlike pick_replacement_truck,
# this never swaps the target's truck - "a truck serves one route at a
# time" (docs/assumptions.md), so the target keeps its own truck_id/id and
# just carries more farmers. None if no such route exists.
def _try_attach_to_existing_route(
    orphan: BaselineRoute, candidates: list[BaselineRoute], trucks_by_id: dict[str, Truck],
    harvest_by_id: dict[str, Harvest],
) -> BaselineRoute | None {
    for target in sorted(candidates, key=_route_id_key) {
        if target.market_id != orphan.market_id {
            continue;
        }
        truck = trucks_by_id.get(target.truck_id);
        if truck is None {
            continue;
        }
        combined_kg = _route_kg(target, harvest_by_id) + _route_kg(orphan, harvest_by_id);
        if combined_kg > truck.capacity_kg {
            continue;
        }
        combined_hub_ids = _dedupe(target.hub_ids + orphan.hub_ids);
        leg = _merged_leg(combined_hub_ids, target.market_id);
        if leg is None {
            continue;
        }
        combined_farmer_ids = target.farmer_ids + orphan.farmer_ids;
        combined_harvest_ids = target.harvest_ids + orphan.harvest_ids;
        score = _score_route_from_leg(combined_harvest_ids, leg, truck, harvest_by_id);
        return BaselineRoute(
            id=target.id, truck_id=target.truck_id, farmer_ids=combined_farmer_ids,
            harvest_ids=combined_harvest_ids, hub_ids=combined_hub_ids,
            market_id=target.market_id, distance_km=score.distance_km, hours=score.hours,
            spoilage_pct=score.spoilage_pct, expected_income=score.expected_income, truck_cost=score.truck_cost,
        );
    }
    return None;
}

# Deterministic per-language, per-outcome farmer notification templates -
# the fallback this block always uses (isFallback=True); a later block
# swaps these for llm.farmer_message(). Sinhala/Tamil text is machine-
# drafted, same caveat as llm.jac's FARMER_MESSAGE_FALLBACKS: please have a
# native speaker sanity-check before the demo.
glob BREAKDOWN_MESSAGE_TEMPLATES: dict[str, str] = {
    "en:reassigned": "Your harvest pickup is still happening - a replacement truck will collect it as planned.",
    "en:attached": "Your harvest pickup is still happening - it will now travel together with another route.",
    "en:unserved": "We're sorry - a truck breakdown means we could not arrange pickup for your harvest right now. We will follow up with next steps.",
    "si:reassigned": "ට්‍රක් රථය කැඩී ගිය නිසා ඔබේ අස්වැන්න රැගෙන යාමට වෙනත් ට්‍රක් රථයක් යොදවා ඇත.",
    "si:attached": "ට්‍රක් රථය කැඩී ගිය නිසා ඔබේ අස්වැන්න දැන් තවත් මගක් සමඟ ඒකාබද්ධ කර ඇත.",
    "si:unserved": "කණගාටුයි, ට්‍රක් රථය කැඩී යාම නිසා ඔබේ අස්වැන්න දැනට රැගෙන යා නොහැක. කණ්ඩායම ඉක්මනින් සම්බන්ධ වනු ඇත.",
    "ta:reassigned": "லாரி பழுதடைந்ததால் உங்கள் அறுவடையை சேகரிக்க வேறு லாரி ஏற்பாடு செய்யப்பட்டுள்ளது.",
    "ta:attached": "லாரி பழுதடைந்ததால் உங்கள் அறுவடை இப்போது மற்றொரு பாதையுடன் இணைக்கப்பட்டுள்ளது.",
    "ta:unserved": "வருந்துகிறோம், லாரி பழுதடைந்ததால் தற்போது உங்கள் அறுவடையை சேகரிக்க முடியவில்லை. குழு விரைவில் தொடர்பு கொள்ளும்.",
};

def _breakdown_message_text(language: str, outcome: str) -> str {
    key = f"{language}:{outcome}";
    if key in BREAKDOWN_MESSAGE_TEMPLATES {
        return BREAKDOWN_MESSAGE_TEMPLATES[key];
    }
    return BREAKDOWN_MESSAGE_TEMPLATES[f"en:{outcome}"];
}

# truck_breakdown: always rebuilds the current plan from a fresh
# run_merge_routes() first (so two calls with the same event are
# identical regardless of what an earlier replan call did), marks the
# truck broken, then resolves each route it was serving in descending-kg
# order (ties broken by the lowest route id - see the `affected` sort
# below): replacement truck (pick_replacement_truck) -> attach to another
# route (already-reassigned or untouched) with spare capacity on the same
# market -> else drop the route and report its farmers unserved. See
# docs/assumptions.md for the full write-up.
def apply_truck_breakdown_event(truck_id: str | None) -> ReplanOutcome {
    if truck_id is None {
        note = "Truck breakdown event is missing a truckId.";
        return ReplanOutcome(
            diff=DiffRecord(removedRouteIds=[], addedRouteIds=[], reassigned=[], notes=note),
            explanation=note, messages=[],
        );
    }
    try {
        truck_obj = jobj(truck_id);
    } except Exception {
        # jobj() raises on a malformed id (e.g. not a UUID) rather than
        # returning None - a truckId can be any client-supplied string, so
        # this is a normal "not found", never a crash.
        truck_obj = None;
    }
    if truck_obj is None or not isinstance(truck_obj, Truck) {
        note = f"Truck {truck_id} does not exist.";
        return ReplanOutcome(
            diff=DiffRecord(removedRouteIds=[], addedRouteIds=[], reassigned=[], notes=note),
            explanation=note, messages=[],
        );
    }

    truck_obj.status = "broken";
    run_merge_routes();
    routes = _routes_from_plans();
    harvest_by_id = _harvest_by_id();
    all_trucks = _all_trucks();
    trucks_by_id: dict[str, Truck] = {};
    for t in all_trucks {
        trucks_by_id[jid(t)] = t;
    }

    old_spoilage = _kg_weighted_spoilage(routes, harvest_by_id);
    # Biggest route first: it gets first pick of the free replacement trucks,
    # so a large route is never starved by smaller ones claiming the spares
    # ahead of it. Ties (equal kg) break on the lowest route id, so the
    # order - and therefore the whole outcome - stays deterministic.
    affected = sorted(
        [r for r in routes if r.truck_id == truck_id],
        key=lambda (r: BaselineRoute) { (-_route_kg(r, harvest_by_id), r.id) },
    );

    if len(affected) == 0 {
        _persist_current_plan(routes);
        note = f"Truck {truck_obj.plate} broke down but was not serving any route.";
        return ReplanOutcome(
            diff=DiffRecord(removedRouteIds=[], addedRouteIds=[], reassigned=[], notes=note),
            explanation=note, messages=[],
        );
    }

    used_truck_ids: set[str] = set();
    for r in routes {
        if r.truck_id != truck_id {
            used_truck_ids.add(r.truck_id);
        }
    }

    working_routes = [r for r in routes if r.truck_id != truck_id];
    removed_ids: list[str] = [];
    added_ids: list[str] = [];
    reassigned: list[ReassignmentRecord] = [];
    sentences: list[str] = [];
    farmer_outcome: dict[str, str] = {};
    unserved_farmer_count = 0;
    x_counter = 0;

    for route in affected {
        removed_ids.append(route.id);
        route_kg = _route_kg(route, harvest_by_id);
        handled = False;

        free_trucks = [_truck_info(t) for t in all_trucks if t.status != "broken" and jid(t) not in used_truck_ids];
        new_truck_id = pick_replacement_truck(route_kg, free_trucks);
        if new_truck_id is not None and new_truck_id in trucks_by_id {
            new_truck = trucks_by_id[new_truck_id];
            leg = _merged_leg(route.hub_ids, route.market_id);
            if leg is not None {
                score = _score_route_from_leg(route.harvest_ids, leg, new_truck, harvest_by_id);
                x_counter += 1;
                new_id = f"x{x_counter}";
                working_routes.append(BaselineRoute(
                    id=new_id, truck_id=new_truck_id, farmer_ids=route.farmer_ids, harvest_ids=route.harvest_ids,
                    hub_ids=route.hub_ids, market_id=route.market_id, distance_km=score.distance_km, hours=score.hours,
                    spoilage_pct=score.spoilage_pct, expected_income=score.expected_income, truck_cost=score.truck_cost,
                ));
                added_ids.append(new_id);
                reassigned.append(ReassignmentRecord(routeId=new_id, fromTruckId=truck_id, toTruckId=new_truck_id));
                used_truck_ids.add(new_truck_id);
                sentences.append(
                    f"Route {route.id} ({len(route.farmer_ids)} farmers, {route_kg:.0f} kg) moved to truck {new_truck.plate}."
                );
                for fid in route.farmer_ids {
                    farmer_outcome[fid] = "reassigned";
                }
                handled = True;
            }
        }

        if not handled {
            target = _try_attach_to_existing_route(route, working_routes, trucks_by_id, harvest_by_id);
            if target is not None {
                working_routes = [target if r.id == target.id else r for r in working_routes];
                sentences.append(
                    f"Route {route.id} ({len(route.farmer_ids)} farmers, {route_kg:.0f} kg) attached to route {target.id}."
                );
                for fid in route.farmer_ids {
                    farmer_outcome[fid] = "attached";
                }
                handled = True;
            }
        }

        if not handled {
            unserved_farmer_count += len(route.farmer_ids);
            farmer_names = [_farmer_name(fid) for fid in route.farmer_ids];
            sentences.append(
                f"Route {route.id} ({len(route.farmer_ids)} farmers, {route_kg:.0f} kg) removed - no spare truck "
                + f"or route capacity for farmer(s) {', '.join(farmer_names)}; they are unserved."
            );
            for fid in route.farmer_ids {
                farmer_outcome[fid] = "unserved";
            }
        }
    }

    _persist_current_plan(working_routes);
    new_spoilage = _kg_weighted_spoilage(working_routes, harvest_by_id);

    if unserved_farmer_count == 0 {
        sentences.append("No farmers are unserved.");
    } else {
        word = "farmer is" if unserved_farmer_count == 1 else "farmers are";
        sentences.append(f"{unserved_farmer_count} {word} unserved.");
    }

    spoilage_delta = new_spoilage - old_spoilage;
    if abs(spoilage_delta) < 1e-9 {
        sentences.append("Spoilage stayed flat.");
    } else {
        direction = "rose" if spoilage_delta > 0.0 else "fell";
        sentences.append(f"Spoilage {direction} by {abs(spoilage_delta):.1f} points.");
    }

    notes = " ".join(sentences);
    explanation = f"Truck {truck_obj.plate} broke down. " + notes;

    messages: list[MessageRecord] = [];
    for route in affected {
        for fid in route.farmer_ids {
            outcome = farmer_outcome.get(fid, "unserved");
            language = _farmer_language(fid);
            messages.append(MessageRecord(
                farmerId=fid, farmerName=_farmer_name(fid), language=language,
                text=_breakdown_message_text(language, outcome), isFallback=True,
            ));
        }
    }

    return ReplanOutcome(
        diff=DiffRecord(removedRouteIds=removed_ids, addedRouteIds=added_ids, reassigned=reassigned, notes=notes),
        explanation=explanation, messages=messages,
    );
}

# Top-level replan entry point - api.jac's replan_on_event() calls this
# with the wire Event's plain fields (never the Event object itself, to
# avoid importing api.jac's type back into logic.jac). Only type +
# truckId are needed for "truck_breakdown"; the other event types are a
# documented no-op until their own block lands.
def apply_replan_event(event_type: str, truck_id: str | None = None) -> ReplanOutcome {
    if event_type == "truck_breakdown" {
        return apply_truck_breakdown_event(truck_id);
    }
    note = f"Event type {event_type} is not handled yet";
    return ReplanOutcome(
        diff=DiffRecord(removedRouteIds=[], addedRouteIds=[], reassigned=[], notes=note),
        explanation=note, messages=[],
    );
}
