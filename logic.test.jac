"""agriPulse - Smoke tests for logic.jac (owner: A).

score_route is still a stub - that assertion is a placeholder. score_cargo,
compute_baseline, run_merge_routes, pick_best_merge and
apply_replan_event()'s truck_breakdown handling are real.
pick_replacement_truck is a deliberate stub (see its TODO in logic.jac), so
the tests that need a real replacement-truck choice are EXPECTED TO FAIL
until it's implemented - do not "fix" pick_replacement_truck here to make
them pass.

Every test that touches the graph builds its own tiny fixture and filters
results by its own node identities (jid) rather than asserting on the
whole graph's node count, per jac-testing's guidance on shared, persisted,
parallel-run root state - other tests (e.g. api.test.jac's load_seed) may
have their own nodes on `root` at the same time. Run with JAC_TEST_JOBS=0
for a fully deterministic single run.

The real-12-farmer-seed truck_breakdown test lives in api.test.jac, not
here - it needs load_seed(), and logic.jac cannot import from api.jac
(api.jac already imports from logic.jac; logic.test.jac is an annex of
logic.jac, so importing api back from here is a real circular import, not
just a style choice).
"""

test "score_route stub returns a float" {
    assert score_route(10.0, 1.0, True) == 0.0;
}

test "compute_baseline: solo trip on the smallest fitting truck" {
    hub = Hub(name="Unit Test Hub", capacity_kg=9999.0);
    market = Market(
        name="Unit Test Market", demand_kg=9999.0,
        prices={"test_crop": 100.0},
    );
    big_truck = Truck(plate="UNIT-BIG", capacity_kg=500.0, cost_per_km=5.0);
    small_truck = Truck(plate="UNIT-SMALL", capacity_kg=50.0, cost_per_km=2.0);
    farmer = Farmer(name="Unit Test Farmer");
    harvest = Harvest(crop="test_crop", quantity_kg=40.0, shelf_life_hours=20.0);

    root ++> hub;
    root ++> market;
    root ++> big_truck;
    root ++> small_truck;
    root ++> farmer;
    root ++> harvest;
    hub +>:HubMarketRoute(distance_km=10.0, hours=1.0, open=True):+> market;
    farmer +>:DeliversTo():+> hub;

    routes = compute_baseline();
    mine = [r for r in routes if r.farmer_ids == [jid(farmer)]];
    assert len(mine) == 1;
    route = mine[0];

    # elapsed = waiting_hours(10.0) + leg.hours(1.0) = 11.0; loss = 11/20 = 0.55
    # distanceKm = assumed_farmer_to_hub_km(8.0) + leg.distance_km(10.0) = 18.0
    assert route.truck_id == jid(small_truck);   # smallest truck that still fits 40kg
    assert route.market_id == jid(market);
    assert abs(route.distance_km - 18.0) < 1e-6;
    assert abs(route.hours - 1.0) < 1e-6;
    assert abs(route.spoilage_pct - 55.0) < 1e-6;
    assert abs(route.expected_income - 1800.0) < 1e-6;         # 40 * 100 * 0.45
    assert abs(route.truck_cost - 36.0) < 1e-6;                 # 2.0 cost/km * 18km

    del [edge farmer ->:DeliversTo:-> hub];
    del [edge hub ->:HubMarketRoute:-> market];
    del hub; del market; del big_truck; del small_truck; del farmer; del harvest;
}

test "pick_best_merge: empty list returns None" {
    assert pick_best_merge([]) == None;
}

test "pick_best_merge: every delta zero or negative returns None" {
    candidates = [
        MergeCandidate(idA="r1", idB="r2", delta=0.0, spoilageChangePts=0.0, tripsSaved=1),
        MergeCandidate(idA="r3", idB="r4", delta=-50.0, spoilageChangePts=1.0, tripsSaved=1),
    ];
    assert pick_best_merge(candidates) == None;
}

test "pick_best_merge: returns the highest positive delta" {
    low = MergeCandidate(idA="r1", idB="r2", delta=100.0, spoilageChangePts=-1.0, tripsSaved=1);
    high = MergeCandidate(idA="r3", idB="r4", delta=500.0, spoilageChangePts=-2.0, tripsSaved=1);
    mid = MergeCandidate(idA="r5", idB="r6", delta=200.0, spoilageChangePts=-0.5, tripsSaved=1);
    best = pick_best_merge([low, high, mid]);
    assert best is not None;
    assert best.idA == "r3";
    assert best.idB == "r4";
}

test "pick_best_merge: equal deltas tie-break on the lowest sorted ids" {
    a = MergeCandidate(idA="r3", idB="r4", delta=100.0, spoilageChangePts=0.0, tripsSaved=1);
    b = MergeCandidate(idA="r1", idB="r2", delta=100.0, spoilageChangePts=0.0, tripsSaved=1);
    c = MergeCandidate(idA="r1", idB="r5", delta=100.0, spoilageChangePts=0.0, tripsSaved=1);
    best = pick_best_merge([a, b, c]);
    assert best is not None;
    assert best.idA == "r1";
    assert best.idB == "r2";
}

test "a merge whose combined kg exceeds every truck's capacity is rejected" {
    hub = Hub(name="Capacity Test Hub", capacity_kg=9999.0);
    market = Market(name="Capacity Test Market", demand_kg=9999.0, prices={"test_crop": 50.0});
    truck = Truck(plate="CAP-TEST", capacity_kg=1000.0, cost_per_km=10.0);
    farmer_a = Farmer(name="Capacity Farmer A");
    farmer_b = Farmer(name="Capacity Farmer B");
    harvest_a = Harvest(crop="test_crop", quantity_kg=600.0, shelf_life_hours=72.0);
    harvest_b = Harvest(crop="test_crop", quantity_kg=600.0, shelf_life_hours=72.0);

    root ++> hub;
    root ++> market;
    root ++> truck;
    root ++> farmer_a;
    root ++> farmer_b;
    root ++> harvest_a;
    root ++> harvest_b;
    hub +>:HubMarketRoute(distance_km=5.0, hours=0.2, open=True):+> market;
    farmer_a +>:DeliversTo():+> hub;
    farmer_b +>:DeliversTo():+> hub;

    routes = compute_baseline();
    mine = [r for r in routes if r.farmer_ids == [jid(farmer_a)] or r.farmer_ids == [jid(farmer_b)]];
    assert len(mine) == 2;

    harvest_by_id = _harvest_by_id();
    candidates = _build_merge_candidates(mine, [truck], harvest_by_id);
    # 600kg + 600kg = 1200kg, exceeds the only available truck's 1000kg capacity
    assert len(candidates) == 0;

    del [edge farmer_a ->:DeliversTo:-> hub];
    del [edge farmer_b ->:DeliversTo:-> hub];
    del [edge hub ->:HubMarketRoute:-> market];
    del hub;
    del market;
    del truck;
    del farmer_a;
    del farmer_b;
    del harvest_a;
    del harvest_b;
}

test "the 5-farmer 880kg scenario merges onto one 1000kg truck" {
    hub = Hub(name="Fixture Hub", capacity_kg=9999.0);
    market = Market(name="Fixture Market", demand_kg=9999.0, prices={"tomato": 180.0});
    small_truck = Truck(plate="FIX-1000", capacity_kg=1000.0, cost_per_km=45.0);
    big_truck = Truck(plate="FIX-2000", capacity_kg=2000.0, cost_per_km=75.0);
    root ++> hub;
    root ++> market;
    root ++> small_truck;
    root ++> big_truck;
    hub +>:HubMarketRoute(distance_km=2.0, hours=0.1, open=True):+> market;

    kgs = [180.0, 150.0, 200.0, 160.0, 190.0];  # sums to 880kg, per data.jac's DEMO_MERGE_SCENARIO
    farmers: list[Farmer] = [];
    harvests: list[Harvest] = [];
    for kg in kgs {
        f = Farmer(name="Fixture Farmer");
        h = Harvest(crop="tomato", quantity_kg=kg, shelf_life_hours=72.0);
        root ++> f;
        root ++> h;
        f +>:DeliversTo():+> hub;
        farmers.append(f);
        harvests.append(h);
    }
    farmer_ids = sorted([jid(f) for f in farmers]);

    run_merge_routes();

    plans = [p for p in [root -->][?:Plan] if sorted(p.farmer_ids) == farmer_ids];
    assert len(plans) == 1, "all 5 fixture farmers should land on exactly one merged Plan";
    assert plans[0].truck_id == jid(small_truck);

    del [edge hub ->:HubMarketRoute:-> market];
    for f in farmers {
        del [edge f ->:DeliversTo:-> hub];
    }
    del hub;
    del market;
    del small_truck;
    del big_truck;
    for f in farmers {
        del f;
    }
    for h in harvests {
        del h;
    }
}

#   ---- pick_replacement_truck (stub - see its TODO in logic.jac) ----
#
# "None for empty list" and "None when every truck is too small" pass right
# now because the stub always returns None - they're real negative-case
# pins, not placeholders. "picks the smallest truck that fits" and "equal
# capacities pick the lowest id" need the real body and are EXPECTED TO
# FAIL until it's written - do not "fix" pick_replacement_truck here.

test "pick_replacement_truck: empty list returns None" {
    assert pick_replacement_truck(100.0, []) == None;
}

test "pick_replacement_truck: every truck too small returns None" {
    free = [
        TruckInfo(id="t1", name="Small A", capacityKg=50.0, costPerKm=1.0, status="available"),
        TruckInfo(id="t2", name="Small B", capacityKg=80.0, costPerKm=1.0, status="available"),
    ];
    assert pick_replacement_truck(100.0, free) == None;
}

test "pick_replacement_truck: picks the smallest truck that fits" {
    free = [
        TruckInfo(id="big", name="Big", capacityKg=2000.0, costPerKm=1.0, status="available"),
        TruckInfo(id="fit", name="Fit", capacityKg=500.0, costPerKm=1.0, status="available"),
        TruckInfo(id="small", name="Small", capacityKg=100.0, costPerKm=1.0, status="available"),
    ];
    assert pick_replacement_truck(400.0, free) == "fit";
}

test "pick_replacement_truck: equal capacities tie-break on the lowest id" {
    free = [
        TruckInfo(id="t2", name="B", capacityKg=500.0, costPerKm=1.0, status="available"),
        TruckInfo(id="t1", name="A", capacityKg=500.0, costPerKm=1.0, status="available"),
    ];
    assert pick_replacement_truck(400.0, free) == "t1";
}

#   ---- apply_replan_event / truck_breakdown -------------------------
#
# Each test builds its own tiny fixture under root and cleans it up, per
# jac-testing's guidance - run_merge_routes()/apply_truck_breakdown_event()
# both read the WHOLE graph under root, so these fixtures must not rely on
# any other test's nodes still being there, and must remove their own nodes
# (Plan nodes from run_merge_routes() included) when done.

def _cleanup_plans() -> None {
    for p in [root -->][?:Plan] {
        del p;
    }
}

test "apply_replan_event: unknown event type is a documented no-op" {
    outcome = apply_replan_event("road_closed");
    assert outcome.diff.removedRouteIds == [];
    assert outcome.diff.addedRouteIds == [];
    assert outcome.diff.reassigned == [];
    assert outcome.diff.notes == "Event type road_closed is not handled yet";

    outcome2 = apply_replan_event("totally_bogus_type");
    assert outcome2.diff.removedRouteIds == [];
    assert outcome2.diff.notes == "Event type totally_bogus_type is not handled yet";
}

test "apply_replan_event: truck_breakdown with an unknown truckId never crashes" {
    outcome = apply_replan_event("truck_breakdown", "no-such-truck-id");
    assert outcome.diff.removedRouteIds == [];
    assert outcome.diff.addedRouteIds == [];
    assert outcome.diff.reassigned == [];
    assert "no-such-truck-id" in outcome.diff.notes;

    outcome2 = apply_replan_event("truck_breakdown", None);
    assert outcome2.diff.removedRouteIds == [];
}

test "truck_breakdown with no spare truck or route: route removed, farmers unserved, no crash" {
    hub = Hub(name="Breakdown Hub", capacity_kg=9999.0);
    market = Market(name="Breakdown Market", demand_kg=9999.0, prices={"tomato": 100.0});
    lone_truck = Truck(plate="LONE-TRUCK", capacity_kg=200.0, cost_per_km=10.0);
    farmer = Farmer(name="Breakdown Farmer");
    harvest = Harvest(crop="tomato", quantity_kg=150.0, shelf_life_hours=48.0);

    root ++> hub;
    root ++> market;
    root ++> lone_truck;
    root ++> farmer;
    root ++> harvest;
    hub +>:HubMarketRoute(distance_km=5.0, hours=0.2, open=True):+> market;
    farmer +>:DeliversTo():+> hub;

    truck_id = jid(lone_truck);
    farmer_id = jid(farmer);

    outcome = apply_replan_event("truck_breakdown", truck_id);

    assert lone_truck.status == "broken";
    assert len(outcome.diff.removedRouteIds) >= 1;
    assert outcome.diff.addedRouteIds == [];
    assert outcome.diff.reassigned == [];
    assert farmer.name in outcome.diff.notes;    # notes show farmer NAMES, not ids
    assert farmer_id not in outcome.diff.notes;
    assert "unserved" in outcome.diff.notes;
    assert len(outcome.messages) == 1;
    message = outcome.messages[0];
    assert message.farmerId == farmer_id;
    assert message.isFallback == True;

    # no surviving route should still point at the broken truck
    for p in [root -->][?:Plan] {
        assert p.truck_id != truck_id;
    }

    _cleanup_plans();
    del [edge farmer ->:DeliversTo:-> hub];
    del [edge hub ->:HubMarketRoute:-> market];
    del hub; del market; del lone_truck; del farmer; del harvest;
}

test "truck_breakdown: calling the same event twice gives identical results" {
    hub = Hub(name="Idempotent Hub", capacity_kg=9999.0);
    market = Market(name="Idempotent Market", demand_kg=9999.0, prices={"tomato": 100.0});
    lone_truck = Truck(plate="IDEMP-TRUCK", capacity_kg=200.0, cost_per_km=10.0);
    farmer = Farmer(name="Idempotent Farmer");
    harvest = Harvest(crop="tomato", quantity_kg=150.0, shelf_life_hours=48.0);

    root ++> hub;
    root ++> market;
    root ++> lone_truck;
    root ++> farmer;
    root ++> harvest;
    hub +>:HubMarketRoute(distance_km=5.0, hours=0.2, open=True):+> market;
    farmer +>:DeliversTo():+> hub;

    truck_id = jid(lone_truck);

    first = apply_replan_event("truck_breakdown", truck_id);
    second = apply_replan_event("truck_breakdown", truck_id);

    assert sorted(first.diff.removedRouteIds) == sorted(second.diff.removedRouteIds);
    assert sorted(first.diff.addedRouteIds) == sorted(second.diff.addedRouteIds);
    assert first.diff.notes == second.diff.notes;
    assert lone_truck.status == "broken";

    _cleanup_plans();
    del [edge farmer ->:DeliversTo:-> hub];
    del [edge hub ->:HubMarketRoute:-> market];
    del hub; del market; del lone_truck; del farmer; del harvest;
}

test "truck_breakdown on a merged route: reassigns to the spare truck" {
    # Mirrors the 5-farmer 880kg demo scenario: two farmers merge onto the
    # smallest fitting truck, which then breaks down with a bigger spare
    # truck free. pick_replacement_truck picks that spare, so this reassigns
    # (>=1 removed, >=1 added, >=1 reassigned record) instead of falling
    # back to "unserved".
    hub = Hub(name="Reassign Hub", capacity_kg=9999.0);
    market = Market(name="Reassign Market", demand_kg=9999.0, prices={"tomato": 100.0});
    small_truck = Truck(plate="REASSIGN-SMALL", capacity_kg=500.0, cost_per_km=10.0);
    spare_truck = Truck(plate="REASSIGN-SPARE", capacity_kg=2000.0, cost_per_km=20.0);
    farmer_a = Farmer(name="Reassign Farmer A");
    farmer_b = Farmer(name="Reassign Farmer B");
    harvest_a = Harvest(crop="tomato", quantity_kg=200.0, shelf_life_hours=72.0);
    harvest_b = Harvest(crop="tomato", quantity_kg=150.0, shelf_life_hours=72.0);

    root ++> hub;
    root ++> market;
    root ++> small_truck;
    root ++> spare_truck;
    root ++> farmer_a;
    root ++> farmer_b;
    root ++> harvest_a;
    root ++> harvest_b;
    hub +>:HubMarketRoute(distance_km=5.0, hours=0.2, open=True):+> market;
    farmer_a +>:DeliversTo():+> hub;
    farmer_b +>:DeliversTo():+> hub;

    outcome = apply_replan_event("truck_breakdown", jid(small_truck));

    assert len(outcome.diff.removedRouteIds) >= 1;
    assert len(outcome.diff.addedRouteIds) >= 1;
    assert len(outcome.diff.reassigned) >= 1;
    assert "No farmers are unserved." in outcome.diff.notes;

    # structural check: both farmers got the "reassigned" template, not
    # the "unserved" one - no farmer id was dropped into an unserved list.
    assert len(outcome.messages) == 2;
    for m in outcome.messages {
        assert m.text == BREAKDOWN_MESSAGE_TEMPLATES["en:reassigned"];
    }

    _cleanup_plans();
    del [edge farmer_a ->:DeliversTo:-> hub];
    del [edge farmer_b ->:DeliversTo:-> hub];
    del [edge hub ->:HubMarketRoute:-> market];
    del hub; del market; del small_truck; del spare_truck;
    del farmer_a; del farmer_b; del harvest_a; del harvest_b;
}

# score_cargo: pins the spoilage/revenue/value formula (now implemented).

test "score_cargo: partial spoilage over shelf life" {
    result = score_cargo(100.0, 120.0, 18.0, 72.0, 2000.0);
    assert abs(result.loss - 0.25) < 1e-6;
    assert abs(result.revenue - 9000.0) < 1e-6;
    assert abs(result.value - 7000.0) < 1e-6;
}

test "score_cargo: fully spoiled once elapsed exceeds shelf life" {
    result = score_cargo(100.0, 120.0, 80.0, 72.0, 2000.0);
    assert abs(result.loss - 1.0) < 1e-6;
    assert abs(result.revenue - 0.0) < 1e-6;
    assert abs(result.value - (-2000.0)) < 1e-6;
}

test "score_cargo: zero kg does not crash and nets out to minus truck cost" {
    result = score_cargo(0.0, 120.0, 18.0, 72.0, 2000.0);
    assert abs(result.revenue - 0.0) < 1e-6;
    assert abs(result.value - (-2000.0)) < 1e-6;
}

test "score_cargo: zero shelf life does not crash and is treated as fully spoiled" {
    result = score_cargo(100.0, 120.0, 18.0, 0.0, 2000.0);
    assert abs(result.loss - 1.0) < 1e-6;
    assert abs(result.revenue - 0.0) < 1e-6;
}
