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
import from logic { compute_baseline, BaselineRoute, run_merge_routes, apply_replan_event, ReplanOutcome }
import from llm { explain, farmer_message, parse_harvest, EXPLAIN_FALLBACK, FARMER_MESSAGE_FALLBACKS }

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
        hours: float,
        harvestIds: list[str] = [];
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
        text: str | None = None,       # new_harvest, free-text from the farmer
        farmerId: str | None = None;   # new_harvest, which farmer sent `text`
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

    for (f, h) in zip(SEED_FARMERS, SEED_HARVESTS) {
        root ++> Harvest(
            crop=h.crop, quantity_kg=h.quantity_kg, harvested_at=h.harvested_at,
            shelf_life_hours=CROP_SHELF_LIFE_HOURS.get(h.crop, 0.0),
            farmer_id=jid(farmer_by_name[f.name]),
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

# readyHour is 0.0 for every SEEDED harvest: every data.jac Harvest's
# harvested_at is already in the past (a negative hour offset, e.g. "-2h"),
# so every seeded harvest is ready for pickup immediately - see
# docs/assumptions.md. A harvest added live via the "new_harvest" event
# carries whatever readyHour its farmer's message implied (default 0.0).
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
            id=jid(harvest), farmerId=harvest.farmer_id, crop=harvest.crop,
            kg=harvest.quantity_kg, readyHour=harvest.ready_hour, shelfLifeHours=harvest.shelf_life_hours,
        )
        for harvest in harvests
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
            harvestIds=p.harvest_ids,
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

def _kg_by_harvest_id() -> dict[str, float] {
    out: dict[str, float] = {};
    for h in [root -->][?:Harvest] {
        out[jid(h)] = h.quantity_kg;
    }
    return out;
}

# Same kg-weighted-spoilage/summed-income/summed-truckCost shape as
# _aggregate_score, but generic over any RouteInfo/PlanInfo list (not just
# one-harvest-per-route baseline routes) - a merged route can carry
# several harvestIds (a farmer can contribute more than one, e.g. after
# new_harvest), so kg is summed per route by harvest id, never by farmer
# id, to stay unambiguous.
def _aggregate_score_from_routes(routes: list[RouteInfo], plans: list[PlanInfo]) -> ScoreSet {
    kg_by_harvest = _kg_by_harvest_id();
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
        for hid in r.harvestIds {
            route_kg += kg_by_harvest.get(hid, 0.0);
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

# ---- LLM hookup (owner: A - calls into llm.jac's by-llm functions, owner
# C, without editing that file) --------------------------------------------
# logic.jac stays deterministic (CLAUDE.md): apply_replan_event() already
# computes a real explanation string and one template Message per AFFECTED
# farmer (reassigned/attached/unserved), always isFallback=True. The helpers
# below optionally upgrade that deterministic result with llm.explain() /
# llm.farmer_message() - numbers still come entirely from this module/
# logic.jac, never from the model - and fall back to the deterministic
# text whenever the call raises, times out, or comes back empty. Both
# llm.jac functions already swallow their own exceptions and return a
# labelled fallback string; comparing against that exact sentinel (rather
# than trusting any non-exception return) is what lets us tell "the model
# really answered" apart from "llm.jac quietly used its own fallback".

# Caps the number of farmer_message() calls per replan so the endpoint
# answers in a few seconds even though byllm calls are made one at a time
# (sequentially) rather than concurrently - a wider breakdown just means
# more farmers ride the (already-correct) deterministic template below the
# cap. 6 was chosen as comfortably more than this scaffold's demo breakdown
# scenarios ever affect in one event, while still bounding worst case
# latency to a handful of sequential model calls.
glob MAX_LLM_FARMER_MESSAGES: int = 6;

def _truck_plate(truck_id: str | None) -> str {
    if truck_id is None {
        return "unknown";
    }
    try {
        t = jobj(truck_id);
    } except Exception {
        t = None;
    }
    if t is not None and isinstance(t, Truck) {
        return t.plate;
    }
    return truck_id;
}

def _route_by_farmer_id(routes: list[RouteInfo]) -> dict[str, RouteInfo] {
    out: dict[str, RouteInfo] = {};
    for r in routes {
        for fid in r.farmerIds {
            out[fid] = r;
        }
    }
    return out;
}

def _truck_plate_by_id() -> dict[str, str] {
    out: dict[str, str] = {};
    for t in [root -->][?:Truck] {
        out[jid(t)] = t.plate;
    }
    return out;
}

# explanation: facts-only plan_summary (event type, broken truck name, the
# deterministic diff notes, spoilage/income before -> after) handed to
# llm.explain(); the model never sees or computes any number it isn't
# simply restating from this string.
def _build_explanation(event: Event, outcome: ReplanOutcome, before: ScoreSet, after: ScoreSet) -> str {
    truck_name = _truck_plate(event.truckId);
    plan_summary = (
        f"Event type: {event.type}. Broken truck: {truck_name}. {outcome.diff.notes} "
        + f"Spoilage changed from {before.spoilagePct:.1f}% to {after.spoilagePct:.1f}%. "
        + f"Income changed from LKR {before.income:.0f} to LKR {after.income:.0f}."
    );
    try {
        llm_text = explain(plan_summary);
    } except Exception {
        return outcome.explanation;
    }
    if llm_text is None or llm_text.strip() == "" or llm_text == EXPLAIN_FALLBACK {
        return outcome.explanation;
    }
    return llm_text;
}

# messages: one per outcome.messages entry (already exactly the AFFECTED
# farmers - logic.jac never builds one for an untouched farmer). Farmers
# whose route disappeared entirely (after_route is None - the "unserved"
# template logic.jac already wrote: pickup couldn't be rescheduled, the
# operator will call) never get an llm.farmer_message() call - there is no
# "new truck/route" fact to personalize for them. Served farmers
# (reassigned onto a new route id, or attached onto an existing one) are
# upgraded in outcome.messages order up to MAX_LLM_FARMER_MESSAGES; the
# rest keep logic.jac's per-language template, isFallback=True.
def _build_messages(outcome: ReplanOutcome, routes_after: list[RouteInfo]) -> list[Message] {
    route_by_farmer = _route_by_farmer_id(routes_after);
    truck_plate_by_id = _truck_plate_by_id();
    added_ids: set[str] = set(outcome.diff.addedRouteIds);

    messages: list[Message] = [];
    llm_calls_used = 0;

    for m in outcome.messages {
        after_route = route_by_farmer.get(m.farmerId);
        if after_route is None {
            # Unserved - keep logic.jac's deterministic "could not be
            # rescheduled, operator will call" template. No LLM call.
            messages.append(Message(
                farmerId=m.farmerId, farmerName=m.farmerName, language=m.language,
                text=m.text, isFallback=True,
            ));
            continue;
        }

        truck_name = truck_plate_by_id.get(after_route.truckId, after_route.truckId);
        text = m.text;
        is_fallback = True;

        if llm_calls_used < MAX_LLM_FARMER_MESSAGES {
            llm_calls_used += 1;
            if after_route.id in added_ids {
                change = f"Their pickup moved to a new truck, {truck_name}, on route {after_route.id}.";
            } else {
                change = f"Their pickup is now combined onto route {after_route.id}, handled by truck {truck_name}.";
            }
            plan_summary = (
                f"Farmer {m.farmerName}'s original pickup truck broke down. " + change
                + " The pickup itself is still happening, just with this new arrangement."
            );
            fallback_text = FARMER_MESSAGE_FALLBACKS.get(m.language, FARMER_MESSAGE_FALLBACKS["en"]);
            llm_text: str | None = None;
            try {
                llm_text = farmer_message(plan_summary, m.language);
            } except Exception {
                llm_text = None;
            }
            if llm_text is not None and llm_text.strip() != "" and llm_text != fallback_text {
                text = llm_text;
                is_fallback = False;
            }
        }

        messages.append(Message(
            farmerId=m.farmerId, farmerName=m.farmerName, language=m.language,
            text=text, isFallback=is_fallback,
        ));
    }
    return messages;
}

# ---- new_harvest (owner: A) -----------------------------------------
# A deterministic, code-only parser for a farmer's free-text harvest
# report - "80kg beans, ready in 2 hours" and friends. Runs BEFORE
# llm.parse_harvest() is ever consulted (CLAUDE.md: the LLM is never
# required) and is good enough on its own to power the whole feature with
# no API key configured. Splits digit/letter runs apart so "80kg" and
# "80 kg" tokenize the same way, without a regex dependency.
def _tokenize(text: str) -> list[str] {
    out: list[str] = [];
    buf = "";
    buf_kind = "";   # "digit" | "alpha" | ""
    for ch in text.lower() {
        if ch.isdigit() or ch == "." {
            kind = "digit";
        } elif ch.isalpha() {
            kind = "alpha";
        } else {
            kind = "";
        }
        if kind == "" {
            if buf != "" {
                out.append(buf);
                buf = "";
            }
            buf_kind = "";
            continue;
        }
        if buf_kind != "" and buf_kind != kind {
            out.append(buf);
            buf = "";
        }
        buf += ch;
        buf_kind = kind;
    }
    if buf != "" {
        out.append(buf);
    }
    return out;
}

def _is_number(tok: str) -> bool {
    try {
        float(tok);
        return True;
    } except Exception {
        return False;
    }
}

glob KG_UNIT_WORDS: set[str] = {"kg", "kgs", "kilo", "kilos", "kilogram", "kilograms"};

# "beans" is already the plural-only crop key data.jac/CROP_SHELF_LIFE_HOURS
# uses, so "bean"/"beans" both map to it; the others get their plain -s.
glob CROP_SURFACE_FORMS: dict[str, str] = {
    "tomato": "tomato", "tomatoes": "tomato",
    "bean": "beans", "beans": "beans",
    "carrot": "carrot", "carrots": "carrot",
};

def _extract_crop(tokens: list[str]) -> str {
    n = len(tokens);
    i = 0;
    while i < n {
        if i < n - 1 and tokens[i] == "leafy" and tokens[i + 1] in ("green", "greens") {
            return "leafy_greens";
        }
        if tokens[i] in CROP_SURFACE_FORMS {
            return CROP_SURFACE_FORMS[tokens[i]];
        }
        i += 1;
    }
    return "";
}

def _normalize_crop(raw: str) -> str {
    return _extract_crop(_tokenize(raw));
}

obj ParsedHarvest {
    has ok: bool = False,
        crop: str = "",
        quantity_kg: float = 0.0,
        ready_hour: float = 0.0;
}

# Deterministic parse of a farmer's free-text harvest report. `ok` is True
# only once BOTH a kg quantity (a number immediately followed by a kg/kilo
# unit word) and a known crop are found; `ready_hour` is read independently
# ("ready [in] N hours", default 0.0) so it still comes through even on a
# partial match that an LLM fallback later completes.
def parse_harvest_text(text: str) -> ParsedHarvest {
    tokens = _tokenize(text);
    n = len(tokens);

    quantity_kg = 0.0;
    found_qty = False;
    i = 0;
    while i < n - 1 {
        if _is_number(tokens[i]) and tokens[i + 1] in KG_UNIT_WORDS {
            quantity_kg = float(tokens[i]);
            found_qty = True;
            break;
        }
        i += 1;
    }

    crop = _extract_crop(tokens);

    ready_hour = 0.0;
    i = 0;
    while i < n {
        if tokens[i] == "ready" {
            j = i + 1;
            if j < n and tokens[j] == "in" {
                j += 1;
            }
            if j < n and _is_number(tokens[j]) {
                ready_hour = float(tokens[j]);
            }
            break;
        }
        i += 1;
    }

    return ParsedHarvest(ok=found_qty and crop != "", crop=crop, quantity_kg=quantity_kg, ready_hour=ready_hour);
}

# llm.parse_harvest() is consulted ONLY when the deterministic parser above
# couldn't find a crop+kg - never required, and its crop is re-validated
# against the same known-crop list before being trusted (CLAUDE.md: by
# llm() output is never trusted blindly). llm.jac's HarvestDraft has no
# notion of "ready in N hours", so ready_hour always comes from the
# deterministic pass, even on this upgrade path.
def _parse_new_harvest(text: str) -> ParsedHarvest {
    parsed = parse_harvest_text(text);
    if parsed.ok {
        return parsed;
    }
    try {
        draft = parse_harvest(text);
    } except Exception {
        return parsed;
    }
    if draft.is_fallback {
        return parsed;
    }
    crop = _normalize_crop(draft.crop);
    if crop == "" or draft.quantity_kg <= 0.0 {
        return parsed;
    }
    return ParsedHarvest(ok=True, crop=crop, quantity_kg=draft.quantity_kg, ready_hour=parsed.ready_hour);
}

def _crop_display(crop: str) -> str {
    return crop.replace("_", " ");
}

def _farmer_by_id(fid: str | None) -> Farmer | None {
    if fid is None or fid == "" {
        return None;
    }
    try {
        f = jobj(fid);
    } except Exception {
        return None;
    }
    if f is not None and isinstance(f, Farmer) {
        return f;
    }
    return None;
}

glob NEW_HARVEST_PARSE_FAILURE_NOTE: str = "I couldn't understand that. Try: 80kg beans, ready in 2 hours.";

# Deterministic per-language confirmation templates (isFallback=True), same
# machine-drafted-Sinhala/Tamil caveat as llm.jac's FARMER_MESSAGE_FALLBACKS
# and logic.jac's BREAKDOWN_MESSAGE_TEMPLATES - have a native speaker check
# these before the demo.
def _new_harvest_message_text(language: str, crop_display: str, kg: float, truck_name: str) -> str {
    if language == "si" {
        return f"ඔබේ {crop_display} කිලෝ {kg:.0f}ක් ලැබී ඇත. එය {truck_name} රථය මගින් රැගෙන යනු ඇත.";
    } elif language == "ta" {
        return f"உங்கள் {crop_display} {kg:.0f} கிலோ பதிவு செய்யப்பட்டது. இதை {truck_name} லாரி சேகரிக்கும்.";
    }
    return f"We've recorded {kg:.0f} kg of {crop_display}. Truck {truck_name} will collect it.";
}

# removedRouteIds/addedRouteIds/reassigned by comparing each route's exact
# farmerIds list (its "signature") before vs after re-planning - NOT raw
# route ids, which run_merge_routes() reassigns fresh (r1, r2, m1, ...) on
# every call regardless of whether a given group of farmers changed at
# all. A route whose farmer composition is byte-identical before and after
# is untouched and never appears in the diff; same composition but a
# different truck is a reassignment; a composition that only now exists is
# added; one that no longer exists (folded into a bigger group) is removed.
obj DiffParts {
    has removedRouteIds: list[str],
        addedRouteIds: list[str],
        reassigned: list[Reassignment];
}

def _route_signature(r: RouteInfo) -> str {
    return "|".join(r.farmerIds);
}

def _diff_before_after(before: list[RouteInfo], after: list[RouteInfo]) -> DiffParts {
    before_by_sig: dict[str, RouteInfo] = {};
    for r in before {
        before_by_sig[_route_signature(r)] = r;
    }
    after_by_sig: dict[str, RouteInfo] = {};
    for r in after {
        after_by_sig[_route_signature(r)] = r;
    }

    removed_ids: list[str] = [];
    added_ids: list[str] = [];
    reassigned: list[Reassignment] = [];

    for sig in before_by_sig.keys() {
        if sig not in after_by_sig {
            removed_ids.append(before_by_sig[sig].id);
        }
    }
    for sig in after_by_sig.keys() {
        if sig not in before_by_sig {
            added_ids.append(after_by_sig[sig].id);
        } elif before_by_sig[sig].truckId != after_by_sig[sig].truckId {
            reassigned.append(Reassignment(
                routeId=after_by_sig[sig].id,
                fromTruckId=before_by_sig[sig].truckId,
                toTruckId=after_by_sig[sig].truckId,
            ));
        }
    }
    return DiffParts(removedRouteIds=removed_ids, addedRouteIds=added_ids, reassigned=reassigned);
}

def _route_for_harvest(routes: list[RouteInfo], harvest_id: str) -> RouteInfo | None {
    for r in routes {
        if harvest_id in r.harvestIds {
            return r;
        }
    }
    return None;
}

def _handle_new_harvest_event(event: Event) -> ReplanResult {
    before_routes = _current_plan_route_infos();
    before_plans = _current_plan_plan_infos();
    before_score = _aggregate_score_from_routes(before_routes, before_plans);
    baseline_score_now = _aggregate_score(compute_baseline()).baseline;

    text = event.text if event.text is not None else "";
    farmer = _farmer_by_id(event.farmerId);
    parsed = _parse_new_harvest(text);

    if farmer is None or not parsed.ok {
        return ReplanResult(
            diff=Diff(removedRouteIds=[], addedRouteIds=[], reassigned=[], notes=NEW_HARVEST_PARSE_FAILURE_NOTE),
            state=_real_state(routes=before_routes, plans=before_plans),
            score=Score(baseline=baseline_score_now, agent=before_score),
            explanation=NEW_HARVEST_PARSE_FAILURE_NOTE,
            messages=[],
        );
    }

    new_harvest = Harvest(
        crop=parsed.crop, quantity_kg=parsed.quantity_kg, harvested_at="0h",
        shelf_life_hours=CROP_SHELF_LIFE_HOURS.get(parsed.crop, 0.0),
        farmer_id=jid(farmer), ready_hour=parsed.ready_hour,
    );
    root ++> new_harvest;
    new_harvest_id = jid(new_harvest);

    run_merge_routes();

    routes = _current_plan_route_infos();
    plans = _current_plan_plan_infos();
    baseline_score = _aggregate_score(compute_baseline()).baseline;
    agent_score = _aggregate_score_from_routes(routes, plans);

    diff_parts = _diff_before_after(before_routes, routes);
    after_route = _route_for_harvest(routes, new_harvest_id);
    crop_display = _crop_display(parsed.crop);
    truck_name = _truck_plate(after_route.truckId if after_route is not None else None);
    pooled = after_route is not None and len(after_route.farmerIds) > 1;
    verb = "pooled onto" if pooled else "shipping solo on";
    route_label = after_route.id if after_route is not None else "an unassigned route";
    notes = (
        f"Added {parsed.quantity_kg:.0f} kg {crop_display} for {farmer.name}; "
        + f"{verb} truck {truck_name} with route {route_label}."
    );

    diff = Diff(
        removedRouteIds=diff_parts.removedRouteIds,
        addedRouteIds=diff_parts.addedRouteIds,
        reassigned=diff_parts.reassigned,
        notes=notes,
    );

    language = farmer.language if farmer.language in FARMER_MESSAGE_FALLBACKS else "en";
    text_out = _new_harvest_message_text(language, crop_display, parsed.quantity_kg, truck_name);
    is_fallback = True;
    plan_summary = (
        f"Farmer {farmer.name} reported a new harvest: {parsed.quantity_kg:.0f} kg of {crop_display}. "
        + f"It will be collected by truck {truck_name}."
    );
    fallback_text = FARMER_MESSAGE_FALLBACKS.get(language, FARMER_MESSAGE_FALLBACKS["en"]);
    llm_text: str | None = None;
    try {
        llm_text = farmer_message(plan_summary, language);
    } except Exception {
        llm_text = None;
    }
    if llm_text is not None and llm_text.strip() != "" and llm_text != fallback_text {
        text_out = llm_text;
        is_fallback = False;
    }
    message = Message(farmerId=jid(farmer), farmerName=farmer.name, language=language, text=text_out, isFallback=is_fallback);

    return ReplanResult(
        diff=diff,
        state=_real_state(routes=routes, plans=plans),
        score=Score(baseline=baseline_score, agent=agent_score),
        explanation=notes,
        messages=[message],
    );
}

def:pub replan_on_event(event: Event) -> ReplanResult {
    if event.type == "new_harvest" {
        return _handle_new_harvest_event(event);
    }

    # Captured BEFORE apply_replan_event() mutates the current plan, so
    # _build_explanation() can report a real before/after, not before==after.
    before_routes = _current_plan_route_infos();
    before_plans = _current_plan_plan_infos();
    before_score = _aggregate_score_from_routes(before_routes, before_plans);

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

    return ReplanResult(
        diff=diff,
        state=_real_state(routes=routes, plans=plans),
        score=Score(baseline=baseline_score, agent=agent_score),
        explanation=_build_explanation(event, outcome, before_score, agent_score),
        messages=_build_messages(outcome, routes),
    );
}
