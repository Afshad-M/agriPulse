"""agriPulse - Shape tests for api.jac contract endpoints (owner: A).

load_seed(), baseline_plan() and merge_routes() are real (build/read the
actual graph from data.jac's 50-farmer seed - the original 12-farmer/
4-hub/3-market/3-truck fixture plus a second, separate island-wide
component with no route back into it; see data.jac's module docstring).
replan_on_event() is real
for "truck_breakdown"; every other event type is still a documented no-op
(see logic.jac). logic.pick_replacement_truck() is a deliberate stub, so
tests needing a real truck reassignment are EXPECTED TO FAIL until it's
implemented - do not "fix" it here.

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
    assert len(state.farmers) == 50;
    assert len(state.harvests) == 50;
    assert len(state.hubs) == 9;
    assert len(state.markets) == 7;
    assert len(state.trucks) == 9;
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
    assert len(first.farmers) == len(second.farmers) == 50;
    assert len(first.harvests) == len(second.harvests) == 50;
    assert len(first.hubs) == len(second.hubs) == 9;
    assert len(first.markets) == len(second.markets) == 7;
    assert len(first.trucks) == len(second.trucks) == 9;
}

test "baseline_plan matches contract shape" {
    load_seed();
    result = baseline_plan();
    assert isinstance(result, BaselinePlanResult);
    assert isinstance(result.state, State);
    assert len(result.state.routes) == 50;
    assert len(result.state.plans) == 50;

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
    load_seed();
    merged = merge_routes();
    truck_id = merged.state.routes[0].truckId;

    event = Event(type="truck_breakdown", truckId=truck_id);
    result = replan_on_event(event);
    assert isinstance(result, ReplanResult);

    assert isinstance(result.diff, Diff);
    assert isinstance(result.diff.removedRouteIds, list);
    assert isinstance(result.diff.addedRouteIds, list);
    assert isinstance(result.diff.reassigned, list);
    assert isinstance(result.diff.notes, str);

    assert isinstance(result.state, State);
    assert isinstance(result.score, Score);
    assert isinstance(result.score.agent.spoilagePct, float);
    assert 0.0 <= result.score.agent.spoilagePct <= 100.0;
    assert isinstance(result.explanation, str);

    assert isinstance(result.messages, list);
    for message in result.messages {
        assert isinstance(message.farmerId, str);
        assert isinstance(message.farmerName, str);
        assert isinstance(message.language, str);
        assert isinstance(message.text, str);
        assert message.isFallback;
    }
    for plan in result.state.plans {
        assert 0.0 <= plan.expectedSpoilagePct <= 100.0;
    }
}

test "replan_on_event: truck_breakdown with an unknown truckId is a no-op with a note" {
    load_seed();
    event = Event(type="truck_breakdown", truckId="no-such-truck");
    result = replan_on_event(event);
    assert isinstance(result, ReplanResult);
    assert result.diff.removedRouteIds == [];
    assert result.diff.addedRouteIds == [];
    assert result.diff.reassigned == [];
    assert "no-such-truck" in result.diff.notes;
}

test "replan_on_event accepts an event with only its type set" {
    load_seed();
    event = Event(type="price_crash");
    result = replan_on_event(event);
    assert isinstance(result, ReplanResult);
    assert event.truckId == None;
    assert event.marketId == None;
    assert result.diff.notes == "Event type price_crash is not handled yet";
}

test "replan_on_event: the same truck_breakdown event twice gives identical results" {
    load_seed();
    merged = merge_routes();
    truck_id = merged.state.routes[0].truckId;

    event = Event(type="truck_breakdown", truckId=truck_id);
    first = replan_on_event(event);
    second = replan_on_event(event);

    assert sorted(first.diff.removedRouteIds) == sorted(second.diff.removedRouteIds);
    assert sorted(first.diff.addedRouteIds) == sorted(second.diff.addedRouteIds);
    assert first.diff.notes == second.diff.notes;
    assert abs(first.score.agent.spoilagePct - second.score.agent.spoilagePct) < 1e-6;

    broken = [t for t in second.state.trucks if t.id == truck_id][0];
    assert broken.status == "broken";

    # load_seed() rebuilds Truck nodes from scratch (new ids too), so it
    # resets every truck's status rather than reviving this specific id.
    reloaded = load_seed();
    assert len([t for t in reloaded.state.trucks if t.status == "broken"]) == 0;
}

test "truck_breakdown on the real seed: breaking the truck behind the original 12-farmer merge leaves 0 unserved" {
    # merge_routes() over the original 12-farmer fixture (Dambulla/Nuwara
    # Eliya/Kandy/Matale) always produces four merged routes, one per hub -
    # 390/190/500/880 kg - all landing on WP CAB-1001, the smallest truck in
    # the whole fleet, since every one of those loads still fits under its
    # 1000kg cap. Breaking that truck therefore affects all 12 farmers /
    # 1960kg total at once. The only other original-fleet trucks are
    # CP CAB-1500 (1500kg) and MH CAB-2000 (2000kg) - 3500kg of spare
    # capacity, comfortably more than the 1960kg that needs a new home - so
    # with the biggest route (880kg) given first pick of the free trucks,
    # and the smaller routes then folding onto spare capacity (direct or
    # already-reassigned), every farmer should end up served.
    #
    # The expanded (50-farmer) seed adds a second, separate island-wide
    # component with its own hubs/markets, kept unreachable from this one
    # (see data.jac's module docstring) so it can never merge WITH these
    # routes - but run_merge_routes()'s merge-id counter ("m1", "m2", ...)
    # is one global sequence across the whole graph, so which literal ids
    # this fixture's four routes land on now depends on merge order
    # island-wide. Identify them by FARMER membership instead - that's
    # invariant to the rest of the graph - not by a hardcoded id list. If a
    # future seed or assumptions change ever breaks this math, this test
    # documents the exact numbers so a human can look instead of silently
    # forcing it.
    load_seed();
    merged = merge_routes();

    original_farmer_names = [
        "Kamal Perera", "Nimal Silva", "Sunil Fernando", "Ranjan Gunawardena", "Chaminda Rathnayake",
        "Priyantha Jayasuriya", "Mahinda Wickramasinghe",
        "Susantha Dissanayake", "Anura Bandara",
        "Gayan Senanayake", "Nalin Kumara", "Lasantha Weerasinghe",
    ];
    original_farmer_ids = set([f.id for f in merged.state.farmers if f.name in original_farmer_names]);
    assert len(original_farmer_ids) == 12, "original 12-farmer fixture no longer resolves by name";

    target_routes = [
        r for r in merged.state.routes
        if len(r.farmerIds) > 1 and set(r.farmerIds).issubset(original_farmer_ids)
    ];
    assert len(target_routes) == 4, "seed/merge shape changed - the original fixture no longer merges into 4 routes";

    truck_ids = set([r.truckId for r in target_routes]);
    assert len(truck_ids) == 1, "m1/m3/m6/m8 are expected to all share one truck in this seed";
    broken_truck_id = list(truck_ids)[0];

    event = Event(type="truck_breakdown", truckId=broken_truck_id);
    result = replan_on_event(event);

    assert "No farmers are unserved." in result.diff.notes;
    total_affected_farmers = sum([len(r.farmerIds) for r in target_routes]);
    assert len(result.messages) == total_affected_farmers;
    for message in result.messages {
        assert message.isFallback;
    }
}

# replan_on_event's LLM hookup (explain()/farmer_message(), api.jac) is
# exercised by every test above already, on the fallback path (no API key
# in this environment - see .env.example/jac.toml's [byllm.model]), since
# that is the only path `jac test` can run without network/secrets. This
# test additionally builds its own tiny fixture (same convention as
# logic.test.jac's apply_replan_event tests) with an UNTOUCHED third
# farmer on a separate hub/market/truck, specifically to pin that
# replan_on_event only ever builds a Message for an AFFECTED farmer - not
# every farmer on the graph, which load_seed()'s fixed 12-farmer seed can't
# by itself distinguish (see the test above: that breakdown happens to hit
# all 12).
test "replan_on_event: messages are scoped to affected farmers only" {
    hub = Hub(name="Scoped Hub", capacity_kg=9999.0);
    other_hub = Hub(name="Scoped Other Hub", capacity_kg=9999.0);
    market = Market(name="Scoped Market", demand_kg=9999.0, prices={"tomato": 100.0});
    other_market = Market(name="Scoped Other Market", demand_kg=9999.0, prices={"tomato": 100.0});
    small_truck = Truck(plate="SCOPED-SMALL", capacity_kg=500.0, cost_per_km=10.0);
    spare_truck = Truck(plate="SCOPED-SPARE", capacity_kg=2000.0, cost_per_km=20.0);
    # Deliberately too small for farmer_a/b's kg (200/150) so
    # _smallest_fitting_truck() (logic.jac) can never pick it for them -
    # compute_baseline() picks the smallest-fitting truck GLOBALLY, with no
    # concept of hub/market grouping, so without this farmer_c would tie
    # with farmer_a/b for small_truck and get swept into the same breakdown.
    untouched_truck = Truck(plate="SCOPED-UNTOUCHED", capacity_kg=80.0, cost_per_km=10.0);
    farmer_a = Farmer(name="Scoped Farmer A", language="en");
    farmer_b = Farmer(name="Scoped Farmer B", language="en");
    farmer_c = Farmer(name="Scoped Farmer C", language="en");
    harvest_a = Harvest(crop="tomato", quantity_kg=200.0, shelf_life_hours=72.0);
    harvest_b = Harvest(crop="tomato", quantity_kg=150.0, shelf_life_hours=72.0);
    harvest_c = Harvest(crop="tomato", quantity_kg=50.0, shelf_life_hours=72.0);

    root ++> hub;
    root ++> other_hub;
    root ++> market;
    root ++> other_market;
    root ++> small_truck;
    root ++> spare_truck;
    root ++> untouched_truck;
    root ++> farmer_a;
    root ++> farmer_b;
    root ++> farmer_c;
    root ++> harvest_a;
    root ++> harvest_b;
    root ++> harvest_c;
    hub +>:HubMarketRoute(distance_km=5.0, hours=0.2, open=True):+> market;
    other_hub +>:HubMarketRoute(distance_km=5.0, hours=0.2, open=True):+> other_market;
    farmer_a +>:DeliversTo():+> hub;
    farmer_b +>:DeliversTo():+> hub;
    farmer_c +>:DeliversTo():+> other_hub;

    event = Event(type="truck_breakdown", truckId=jid(small_truck));
    result = replan_on_event(event);

    farmer_c_id = jid(farmer_c);
    message_farmer_ids = [m.farmerId for m in result.messages];
    assert farmer_c_id not in message_farmer_ids;   # untouched farmer gets no message
    assert len(result.messages) == 2;                # only farmer_a and farmer_b were affected

    for message in result.messages {
        assert isinstance(message.farmerId, str);
        assert isinstance(message.farmerName, str);
        assert isinstance(message.language, str);
        assert message.text.strip() != "";           # every message has non-empty text
        assert message.isFallback;                    # no API key here - fallback path
    }
    assert isinstance(result.explanation, str);
    assert result.explanation.strip() != "";

    for p in [root -->][?:Plan] {
        del p;
    }
    del [edge farmer_a ->:DeliversTo:-> hub];
    del [edge farmer_b ->:DeliversTo:-> hub];
    del [edge farmer_c ->:DeliversTo:-> other_hub];
    del [edge hub ->:HubMarketRoute:-> market];
    del [edge other_hub ->:HubMarketRoute:-> other_market];
    del hub; del other_hub; del market; del other_market;
    del small_truck; del spare_truck; del untouched_truck;
    del farmer_a; del farmer_b; del farmer_c;
    del harvest_a; del harvest_b; del harvest_c;
}

#   ---- parse_harvest_text (deterministic, no LLM, no API key needed) ----

test "parse_harvest_text: '80kg beans, ready in 2 hours'" {
    result = parse_harvest_text("80kg beans, ready in 2 hours");
    assert result.ok;
    assert result.crop == "beans";
    assert abs(result.quantity_kg - 80.0) < 1e-6;
    assert abs(result.ready_hour - 2.0) < 1e-6;
}

test "parse_harvest_text: '200 kg tomatoes'" {
    result = parse_harvest_text("200 kg tomatoes");
    assert result.ok;
    assert result.crop == "tomato";
    assert abs(result.quantity_kg - 200.0) < 1e-6;
    assert abs(result.ready_hour - 0.0) < 1e-6;   # no "ready" clause - defaults to 0
}

test "parse_harvest_text: '50 kilos of carrot ready in 5 hours'" {
    result = parse_harvest_text("50 kilos of carrot ready in 5 hours");
    assert result.ok;
    assert result.crop == "carrot";
    assert abs(result.quantity_kg - 50.0) < 1e-6;
    assert abs(result.ready_hour - 5.0) < 1e-6;
}

test "parse_harvest_text: leafy greens, plain 'ready' (no 'in') still reads the hours" {
    result = parse_harvest_text("90 kg leafy greens ready 3 hours");
    assert result.ok;
    assert result.crop == "leafy_greens";
    assert abs(result.quantity_kg - 90.0) < 1e-6;
    assert abs(result.ready_hour - 3.0) < 1e-6;
}

test "parse_harvest_text: garbage text never crashes and fails to parse" {
    result = parse_harvest_text("asdf qwerty zzz lorem ipsum");
    assert not result.ok;
}

test "parse_harvest_text: empty text never crashes and fails to parse" {
    result = parse_harvest_text("");
    assert not result.ok;
    assert abs(result.quantity_kg - 0.0) < 1e-6;
}

#   ---- new_harvest event (api.jac) --------------------------------------
#
# No API key in this environment (see .env.example/jac.toml's
# [byllm.model]), so llm.parse_harvest()/llm.farmer_message() both run on
# their own fallback path - these tests exercise the DETERMINISTIC parser
# and DETERMINISTIC message template end to end, per CLAUDE.md ("the LLM
# is never required").

test "new_harvest: adds a harvest, returns a non-empty diff and a message for that farmer" {
    seeded = load_seed().state;
    farmer = seeded.farmers[0];

    event = Event(type="new_harvest", farmerId=farmer.id, text="80kg beans, ready in 2 hours");
    result = replan_on_event(event);

    assert isinstance(result, ReplanResult);
    assert len(result.state.harvests) == 51;   # the 50 seeded + this one
    matching = [h for h in result.state.harvests if h.farmerId == farmer.id and h.crop == "beans"];
    assert len(matching) == 1;
    assert abs(matching[0].kg - 80.0) < 1e-6;

    assert result.diff.notes.strip() != "";
    assert farmer.name in result.diff.notes;
    assert "beans" in result.diff.notes;

    assert len(result.messages) == 1;
    message = result.messages[0];
    assert message.farmerId == farmer.id;
    assert message.isFallback;   # no API key here - deterministic template
    assert message.text.strip() != "";
}

test "new_harvest: unknown input returns the note without crashing and without changing state" {
    seeded = load_seed().state;
    farmer = seeded.farmers[0];

    event = Event(type="new_harvest", farmerId=farmer.id, text="the quick brown fox");
    result = replan_on_event(event);

    assert isinstance(result, ReplanResult);
    assert result.diff.removedRouteIds == [];
    assert result.diff.addedRouteIds == [];
    assert result.diff.reassigned == [];
    assert result.diff.notes == "I couldn't understand that. Try: 80kg beans, ready in 2 hours.";
    assert result.messages == [];

    after = load_seed().state;   # re-seed just to count - new_harvest above must not have added anything
    assert len(after.harvests) == 50;
}

test "new_harvest: load_seed after a new_harvest restores the baseline" {
    seeded = load_seed().state;
    farmer = seeded.farmers[0];

    event = Event(type="new_harvest", farmerId=farmer.id, text="80kg beans, ready in 2 hours");
    replan_on_event(event);

    reloaded = load_seed();
    assert len(reloaded.state.harvests) == 50;
    assert len(reloaded.state.farmers) == 50;

    base = baseline_plan();
    assert len(base.state.routes) == 50;
}
