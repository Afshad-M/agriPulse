"""agriPulse - Shape tests for api.jac contract endpoints (owner: A).

load_seed() and baseline_plan() are real now (build/read the actual graph
from data.jac's 12-farmer seed); merge_routes()/replan_on_event() are
still STUB and keep asserting on the fixed placeholder seed.

These tests share `root` with every other test file (jac-testing: parallel
workers, persisted graph) - run with JAC_TEST_JOBS=0 for a clean run, since
load_seed() wipes/rebuilds the Farmer/Harvest/Hub/Market/Truck node types
that other test files (models.test.jac, logic.test.jac) also touch.
"""

test "load_seed matches contract shape" {
    result = load_seed();
    assert isinstance(result, LoadSeedResult);
    assert isinstance(result.state, State);

    state = result.state;
    assert len(state.farmers) == 12;
    assert len(state.harvests) == 12;
    assert len(state.hubs) == 4;
    assert len(state.markets) == 3;
    assert len(state.trucks) == 3;
    assert len(state.routes) == 0;   # nothing planned yet - that's baseline_plan()'s job
    assert len(state.plans) == 0;

    farmer = state.farmers[0];
    assert isinstance(farmer.id, str);
    assert isinstance(farmer.name, str);
    assert isinstance(farmer.district, str);
    assert isinstance(farmer.language, str);

    harvest = state.harvests[0];
    assert isinstance(harvest.farmerId, str);
    assert isinstance(harvest.crop, str);
    assert isinstance(harvest.kg, float);
    assert isinstance(harvest.readyHour, float);
    assert isinstance(harvest.shelfLifeHours, float);

    hub = state.hubs[0];
    assert isinstance(hub.name, str);
    assert isinstance(hub.district, str);

    market = state.markets[0];
    assert isinstance(market.prices, dict);
    assert isinstance(market.demandCapKg, float);

    truck = state.trucks[0];
    assert isinstance(truck.capacityKg, float);
    assert isinstance(truck.costPerKm, float);
    assert isinstance(truck.status, str);
}

test "load_seed is idempotent: same counts on repeat calls, no duplicates" {
    first = load_seed().state;
    second = load_seed().state;
    assert len(first.farmers) == len(second.farmers) == 12;
    assert len(first.harvests) == len(second.harvests) == 12;
    assert len(first.hubs) == len(second.hubs) == 4;
    assert len(first.markets) == len(second.markets) == 3;
    assert len(first.trucks) == len(second.trucks) == 3;
}

test "baseline_plan matches contract shape" {
    load_seed();
    result = baseline_plan();
    assert isinstance(result, BaselinePlanResult);
    assert isinstance(result.state, State);
    assert len(result.state.routes) == 12;
    assert len(result.state.plans) == 12;

    route = result.state.routes[0];
    assert isinstance(route.truckId, str);
    assert isinstance(route.farmerIds, list);
    assert isinstance(route.hubIds, list);
    assert isinstance(route.marketId, str);
    assert isinstance(route.distanceKm, float);
    assert isinstance(route.hours, float);

    plan = result.state.plans[0];
    assert isinstance(plan.routeId, str);
    assert isinstance(plan.expectedSpoilagePct, float);
    assert isinstance(plan.expectedIncome, float);
    assert isinstance(plan.truckCost, float);

    assert isinstance(result.score, Score);
    assert isinstance(result.score.baseline, ScoreSet);
    assert isinstance(result.score.agent, ScoreSet);
    assert isinstance(result.score.baseline.spoilagePct, float);
    assert isinstance(result.score.baseline.income, float);
    assert isinstance(result.score.baseline.truckCost, float);
    assert isinstance(result.score.agent.spoilagePct, float);
}

test "baseline_plan: every harvest appears in exactly one route" {
    load_seed();
    result = baseline_plan();
    state = result.state;

    for harvest in state.harvests {
        matching = [
            r for r in state.routes
            if harvest.farmerId in r.farmerIds
        ];
        assert len(matching) == 1, f"harvest {harvest.id} should be on exactly one route";
    }
}

test "baseline_plan: spoilagePct is 0-100, income and truckCost are positive" {
    load_seed();
    result = baseline_plan();

    assert 0.0 <= result.score.baseline.spoilagePct <= 100.0;
    assert result.score.baseline.income > 0.0;
    assert result.score.baseline.truckCost > 0.0;

    for plan in result.state.plans {
        assert 0.0 <= plan.expectedSpoilagePct <= 100.0;
        assert plan.expectedIncome > 0.0;
        assert plan.truckCost > 0.0;
    }
}

test "baseline_plan: no route exceeds its truck's capacityKg" {
    load_seed();
    result = baseline_plan();
    state = result.state;

    truck_by_id: dict[str, TruckInfo] = {};
    for t in state.trucks { truck_by_id[t.id] = t; }
    harvest_by_farmer_id: dict[str, HarvestInfo] = {};
    for h in state.harvests { harvest_by_farmer_id[h.farmerId] = h; }

    for route in state.routes {
        truck = truck_by_id[route.truckId];
        harvest = harvest_by_farmer_id[route.farmerIds[0]];
        assert harvest.kg <= truck.capacityKg;
    }
}

test "merge_routes matches contract shape" {
    load_seed();
    result = merge_routes();
    assert isinstance(result, MergeRoutesResult);

    assert isinstance(result.steps, list);
    if len(result.steps) > 0 {
        step = result.steps[0];
        assert isinstance(step.stepNo, int);
        assert isinstance(step.mergedRouteIds, list);
        assert isinstance(step.newRouteId, str);
        assert isinstance(step.reason, str);
    }

    assert isinstance(result.state, State);
    assert len(result.state.routes) > 0;
    assert len(result.state.plans) > 0;
    assert isinstance(result.score, Score);
    assert isinstance(result.score.baseline, ScoreSet);
    assert isinstance(result.score.agent, ScoreSet);
}

test "merge_routes on the real seed: agent beats baseline on net value and spoilage" {
    # EXPECTED TO FAIL until pick_best_merge is implemented: with no merges
    # applied, agent == baseline, so the strict inequalities below don't hold.
    load_seed();
    result = merge_routes();
    agent = result.score.agent;
    baseline = result.score.baseline;

    assert (agent.income - agent.truckCost) > (baseline.income - baseline.truckCost);
    assert agent.spoilagePct < baseline.spoilagePct;
}

test "merge_routes on the real seed: no route exceeds its truck's capacityKg" {
    load_seed();
    result = merge_routes();
    state = result.state;

    truck_by_id: dict[str, TruckInfo] = {};
    for t in state.trucks { truck_by_id[t.id] = t; }
    kg_by_farmer_id: dict[str, float] = {};
    for h in state.harvests { kg_by_farmer_id[h.farmerId] = h.kg; }

    for route in state.routes {
        truck = truck_by_id[route.truckId];
        combined_kg = 0.0;
        for fid in route.farmerIds { combined_kg += kg_by_farmer_id.get(fid, 0.0); }
        assert combined_kg <= truck.capacityKg;
    }
}

test "merge_routes on the real seed: every harvest is in exactly one route" {
    load_seed();
    result = merge_routes();
    state = result.state;

    for harvest in state.harvests {
        matching = [r for r in state.routes if harvest.farmerId in r.farmerIds];
        assert len(matching) == 1, f"harvest {harvest.id} should be on exactly one route";
    }
}

test "merge_routes is deterministic: calling it twice gives identical results" {
    load_seed();
    first = merge_routes();
    second = merge_routes();

    first_ids = sorted([r.id for r in first.state.routes]);
    second_ids = sorted([r.id for r in second.state.routes]);
    assert first_ids == second_ids;
    assert len(first.steps) == len(second.steps);
    assert abs(first.score.agent.income - second.score.agent.income) < 1e-6;
    assert abs(first.score.agent.spoilagePct - second.score.agent.spoilagePct) < 1e-6;
    assert abs(first.score.agent.truckCost - second.score.agent.truckCost) < 1e-6;
}

test "replan_on_event matches contract shape" {
    event = Event(type="truck_breakdown", truckId="t1");
    result = replan_on_event(event);
    assert isinstance(result, ReplanResult);

    assert isinstance(result.diff, Diff);
    assert isinstance(result.diff.removedRouteIds, list);
    assert isinstance(result.diff.addedRouteIds, list);
    assert isinstance(result.diff.reassigned, list);
    reassignment = result.diff.reassigned[0];
    assert isinstance(reassignment.routeId, str);
    assert isinstance(reassignment.fromTruckId, str);
    assert isinstance(reassignment.toTruckId, str);
    assert isinstance(result.diff.notes, str);

    assert isinstance(result.state, State);
    assert isinstance(result.score, Score);
    assert isinstance(result.explanation, str);

    assert len(result.messages) == 1;
    message = result.messages[0];
    assert isinstance(message.farmerId, str);
    assert isinstance(message.farmerName, str);
    assert isinstance(message.language, str);
    assert isinstance(message.text, str);
    assert message.isFallback == True;
}

test "replan_on_event accepts an event with only its type set" {
    event = Event(type="price_crash");
    result = replan_on_event(event);
    assert isinstance(result, ReplanResult);
    assert event.truckId == None;
    assert event.marketId == None;
}
