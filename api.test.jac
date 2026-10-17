"""agriPulse - Shape tests for api.jac contract endpoints (owner: A).

CONTRACT v1 shape checks against the current STUB placeholder seed. These
assert every required key exists with the right type and that required
lists are non-empty - they do NOT assert real scoring/merge/replan values,
since none of that logic exists yet.
"""

test "load_seed matches contract shape" {
    result = load_seed();
    assert isinstance(result, LoadSeedResult);
    assert isinstance(result.state, State);

    state = result.state;
    assert len(state.farmers) == 3;
    assert len(state.harvests) == 3;
    assert len(state.hubs) == 2;
    assert len(state.markets) == 1;
    assert len(state.trucks) == 2;
    assert len(state.routes) > 0;
    assert len(state.plans) > 0;

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

    route = state.routes[0];
    assert isinstance(route.truckId, str);
    assert isinstance(route.farmerIds, list);
    assert isinstance(route.hubIds, list);
    assert isinstance(route.marketId, str);
    assert isinstance(route.distanceKm, float);
    assert isinstance(route.hours, float);

    plan = state.plans[0];
    assert isinstance(plan.routeId, str);
    assert isinstance(plan.expectedSpoilagePct, float);
    assert isinstance(plan.expectedIncome, float);
    assert isinstance(plan.truckCost, float);
}

test "baseline_plan matches contract shape" {
    result = baseline_plan();
    assert isinstance(result, BaselinePlanResult);
    assert isinstance(result.state, State);
    assert len(result.state.routes) > 0;

    assert isinstance(result.score, Score);
    assert isinstance(result.score.baseline, ScoreSet);
    assert isinstance(result.score.agent, ScoreSet);
    assert isinstance(result.score.baseline.spoilagePct, float);
    assert isinstance(result.score.baseline.income, float);
    assert isinstance(result.score.baseline.truckCost, float);
    assert isinstance(result.score.agent.spoilagePct, float);
}

test "merge_routes matches contract shape" {
    result = merge_routes();
    assert isinstance(result, MergeRoutesResult);

    assert len(result.steps) == 2;
    step = result.steps[0];
    assert isinstance(step.stepNo, int);
    assert isinstance(step.mergedRouteIds, list);
    assert isinstance(step.newRouteId, str);
    assert isinstance(step.reason, str);

    assert isinstance(result.state, State);
    assert len(result.state.routes) > 0;
    assert isinstance(result.score, Score);
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
