"""agriPulse - Server Contract Endpoints (owner: A).

Public HTTP contract for scenario setup, baseline planning, route merging,
and replanning on events, per CONTRACT v1. Added alongside endpoints.jac
(the template's guestbook demo, left untouched) rather than replacing it.

The types below are plain data (`obj`, not `node`/`edge`) - the wire
contract, deliberately decoupled from the persisted graph schema in
models.jac. Field names are camelCase exactly as the contract specifies;
fields may be added later but never renamed or removed. Money is LKR.

load_seed() and baseline_plan() are real: they build the graph from
data.jac's SEED_* records (models.jac node/edge types) and compute the
baseline from it (logic.jac.compute_baseline()). merge_routes() and
replan_on_event() are still STUB - unchanged, returning the fixed
placeholder seed, until that work lands.
"""

import from models { Farmer, Harvest, Hub, Market, Truck, DeliversTo, HubRoute, HubMarketRoute }
import from data {
    SEED_FARMERS, SEED_HARVESTS, SEED_HUBS, SEED_MARKETS, SEED_TRUCKS,
    SEED_FARMER_HUB_LINKS, SEED_HUB_ROUTES, SEED_HUB_MARKET_ROUTES,
    CROP_SHELF_LIFE_HOURS, SEED_FARMER_RECORDS, SEED_HUB_RECORDS,
    SEED_MARKET_RECORDS, SEED_TRUCK_RECORDS,
}
import from logic { compute_baseline, BaselineRoute }

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
        TruckInfo(id=jid(t), name=t.plate, capacityKg=t.capacity_kg, costPerKm=t.cost_per_km, status="available")
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

# ---- STUB placeholder seed ------------------------------------------------
# Still used by merge_routes()/replan_on_event(), which are not real yet.

def _placeholder_state() -> State {
    farmers = [
        FarmerInfo(id="f1", name="Kamal Perera", district="Kandy", language="si"),
        FarmerInfo(id="f2", name="Nirmala Silva", district="Matale", language="si"),
        FarmerInfo(id="f3", name="Suresh Kumar", district="Jaffna", language="ta"),
    ];
    harvests = [
        HarvestInfo(id="h1", farmerId="f1", crop="Tomato", kg=500.0, readyHour=6.0, shelfLifeHours=48.0),
        HarvestInfo(id="h2", farmerId="f2", crop="Banana", kg=300.0, readyHour=7.0, shelfLifeHours=72.0),
        HarvestInfo(id="h3", farmerId="f3", crop="Rice", kg=800.0, readyHour=5.0, shelfLifeHours=240.0),
    ];
    hubs = [
        HubInfo(id="hub1", name="Kandy Hub", district="Kandy"),
        HubInfo(id="hub2", name="Matale Hub", district="Matale"),
    ];
    markets = [
        MarketInfo(
            id="mk1",
            name="Dambulla Economic Centre",
            prices={"Tomato": 120.0, "Banana": 80.0, "Rice": 150.0},
            demandCapKg=2000.0,
        ),
    ];
    trucks = [
        TruckInfo(id="t1", name="Truck A", capacityKg=1000.0, costPerKm=45.0, status="available"),
        TruckInfo(id="t2", name="Truck B", capacityKg=1500.0, costPerKm=60.0, status="available"),
    ];
    routes = [
        RouteInfo(id="r1", truckId="t1", farmerIds=["f1"], hubIds=["hub1"], marketId="mk1", distanceKm=42.0, hours=1.1),
        RouteInfo(id="r2", truckId="t1", farmerIds=["f2"], hubIds=["hub1"], marketId="mk1", distanceKm=38.0, hours=1.0),
        RouteInfo(id="r3", truckId="t2", farmerIds=["f3"], hubIds=["hub2"], marketId="mk1", distanceKm=55.0, hours=1.4),
        RouteInfo(id="r4", truckId="t1", farmerIds=["f1", "f2"], hubIds=["hub1"], marketId="mk1", distanceKm=40.0, hours=1.05),
    ];
    plans = [
        PlanInfo(routeId="r1", expectedSpoilagePct=10.0, expectedIncome=55000.0, truckCost=1890.0),
        PlanInfo(routeId="r2", expectedSpoilagePct=8.0, expectedIncome=22000.0, truckCost=1710.0),
        PlanInfo(routeId="r3", expectedSpoilagePct=15.0, expectedIncome=100000.0, truckCost=3300.0),
        PlanInfo(routeId="r4", expectedSpoilagePct=7.0, expectedIncome=76000.0, truckCost=1800.0),
    ];
    return State(
        farmers=farmers, harvests=harvests, hubs=hubs, markets=markets,
        trucks=trucks, routes=routes, plans=plans,
    );
}

def _placeholder_score() -> Score {
    return Score(
        baseline=ScoreSet(spoilagePct=12.0, income=150000.0, truckCost=6000.0),
        agent=ScoreSet(spoilagePct=9.0, income=153000.0, truckCost=5900.0),
    );
}

def _placeholder_merge_steps() -> list[MergeStep] {
    return [
        MergeStep(
            stepNo=1, mergedRouteIds=["r1", "r2"], newRouteId="r4",
            reason="STUB: same hub and market, overlapping pickup window.",
        ),
        MergeStep(
            stepNo=2, mergedRouteIds=["r3"], newRouteId="r3",
            reason="STUB: kept solo - different hub, no compatible match.",
        ),
    ];
}

def _placeholder_diff() -> Diff {
    return Diff(
        removedRouteIds=["r3"],
        addedRouteIds=["r5"],
        reassigned=[Reassignment(routeId="r2", fromTruckId="t1", toTruckId="t2")],
        notes="STUB: placeholder diff, not derived from the actual event yet.",
    );
}

def _placeholder_messages() -> list[Message] {
    return [
        Message(
            farmerId="f1", farmerName="Kamal Perera", language="si",
            text="STUB: your harvest pickup is confirmed.", isFallback=True,
        ),
    ];
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

def:pub merge_routes() -> MergeRoutesResult {
    # STUB: no real merge logic yet; spawn logic.MergeRoutes() here once it lands.
    return MergeRoutesResult(
        steps=_placeholder_merge_steps(), state=_placeholder_state(), score=_placeholder_score(),
    );
}

def:pub replan_on_event(event: Event) -> ReplanResult {
    # STUB: ignores event's actual contents; spawn logic.ReplanOnEvent(event=event) once it lands.
    return ReplanResult(
        diff=_placeholder_diff(),
        state=_placeholder_state(),
        score=_placeholder_score(),
        explanation="STUB: explanation generation not implemented yet.",
        messages=_placeholder_messages(),
    );
}
