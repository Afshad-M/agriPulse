import from api { load_seed, baseline_plan, FarmerInfo, HarvestInfo, HubInfo, MarketInfo, TruckInfo,
    RouteInfo, PlanInfo, State, ScoreSet, Score }

# load_seed() and baseline_plan() are real (api.jac, A). This module is
# pinned "server" in jac.toml's [placement.pins] on purpose: it imports
# logic.jac (via api.jac -> compute_baseline), whose graph-filter syntax
# the client bundler can't lower (E5097) if this file gets inferred
# client. Pinned server + def:pub, fetch_seed/fetch_baseline_plan become
# real RPC endpoints the client bridges to with `await`, same as calling
# load_seed/baseline_plan directly - only now the dict-conversion helpers
# below also run server-side instead of needing FarmerInfo/HarvestInfo
# etc. shipped to the browser.
#
# merge_routes() and replan_on_event() are still STUB server-side; their
# mock-data wrappers live in mock_layer.jac instead, pinned "client" (no
# server imports there, so no reason to pay a network round trip for
# what's just in-browser mock data).
#
# Every fetch_* function across both files returns the same flat dict
# shape regardless of source, tagged "source": "real" | "mock", so the UI
# can show which numbers are genuinely code-computed vs a placeholder -
# the same honesty principle as `isFallback` on LLM-generated messages.

def _farmer_to_dict(f: FarmerInfo) -> dict[str, any] {
    return {"id": f.id, "name": f.name, "district": f.district, "language": f.language};
}

def _harvest_to_dict(h: HarvestInfo) -> dict[str, any] {
    return {"id": h.id, "farmerId": h.farmerId, "crop": h.crop, "kg": h.kg,
            "readyHour": h.readyHour, "shelfLifeHours": h.shelfLifeHours};
}

def _hub_to_dict(h: HubInfo) -> dict[str, any] {
    return {"id": h.id, "name": h.name, "district": h.district};
}

def _market_to_dict(m: MarketInfo) -> dict[str, any] {
    return {"id": m.id, "name": m.name, "prices": m.prices, "demandCapKg": m.demandCapKg};
}

def _truck_to_dict(t: TruckInfo) -> dict[str, any] {
    return {"id": t.id, "name": t.name, "capacityKg": t.capacityKg,
            "costPerKm": t.costPerKm, "status": t.status};
}

def _route_to_dict(r: RouteInfo) -> dict[str, any] {
    return {"id": r.id, "truckId": r.truckId, "farmerIds": r.farmerIds, "hubIds": r.hubIds,
            "marketId": r.marketId, "distanceKm": r.distanceKm, "hours": r.hours};
}

def _plan_to_dict(p: PlanInfo) -> dict[str, any] {
    return {"routeId": p.routeId, "expectedSpoilagePct": p.expectedSpoilagePct,
            "expectedIncome": p.expectedIncome, "truckCost": p.truckCost};
}

def _state_to_dict(s: State) -> dict[str, any] {
    return {
        "farmers": [_farmer_to_dict(f) for f in s.farmers],
        "harvests": [_harvest_to_dict(h) for h in s.harvests],
        "hubs": [_hub_to_dict(h) for h in s.hubs],
        "markets": [_market_to_dict(m) for m in s.markets],
        "trucks": [_truck_to_dict(t) for t in s.trucks],
        "routes": [_route_to_dict(r) for r in s.routes],
        "plans": [_plan_to_dict(p) for p in s.plans]
    };
}

def _score_set_to_dict(ss: ScoreSet) -> dict[str, any] {
    return {"spoilagePct": ss.spoilagePct, "income": ss.income, "truckCost": ss.truckCost};
}

def _score_to_dict(sc: Score) -> dict[str, any] {
    return {"baseline": _score_set_to_dict(sc.baseline), "agent": _score_set_to_dict(sc.agent)};
}

def:pub fetch_seed() -> dict[str, any] {
    result = load_seed();
    return {"state": _state_to_dict(result.state), "source": "real"};
}

def:pub fetch_baseline_plan() -> dict[str, any] {
    result = baseline_plan();
    return {
        "state": _state_to_dict(result.state),
        "score": _score_to_dict(result.score),
        "source": "real"
    };
}
