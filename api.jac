"""agriPulse - Server Contract Endpoints (owner: A).

Public HTTP contract for scenario setup, baseline planning, route merging,
and replanning on events, per CONTRACT v1. Added alongside endpoints.jac
(the template's guestbook demo, left untouched) rather than replacing it.

The types below are plain data (`obj`, not `node`/`edge`) - the wire
contract, deliberately decoupled from the persisted graph schema in
models.jac. Field names are camelCase exactly as the contract specifies;
fields may be added later but never renamed or removed. Money is LKR.

load_seed(), baseline_plan() and merge_routes() are real: they build the
graph from data.jac's SEED_* records (models.jac node/edge types) and
compute from it (logic.jac.compute_baseline() / run_merge_routes()).
replan_on_event() is real for the "truck_breakdown" event type (delegates
to logic.apply_replan_event(), which depends on logic.pick_replacement_truck(),
a deliberate stub - see its TODO in logic.jac); every other event type is
still a documented no-op until its own block lands.
"""

import from models { Farmer, Harvest, Hub, Market, Truck, Plan, DeliversTo, HubRoute, HubMarketRoute }
import from data {
    SEED_FARMERS, SEED_HARVESTS, SEED_HUBS, SEED_MARKETS, SEED_TRUCKS,
    SEED_FARMER_HUB_LINKS, SEED_HUB_ROUTES, SEED_HUB_MARKET_ROUTES,
    CROP_SHELF_LIFE_HOURS, SEED_FARMER_RECORDS, SEED_HUB_RECORDS,
    SEED_MARKET_RECORDS, SEED_TRUCK_RECORDS,
}
import from logic { compute_baseline, BaselineRoute, run_merge_routes, apply_replan_event }

# ---- Contract data types -----------------------------------------------

obj FarmerInfo {
    has id: str,
        name: str,
        district: str,
        language: str;      # "si" | "ta" | "en"
}

obj HarvestInfo {
    has id: str,
        farmerId: str,
        crop: str,
        kg: float,
        readyHour: float,
        shelfLifeHours: float;
}

obj HubInfo {
    has id: str,
        name: str,
        district: str;
}

obj MarketInfo {
    has id: str,
        name: str,
        prices: dict[str, float],   # LKR per kg, keyed by crop
        demandCapKg: float;
}

obj TruckInfo {
    has id: str,
        name: str,
        capacityKg: float,
        costPerKm: float,
        status: str;        # "available" | "broken"
}

obj RouteInfo {
    has id: str,
        truckId: str,
        farmerIds: list[str],
        hubIds: list[str],
        marketId: str,
        distanceKm: float,
        hours: float;
}

obj PlanInfo {
    has routeId: str,
        expectedSpoilagePct: float,   # 0-100, not a 0-1 fraction
        expectedIncome: float,
        truckCost: float;
}

obj State {
    has farmers: list[FarmerInfo] = [],
        harvests: list[HarvestInfo] = [],
        hubs: list[HubInfo] = [],
        markets: list[MarketInfo] = [],
        trucks: list[TruckInfo] = [],
        routes: list[RouteInfo] = [],
        plans: list[PlanInfo] = [];
}

obj ScoreSet {
    has spoilagePct: float,
        income: float,
        truckCost: float;
}

obj Score {
    has baseline: ScoreSet,
        agent: ScoreSet;
}

obj MergeStep {
    has stepNo: int,
        mergedRouteIds: list[str],
        newRouteId: str,
        reason: str;
}

obj Reassignment {
    has routeId: str,
        fromTruckId: str,
        toTruckId: str;
}

obj Diff {
    has removedRouteIds: list[str],
        addedRouteIds: list[str],
        reassigned: list[Reassignment],
        notes: str;
}

obj Message {
    has farmerId: str,
        farmerName: str,
        language: str,
        text: str,
        isFallback: bool = False;
}

obj Event {
    has type: str,           # "truck_breakdown" | "road_closed" | "price_crash" | "new_harvest"
        truckId: str | None = None,    # truck_breakdown
        edgeId: str | None = None,     # road_closed
        marketId: str | None = None,   # price_crash
        crop: str | None = None,       # price_crash (optional) / new_harvest
        text: str | None = None;       # new_harvest, free-text from the farmer
}

# ---- Endpoint result types ----------------------------------------------

obj LoadSeedResult {
    has state: State;
}

obj BaselinePlanResult {
    has state: State,
        score: Score;
}

obj MergeRoutesResult {
    has steps: list[MergeStep],
        state: State,
        score: Score;
}

obj ReplanResult {
    has diff: Diff,
        state: State,
        score: Score,
        explanation: str,
        messages: list[Message];
}

# ---- Real graph loader (owner: A) -----------------------------------------
# Builds the graph from data.jac's SEED_* records, using the node/edge
# types in models.jac. Cross-references by the matching NAME field shared
# between data.jac's two seed shapes (e.g. a Market's `name` is the same
# string in both SEED_MARKETS and SEED_MARKET_RECORDS) to fill in the
# camelCase-contract fields models.jac's original node shape didn't carry
# (Farmer.language, Hub.district, Market.prices, Truck.cost_per_km,
# Harvest.shelf_life_hours) - see docs/assumptions.md for the full list.

def _clear_seeded_graph() -> None {
    for n in [root -->][?:Farmer] { del n; }
    for n in [root -->][?:Harvest] { del n; }
    for n in [root -->][?:Hub] { del n; }
    for n in [root -->][?:Market] { del n; }
    for n in [root -->][?:Truck] { del n; }
}

def _build_seed_graph() -> None {
    _clear_seeded_graph();

    farmer_lang_by_name: dict[str, str] = {};
    for rec in SEED_FARMER_RECORDS {
        farmer_lang_by_name[rec["name"]] = rec["language"];
    }
    hub_district_by_name: dict[str, str] = {};
    for rec in SEED_HUB_RECORDS {
        hub_district_by_name[rec["name"]] = rec["district"];
    }
    market_prices_by_name: dict[str, dict[str, float]] = {};
    for rec in SEED_MARKET_RECORDS {
        market_prices_by_name[rec["name"]] = rec["prices"];
    }
    truck_cost_by_name: dict[str, float] = {};
    for rec in SEED_TRUCK_RECORDS {
        truck_cost_by_name[rec["name"]] = rec["costPerKm"];
    }

    hub_by_name: dict[str, Hub] = {};
    for h in SEED_HUBS {
        hub_node = Hub(
            name=h.name, capacity_kg=h.capacity_kg,
            district=hub_district_by_name.get(h.name, ""),
        );
        root ++> hub_node;
        hub_by_name[h.name] = hub_node;
    }

    market_by_name: dict[str, Market] = {};
    for m in SEED_MARKETS {
        market_node = Market(
            name=m.name, demand_kg=m.demand_kg,
            prices=market_prices_by_name.get(m.name, {}),
        );
        root ++> market_node;
        market_by_name[m.name] = market_node;
    }

    for t in SEED_TRUCKS {
        root ++> Truck(
            plate=t.plate, capacity_kg=t.capacity_kg,
            cost_per_km=truck_cost_by_name.get(t.plate, 0.0),
        );
    }

    farmer_by_name: dict[str, Farmer] = {};
    for f in SEED_FARMERS {
        farmer_node = Farmer(
            name=f.name, phone=f.phone, location=f.location,
            language=farmer_lang_by_name.get(f.name, ""),
        );
        root ++> farmer_node;
        farmer_by_name[f.name] = farmer_node;
    }

    for h in SEED_HARVESTS {
        root ++> Harvest(
            crop=h.crop, quantity_kg=h.quantity_kg, harvested_at=h.harvested_at,
            shelf_life_hours=CROP_SHELF_LIFE_HOURS.get(h.crop, 0.0),
        );
    }

    for link in SEED_FARMER_HUB_LINKS {
        farmer = farmer_by_name.get(link["farmer_name"]);
        hub = hub_by_name.get(link["hub_name"]);
        if farmer is not None and hub is not None {
            farmer +>:DeliversTo():+> hub;
        }
    }

    for r in SEED_HUB_ROUTES {
        a = hub_by_name.get(r["from_hub"]);
        b = hub_by_name.get(r["to_hub"]);
        if a is not None and b is not None {
            a +>:HubRoute(distance_km=r["distance_km"], hours=r["hours"], open=r["open"]):+> b;
        }
    }

    for r in SEED_HUB_MARKET_ROUTES {
        hub = hub_by_name.get(r["from_hub"]);
        market = market_by_name.get(r["to_market"]);
        if hub is not None and market is not None {
            hub +>:HubMarketRoute(distance_km=r["distance_km"], hours=r["hours"], open=r["open"]):+> market;
        }
    }
}

# readyHour is always 0.0: every data.jac Harvest's harvested_at is already
# in the past (a negative hour offset, e.g. "-2h"), so every seeded harvest
# is ready for pickup immediately - see docs/assumptions.md.
def _real_state(routes: list[RouteInfo] = [], plans: list[PlanInfo] = []) -> State {
    farmers = [root -->][?:Farmer];
    harvests = [root -->][?:Harvest];
    hubs = [root -->][?:Hub];
    markets = [root -->][?:Market];
    trucks = [root -->][?:Truck];

    farmer_infos = [
        FarmerInfo(id=jid(f), name=f.name, district=f.location, language=f.language)
        for f in farmers
    ];
    harvest_infos = [
        HarvestInfo(
            id=jid(harvest), farmerId=jid(farmer), crop=harvest.crop,
            kg=harvest.quantity_kg, readyHour=0.0, shelfLifeHours=harvest.shelf_life_hours,
        )
        for (farmer, harvest) in zip(farmers, harvests)
    ];
    hub_infos = [HubInfo(id=jid(h), name=h.name, district=h.district) for h in hubs];
    market_infos = [
        MarketInfo(id=jid(m), name=m.name, prices=m.prices, demandCapKg=m.demand_kg)
        for m in markets
    ];
    truck_infos = [
        TruckInfo(id=jid(t), name=t.plate, capacityKg=t.capacity_kg, costPerKm=t.cost_per_km, status=t.status)
        for t in trucks
    ];

    return State(
        farmers=farmer_infos, harvests=harvest_infos, hubs=hub_infos,
        markets=market_infos, trucks=truck_infos, routes=routes, plans=plans,
    );
}

# kg-weighted spoilagePct average across baseline routes; income and
# truckCost are plain sums. agent == baseline for now (task 4).
def _aggregate_score(baseline_routes: list[BaselineRoute]) -> Score {
    total_income = 0.0;
    total_truck_cost = 0.0;
    total_kg = 0.0;
    spoiled_kg = 0.0;

    harvests = [root -->][?:Harvest];
    for (route, harvest) in zip(baseline_routes, harvests) {
        total_income += route.expected_income;
        total_truck_cost += route.truck_cost;
        total_kg += harvest.quantity_kg;
        spoiled_kg += harvest.quantity_kg * (route.spoilage_pct / 100.0);
    }
    spoilage_pct = (spoiled_kg / total_kg * 100.0) if total_kg > 0.0 else 0.0;

    baseline = ScoreSet(spoilagePct=spoilage_pct, income=total_income, truckCost=total_truck_cost);
    return Score(baseline=baseline, agent=baseline);
}

# ---- Endpoints ------------------------------------------------------------

def:pub load_seed() -> LoadSeedResult {
    # Idempotent: wipes and rebuilds the graph from data.jac's SEED_*
    # records every call - same counts on repeat calls, no duplicates.
    _build_seed_graph();
    return LoadSeedResult(state=_real_state());
}

def:pub baseline_plan() -> BaselinePlanResult {
    baseline_routes = compute_baseline();
    routes = [
        RouteInfo(
            id=r.id, truckId=r.truck_id, farmerIds=r.farmer_ids, hubIds=r.hub_ids,
            marketId=r.market_id, distanceKm=r.distance_km, hours=r.hours,
        )
        for r in baseline_routes
    ];
    plans = [
        PlanInfo(
            routeId=r.id, expectedSpoilagePct=r.spoilage_pct,
            expectedIncome=r.expected_income, truckCost=r.truck_cost,
        )
        for r in baseline_routes
    ];
    return BaselinePlanResult(
        state=_real_state(routes=routes, plans=plans),
        score=_aggregate_score(baseline_routes),
    );
}

# ---- Real merge (owner: A) -------------------------------------------
# run_merge_routes() (logic.jac) persists the merged "current plan" as
# Plan nodes - these helpers read that back into the contract shape.
# logic.MergeStepRecord already uses CONTRACT v1's exact field names
# (stepNo, mergedRouteIds, newRouteId, reason), so converting to api.jac's
# MergeStep is a 1:1 rename of the type only.

def _current_plan_route_infos() -> list[RouteInfo] {
    plans = [root -->][?:Plan];
    return [
        RouteInfo(
            id=p.route_id, truckId=p.truck_id, farmerIds=p.farmer_ids,
            hubIds=p.hub_ids, marketId=p.market_id, distanceKm=p.distance_km, hours=p.hours,
        )
        for p in plans
    ];
}

def _current_plan_plan_infos() -> list[PlanInfo] {
    plans = [root -->][?:Plan];
    return [
        PlanInfo(
            routeId=p.route_id, expectedSpoilagePct=p.spoilage_pct,
            expectedIncome=p.expected_income, truckCost=p.truck_cost,
        )
        for p in plans
    ];
}

def _kg_by_farmer_id() -> dict[str, float] {
    farmers = [root -->][?:Farmer];
    harvests = [root -->][?:Harvest];
    out: dict[str, float] = {};
    for (farmer, harvest) in zip(farmers, harvests) {
        out[jid(farmer)] = harvest.quantity_kg;
    }
    return out;
}

# Same kg-weighted-spoilage/summed-income/summed-truckCost shape as
# _aggregate_score, but generic over any RouteInfo/PlanInfo list (not just
# one-harvest-per-route baseline routes) - a merged route can carry
# several farmerIds, so kg is summed per route from State.harvests rather
# than assumed 1:1 with a positional harvest.
def _aggregate_score_from_routes(routes: list[RouteInfo], plans: list[PlanInfo]) -> ScoreSet {
    kg_by_farmer = _kg_by_farmer_id();
    plan_by_route_id: dict[str, PlanInfo] = {};
    for p in plans {
        plan_by_route_id[p.routeId] = p;
    }

    total_income = 0.0;
    total_truck_cost = 0.0;
    total_kg = 0.0;
    spoiled_kg = 0.0;
    for r in routes {
        plan = plan_by_route_id.get(r.id);
        if plan is None {
            continue;
        }
        route_kg = 0.0;
        for fid in r.farmerIds {
            route_kg += kg_by_farmer.get(fid, 0.0);
        }
        total_income += plan.expectedIncome;
        total_truck_cost += plan.truckCost;
        total_kg += route_kg;
        spoiled_kg += route_kg * (plan.expectedSpoilagePct / 100.0);
    }
    spoilage_pct = (spoiled_kg / total_kg * 100.0) if total_kg > 0.0 else 0.0;
    return ScoreSet(spoilagePct=spoilage_pct, income=total_income, truckCost=total_truck_cost);
}

def:pub merge_routes() -> MergeRoutesResult {
    baseline_score = _aggregate_score(compute_baseline()).baseline;

    merge_steps = run_merge_routes();
    steps = [
        MergeStep(stepNo=s.stepNo, mergedRouteIds=s.mergedRouteIds, newRouteId=s.newRouteId, reason=s.reason)
        for s in merge_steps
    ];

    routes = _current_plan_route_infos();
    plans = _current_plan_plan_infos();
    agent_score = _aggregate_score_from_routes(routes, plans);

    return MergeRoutesResult(
        steps=steps,
        state=_real_state(routes=routes, plans=plans),
        score=Score(baseline=baseline_score, agent=agent_score),
    );
}

def:pub replan_on_event(event: Event) -> ReplanResult {
    outcome = apply_replan_event(event.type, event.truckId);

    routes = _current_plan_route_infos();
    plans = _current_plan_plan_infos();
    baseline_score = _aggregate_score(compute_baseline()).baseline;
    agent_score = _aggregate_score_from_routes(routes, plans);

    diff = Diff(
        removedRouteIds=outcome.diff.removedRouteIds,
        addedRouteIds=outcome.diff.addedRouteIds,
        reassigned=[
            Reassignment(routeId=r.routeId, fromTruckId=r.fromTruckId, toTruckId=r.toTruckId)
            for r in outcome.diff.reassigned
        ],
        notes=outcome.diff.notes,
    );
    messages = [
        Message(farmerId=m.farmerId, farmerName=m.farmerName, language=m.language, text=m.text, isFallback=m.isFallback)
        for m in outcome.messages
    ];

    return ReplanResult(
        diff=diff,
        state=_real_state(routes=routes, plans=plans),
        score=Score(baseline=baseline_score, agent=agent_score),
        explanation=outcome.explanation,
        messages=messages,
    );
}
