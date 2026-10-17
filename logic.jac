"""agriPulse - Deterministic Planning Logic (owner: A).

Scoring, baseline assignment, route merging, and replanning. This is plain
deterministic code - it never delegates a numeric computation to an LLM
(see CLAUDE.md and llm.jac). compute_baseline() is real (reads the graph
load_seed() built in api.jac); score_route, merge, and replan are still
stubs until that work lands.
"""

import from models { Farmer, Harvest, Hub, Market, Truck, Plan, DeliversTo, HubMarketRoute }

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

walker MergeRoutes {
    """Consolidate overlapping hub<->market routes into merged Plan(s)."""
    has reports: list[Plan] = [];

    can run with Root entry {
        # TODO(A): merge/consolidate overlapping routes.
        skip;
    }
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
