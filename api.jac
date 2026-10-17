"""agriPulse - Server Contract Endpoints (owner: A).

Public HTTP contract for scenario setup, baseline planning, route merging,
and replanning on events, per CONTRACT v1. Added alongside endpoints.jac
(the template's guestbook demo, left untouched) rather than replacing it.

The types below are plain data (`obj`, not `node`/`edge`) - the wire
contract, deliberately decoupled from the persisted graph schema in
models.jac. Field names are camelCase exactly as the contract specifies;
fields may be added later but never renamed or removed. Money is LKR.

STUB: every endpoint currently returns a fixed placeholder seed (3 farmers,
2 hubs, 1 market, 2 trucks, 3 solo routes + 1 merged route, 2 merge steps,
one Diff, one fallback Message) instead of real scoring/merge/replan logic.
Real logic lands later in logic.jac (A) and data.jac (C).
"""

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

# ---- STUB placeholder seed ------------------------------------------------
# One shared tiny seed so every list is non-empty until data.jac (C) and
# logic.jac (A) land. Not derived from any real computation.

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
    # STUB: returns the fixed placeholder seed; real seeding comes from data.jac.
    return LoadSeedResult(state=_placeholder_state());
}

def:pub baseline_plan() -> BaselinePlanResult {
    # STUB: no real scoring yet; call logic.baseline_plan() here once it lands.
    return BaselinePlanResult(state=_placeholder_state(), score=_placeholder_score());
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
