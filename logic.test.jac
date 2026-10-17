"""agriPulse - Smoke tests for logic.jac (owner: A).

score_route, MergeRoutes and ReplanOnEvent are still stubs - those
assertions are placeholders. score_cargo and compute_baseline are real;
compute_baseline's test builds its own tiny graph fixture and filters by
its own farmer's id rather than asserting on the whole graph's node count,
per jac-testing's guidance on shared, persisted, parallel-run root state -
other tests (e.g. api.test.jac's load_seed) may have their own nodes on
`root` at the same time.
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

test "merge routes walker runs without error" {
    result = root spawn MergeRoutes();
    assert result.reports == [];
}

test "replan on event walker runs without error" {
    result = root spawn ReplanOnEvent(reason="route closed");
    assert result.reports == [];
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
