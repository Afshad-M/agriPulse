"""agriPulse - Deterministic Planning Logic (owner: A).

Scoring, baseline assignment, route merging, and replanning. This is plain
deterministic code - it never delegates a numeric computation to an LLM
(see CLAUDE.md and llm.jac). compute_baseline() and run_merge_routes() are
real; pick_best_merge() is a deliberate stub (see its TODO); score_route
and replan are still stubs until that work lands.
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
        truck_cost: float;
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
# shape rule in jac-sv-endpoints.
def compute_baseline() -> list[BaselineRoute] {
    farmers = [root -->][?:Farmer];
    harvests = [root -->][?:Harvest];
    trucks = [root -->][?:Truck];

    routes: list[BaselineRoute] = [];
    i = 0;
    for (farmer, harvest) in zip(farmers, harvests) {
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

# farmer jid -> that farmer's single Harvest. Built once per merge_routes()
# call (same association compute_baseline() itself relies on: `[root-->]`
# filtered by type preserves SEED_FARMERS/SEED_HARVESTS' parallel order).
def _harvest_by_farmer_id() -> dict[str, Harvest] {
    farmers = [root -->][?:Farmer];
    harvests = [root -->][?:Harvest];
    out: dict[str, Harvest] = {};
    for (farmer, harvest) in zip(farmers, harvests) {
        out[jid(farmer)] = harvest;
    }
    return out;
}

def _route_kg(route: BaselineRoute, harvest_by_farmer: dict[str, Harvest]) -> float {
    total = 0.0;
    for fid in route.farmer_ids {
        total += harvest_by_farmer[fid].quantity_kg;
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

# Builds (and scores) the merged route candidate for A+B, or None if no
# truck fits the combined kg or no path connects the union of hubs to the
# shared market. `route_id` is a placeholder during candidate-scoring
# (doesn't affect delta); the real id (m1, m2, ...) is assigned on apply.
def _try_merge(
    a: BaselineRoute, b: BaselineRoute, trucks: list[Truck],
    harvest_by_farmer: dict[str, Harvest], route_id: str,
) -> BaselineRoute | None {
    combined_farmer_ids = a.farmer_ids + b.farmer_ids;
    combined_hub_ids = a.hub_ids + b.hub_ids;
    combined_kg = _route_kg(a, harvest_by_farmer) + _route_kg(b, harvest_by_farmer);

    truck = _smallest_fitting_truck_or_none(trucks, combined_kg);
    if truck is None {
        return None;
    }

    leg = _merged_leg(combined_hub_ids, a.market_id);
    if leg is None {
        return None;
    }

    elapsed = MERGED.waiting_hours + leg.hours;
    total_income = 0.0;
    total_kg = 0.0;
    spoiled_kg = 0.0;
    for fid in combined_farmer_ids {
        harvest = harvest_by_farmer[fid];
        price = leg.market.prices.get(harvest.crop, 0.0);
        score = score_cargo(harvest.quantity_kg, price, elapsed, harvest.shelf_life_hours, 0.0);
        total_income += score.revenue;
        total_kg += harvest.quantity_kg;
        spoiled_kg += harvest.quantity_kg * score.loss;
    }
    spoilage_pct = (spoiled_kg / total_kg * 100.0) if total_kg > 0.0 else 0.0;
    truck_cost = truck.cost_per_km * leg.distance_km;

    unique_hub_ids: list[str] = [];
    for h in combined_hub_ids {
        if h not in unique_hub_ids {
            unique_hub_ids.append(h);
        }
    }

    return BaselineRoute(
        id=route_id,
        truck_id=jid(truck),
        farmer_ids=combined_farmer_ids,
        hub_ids=unique_hub_ids,
        market_id=a.market_id,
        distance_km=leg.distance_km,
        hours=leg.hours,
        spoilage_pct=spoilage_pct,
        expected_income=total_income,
        truck_cost=truck_cost,
    );
}

# Every pair of distinct routes sharing a marketId whose combined kg fits
# some available truck. O(n^2) over routes, fine at this seed's scale.
def _build_merge_candidates(
    routes: list[BaselineRoute], trucks: list[Truck], harvest_by_farmer: dict[str, Harvest],
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
                merged = _try_merge(a, b, trucks, harvest_by_farmer, "");
                if merged is not None {
                    kg_a = _route_kg(a, harvest_by_farmer);
                    kg_b = _route_kg(b, harvest_by_farmer);
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
            farmer_ids=r.farmer_ids, hub_ids=r.hub_ids, market_id=r.market_id,
            distance_km=r.distance_km, hours=r.hours, spoilage_pct=r.spoilage_pct,
            expected_income=r.expected_income, truck_cost=r.truck_cost,
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
    harvest_by_farmer = _harvest_by_farmer_id();

    steps: list[MergeStepRecord] = [];
    max_passes = len(routes);
    merge_count = 0;
    pass_no = 0;
    while pass_no < max_passes {
        candidates = _build_merge_candidates(routes, trucks, harvest_by_farmer);
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
        merged = _try_merge(route_a, route_b, trucks, harvest_by_farmer, new_id);
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

walker ReplanOnEvent {
    """Recompute the plan after a disruption event (e.g. a closed route)."""
    has reason: str = "",
        reports: list[Plan] = [];

    can run with Root entry {
        # TODO(A): recompute plan after self.reason disrupts the graph.
        skip;
    }
}
